--- YALM2 Native Quest Coordinator (TaskHUD Architecture)
--- This script runs standalone like TaskHUD and coordinates with YALM2
--- Master instance shows UI and runs on main character
--- Collector instances (nohud) run on remote characters

local mq = require("mq")
local actors = require("actors")
local ImGui = require('ImGui')
local Write = require("yalm.lib.Write")

-- Arguments passed when starting the script  
local args = { ... }
local drawGUI = true  -- Will be set to false with 'nohud' argument
local debug_mode = false
local running = true
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

local taskheader = "\\ay[\\agYALM2 Native Quest\\ay]"

-- Prevent multiple instances by checking if we're already loaded
if _G.yalm2_native_quest_loaded then
    mq.cmd(string.format('/echo %s \\arAlready running - stopping this instance', taskheader))
    mq.exit()
end
_G.yalm2_native_quest_loaded = true

--- Get tasks using TaskHUD's exact method
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
            tasks[count1] = {
                task_name = mq.TLO.Window('TaskWnd/TASK_TaskList').List(i, 3)(),
                objectives = {},
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
                    
                    local tmp_objective = {
                        objective = clean_objective,  -- Cleaned objective text
                        status = col2,               -- Col2 is the status (Done, 0/4, etc.)
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
    
    ImGui.SetNextWindowSize(445, 490, ImGuiCond.FirstUseEver)
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
            triggers.do_refresh = true
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

-- Command handler
local function cmd_yalm2quest(cmd)
    cmd = cmd or ""
    
    if cmd == 'refresh' then
        -- Only show refresh message on manual command, not automatic refreshes
        Write.Debug("[NativeQuest] Processing refresh request...")
        triggers.do_refresh = true
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
        
        -- Send current data to YALM2 only when we have complete quest data from all characters
        if drawGUI and #peer_list > 0 and (mq.gettime() - triggers.last_data_send) > 10000 then
            -- Only send after UI is populated and we have actual quest data
            triggers.need_yalm2_data_send = true
            triggers.last_data_send = mq.gettime()
        end
        
        if triggers.need_task_update then
            triggers.need_task_update = false
            update_tasks()
        end
        
        if triggers.need_yalm2_data_send then
            triggers.need_yalm2_data_send = false
            print("[YALM2 Native Quest] Sending quest data to YALM2 core with " .. (#peer_list) .. " characters")
            -- Send as broadcast message (should reach all actors)
            actor:send({ 
                id = 'YALM2_QUEST_DATA', 
                data = {
                    tasks = task_data.tasks,
                    peer_list = peer_list,
                    timestamp = mq.gettime()
                }
            })
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
        -- Master instance - ensure clean start by stopping any existing instances first
        mq.cmd(string.format('/echo %s \\aoStopping any existing instances...', taskheader))
        mq.cmd('/dgga /lua stop yalm2/yalm2_native_quest')
        mq.delay(2000)  -- Give more time for cleanup
        mq.cmd(string.format('/echo %s \\aoStarting collectors on other characters...', taskheader))
        mq.cmd('/dge /lua run yalm2/yalm2_native_quest nohud')  -- Use /dge instead of /dgga to exclude self
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
    mq.delay(1000)  -- Longer delay to ensure full initialization
end

-- Start the system (TaskHUD's exact pattern)
check_args()
init()
main()