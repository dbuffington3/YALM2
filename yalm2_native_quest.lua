--[[
=====================================================================================
YALM2 NATIVE QUEST SYSTEM - ARCHITECTURE DOCUMENTATION
=====================================================================================

PURPOSE:
This script replaces TaskHUD for quest item detection in YALM2. It creates a native 
quest coordination system that detects quest items from task objectives and 
distributes them to characters who need them.

CRITICAL ARCHITECTURE RULES:

1. DATA STRUCTURE CONSISTENCY (MOST IMPORTANT!):
   - task.task_name (NOT task.name)
   - objective.objective (NOT objective.text) 
   - These fields are created by get_tasks() and used everywhere
   - UI, manual refresh, and automatic processing MUST use same fields

2. DATA SOURCES:
   - get_tasks(): Creates authoritative task structure from TaskWnd
   - task_data.tasks[char]: Populated by DanNet actor messages
   - UI displays from task_data.tasks (same source as processing functions)
   - Manual refresh processes task_data.tasks (same as UI)
   - Automatic processing uses task_data.tasks (same as UI and manual)

3. MESSAGE CONTROL:
   - Manual refresh: User-facing messages with taskheader formatting
   - Automatic processing: Silent operation, debug logging only
   - NEVER mix manual and automatic message systems

4. PATTERN SAFETY:
   - Lua patterns (%w, %s) conflict with string.format() 
   - Use print() + string.format() when displaying patterns
   - NEVER pass lua patterns to Write.Info/Write.Debug

5. FIELD NAME DEBUGGING:
   - If quest items aren't found, check field names first
   - objective.objective vs objective.text is most common error
   - task.task_name vs task.name is second most common error

COMMON MISTAKES TO AVOID:
- Using objective.text instead of objective.objective
- Using task.name instead of task.task_name  
- Mixing message systems (manual vs automatic)
- Passing lua patterns to Write.Info functions
- Creating different data sources for UI vs processing

MODIFICATION CHECKLIST:
If you change anything, verify these still match:
1. get_tasks() field creation
2. UI display field access  
3. Manual refresh field access
4. Automatic processing field access
5. Message systems remain separate
=====================================================================================
]]--

--- YALM2 Native Quest Coordinator (TaskHUD Architecture)
--- This script runs standalone like TaskHUD and coordinates with YALM2
--- Master instance shows UI and runs on main character
--- Collector instances (nohud) run on remote characters

local mq = require("mq")
local actors = require("actors")
local ImGui = require('ImGui')
local Write = require("yalm.lib.Write")
require("yalm.lib.database")  -- Load the database module to set up the global Database table

-- Initialize database connection using the global Database variable
Database.database = Database.OpenDatabase()
if not Database.database then
    Write.Error("Failed to open database")
    mq.exit()
end

-- Arguments passed when starting the script  
local args = { ... }
local drawGUI = true  -- Will be set to false with 'nohud' argument

local debug_mode = false
local running = true
local startup_summary_shown = false
local my_name = mq.TLO.Me.DisplayName()

-- Task data storage (TaskHUD format)
local task_data = {
    tasks = {},      -- character_name -> task_array
    my_tasks = {},   -- This character's tasks
}

local peer_list = {}
local triggers = {
    do_refresh = false,
    timestamp = mq.gettime(),
    need_task_update = false,
    need_yalm2_data_send = false,
    last_data_send = 0
}

local taskheader = "\\ay[\\agYALM2 Native Quest\\ay]"  -- Colored for /echo commands
local taskheader_plain = "[YALM2 Native Quest]"            -- Plain for print() statements

--[[
Smart quest item extraction from objective text
Extracts proper item names with correct capitalization and validates against database
]]--
local function extract_quest_item_from_objective(objective_text)
    if not objective_text then 
        return nil 
    end
    
    -- Pattern to extract item names from gather objectives with proper case preservation
    local patterns = {
        "Gather some (.+) from",           -- "Gather some Orbweaver Silks from the orbweaver spiders"
        "Collect %d* ?(.+) from",          -- "Collect 5 Bone Fragments from skeletons"
        "Gather (.+) from",                -- "Gather Werewolf Pelts from wolves" 
        "Collect (.+) %- %d+/%d+",         -- "Collect Bone Fragments - 2/5"
    }
    
    for _, pattern in ipairs(patterns) do
        local match = objective_text:match(pattern)
        if match then
            -- Clean up the match - remove extra descriptors but preserve proper case
            local cleaned = match
            
            -- Remove quality descriptors while preserving actual item name case
            cleaned = cleaned:gsub("^quality ", "")
            cleaned = cleaned:gsub("^fine ", "")
            cleaned = cleaned:gsub("^pristine ", "")
            cleaned = cleaned:gsub("^perfect ", "")
            
            -- Trim whitespace
            cleaned = cleaned:gsub("^%s*(.-)%s*$", "%1")
            
            -- Only return if it looks like a valid item name (not empty, not just spaces)
            if cleaned and cleaned:len() > 0 and not cleaned:match("^%s*$") then
                return cleaned
            end
        end
    end
    
    return nil
end

