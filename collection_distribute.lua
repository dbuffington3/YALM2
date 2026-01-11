--[[
    Collection Item Distributor
    
    Scans your inventory for collectible items and distributes them to characters
    who need them based on the collection_needs database.
    
    Usage: /lua run yalm2/collection_distribute
    
    Features:
    - Finds collectible items in your inventory
    - Checks database for who needs each item
    - Trades up to 8 items at a time for efficiency
    - Updates database after each trade
    - Uses spawn filtering to avoid targeting pets
    
    Requirements:
    - Run /yalm2 collectscan on all characters first
    - All characters must be nearby for trading
]]

local mq = require('mq')
local ImGui = require('ImGui')

-- Database setup
local sqlite3 = require('lsqlite3')
local DB_PATH = mq.configDir .. "/YALM2/collection_needs.db"

-- State
local state = {
    db = nil,
    server_name = nil,
    my_name = nil,
    my_class = nil,
    
    -- Items to distribute
    items_to_distribute = {},  -- {item_name, slot_index, container_slot, recipient, collection_name}
    
    -- Trade state machine
    pending_trade = nil,
    trade_step_timer = 0,
    
    -- UI state
    show_ui = true,
    should_run = true,
    status_message = "Ready",
    last_scan_time = 0,
    
    -- Deferred actions (to run from main loop, not ImGui callback)
    request_scan = false,
    request_distribute_next = false,
    request_distribute_all = false,
}

-- ============================================================================
-- Database Functions
-- ============================================================================

local function open_db()
    if state.db then return state.db end
    
    state.db = sqlite3.open(DB_PATH)
    if not state.db then
        mq.cmdf('/echo [CollectDist] ERROR: Could not open database: %s', DB_PATH)
        return nil
    end
    return state.db
end

local function close_db()
    if state.db then
        state.db:close()
        state.db = nil
    end
end

--- Find characters who need a specific item (excluding self)
--- @param item_name string
--- @return table - Array of {character_name, collection_name}
local function find_characters_needing_item(item_name)
    local db = open_db()
    if not db then return {} end
    
    local results = {}
    local query = [[
        SELECT character_name, collection_name 
        FROM collection_needs 
        WHERE item_name = ? AND server_name = ? AND needed = 1 AND character_name != ?
        ORDER BY character_name
    ]]
    
    local stmt = db:prepare(query)
    if not stmt then return {} end
    
    stmt:bind_values(item_name, state.server_name, state.my_name)
    
    for row in stmt:nrows() do
        table.insert(results, {
            character_name = row.character_name,
            collection_name = row.collection_name
        })
    end
    
    stmt:finalize()
    return results
end

--- Mark an item as collected (needed = 0) for a character
--- @param character_name string
--- @param item_name string
--- @return boolean success
local function mark_item_collected(character_name, item_name)
    local db = open_db()
    if not db then 
        mq.cmdf('/echo [CollectDist] ERROR: Could not open database to mark item collected')
        return false 
    end
    
    mq.cmdf('/echo [CollectDist] DB Update: char=%s item=%s server=%s', 
        character_name or "nil", item_name or "nil", state.server_name or "nil")
    
    local query = [[
        UPDATE collection_needs 
        SET needed = 0, last_updated = datetime('now') 
        WHERE character_name = ? AND item_name = ? AND server_name = ?
    ]]
    
    local stmt = db:prepare(query)
    if not stmt then 
        mq.cmdf('/echo [CollectDist] ERROR: Failed to prepare update statement: %s', db:errmsg())
        return false 
    end
    
    stmt:bind_values(character_name, item_name, state.server_name)
    local result = stmt:step()
    stmt:finalize()
    
    local changes = db:changes()
    mq.cmdf('/echo [CollectDist] DB Update result: step=%s changes=%d', tostring(result), changes)
    
    if changes > 0 then
        mq.cmdf('/echo \ag[CollectDist] Database updated: %s now has %s\ax', character_name, item_name)
        return true
    else
        mq.cmdf('/echo \ar[CollectDist] WARNING: No database rows updated for %s / %s\ax', character_name, item_name)
    end
    return false
end

-- ============================================================================
-- DanNet / Spawn Functions
-- ============================================================================

local function get_dannet_peers()
    local peers = {}
    local peer_count = mq.TLO.DanNet.PeerCount() or 0
    
    for i = 1, peer_count do
        local peer_name = mq.TLO.DanNet.Peers(i)()
        if peer_name then
            table.insert(peers, peer_name)
        end
    end
    
    return peers
end

