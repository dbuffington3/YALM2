--[[
=====================================================================================
LOOT SIMULATOR - For testing distribution logic without actual loot
=====================================================================================

PURPOSE:
Allows testing of the entire loot distribution pipeline by simulating advloot items
without needing to actually hunt and receive items. Creates mock item objects that
pass through the normal looting.get_member_can_loot() evaluation chain.

USAGE:
  /yalm2 simulate <item_name>          -- Simulate looting an item by name
  /yalm2 simulate id <item_id>         -- Simulate looting an item by ID
  /yalm2 simulate quest <item_name>    -- Simulate quest item (forces quest characters)

EXAMPLES:
  /yalm2 simulate Orbweaver Silk
  /yalm2 simulate id 120331
  /yalm2 simulate quest Orbweaver Silks

The simulator:
1. Creates a mock item object matching real advloot structure
2. Queries the database to get full item properties
3. Runs through full looting evaluation pipeline
4. Shows assignment logic without giving item
5. Validates quest character detection
=====================================================================================
--]]

---@type Mq
local mq = require("mq")

local looting = require("yalm2.core.looting")
local evaluate = require("yalm2.core.evaluate")
local database = require("yalm.lib.database")
local dannet = require("yalm.lib.dannet")
local Write = require("yalm.lib.Write")
local debug_logger = require("yalm2.lib.debug_logger")

local simulator = {}

-- Create a mock item object that mimics AdvLoot item structure
local function create_mock_item(item_id, item_name)
    return {
        Index = 1,  -- Required field for get_loot_item()
        ID = function() return item_id end,
        Name = function() return item_name end,
        -- Additional fields that might be accessed
        Stackable = function() return true end,
        Count = function() return 1 end,
    }
end