--[[
Parse progress from status string
Examples:
  "0/4" → { current = 0, needed = 4 }
  "2/5" → { current = 2, needed = 5 }
  "Done" → { current = -1, needed = -1 } (indicates completed)
Returns: table with current and needed, or nil
]]--
local function parse_progress_status(status_string)
    if not status_string then
        return nil
    end
    
    if status_string == "Done" then
        return { current = -1, needed = -1, is_done = true }
    end
    
    local current, needed = status_string:match("(%d+)/(%d+)")
    if current and needed then
        return {
            current = tonumber(current),
            needed = tonumber(needed),
            is_done = false
        }
    end
    
    return nil
end

-- Prevent multiple instances by checking if we're already loaded
if _G.yalm2_native_quest_loaded then
    mq.cmd(string.format('/echo %s \\arAlready running - stopping this instance', taskheader))
    mq.exit()
end
_G.yalm2_native_quest_loaded = true

--[[
=====================================================================================
TASK DATA STRUCTURE DOCUMENTATION - READ THIS BEFORE MODIFYING!
=====================================================================================

This function creates the AUTHORITATIVE task data structure used throughout the system.
ALL other code must match this exact structure to avoid field name mismatches.

RETURNED STRUCTURE:
tasks = {
    [1] = {
        task_name = "string",     -- CRITICAL: Field is task_name NOT name!
        objectives = {
            [1] = {
                objective = "string", -- CRITICAL: Field is objective NOT text!
                status = "string"     -- "Done", "0/4", etc.
            }
        }
    }
}

FIELD NAME RULES (ENFORCED):
- Use task.task_name everywhere (UI, manual refresh, automatic processing)
- Use objective.objective everywhere (UI, manual refresh, automatic processing)  
- NEVER use task.name or objective.text - these fields don't exist!

DATA FLOW:
1. get_tasks() creates structure with task_name and objective fields
2. Actor messages distribute this structure to all characters  
3. UI displays using task.task_name and objective.objective
4. Manual refresh MUST use same fields as UI
5. Automatic processing MUST use same fields as manual refresh
=====================================================================================
]]--

--- Get tasks using TaskHUD's exact method - CREATES AUTHORITATIVE DATA STRUCTURE
local function get_tasks()
    local tasks = {}
    mq.TLO.Window('TaskWnd').DoOpen()
    while mq.TLO.Window('TaskWnd').Open() == false do
        -- Wait for window to open
    end
    
    local count1, count2 = 1, 1
    for i = 1, mq.TLO.Window('TaskWnd/TASK_TaskList').Items() do
        mq.TLO.Window('TaskWnd/TASK_TaskList').Select(i)
        while mq.TLO.Window('TaskWnd/TASK_TaskList').GetCurSel() ~= i do
            -- Wait for selection
        end
        
        -- Check that the name of the task is not nil (skip separator lines)
        if mq.TLO.Window('TaskWnd/TASK_TaskList').List(i, 3)() ~= nil then
            -- CRITICAL: Creating task_name field (NOT name!)
            -- All code must use task.task_name to access this field
            tasks[count1] = {
                task_name = mq.TLO.Window('TaskWnd/TASK_TaskList').List(i, 3)(),  -- FIELD: task_name
                objectives = {},  -- Will contain array of {objective="text", status="Done/0/4"}
            }

            -- Loop through the objectives of the current task
            for j = 1, mq.TLO.Window('TaskWnd/TASK_TaskElementList').Items() do
                local col1 = mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 1)()
                local col2 = mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 2)()
                local col3 = mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 3)()
                
                -- Only include entries where col2 is not nil and not empty (skip ? ? ? entries)
                if col2 ~= nil and col2 ~= "" and col1 ~= "? ? ?" then
                    -- Clean up objective text by removing leading ? and spaces
                    local clean_objective = col1:gsub("^%?%s*", "")
                    
                    -- CRITICAL: Creating objective field (NOT text!)
                    -- All code must use objective.objective to access this field
                    local tmp_objective = {
                        objective = clean_objective,  -- FIELD: objective (cleaned text from TaskWnd)
                        status = col2,               -- FIELD: status (Done, 0/4, etc.)
                    }
                    table.insert(tasks[count1]['objectives'], count2, tmp_objective)
                    count2 = count2 + 1
                end
            end
            count2 = 1
            count1 = count1 + 1
        end
    end
    mq.TLO.Window('TaskWnd').DoClose()
    return tasks
end