--- Validate a target by name, ensuring it's a PC (not a pet) within range
--- @param target_name string The name to target
--- @return number|nil The spawn ID if valid, nil otherwise
local function validate_target_by_name(target_name)
    if not target_name or target_name == "" then
        return nil
    end
    
    -- Define a predicate to filter spawns by name, within 200 units, ensuring they are PC and not a pet
    local function isValidTarget(spawn)
        local isInRange = spawn.Distance() <= 200
        local isMatch = spawn.CleanName():lower() == target_name:lower()
        local isPC = spawn.Type() == "PC"
        local isNotPet = spawn.Type() ~= "Pet"
        
        return isInRange and isMatch and isPC and isNotPet
    end
    
    -- Retrieve and filter spawns
    local matchingSpawns = mq.getFilteredSpawns(isValidTarget)
    
    if #matchingSpawns > 0 then
        local targetID = matchingSpawns[1].ID()
        if targetID then
            return targetID
        end
    end
    
    return nil
end

--- Get all nearby PCs (not pets) within range as a set
--- @return table<string, boolean> Set of lowercase character names
local function get_nearby_pcs()
    local nearby = {}
    
    -- Get all PC spawns within 200 units that are not pets
    local function isValidPC(spawn)
        local isInRange = spawn.Distance() <= 200
        local isPC = spawn.Type() == "PC"
        return isInRange and isPC
    end
    
    local pcs = mq.getFilteredSpawns(isValidPC)
    for _, spawn in ipairs(pcs) do
        local name = spawn.CleanName()
        if name then
            nearby[name:lower()] = true
        end
    end
    
    return nearby
end

-- ============================================================================
-- Inventory Scanning
-- ============================================================================

local function is_collectible(item)
    if not item or not item() then return false end
    return item.Collectible() == true
end

local function scan_inventory_for_collectibles()
    local collectibles = {}
    
    -- Scan pack slots (bags in inventory)
    for pack_idx = 1, 10 do
        local pack = mq.TLO.Me.Inventory('pack' .. pack_idx)
        if pack() then
            local container_size = pack.Container() or 0
            if container_size > 0 then
                -- It's a bag, scan inside
                for slot = 1, container_size do
                    local item = pack.Item(slot)
                    if item() and is_collectible(item) then
                        local item_name = item.Name()
                        if item_name then
                            table.insert(collectibles, {
                                item_name = item_name,
                                slot_index = 22 + pack_idx,  -- pack1 = slot 23
                                container_slot = slot,
                                stack_count = item.Stack() or 1
                            })
                        end
                    end
                end
            end
        end
    end
    
    return collectibles
end