-- Create a mock loot object (what's returned by looting evaluation)
local function create_mock_loot(item_id, item_name)
    return {
        item_id = item_id,
        item_name = item_name,
        -- Mock loot structure
        List = "shared",  -- or "personal"
    }
end

-- Find item by name, trying multiple variations
local function find_item_by_name(search_name)
    -- Try progressively more flexible searches
    local search_variations = {
        -- Exact match first
        search_name,
        -- Exact case-insensitive
        search_name:lower(),
        -- Plural/singular variations
        search_name:gsub("s$", ""),
        search_name:lower():gsub("s$", ""),
        -- Add back 's' if not present
        search_name .. "s",
        (search_name:lower() .. "s"):gsub("ss$", "s"),
    }
    
    for _, search_term in ipairs(search_variations) do
        local escaped = search_term:gsub("'", "''")
        
        local query = string.format("SELECT * FROM raw_item_data WHERE name = '%s' LIMIT 1", escaped)
        for row in database.database:nrows(query) do
            Write.Debug("Found: %s (ID: %d)", row.name, row.id)
            return row.id, row.name
        end
    end
    
    -- If exact match failed, try LIKE search as last resort
    Write.Debug("Exact matches failed, trying LIKE search for: %s", search_name)
    local like_pattern = search_name:lower():gsub("s$", "")  -- Remove trailing 's'
    local q_like = string.format("SELECT * FROM raw_item_data WHERE LOWER(name) LIKE '%%%s%%' LIMIT 1", like_pattern:gsub("'", "''"))
    for row in database.database:nrows(q_like) do
        Write.Debug("Found via LIKE: %s (ID: %d)", row.name, row.id)
        return row.id, row.name
    end
    
    return nil, nil
end

-- Find item by ID
local function find_item_by_id(item_id)
    local query = string.format("SELECT * FROM raw_item_data WHERE id = %d LIMIT 1", item_id)
    for row in database.database:nrows(query) do
        return row.id, row.name
    end
    
    return nil, nil
end

-- Run the full loot evaluation pipeline
function simulator.simulate_loot(item_name_or_id, is_id, force_quest)
    Write.Info("=" .. string.rep("=", 58) .. "=")
    Write.Info("LOOT SIMULATOR - Testing Distribution Logic")
    Write.Info("=" .. string.rep("=", 58) .. "=")
    
    local item_id, item_name
    
    -- Find the item
    if is_id then
        item_id = tonumber(item_name_or_id)
        item_id, item_name = find_item_by_id(item_id)
    else
        item_name = item_name_or_id
        item_id, item_name = find_item_by_name(item_name)
    end
    
    if not item_id or not item_name then
        Write.Error("Item not found: %s", item_name_or_id)
        return
    end
    
    Write.Info("Found item: %s (ID: %d)", item_name, item_id)
    
    -- Verify the item is actually in the database with this ID
    local verification_query = string.format("SELECT id, name FROM raw_item_data WHERE id = %d LIMIT 1", item_id)
    local verified_id, verified_name = nil, nil
    for row in database.database:nrows(verification_query) do
        verified_id = row.id
        verified_name = row.name
        break
    end
    
    if verified_id then
        Write.Info("Database verification: ID %d = %s", verified_id, verified_name)
    else
        Write.Error("ERROR: Item ID %d not found in database for verification!", item_id)
        return
    end
    
    -- Create mock objects
    local mock_item = create_mock_item(item_id, item_name)
    local mock_loot = create_mock_loot(item_id, item_name)
    
    -- Prepare loot evaluation parameters
    local save_slots = 0
    local dannet_delay = 100
    local always_loot = false
    local unmatched_item_rule = nil
    
    -- Get group/raid info
    local group_or_raid_tlo = looting.get_group_or_raid_tlo()
    local group_size = looting.get_member_count(group_or_raid_tlo)
    
    Write.Info("Group/Raid type: %s (%d members)", group_or_raid_tlo, group_size)
    
    -- Check if this is a quest item
    local needed_by = nil
    if force_quest or _G.YALM2_QUEST_ITEMS_WITH_QTY then
        -- Parse quest data to check if this item is needed
        local quest_data = _G.YALM2_QUEST_ITEMS_WITH_QTY or ""
        if quest_data:len() > 0 then
            for item_data in quest_data:gmatch("([^|]+)") do
                local parts = {}
                for part in item_data:gmatch("([^:]+)") do
                    table.insert(parts, part)
                end
                
                if parts[1] and (parts[1] == item_name or parts[1]:lower() == item_name:lower()) then
                    -- Found matching quest item
                    needed_by = {}
                    if #parts > 1 then
                        for i = 2, #parts do
                            local char_qty_pair = parts[i]
                            local char_name, qty_str = char_qty_pair:match("([^:]+):(.+)")
                            if char_name then
                                table.insert(needed_by, char_name)
                            end
                        end
                    end
                    break
                end
            end
        end
    end
    
    if needed_by and #needed_by > 0 then
        Write.Error("QUEST ITEM DETECTED: %s needed by [%s]", item_name, table.concat(needed_by, ", "))
        Write.Info("This item will be distributed to quest characters only")
    else
        Write.Info("Regular item (not needed for quests)")
    end
    
    -- Evaluate each member
    Write.Info("\nEvaluating group members...")
    Write.Info(string.rep("-", 60))
    
    local candidates = {}
    
    for i = 0, group_size do
        local member = looting.get_valid_member(group_or_raid_tlo, i)
        if member then
            local member_name = member.CleanName()
            Write.Info("\nTesting: %s", member_name)
            
            -- Skip quest-only filter if not a quest item
            if not needed_by or #needed_by == 0 then
                -- Regular loot evaluation
                local can_loot, check_rematch, preference = looting.get_member_can_loot(
                    mock_item, 
                    mock_loot, 
                    save_slots, 
                    dannet_delay, 
                    always_loot, 
                    unmatched_item_rule
                )
                
                if can_loot then
                    Write.Info("  ✓ CAN LOOT")
                    table.insert(candidates, {
                        name = member_name,
                        member = member,
                        reason = "Regular loot rules passed"
                    })
                else
                    Write.Info("  ✗ CANNOT LOOT (failed preference/inventory checks)")
                end
            else
                -- Quest item - check if this member needs it
                local member_needs = false
                for _, quest_char in ipairs(needed_by) do
                    if quest_char:lower() == member_name:lower() then
                        member_needs = true
                        break
                    end
                end
                
                if member_needs then
                    Write.Info("  ✓ QUEST CHARACTER (needs %s)", item_name)
                    table.insert(candidates, {
                        name = member_name,
                        member = member,
                        reason = "Needs for quest"
                    })
                else
                    Write.Info("  ✗ NOT QUEST CHARACTER (doesn't need %s)", item_name)
                end
            end
        end
    end
    
    -- Show final result
    Write.Info("\n" .. string.rep("=", 60))
    if #candidates > 0 then
        Write.Info("DISTRIBUTION DECISION:")
        if needed_by and #needed_by > 0 then
            -- Quest item - show priority order
            Write.Info("Top candidate: %s (%s)", candidates[1].name, candidates[1].reason)
            Write.Info("Would give to: %s", candidates[1].name)
        else
            -- Regular item - show first valid
            Write.Info("Top candidate: %s (%s)", candidates[1].name, candidates[1].reason)
            Write.Info("Would give to: %s", candidates[1].name)
        end
        
        if #candidates > 1 then
            Write.Info("\nOther candidates:")
            for i = 2, #candidates do
                Write.Info("  %d. %s (%s)", i, candidates[i].name, candidates[i].reason)
            end
        end
    else
        Write.Error("NO VALID RECIPIENTS - Item would be left on corpse")
    end
    
    Write.Info(string.rep("=", 60))
    Write.Info("Simulation complete. No item was actually looted.")
    Write.Info("=" .. string.rep("=", 58) .. "=")
end

return simulator