-- Message handler (TaskHUD's exact pattern) - using anonymous registration  
local actor = actors.register(function(message)
    -- Add error handling to prevent coroutine issues
    local success, err = pcall(function()
        if message.content.id == 'REQUEST_TASKS' then
            triggers.need_task_update = true
            peer_list = {}
            task_data.tasks = {}
            
        elseif message.content.id == 'INCOMING_TASKS' then
            if drawGUI == true then  -- Only UI instance processes incoming tasks
                task_data.tasks[message.sender.character] = message.content.tasks
                table.insert(peer_list, message.sender.character)
                table.sort(peer_list)
            end
            triggers.timestamp = mq.gettime()
            
        elseif message.content.id == 'TASKS_UPDATED' then
            if mq.gettime() > triggers.timestamp + 1500 then
                triggers.do_refresh = true
            end
            
        elseif message.content.id == 'END_SCRIPT' then
            running = false
        end
    end)
    
    if not success then
        mq.cmd('/echo Error in actor message handler: ' .. tostring(err))
    end
end)

local function request_task_update()
    actor:send({ id = 'REQUEST_TASKS' })
    -- Also trigger quest data sharing after refresh completes
    mq.delay(5000)  -- Wait for all characters to respond
    triggers.need_yalm2_data_send = true
end

local function update_tasks()
    task_data.my_tasks = get_tasks()
    mq.delay(3000, function() return not mq.TLO.Window('TaskWnd').Open() end)
    actor:send({ id = 'INCOMING_TASKS', tasks = task_data.my_tasks })
end

-- Task update events (TaskHUD's exact events)
local function update_event()
    actor:send({ id = 'TASKS_UPDATED' })
end

local function create_events()
    mq.event('update_event', '#*#Your task #*# has been updated#*#', update_event)
    mq.event('new_task_event', '#*#You have been assigned the task#*#', update_event)
    mq.event('shared_task_event', '#*#Your shared task#*# has ended.', update_event)
end

-- Enhanced UI similar to TaskHUD
local selected_character = 1
local selected_task = 1
local ui_initialized = false
local manual_character_selection = false  -- Track if user manually changed character

-- Find master looter in peer list
local function find_master_looter_index()
    for i, character in ipairs(peer_list) do
        if character == my_name then  -- Master looter is the character running the UI
            return i
        end
    end
    return 1  -- Default to first character if not found
end

-- Initialize UI defaults on first run or when peer list changes
local function initialize_ui_selection()
    if not ui_initialized and #peer_list > 0 then
        selected_character = find_master_looter_index()
        ui_initialized = true
    elseif #peer_list > 0 and not manual_character_selection then
        -- Only auto-update to master looter if user hasn't manually selected someone
        local ml_index = find_master_looter_index()
        if ml_index > 0 then
            selected_character = ml_index
        end
    end
end

-- Get character's group position (1-6) or assign based on peer_list order
local function get_character_position(character)
    for i, peer in ipairs(peer_list) do
        if peer == character then
            return i
        end
    end
    return 0  -- Not found
end

-- Get other characters with the same task
local function get_characters_with_task(task_name)
    local characters_with_task = {}
    
    for character, tasks in pairs(task_data.tasks) do
        for _, task in ipairs(tasks) do
            if task.task_name == task_name then
                table.insert(characters_with_task, {
                    character = character,
                    task = task,
                    position = get_character_position(character)
                })
                break
            end
        end
    end
    
    -- Sort by position for consistent display
    table.sort(characters_with_task, function(a, b) return a.position < b.position end)
    
    return characters_with_task
end

-- Draw a colored text indicator (simpler than circles to avoid ImGui draw list issues)
local function draw_colored_indicator(color_r, color_g, color_b, text, is_ml)
    if is_ml then
        ImGui.TextColored(1, 0.84, 0, 1, "[" .. text .. "]")  -- Gold brackets for ML
    else
        ImGui.TextColored(color_r, color_g, color_b, 1, "(" .. text .. ")")
    end
end

local function displayGUI()
    if not drawGUI then return end
    
    ImGui.SetNextWindowSize(445, 490)
    local open, show = ImGui.Begin("YALM2 Native Quest##" .. my_name, true)
    if not open then
        drawGUI = false
    end
    
    if show then
        -- Initialize UI selection to master looter
        initialize_ui_selection()
        -- Two-column layout for header
        ImGui.Columns(2, nil, false)
        
        -- Column 1: Labels + Refresh button
        ImGui.Text("Characters tracked: " .. #peer_list)
        ImGui.Text("My tasks: " .. #task_data.my_tasks)
        ImGui.Text("Last update: " .. math.floor((mq.gettime() - triggers.timestamp) / 1000) .. "s ago")
        
        -- Refresh button
        if ImGui.Button("Refresh Quest Data") then
            -- Use command system instead of direct function call to avoid scope issues
            mq.cmd('/yalm2quest refresh')
        end
        
        ImGui.SameLine()
        
        -- Test button - prints per-character needs to console
        if ImGui.Button("Test Qty Parser") then
            print("\n" .. string.rep("=", 60))
            print("PER-CHARACTER QUEST ITEM QUANTITIES TEST")
            print(string.rep("=", 60))
            
            -- Get the parsed needs data
            local needs = {}
            local success, quest_data_str = pcall(function()
                if mq.TLO.YALM2_Quest_Items_WithQty then
                    return tostring(mq.TLO.YALM2_Quest_Items_WithQty)
                end
                return nil
            end)
            
            if success and quest_data_str and quest_data_str ~= "NULL" and quest_data_str:len() > 0 then
                -- Parse the enhanced format: "Item:char1:qty1,char2:qty2|Item2:char3:qty3|"
                for item_data in quest_data_str:gmatch("([^|]+)") do
                    local parts = {}
                    for part in item_data:gmatch("([^:]+)") do
                        table.insert(parts, part)
                    end
                    
                    if #parts >= 2 then
                        local item_name = parts[1]
                        
                        -- Re-parse to get char:qty pairs
                        local rest = item_data:sub(item_name:len() + 2)  -- Skip "ItemName:"
                        
                        print(string.format("\n%s:", item_name))
                        
                        for char_qty_pair in rest:gmatch("([^,]+)") do
                            local char_name, qty_str = char_qty_pair:match("([^:]+):(.+)")
                            if char_name then
                                local qty = tonumber(qty_str)
                                if qty then
                                    print(string.format("  %-15s needs %d", char_name, qty))
                                else
                                    print(string.format("  %-15s needs ? (parse error)", char_name))
                                end
                            end
                        end
                    end
                end
                print(string.rep("=", 60) .. "\n")
            else
                print("ERROR: No quest data available - run Refresh Quest Data first!")
                print(string.rep("=", 60) .. "\n")
            end
        end
        
        -- Column 2: Dropdowns
        ImGui.NextColumn()
        if #peer_list > 0 then
            -- Character selection dropdown
            ImGui.Text("Quest Character:")
            ImGui.PushItemWidth(200)
            local previous_selection = selected_character
            selected_character = ImGui.Combo('##CharacterCombo', selected_character, peer_list, #peer_list)
            
            -- Track if user manually changed the selection
            if previous_selection ~= selected_character then
                manual_character_selection = true
            end
            
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip('Select character to view tasks (defaults to master looter)')
            end
            
            -- Show indicator if this is the master looter
            local current_char = peer_list[selected_character]
            if current_char == my_name then
                ImGui.SameLine()
                ImGui.TextColored(0, 1, 0, 1, "[ML]")
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip('Master Looter')
                end
            end
            
            ImGui.PopItemWidth()
            
            local current_char = peer_list[selected_character]
            if current_char and task_data.tasks[current_char] then
                local char_tasks = task_data.tasks[current_char]
                
                if #char_tasks > 0 then
                    -- Task selection dropdown
                    if selected_task > #char_tasks then
                        selected_task = 1
                    end
                    
                    ImGui.Text("Show Tasks:")
                    ImGui.PushItemWidth(300)
                    if ImGui.BeginCombo('##TaskCombo', char_tasks[selected_task] and char_tasks[selected_task].task_name or "No tasks") then
                        for i, task in ipairs(char_tasks) do
                            local is_selected = selected_task == i
                            if ImGui.Selectable(task.task_name, is_selected) then
                                selected_task = i
                            end
                            if is_selected then
                                ImGui.SetItemDefaultFocus()
                            end
                        end
                        ImGui.EndCombo()
                    end
                    ImGui.PopItemWidth()
                end
            end
        end
        
        -- End two-column layout
        ImGui.Columns(1)
        ImGui.Separator()
        
        if #peer_list > 0 then
            local current_char = peer_list[selected_character]
            if current_char and task_data.tasks[current_char] then
                local char_tasks = task_data.tasks[current_char]
                
                if #char_tasks > 0 then
                    
                    -- Display objectives for selected task
                    if char_tasks[selected_task] then
                        local task = char_tasks[selected_task]
                        ImGui.Separator()
                        
                        -- Show other characters with the same task (simple colored indicators)
                        local characters_with_task = get_characters_with_task(task.task_name)
                        if #characters_with_task > 1 then
                            ImGui.Text("Shared with: ")
                            ImGui.SameLine()
                            
                            local first = true
                            for _, char_task in ipairs(characters_with_task) do
                                if char_task.character ~= current_char then
                                    if not first then
                                        ImGui.SameLine()
                                        ImGui.Text(" ")
                                        ImGui.SameLine()
                                    end
                                    first = false
                                    
                                    -- Calculate completion
                                    local completed = 0
                                    for _, obj in ipairs(char_task.task.objectives) do
                                        if obj.status == "Done" then completed = completed + 1 end
                                    end
                                    local total = #char_task.task.objectives
                                    
                                    -- Choose color based on completion
                                    local color_r, color_g, color_b = 1, 0, 0  -- Red for incomplete
                                    if completed == total then
                                        color_r, color_g, color_b = 0, 1, 0  -- Green for complete
                                    elseif completed > 0 then
                                        color_r, color_g, color_b = 1, 1, 0  -- Yellow for partial
                                    end
                                    
                                    -- Draw indicator with position number
                                    local is_ml = char_task.character == my_name
                                    draw_colored_indicator(color_r, color_g, color_b, tostring(char_task.position), is_ml)
                                    
                                    -- Tooltip on hover
                                    if ImGui.IsItemHovered() then
                                        ImGui.SetTooltip(char_task.character .. " (" .. completed .. "/" .. total .. ")" .. 
                                                        (is_ml and " [ML]" or ""))
                                    end
                                    
                                    ImGui.SameLine()
                                end
                            end
                            
                            ImGui.NewLine()
                            ImGui.Separator()
                        end
                        
                        ImGui.Text("Objectives:")
                        
                        for i, objective in ipairs(task.objectives) do
                            -- Skip objectives that are just question marks or meaningless text
                            if objective.objective == "?" or 
                               objective.objective:match("^%?+$") or 
                               objective.objective:match("^[%?%s%-]+$") then
                                -- Skip this objective entirely
                            else
                                -- Clean up objective text
                                local clean_objective = objective.objective:gsub("%?", "")
                                
                                -- Color code based on status
                                if objective.status == "Done" then
                                    ImGui.TextColored(0, 1, 0, 1, "✓ " .. clean_objective)
                                else
                                    ImGui.TextColored(1, 1, 0, 1, "• " .. clean_objective .. " - " .. objective.status)
                                end
                            
                            -- Show who still needs this objective (position numbers) on same line but indented
                            if #characters_with_task > 1 then
                                local incomplete_positions = {}
                                for _, char_task in ipairs(characters_with_task) do
                                    if i <= #char_task.task.objectives then
                                        local other_obj = char_task.task.objectives[i]
                                        if other_obj.status ~= "Done" then
                                            local pos_display = tostring(char_task.position)
                                            if char_task.character == my_name then
                                                pos_display = pos_display .. "*"  -- Asterisk for ML
                                            end
                                            table.insert(incomplete_positions, pos_display)
                                        end
                                    end
                                end
                                
                                if #incomplete_positions > 0 then
                                    ImGui.SameLine()
                                    ImGui.TextColored(1, 0.5, 0.5, 1, " Need: ")
                                    ImGui.SameLine()
                                    
                                    -- Show simple colored indicators for incomplete characters
                                    for j, pos_str in ipairs(incomplete_positions) do
                                        if j > 1 then
                                            ImGui.SameLine()
                                            ImGui.Text(" ")
                                            ImGui.SameLine()
                                        end
                                        
                                        local is_ml = pos_str:find("*") ~= nil
                                        local pos_num = pos_str:gsub("*", "")
                                        
                                        draw_colored_indicator(1, 0.3, 0.3, pos_num, is_ml)  -- Red for incomplete
                                        if j < #incomplete_positions then
                                            ImGui.SameLine()
                                        end
                                    end
                                end
                                end
                            end
                            -- Add a new line after each objective (this ensures vertical stacking)
                        end
                    end
                else
                    ImGui.Text(current_char .. " has no tasks")
                end
            end
        else
            ImGui.Text("No characters connected")
            ImGui.Text("Make sure other characters are in your group/raid")
            ImGui.Text("and have DanNet enabled")
        end
    end
    ImGui.End()
end

--[[
=====================================================================================
MANUAL REFRESH FUNCTION - CRITICAL DOCUMENTATION
=====================================================================================

This function processes quest item detection for MANUAL refreshes only (user-initiated).
It should ONLY be called when the user explicitly requests a refresh, NOT automatically.

KEY LEARNINGS TO PREVENT RECURRING ISSUES:

1. DATA STRUCTURE DOCUMENTATION:
   - task_data.tasks[character_name] = array of task objects
   - Each task object has: { task_name = "string", objectives = array }
   - Each objective has: { objective = "text", status = "Done/0/4/etc" }
   
   CRITICAL: Use objective.objective NOT objective.text!
   The get_tasks() function populates objective.objective, not objective.text.
   UI code uses objective.objective, so manual refresh MUST match this.

2. FIELD NAME CONSISTENCY:
   - Use task.task_name NOT task.name (matches get_tasks() structure)
   - Use objective.objective NOT objective.text (matches get_tasks() structure)
   
3. DATA SOURCE VERIFICATION:
   - Both UI and manual refresh read from task_data.tasks[character_name]
   - This data is populated by DanNet actor messages from all characters
   - Manual refresh should NOT use different data source than UI display

4. PATTERN MATCHING SAFETY:
   - Lua patterns contain %w, %s which conflict with string.format() 
   - Use print() + string.format() directly, NOT Write.Info() with patterns
   - Avoid passing lua patterns to Write.Info/Write.Debug functions

5. MESSAGE CONTROL:
   - Manual refresh = user-facing messages (taskheader formatting)
   - Automatic refresh = silent operation (debug only)
   - NEVER mix manual and automatic message systems
=====================================================================================
]]--

-- Manual refresh with user-facing messages (separate from automatic refresh)
local function manual_refresh_with_messages(show_messages)
    -- Default to showing messages if not specified
    if show_messages == nil then show_messages = true end
    
    -- Request fresh task data from all characters first
    -- This sends REQUEST_TASKS and waits 5 seconds for all responses
    request_task_update()
    
    -- Then process the collected task data
    -- Force task update first to ensure fresh data
    update_tasks()
    
    -- Debug logging only - remove spam from MQ2 character log
    Write.Debug("MANUAL_REFRESH: Starting manual refresh with %d characters", #peer_list)
    local task_count = 0
    for _ in pairs(task_data.tasks or {}) do task_count = task_count + 1 end
    Write.Debug("MANUAL_REFRESH: Processing %d characters with task data", task_count)
    
    -- Process quest data with messages enabled (user-initiated refresh)
    local quest_items = {}
    -- CRITICAL: Use task_data.tasks (same source as UI display) 
    -- This data is populated by DanNet actor messages from all characters
    for character_name, tasks in pairs(task_data.tasks) do
        for _, task in ipairs(tasks) do
            if task.objectives then
                for _, objective in ipairs(task.objectives) do
                    -- CRITICAL: Use objective.objective NOT objective.text! 
                    -- The get_tasks() function creates objective.objective field
                    -- UI code uses objective.objective, manual refresh MUST match
                    if objective and objective.objective then
                        -- Smart quest item extraction - extract proper item names and validate against database
                        local item_name = extract_quest_item_from_objective(objective.objective)
                        
                        if item_name then
                            Write.Debug("MANUAL_REFRESH: Extracted potential item: '%s'", item_name)
                            -- Validate against database to ensure it's a real item
                            if not Database.database then
                                Write.Error("Database not available for item validation")
                                return
                            end
                            
                            -- Inline database query - look up item in database with fuzzy matching
                            local db_item = nil
                            local search_variations = { item_name }
                            
                            -- Try removing trailing 's' for common plurals
                            if item_name:match('s$') then
                                table.insert(search_variations, item_name:sub(1, -2))
                            end
                            
                            -- Try removing trailing 'es'
                            if item_name:match('es$') then
                                table.insert(search_variations, item_name:sub(1, -3))
                            end
                            
                            -- Query variations
                            for idx, search_term in ipairs(search_variations) do
                                if db_item then break end
                                
                                local escaped = search_term:gsub("'", "''")
                                
                                -- Try 315 table
                                local q1 = string.format("SELECT * FROM raw_item_data_315 WHERE name = '%s' LIMIT 1", escaped)
                                for row in Database.database:nrows(q1) do
                                    db_item = row
                                    break
                                end
                                
                                if db_item then break end
                                
                                -- Try old table
                                local q2 = string.format("SELECT * FROM raw_item_data WHERE name = '%s' LIMIT 1", escaped)
                                for row in Database.database:nrows(q2) do
                                    db_item = row
                                    break
                                end
                            end
                            
                            local success = (db_item ~= nil)
                            
                            if db_item then
                                if db_item.questitem == 1 then
                                    Write.Debug("MANUAL_REFRESH: Confirmed quest item in database: '%s'", db_item.name)
                                    
                                    -- Add to quest items if not already added for this character
                                    if not quest_items[item_name] then
                                        quest_items[item_name] = {}
                                    end
                                    
                                    local already_added = false
                                    for _, existing in ipairs(quest_items[item_name]) do
                                        if existing.character == character_name then
                                            already_added = true
                                            break
                                        end
                                    end
                                    
                                    if not already_added then
                                        table.insert(quest_items[item_name], {
                                            character = character_name,
                                            task_name = task.task_name,  -- CRITICAL: Use task.task_name NOT task.name
                                            objective = objective.objective,  -- CRITICAL: Use objective.objective NOT objective.text
                                            status = objective.status
                                        })
                                    end
                                else
                                    Write.Debug("MANUAL_REFRESH: '%s' is not a quest item", db_item.name)
                                end
                            else
                                Write.Debug("MANUAL_REFRESH: '%s' not found in database", item_name)
                            end
                        else
                            Write.Debug("MANUAL_REFRESH: No quest item found in objective")
                        end
                    end  -- Close if objective and objective.objective (NOT objective.text!)
                end  -- Close for _, objective in ipairs(task.objectives)
            end  -- Close if task.objectives
        end  -- Close for _, task in ipairs(tasks)  
    end  -- Close for character_name, tasks in pairs(task_data.tasks) - Same source as UI!
    
    -- Store quest data
    _G.YALM2_QUEST_DATA = {
        quest_items = quest_items,
        timestamp = mq.gettime(),
        character_count = #peer_list,
        task_data = task_data,
        peer_list = peer_list
    }
    
    -- Create MQ2 variable string: "Item:char1:qty1,char2:qty2|Item2:char3:qty3|"
    -- This includes quantity needed for each character
    local quest_data_string = ""
    local quest_data_with_qty = ""
    
    for item_name, char_list in pairs(quest_items) do
        local char_names = {}
        local char_details = {}  -- Will have "char:qty" format
        
        for _, char_data in ipairs(char_list) do
            table.insert(char_names, char_data.character)
            
            -- Get quantity needed from status field (e.g., "0/4" → need 4)
            local progress = parse_progress_status(char_data.status)
            if progress and progress.needed and progress.needed > 0 then
                table.insert(char_details, char_data.character .. ":" .. tostring(progress.needed))
            else
                -- Unknown quantity (shouldn't happen with normal quest data)
                table.insert(char_details, char_data.character .. ":?")
            end
        end
        
        -- Simple format (just character names) for backwards compatibility
        quest_data_string = quest_data_string .. item_name .. ":" .. table.concat(char_names, ",") .. "|"
        
        -- Enhanced format (with quantities) for new distribution logic
        quest_data_with_qty = quest_data_with_qty .. item_name .. ":" .. table.concat(char_details, ",") .. "|"
    end
    
    -- Update MQ2 variables
    local item_count = 0
    for _ in pairs(quest_items) do
        item_count = item_count + 1
    end
    
    if not mq.TLO.Defined('YALM2_Quest_Items')() then
        mq.cmd(string.format('/declare YALM2_Quest_Items string outer "%s"', quest_data_string))
        mq.cmd(string.format('/declare YALM2_Quest_Count int outer %d', item_count))
        mq.cmd(string.format('/declare YALM2_Quest_Timestamp int outer %d', mq.gettime()))
        mq.cmd(string.format('/declare YALM2_Quest_Items_WithQty string outer "%s"', quest_data_with_qty))
    else
        mq.cmd(string.format('/varset YALM2_Quest_Items "%s"', quest_data_string))
        mq.cmd(string.format('/varset YALM2_Quest_Count %d', item_count))
        mq.cmd(string.format('/varset YALM2_Quest_Timestamp %d', mq.gettime()))
    end
    
    -- Handle the WithQty variable separately since it might not exist yet
    if not mq.TLO.Defined('YALM2_Quest_Items_WithQty')() then
        mq.cmd(string.format('/declare YALM2_Quest_Items_WithQty string outer "%s"', quest_data_with_qty))
    else
        mq.cmd(string.format('/varset YALM2_Quest_Items_WithQty "%s"', quest_data_with_qty))
    end
    
    -- SHOW MANUAL REFRESH MESSAGES (this is what the user wants to see)
    if show_messages then
        print(string.format("%s Manual refresh complete: %d quest item types updated", taskheader_plain, item_count))
        
        if item_count > 0 then
            for item_name, char_list in pairs(quest_items) do
                print(string.format("%s Manual refresh - %s: %d characters", taskheader_plain, item_name, #char_list))
            end
            
            if quest_data_string:len() > 100 then
                print(string.format("%s Manual refresh data: %s...", taskheader_plain, quest_data_string:sub(1, 100)))
            elseif quest_data_string:len() > 0 then
                print(string.format("%s Manual refresh data: %s", taskheader_plain, quest_data_string))
            end
        else
            print(string.format("%s Manual refresh: No quest items found", taskheader_plain))
        end
    end
end

-- Command handler
local function cmd_yalm2quest(cmd, arg2)
    cmd = cmd or ""
    
    if cmd == 'refresh' then
        -- Manual refresh requested - process immediately with user messages (unless arg2 says otherwise)
        local show_messages = (arg2 ~= 'silent')  -- 'silent' argument suppresses messages
        Write.Debug("[NativeQuest] Processing %s refresh request...", show_messages and "manual" or "automatic")
        -- Call the function with show_messages parameter
        manual_refresh_with_messages(show_messages)
    elseif cmd == 'show' then
        mq.cmd(string.format('/echo %s \\aoShowing HUD...', taskheader))
        drawGUI = true
    elseif cmd == 'hide' then
        mq.cmd(string.format('/echo %s \\aoHiding HUD...', taskheader))
        drawGUI = false
    elseif cmd == 'stop' then
        mq.cmd(string.format('/echo %s \\aoStopping...', taskheader))
        running = false
    elseif cmd == 'help' then
        mq.cmd(string.format('/echo %s \\aoCommands:', taskheader))
        mq.cmd(string.format('/echo %s \\ao  /yalm2quest refresh - Refresh quest data', taskheader))
        mq.cmd(string.format('/echo %s \\ao  /yalm2quest show - Show HUD', taskheader))
        mq.cmd(string.format('/echo %s \\ao  /yalm2quest hide - Hide HUD', taskheader))
        mq.cmd(string.format('/echo %s \\ao  /yalm2quest stop - Stop system', taskheader))
    else
        mq.cmd(string.format('/echo %s \\aoUse /yalm2quest help for commands', taskheader))
    end
end

-- Main loop (TaskHUD's exact pattern)
local function main()
    mq.delay(500)
    while running do
        mq.doevents()
        mq.delay(200)
        
        if triggers.do_refresh then
            request_task_update()
            triggers.do_refresh = false
        end
        
        -- Send current data to YALM2 more frequently for responsive looting
        if drawGUI and #peer_list > 0 and (mq.gettime() - triggers.last_data_send) > 3000 then
            -- Send quest data every 3 seconds for responsive looting
            triggers.need_yalm2_data_send = true
            triggers.last_data_send = mq.gettime()
        end
        
        if triggers.need_task_update then
            triggers.need_task_update = false
            update_tasks()
        end
        
        if triggers.need_yalm2_data_send then
            triggers.need_yalm2_data_send = false
            
            --[[
            =====================================================================================
            AUTOMATIC QUEST PROCESSING - SILENT OPERATION ONLY!
            =====================================================================================
            
            This section runs every 3 seconds automatically for responsive looting.
            It should be SILENT - no user-facing messages, only debug logging.
            
            CRITICAL DIFFERENCES FROM MANUAL REFRESH:
            - NO Write.Info() calls (creates log spam)  
            - NO taskheader messages (user didn't request this)
            - NO print() statements with quest results
            - Use Write.Debug() only for troubleshooting
            
            DATA STRUCTURE CONSISTENCY:
            - MUST use same fields as manual refresh and UI
            - Use task.task_name NOT task.name
            - Use objective.objective NOT objective.text
            - Use same task_data.tasks source as UI and manual refresh
            
            PURPOSE:
            - Update MQ2 variables for core YALM2 looting system
            - Provide real-time quest data for item distribution
            - Maintain responsive quest item detection during combat
            =====================================================================================
            ]]--
            
            -- Parse quest items from all character task data (SILENT PROCESSING - NO USER MESSAGES!)
            local quest_items = {}
            -- CRITICAL: Use same data source and logic as manual refresh
            for character_name, tasks in pairs(task_data.tasks) do
                for _, task in ipairs(tasks) do
                    for _, objective in ipairs(task.objectives) do
                        -- Use same smart extraction as manual refresh
                        local item_name = extract_quest_item_from_objective(objective.objective)
                        
                        if item_name then
                            -- Validate against database (same as manual refresh but silent)
                            if not Database.database then
                                -- Skip validation if database not available
                                break
                            end
                            
                            -- Inline database query
                            local db_item = nil
                            local search_variations = { item_name }
                            if item_name:match('s$') then
                                table.insert(search_variations, item_name:sub(1, -2))
                            end
                            if item_name:match('es$') then
                                table.insert(search_variations, item_name:sub(1, -3))
                            end
                            
                            for _, search_term in ipairs(search_variations) do
                                if db_item then break end
                                local escaped = search_term:gsub("'", "''")
                                
                                local q1 = string.format("SELECT * FROM raw_item_data_315 WHERE name = '%s' LIMIT 1", escaped)
                                for row in Database.database:nrows(q1) do
                                    db_item = row
                                    break
                                end
                                if db_item then break end
                                
                                local q2 = string.format("SELECT * FROM raw_item_data WHERE name = '%s' LIMIT 1", escaped)
                                for row in Database.database:nrows(q2) do
                                    db_item = row
                                    break
                                end
                            end
                            
                            if db_item and db_item.questitem == 1 then
                                -- Add to quest items (same logic as manual refresh)
                                if not quest_items[item_name] then
                                    quest_items[item_name] = {}
                                end
                                
                                local already_added = false
                                for _, existing in ipairs(quest_items[item_name]) do
                                    if existing.character == character_name then
                                        already_added = true
                                        break
                                    end
                                end
                                
                                if not already_added then
                                    table.insert(quest_items[item_name], {
                                        task_name = task.task_name,      -- CRITICAL: task_name field
                                        objective = objective.objective, -- CRITICAL: objective field  
                                        status = objective.status,
                                        character = character_name
                                    })
                                end
                            end
                        end
                    end  -- Close for _, objective
                end  -- Close for _, task  
            end  -- Close for character_name, tasks
            
            -- Store in global variable for YALM2 core to access
            _G.YALM2_QUEST_DATA = {
                quest_items = quest_items,
                timestamp = mq.gettime(),
                character_count = #peer_list,
                task_data = task_data,  -- Include raw task data for detailed access
                peer_list = peer_list   -- Include peer list for character tracking
            }
            
            -- Show detailed quest data - important for user to see which characters need items
            local quest_count = 0
            for item_name, char_list in pairs(quest_items) do
                quest_count = quest_count + 1
            end
            
            -- AUTOMATIC PROCESSING: SILENT - Update MQ2 variables only, NO USER MESSAGES!
            
            -- Create quest data string for MQ2 variables
            local quest_data_string = ""
            for item_name, char_list in pairs(quest_items) do
                local char_names = {}
                for _, char_info in ipairs(char_list) do
                    table.insert(char_names, char_info.character)
                end
                if #char_names > 0 then
                    quest_data_string = quest_data_string .. item_name .. ":" .. table.concat(char_names, ",") .. "|"
                end
            end
            
            -- Update MQ2 variables silently
            local item_count = 0
            for _ in pairs(quest_items) do
                item_count = item_count + 1
            end
            
            if not mq.TLO.Defined('YALM2_Quest_Items')() then
                mq.cmd(string.format('/declare YALM2_Quest_Items string outer "%s"', quest_data_string))
                mq.cmd(string.format('/declare YALM2_Quest_Count int outer %d', item_count))
                mq.cmd(string.format('/declare YALM2_Quest_Timestamp int outer %d', mq.gettime()))
            else
                mq.cmd(string.format('/varset YALM2_Quest_Items "%s"', quest_data_string))
                mq.cmd(string.format('/varset YALM2_Quest_Count %d', item_count))
                mq.cmd(string.format('/varset YALM2_Quest_Timestamp %d', mq.gettime()))
            end
            
            -- NO USER MESSAGES IN AUTOMATIC PROCESSING!
        end
    end
    
    -- Clean up global flag and send shutdown message
    _G.yalm2_native_quest_loaded = nil
    actor:send({ id = 'END_SCRIPT' })
    mq.exit()
end

-- Argument processing (TaskHUD's exact pattern)
local function check_args()
    if #args == 0 then
        -- Master instance - ensure clean start by stopping any EXISTING instances on other characters only
        mq.cmd(string.format('/echo %s \\aoStopping any existing instances on other characters...', taskheader))
        mq.cmd('/dge /lua stop yalm2/yalm2_native_quest')  -- Use /dge to exclude THIS character
        mq.delay(2000)  -- Give more time for cleanup
        mq.cmd(string.format('/echo %s \\aoStarting collectors on other characters...', taskheader))
        mq.cmd('/dge /lua run yalm2/yalm2_native_quest nohud')  -- Use /dge to exclude self
        drawGUI = true
        triggers.do_refresh = true
    else
        for _, arg in pairs(args) do
            if arg == 'nohud' then
                drawGUI = false
            elseif arg == 'debug' then
                debug_mode = true
                mq.cmd('/dgga /lua run yalm2\\yalm2_native_quest nohud')
                drawGUI = true
                triggers.do_refresh = true
            end
        end
    end
end

-- Initialize (TaskHUD's exact pattern)
local function init()
    create_events()
    if drawGUI then
        mq.imgui.init('displayGUI', displayGUI)
    end
    mq.bind('/yalm2quest', cmd_yalm2quest)
    mq.cmd(string.format('/echo %s \\agstarting for %s. Use \\ar/yalm2quest help \\agfor commands.', taskheader, my_name))
    
    -- Delay initial refresh to allow other characters time to push task data
    -- Wait ~10 seconds from startup to let the network settle
    if drawGUI then  -- Only master coordinator triggers startup refresh
        mq.delay(10000)  -- 10 second delay to allow other characters to respond with task data
        mq.cmd('/yalm2quest refresh silent')  -- Startup refresh is silent - no quest item messages
    end
end

-- Start the system (TaskHUD's exact pattern)
check_args()
init()
main()