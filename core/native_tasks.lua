--- Native Quest Detection System for YALM2
--- Integrates TaskHUD's proven quest detection logic directly into YALM2
--- Eliminates external script dependencies and communication reliability issues

local mq = require("mq")
local dannet = require("yalm.lib.dannet")
local debug_logger = require("yalm2.lib.debug_logger")
require("yalm2.lib.Write")

local native_tasks = {}

-- Internal task storage (replaces external TaskHUD communication)
local native_task_data = {
    characters = {},  -- character_name -> { tasks = {...}, last_updated = timestamp }
    quest_items = {}, -- item_name -> { needed_by = {character_names...}, task_name = "..." }
    master_looter = nil,
    connected_characters = {},
}

--- Get tasks for the current character using TaskHUD's proven method
--- This is TaskHUD's core logic adapted for YALM2
native_tasks.get_current_character_tasks = function()
    Write.Info("Getting tasks for current character using native quest detection...")
    local tasks = {}
    
    -- Open the task window (TaskHUD's approach)
    mq.TLO.Window('TaskWnd').DoOpen()
    while mq.TLO.Window('TaskWnd').Open() == false do
        mq.delay(100)  -- Wait for window to open
    end
    
    local count1, count2 = 1, 1
    for i = 1, mq.TLO.Window('TaskWnd/TASK_TaskList').Items() do
        mq.TLO.Window('TaskWnd/TASK_TaskList').Select(i)
        while mq.TLO.Window('TaskWnd/TASK_TaskList').GetCurSel() ~= i do
            mq.delay(50)  -- Wait for selection
        end
        
        -- Check that the name of the task is not nil (skip separator lines)
        if mq.TLO.Window('TaskWnd/TASK_TaskList').List(i, 3)() ~= nil then
            tasks[count1] = {
                task_name = mq.TLO.Window('TaskWnd/TASK_TaskList').List(i, 3)(),
                objectives = {},
            }

            -- Loop through the objectives of the current task
            for j = 1, mq.TLO.Window('TaskWnd/TASK_TaskElementList').Items() do
                -- Check that the name of the objective is not nil (skip separator lines)
                if mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 2)() ~= nil then
                    local tmp_objective = {
                        objective = mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 1)(),
                        status = mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 2)(),
                    }
                    table.insert(tasks[count1]['objectives'], count2, tmp_objective)
                    count2 = count2 + 1
                end
            end
            count2 = 1
            count1 = count1 + 1
        end
    end
    
    -- Close the task window
    mq.TLO.Window('TaskWnd').DoClose()
    
    Write.Info("Native quest detection found %d tasks for current character", #tasks)
    debug_logger.info("NATIVE_TASKS: Found %d tasks for %s", #tasks, mq.TLO.Me.DisplayName())
    
    return tasks
end

--- Get group/raid members with DanNet connectivity for quest monitoring
native_tasks.get_connected_characters = function()
    Write.Info("Finding group/raid members with DanNet connectivity for quest monitoring...")
    
    local connected = {}
    local group_raid_members = {}
    
    -- Collect all group members
    if mq.TLO.Group.Members() > 0 then
        Write.Info("Checking %d group members for DanNet connectivity", mq.TLO.Group.Members() + 1)
        for i = 0, mq.TLO.Group.Members() do
            local member_name = nil
            if i == 0 then
                member_name = mq.TLO.Me.DisplayName()
            else
                member_name = mq.TLO.Group.Member(i).DisplayName()
            end
            
            if member_name and member_name ~= "" then
                table.insert(group_raid_members, {name = member_name, source = "Group", index = i})
            end
        end
    end
    
    -- Collect all raid members (if in raid, this replaces group logic)
    if mq.TLO.Raid.Members() > 0 then
        Write.Info("In raid - checking %d raid members for DanNet connectivity", mq.TLO.Raid.Members())
        group_raid_members = {} -- Clear group members, raid takes precedence
        
        -- Add self first
        table.insert(group_raid_members, {name = mq.TLO.Me.DisplayName(), source = "Raid", index = 0})
        
        -- Add all raid members
        for i = 1, mq.TLO.Raid.Members() do
            local member_name = mq.TLO.Raid.Member(i).DisplayName()
            if member_name and member_name ~= "" then
                -- Avoid duplicates (self might be in raid member list too)
                local already_added = false
                for _, existing in ipairs(group_raid_members) do
                    if existing.name == member_name then
                        already_added = true
                        break
                    end
                end
                
                if not already_added then
                    table.insert(group_raid_members, {name = member_name, source = "Raid", index = i})
                end
            end
        end
    end
    
    -- If not in group or raid, just use self
    if #group_raid_members == 0 then
        Write.Info("Not in group or raid - monitoring only current character")
        table.insert(group_raid_members, {name = mq.TLO.Me.DisplayName(), source = "Solo", index = 0})
    end
    
    Write.Info("Testing DanNet connectivity for %d %s members...", #group_raid_members, 
        mq.TLO.Raid.Members() > 0 and "raid" or (mq.TLO.Group.Members() > 0 and "group" or "solo"))
    
    -- Test DanNet connectivity for each group/raid member ONLY
    for _, member in ipairs(group_raid_members) do
        Write.Debug("Testing DanNet connectivity to %s (%s %d)...", member.name, member.source, member.index)
        
        local response = dannet.query(member.name, "Me.Name", 2000)
        if response and response ~= "NULL" and response ~= "" then
            table.insert(connected, member.name)
            Write.Info("✅ %s is DanNet connected (%s member)", member.name, member.source)
            
            -- Get additional info for debugging
            local zone = dannet.query(member.name, "Zone.ShortName", 1000) or "unknown"
            local class = dannet.query(member.name, "Me.Class.ShortName", 1000) or "unknown"
            Write.Debug("   %s: %s in %s", member.name, class, zone)
        else
            Write.Warn("❌ %s not responding to DanNet (%s member) - cannot monitor their quests", 
                member.name, member.source)
        end
    end
    
    Write.Info("Quest Monitoring Summary:")
    Write.Info("  %s members: %d", mq.TLO.Raid.Members() > 0 and "Raid" or "Group", #group_raid_members)
    Write.Info("  DanNet connected for quest monitoring: %d", #connected)
    Write.Info("  Will monitor quests for: [%s]", table.concat(connected, ", "))
    
    if #connected < #group_raid_members then
        Write.Warn("⚠️  %d %s members are not DanNet connected - their quests will not be monitored", 
            #group_raid_members - #connected, mq.TLO.Raid.Members() > 0 and "raid" or "group")
    end
    
    native_task_data.connected_characters = connected
    return connected
end

--- Query tasks from a specific character via DanNet
native_tasks.get_character_tasks_via_dannet = function(character_name)
    Write.Debug("Querying tasks from %s via DanNet...", character_name)
    
    -- Use DanNet to execute the task detection on the remote character
    -- This requires the native quest detection function to be available on all clients
    
    -- For now, return empty - this would need TaskHUD-style logic deployed to each character
    -- Or we could query individual task elements directly via DanNet TLO queries
    
    Write.Debug("DanNet task querying not yet implemented for %s", character_name)
    return {}
end

--- Extract quest items from native task data
native_tasks.extract_quest_items = function()
    Write.Info("Extracting quest items from native task data...")
    native_task_data.quest_items = {}
    
    -- Import quest item patterns from tasks module
    local quest_item_patterns = {
        "Sample$", "Essence$", "Fragment$", "Shard$", "Component$", "Part$", "Piece$", 
        "Token$", "Medallion$", "Emblem$", "Seal$", "Crystal$", "Gem$", "Stone$", 
        "Ore$", "Metal$", "Wood$", "Bone$", "Scale$", "Claw$", "Fang$", "Hide$", 
        "Pelt$", "Feather$", "Wing$", "Heart$", "Brain$", "Eye$", "Blood$", "Bile$", 
        "Dust$", "Powder$"
    }
    
    local quest_items_found = 0
    
    -- Process each character's tasks
    for character_name, char_data in pairs(native_task_data.characters) do
        if char_data.tasks and #char_data.tasks > 0 then
            Write.Debug("Processing tasks for %s (%d tasks)", character_name, #char_data.tasks)
            
            for _, task in ipairs(char_data.tasks) do
                if task.objectives then
                    for _, objective in ipairs(task.objectives) do
                        if objective.objective and objective.objective ~= "? ? ?" and objective.objective ~= "" then
                            -- Only process LOOT/COLLECT objectives
                            local is_loot_objective = objective.objective:match("^Loot ") or objective.objective:match("^Collect ")
                            
                            if is_loot_objective then
                                local needs_item = (objective.status ~= "Done" and objective.status ~= "")
                                
                                if needs_item then
                                    local extracted_item = native_tasks.extract_quest_item_name(objective.objective, quest_item_patterns)
                                    
                                    if extracted_item then
                                        Write.Info("Found quest item need: %s for %s (task: %s)", 
                                            extracted_item, character_name, task.task_name)
                                        
                                        if not native_task_data.quest_items[extracted_item] then
                                            native_task_data.quest_items[extracted_item] = {
                                                needed_by = {},
                                                task_name = task.task_name,
                                                objective = objective.objective
                                            }
                                            quest_items_found = quest_items_found + 1
                                        end
                                        
                                        -- Add character to needed_by list if not already there
                                        local already_added = false
                                        for _, char in ipairs(native_task_data.quest_items[extracted_item].needed_by) do
                                            if char == character_name then
                                                already_added = true
                                                break
                                            end
                                        end
                                        
                                        if not already_added then
                                            table.insert(native_task_data.quest_items[extracted_item].needed_by, character_name)
                                        end
                                        
                                        debug_logger.quest("NATIVE_QUEST_ITEM: %s -> [%s] task:'%s'", 
                                            extracted_item, character_name, task.task_name)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    Write.Info("Native quest extraction found %d quest items that need collecting", quest_items_found)
    debug_logger.info("NATIVE_EXTRACTION: Found %d quest items", quest_items_found)
end

--- Extract quest item name from objective text (borrowed from tasks.lua)
native_tasks.extract_quest_item_name = function(objective_text, quest_item_patterns)
    if not objective_text then return nil end
    
    local item_name = nil
    
    -- Try various loot patterns
    item_name = objective_text:match("Loot %d+ (.+) from") or
                objective_text:match("Loot a (.+) from") or
                objective_text:match("Loot some (.+) from") or
                objective_text:match("Collect %d+ (.+) from") or
                objective_text:match("Collect a few (.+) from") or
                objective_text:match("Collect some (.+) from") or
                objective_text:match("Collect %d+ (.+)") or
                objective_text:match("Collect (.+)") or
                objective_text:match("Loot %d+ (.+)") or
                objective_text:match("Loot (.+)")
    
    -- Convert plural to singular and apply title case
    if item_name then
        local lowercase_item = item_name:lower()
        if lowercase_item:match("(.+) samples?$") then
            local base = item_name:match("(.+) [Ss]amples?$")
            if base then
                item_name = base .. " Sample"
            end
        elseif item_name:lower():match("(.+)s$") and not item_name:lower():match("ss$") then
            item_name = item_name:gsub("s$", "")
        end
        
        -- Title case
        item_name = item_name:gsub("(%w)([%w']*)", function(first, rest)
            return string.upper(first) .. string.lower(rest)
        end)
        
        -- Check against quest item patterns
        for _, pattern in ipairs(quest_item_patterns) do
            if item_name:match(pattern) then
                return item_name
            end
        end
    end
    
    return nil
end

--- Initialize native quest system
native_tasks.initialize = function()
    Write.Info("Initializing native quest detection system...")
    
    -- Set master looter
    native_task_data.master_looter = mq.TLO.Me.DisplayName()
    
    -- Get group/raid members with DanNet connectivity
    local connected = native_tasks.get_connected_characters()
    
    if #connected == 0 then
        Write.Warn("No group/raid members have DanNet connectivity - quest detection will be limited to current character only")
        return false
    end
    
    -- Get master looter's tasks (authoritative source)
    local my_tasks = native_tasks.get_current_character_tasks()
    native_task_data.characters[native_task_data.master_looter] = {
        tasks = my_tasks,
        last_updated = os.time()
    }
    
    -- Extract quest items from task data
    native_tasks.extract_quest_items()
    
    Write.Info("Native quest system initialized with %d characters, %d tasks for master looter", 
        #connected, #my_tasks)
    
    return true
end

--- Get quest items from native task data (replaces TaskHUD communication)
native_tasks.get_quest_items = function()
    return native_task_data.quest_items
end

--- Check if item is needed for quests (native implementation)
native_tasks.is_quest_item = function(item_name)
    return native_task_data.quest_items[item_name] ~= nil
end

--- Get characters needing specific quest item (native implementation)
native_tasks.get_characters_needing_item = function(item_name)
    local quest_info = native_task_data.quest_items[item_name]
    if quest_info then
        return quest_info.needed_by, quest_info.task_name, quest_info.objective
    end
    return {}, nil, nil
end

--- Force refresh of group/raid member task data
native_tasks.refresh_all_characters = function()
    Write.Info("Refreshing quest data for group/raid members...")
    
    -- Refresh group/raid member list with DanNet connectivity
    local connected = native_tasks.get_connected_characters()
    
    -- Get fresh task data for master looter (current character)
    local my_tasks = native_tasks.get_current_character_tasks()
    native_task_data.characters[native_task_data.master_looter] = {
        tasks = my_tasks,
        last_updated = os.time()
    }
    
    -- Extract quest items from current task data
    native_tasks.extract_quest_items()
    
    Write.Info("Quest refresh complete for %d connected group/raid members", #connected)
    return true
end

return native_tasks