local function find_items_to_distribute()
    state.items_to_distribute = {}
    state.status_message = "Scanning inventory..."
    
    -- Get all collectibles in inventory
    local collectibles = scan_inventory_for_collectibles()
    mq.cmdf('/echo [CollectDist] Found %d collectible items in inventory', #collectibles)
    
    -- Get DanNet peers
    local peers = get_dannet_peers()
    mq.cmdf('/echo [CollectDist] Found %d DanNet peers', #peers)
    
    -- Build set of peers (lowercase for matching)
    local peer_set = {}
    for _, peer in ipairs(peers) do
        peer_set[peer:lower()] = true
    end
    
    -- Get all nearby PCs in one call (much faster than per-peer checks)
    local nearby_pcs = get_nearby_pcs()
    
    -- Find nearby peers (intersection of DanNet peers and nearby PCs)
    local nearby_peers = {}
    for peer_lower, _ in pairs(peer_set) do
        if nearby_pcs[peer_lower] then
            nearby_peers[peer_lower] = true
            mq.cmdf('/echo [CollectDist] Peer nearby: %s', peer_lower)
        end
    end
    
    -- For each collectible stack, find characters who need it (one per stack item)
    local items_checked = 0
    local items_with_needs = 0
    local total_items_queued = 0
    
    for _, item in ipairs(collectibles) do
        items_checked = items_checked + 1
        local needing_chars = find_characters_needing_item(item.item_name)
        
        if #needing_chars > 0 then
            items_with_needs = items_with_needs + 1
            local stack_count = item.stack_count or 1
            local items_assigned = 0
            
            -- For each character who needs this item, assign one from the stack
            for _, char_info in ipairs(needing_chars) do
                if items_assigned >= stack_count then
                    break  -- No more items in stack to distribute
                end
                
                local char_name = char_info.character_name
                local char_name_lower = char_name:lower()
                
                if nearby_peers[char_name_lower] then
                    -- This character is nearby and needs the item
                    table.insert(state.items_to_distribute, {
                        item_name = item.item_name,
                        slot_index = item.slot_index,
                        container_slot = item.container_slot,
                        recipient = char_name,  -- Keep original casing for display/targeting
                        collection_name = char_info.collection_name
                    })
                    items_assigned = items_assigned + 1
                    total_items_queued = total_items_queued + 1
                    mq.cmdf('/echo [CollectDist] Match: %s -> %s (%d/%d in stack)', 
                        item.item_name, char_name, items_assigned, stack_count)
                end
            end
        end
    end
    
    mq.cmdf('/echo [CollectDist] Checked %d stacks, %d have characters needing them, %d total items queued', 
        items_checked, items_with_needs, total_items_queued)
    
    state.status_message = string.format("Found %d items to distribute", #state.items_to_distribute)
    state.last_scan_time = os.time()
    mq.cmdf('/echo [CollectDist] %s', state.status_message)
end

-- ============================================================================
-- Trading State Machine (Batch up to 8 items per trade)
-- ============================================================================

local MAX_TRADE_SLOTS = 8

local function pick_up_item(slot_index, container_slot)
    if not slot_index then
        mq.cmdf('/echo [CollectDist] ERROR: Invalid slot index')
        return false
    end
    
    if container_slot and container_slot > 0 then
        -- Item is inside a container - use /ctrl to pick up just 1
        local pack_slot = slot_index - 22
        mq.cmdf('/ctrl /itemnotify in pack%d %d leftmouseup', pack_slot, container_slot)
    else
        -- Item is in direct inventory - use /ctrl to pick up just 1
        mq.cmdf('/ctrl /itemnotify inv%d leftmouseup', slot_index)
    end
    
    return true
end

--- Collect up to 8 items for the same recipient
local function get_batch_for_recipient(recipient)
    local batch = {}
    for _, item in ipairs(state.items_to_distribute) do
        if item.recipient == recipient then
            table.insert(batch, item)
            if #batch >= MAX_TRADE_SLOTS then
                break
            end
        end
    end
    return batch
end

local function start_trade(item_info)
    if state.pending_trade then
        mq.cmdf('/echo [CollectDist] Trade already in progress')
        return false
    end
    
    -- Get batch of items for this recipient (up to 8)
    local batch = get_batch_for_recipient(item_info.recipient)
    if #batch == 0 then
        mq.cmdf('/echo [CollectDist] No items to trade')
        return false
    end
    
    state.pending_trade = {
        recipient = item_info.recipient,
        items = batch,           -- Array of items to trade
        current_item_idx = 0,    -- Which item we're currently placing
        step = "target",         -- Start with targeting (pickup happens per-item)
        retries = 0,
        target_id = nil          -- Will be set when we validate target
    }
    state.trade_step_timer = 0
    
    local item_names = {}
    for _, item in ipairs(batch) do
        table.insert(item_names, item.item_name)
    end
    mq.cmdf('/echo [CollectDist] Queued %d items -> %s: %s', 
        #batch, item_info.recipient, table.concat(item_names, ", "))
    return true
end

local function process_pending_trade()
    if not state.pending_trade then return end
    
    state.trade_step_timer = state.trade_step_timer + 1
    local trade = state.pending_trade
    
    -- Step: Target the recipient using spawn filtering (avoids pets)
    if trade.step == "target" then
        if state.trade_step_timer == 1 then
            state.status_message = string.format("Targeting %s (%d items)...", trade.recipient, #trade.items)
            -- Validate and target using spawn filter (ensures PC, not pet)
            local target_id = validate_target_by_name(trade.recipient)
            if target_id then
                trade.target_id = target_id
                mq.cmdf('/target id %d', target_id)
            end
        elseif state.trade_step_timer >= 5 then
            local target = mq.TLO.Target
            if target() and target.CleanName():lower() == trade.recipient:lower() then
                -- Start by picking up first item
                trade.step = "pickup_item"
                trade.current_item_idx = 1
                state.trade_step_timer = 0
            else
                trade.retries = trade.retries + 1
                if trade.retries > 3 then
                    mq.cmdf('/echo [CollectDist] ERROR: Could not target %s (may be out of range or is a pet)', trade.recipient)
                    state.pending_trade = nil
                else
                    state.trade_step_timer = 0
                    -- Retry targeting
                    local target_id = validate_target_by_name(trade.recipient)
                    if target_id then
                        mq.cmdf('/target id %d', target_id)
                    end
                end
            end
        end
    
    -- Step: Pick up current item from inventory
    elseif trade.step == "pickup_item" then
        local current_item = trade.items[trade.current_item_idx]
        if state.trade_step_timer == 1 then
            state.status_message = string.format("Picking up %s (%d/%d)...", 
                current_item.item_name, trade.current_item_idx, #trade.items)
            pick_up_item(current_item.slot_index, current_item.container_slot)
        elseif state.trade_step_timer >= 5 then
            if mq.TLO.Cursor() then
                trade.step = "place_item"
                state.trade_step_timer = 0
            else
                trade.retries = trade.retries + 1
                if trade.retries > 3 then
                    mq.cmdf('/echo [CollectDist] ERROR: Could not pick up %s', current_item.item_name)
                    -- Cancel trade if window is open
                    if mq.TLO.Window('TradeWND').Open() then
                        mq.cmd('/notify TradeWND TRDW_Cancel_Button leftmouseup')
                    end
                    state.pending_trade = nil
                else
                    state.trade_step_timer = 0
                    pick_up_item(current_item.slot_index, current_item.container_slot)
                end
            end
        end
    
    -- Step: Place item in trade window
    elseif trade.step == "place_item" then
        if state.trade_step_timer == 1 then
            if trade.current_item_idx == 1 then
                -- First item: /click left target opens trade window AND places item in slot 0
                mq.cmd('/click left target')
            else
                -- Subsequent items: click the trade slot directly (slots 1-7)
                local slot_idx = trade.current_item_idx - 1  -- slots are 0-indexed, but slot 0 is used by first item
                mq.cmdf('/notify TradeWND TRDW_TradeSlot%d leftmouseup', slot_idx)
            end
        elseif state.trade_step_timer >= 5 then
            -- For first item, also check if trade window opened
            if trade.current_item_idx == 1 and not mq.TLO.Window('TradeWND').Open() then
                trade.retries = trade.retries + 1
                if trade.retries > 3 then
                    mq.cmdf('/echo [CollectDist] ERROR: Trade window did not open')
                    mq.cmd('/autoinv')
                    state.pending_trade = nil
                else
                    state.trade_step_timer = 0
                    mq.cmd('/click left target')  -- Retry
                end
                return
            end
            
            -- Check if cursor is empty (item was placed)
            if not mq.TLO.Cursor() then
                -- Move to next item or confirm trade
                if trade.current_item_idx < #trade.items then
                    trade.current_item_idx = trade.current_item_idx + 1
                    trade.step = "pickup_item"
                    trade.retries = 0
                else
                    trade.step = "confirm_trade"
                end
                state.trade_step_timer = 0
            else
                trade.retries = trade.retries + 1
                if trade.retries > 3 then
                    mq.cmdf('/echo [CollectDist] ERROR: Could not place item in trade window')
                    mq.cmd('/autoinv')
                    mq.cmd('/notify TradeWND TRDW_Cancel_Button leftmouseup')
                    state.pending_trade = nil
                else
                    state.trade_step_timer = 0
                    -- Retry placement
                    if trade.current_item_idx == 1 then
                        mq.cmd('/click left target')
                    else
                        local slot_idx = trade.current_item_idx - 1
                        mq.cmdf('/notify TradeWND TRDW_TradeSlot%d leftmouseup', slot_idx)
                    end
                end
            end
        end
        
    -- Step: Click trade button
    elseif trade.step == "confirm_trade" then
        if state.trade_step_timer >= 5 then
            state.status_message = string.format("Confirming trade: %d items -> %s", #trade.items, trade.recipient)
            mq.cmd('/notify TradeWND TRDW_Trade_Button leftmouseup')
            trade.step = "wait_complete"
            state.trade_step_timer = 0
        end
        
    -- Step: Wait for trade to complete
    elseif trade.step == "wait_complete" then
        local trade_window_open = mq.TLO.Window('TradeWND').Open()
        
        if not trade_window_open then
            -- Trade completed - update database for ALL items in batch
            for _, item in ipairs(trade.items) do
                mark_item_collected(trade.recipient, item.item_name)
                
                -- Remove from items_to_distribute
                for i, dist_item in ipairs(state.items_to_distribute) do
                    if dist_item.item_name == item.item_name and dist_item.recipient == trade.recipient then
                        table.remove(state.items_to_distribute, i)
                        break
                    end
                end
            end
            
            mq.cmdf('/echo \ag[CollectDist] SUCCESS: Traded %d items to %s\ax', #trade.items, trade.recipient)
            state.status_message = string.format("Trade complete - %d items", #trade.items)
            state.pending_trade = nil
        elseif state.trade_step_timer >= 100 then
            mq.cmdf('/echo \ar[CollectDist] ERROR: Trade timed out\ax')
            state.status_message = "Trade timed out"
            state.pending_trade = nil
        end
    end
end

-- ============================================================================
-- UI
-- ============================================================================

local function drawUI()
    local open, show = ImGui.Begin("Collection Distributor", state.show_ui)
    if not open then
        -- X was clicked - exit the script
        state.should_run = false
        ImGui.End()
        return
    end
    
    if show then
        -- Status
        ImGui.Text(string.format("Status: %s", state.status_message))
        ImGui.Text(string.format("Server: %s | Character: %s", state.server_name or "?", state.my_name or "?"))
        
        ImGui.Separator()
        
        -- Controls
        if ImGui.Button("Scan Inventory") then
            state.request_scan = true  -- Deferred to main loop
        end
        
        ImGui.SameLine()
        
        local is_trading = state.pending_trade ~= nil
        if is_trading then
            ImGui.BeginDisabled()
        end
        
        if ImGui.Button("Distribute Next") then
            if #state.items_to_distribute > 0 then
                state.request_distribute_all = false  -- Single batch only
                start_trade(state.items_to_distribute[1])
            else
                state.status_message = "No items to distribute"
            end
        end
        
        ImGui.SameLine()
        
        if ImGui.Button("Distribute All") then
            if #state.items_to_distribute > 0 then
                state.request_distribute_all = true  -- Keep going until done
                start_trade(state.items_to_distribute[1])
            else
                state.status_message = "No items to distribute"
            end
        end
        
        if is_trading then
            ImGui.EndDisabled()
        end
        
        -- Stop button (only show when auto-distributing)
        if state.request_distribute_all then
            ImGui.SameLine()
            if ImGui.Button("Stop") then
                state.request_distribute_all = false
                state.status_message = "Auto-distribute stopped"
            end
        end
        
        ImGui.Separator()
        
        -- Items list
        ImGui.Text(string.format("Items to distribute: %d", #state.items_to_distribute))
        
        if ImGui.BeginChild("items", ImVec2(0, 0), true) then
            for i, item in ipairs(state.items_to_distribute) do
                local is_current = state.pending_trade and 
                    state.pending_trade.item_name == item.item_name and
                    state.pending_trade.recipient == item.recipient
                
                if is_current then
                    ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(1.0, 1.0, 0.0, 1.0))
                end
                
                ImGui.Text(string.format("%d. %s -> %s (%s)", 
                    i, item.item_name, item.recipient, item.collection_name or "?"))
                
                if is_current then
                    ImGui.PopStyleColor()
                end
            end
        end
        ImGui.EndChild()
    end
    ImGui.End()
end

-- ============================================================================
-- Main
-- ============================================================================

local function init()
    state.server_name = mq.TLO.EverQuest.Server()
    state.my_name = mq.TLO.Me.DisplayName()
    state.my_class = mq.TLO.Me.Class.ShortName():lower()
    
    mq.cmdf('/echo [CollectDist] Starting - Server: %s, Character: %s', state.server_name, state.my_name)
    mq.cmdf('/echo [CollectDist] Click "Scan Inventory" to find collectibles to distribute')
    
    -- Verify database exists
    local db = open_db()
    if not db then
        mq.cmdf('/echo [CollectDist] ERROR: Database not found. Run /yalm2 collectscan first!')
        return false
    end
    
    mq.imgui.init("CollectionDistributor", drawUI)
    return true
end

local function main_loop()
    while state.should_run do
        -- Process deferred scan request (can't run from ImGui callback due to mq.delay)
        if state.request_scan then
            state.request_scan = false
            find_items_to_distribute()
        end
        
        -- Process pending trade
        process_pending_trade()
        
        -- Auto-queue next trade if we're distributing all
        if state.request_distribute_all and not state.pending_trade then
            if #state.items_to_distribute > 0 then
                -- Small delay between trades
                mq.delay(500)
                start_trade(state.items_to_distribute[1])
            else
                state.request_distribute_all = false
                state.status_message = "All items distributed!"
                mq.cmdf('/echo \ag[CollectDist] All items distributed!\ax')
            end
        end
        
        mq.delay(100)
    end
    
    close_db()
end

-- Bind command
mq.bind('/collectdist', function()
    state.show_ui = not state.show_ui
    mq.cmdf('/echo [CollectDist] Window %s', state.show_ui and "shown" or "hidden")
end)

if init() then
    main_loop()
end
