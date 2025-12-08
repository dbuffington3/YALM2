--- @type Mq
local mq = require("mq")
local actors = require("actors")
local debug_logger = require("yalm2.lib.debug_logger")

local tasks = {}

-- Task data received from TaskHUD
local task_data = {
    characters = {}, -- character_name -> { tasks = {...}, last_updated = timestamp }
    missing_tasks = {}, -- task_name -> { missing_characters = {...}, objectives = {...} }
    quest_items = {}, -- item_name -> { needed_by = {character_names...}, task_name = "..." }
}

-- Configuration for quest item detection
local quest_item_patterns = {
    -- Common quest item patterns (can be expanded)
    "Sample$",
    "Essence$", 
    "Fragment$",
    "Shard$",
    "Component$",
    "Part$",
    "Piece$",
    "Token$",
    "Medallion$",
    "Emblem$",
    "Seal$",
    "Crystal$",
    "Gem$",
    "Stone$",
    "Ore$",
    "Metal$",
    "Wood$",
    "Bone$",
    "Scale$",
    "Claw$",
    "Fang$",
    "Hide$",
    "Pelt$",
    "Feather$",
    "Wing$",
    "Heart$",
    "Brain$",
    "Eye$",
    "Blood$",
    "Bile$",
    "Dust$",
    "Powder$",
    "Extract$",
    "Potion$",
    "Elixir$",
    "Mixture$",
}

-- Actor for receiving task updates from TaskHUD
local task_actor = nil

-- Initialize the task system
tasks.init = function()
    Write.Info("Initializing task awareness system...")
    debug_logger.info("STARTUP: Initializing task awareness system")
    
    -- Try to register actor with explicit configuration
    Write.Info("Registering task actor...")
    task_actor = actors.register(function(message)
        Write.Info("YALM2 actor received: %s from %s", message.content and message.content.id or "no id", message.sender and message.sender.character or "unknown")
        tasks.handle_task_message(message)
    end)
    
    Write.Info("Task actor registered: %s", tostring(task_actor))
    debug_logger.info("STARTUP: Task actor registered successfully")
    
    -- Request initial task data with retry logic (using same approach as manual refresh)
    local max_startup_attempts = 3
    local received_data = false
    
    for attempt = 1, max_startup_attempts do
        Write.Info("Requesting initial task data (attempt %d/%d)...", attempt, max_startup_attempts)
        debug_logger.info("STARTUP: Requesting initial task data from TaskHUD (attempt %d)", attempt)
        tasks.request_task_update()
        
        -- Use same timing as successful manual refresh: wait 1 full second, then check every 200ms for up to 3 seconds
        Write.Info("Waiting for TaskHUD response...")
        debug_logger.info("STARTUP: Waiting for TaskHUD response (checking every 200ms for up to 3 seconds)...")
        
        local response_timeout = 3000 -- 3 seconds total
        local check_interval = 200    -- Check every 200ms
        local start_time = os.clock() * 1000 -- Convert to milliseconds
        
        while (os.clock() * 1000 - start_time) < response_timeout do
            mq.delay(check_interval)
            if tasks.check_taskhud_response() then
                received_data = true
                Write.Info("Initial task data received successfully!")
                debug_logger.info("STARTUP: Initial task data received successfully on attempt %d after %.1f seconds", attempt, (os.clock() * 1000 - start_time) / 1000)
                break
            end
        end
        
        if received_data then
            break
        else
            debug_logger.warn("STARTUP: Attempt %d failed - no response from TaskHUD after 3 seconds", attempt)
            if attempt < max_startup_attempts then
                Write.Info("No response on attempt %d, retrying in 2 seconds...", attempt)
                debug_logger.info("STARTUP: Retrying in 2 seconds...")
                mq.delay(2000)
            end
        end
    end
    
    if not received_data then
        Write.Warn("Timeout waiting for initial task data - continuing with empty cache")
        Write.Warn("Quest-aware looting will not work until task data is received")
        debug_logger.warn("STARTUP: Timeout waiting for initial task data - quest features may not work initially")
    else
        -- Process the initial quest items
        tasks.update_quest_items()
        local quest_count = 0
        for _ in pairs(task_data.quest_items) do quest_count = quest_count + 1 end
        Write.Info("Task initialization complete - tracking %d quest items", quest_count)
        debug_logger.info("STARTUP: Task initialization complete with %d quest items", quest_count)
    end
end

-- Handle incoming task messages from TaskHUD
tasks.handle_task_message = function(message)
    Write.Info("Received actor message: %s", message.content and message.content.id or "no id")
    
    if not message.content or not message.content.id then
        Write.Warn("Received message with no content or id")
        return
    end
    
    if message.content.id == 'YALM_TASK_DATA' then
        -- Receive task data specifically from TaskHUD for YALM
        Write.Info("Received YALM task data from TaskHUD!")
        
        if message.content.tasks then
            local task_count = #message.content.tasks
            Write.Info("Received %d tasks from TaskHUD", task_count)
            
            -- Update our task cache with the current character's data
            local my_character = mq.TLO.Me.DisplayName()
            task_data.characters[my_character] = {
                tasks = message.content.tasks,
                last_updated = os.time()
            }
            
            -- Update missing tasks data if provided
            if message.content.missing_tasks then
                task_data.missing_tasks = message.content.missing_tasks
            end
            
            -- Update quest item patterns
            tasks.update_quest_items()
            
            -- Log task details
            for i, task in ipairs(message.content.tasks) do
                Write.Debug("Task %d: %s (%d objectives)", i, task.task_name, #task.objectives)
            end
        else
            Write.Warn("Received YALM_TASK_DATA but no tasks in message")
        end
        
    elseif message.content.id == 'INCOMING_TASKS' then
        -- Receive task data from TaskHUD
        local character = message.sender.character
        local character_tasks = message.content.tasks
        local missing_data = nil -- TaskHUD doesn't send missing_tasks in INCOMING_TASKS
        
        Write.Debug("Received task data from %s", character)
        
        -- Store character task data
        task_data.characters[character] = {
            tasks = character_tasks,
            last_updated = os.time()
        }
        
        -- Update missing tasks data
        if missing_data then
            task_data.missing_tasks = missing_data
            tasks.update_quest_items()
        end
        
    elseif message.content.id == 'TASK_UPDATED' then
        -- Task was updated, request fresh data
        Write.Debug("Task update detected, refreshing data...")
        tasks.request_task_update()
    end
end

-- Request task data from TaskHUD  
tasks.request_task_update = function()
    Write.Info("Requesting tasks from TaskHUD...")
    
    -- Method 1: Direct actor messaging (for existing TaskHUD compatibility)
    if task_actor then
        Write.Info("Sending YALM_REQUEST_TASKS via actors...")
        actors.send({ id = 'YALM_REQUEST_TASKS' })
    end
    
    -- Method 2: Use file-based communication (scripts have separate _G tables)
    Write.Info("Creating file-based request for TaskHUD...")
    local request_file = "c:/MQ2/logs/yalm2_request.txt"
    local file = io.open(request_file, "w")
    if file then
        file:write(string.format("REQUEST_TASKS\n%d\n", os.time()))
        file:close()
        Write.Info("Request file created: %s", request_file)
    else
        Write.Error("Failed to create request file: %s", request_file)
    end
    
    Write.Info("Task request sent via actors and file")
end

-- Request task data for a specific character only
tasks.request_character_task_update = function(character_name)
    debug_logger.info("CHAR_REFRESH: Requesting task update for %s only", character_name)
    Write.Info("Requesting task update for character: %s", character_name)
    
    -- Method 1: Direct actor messaging with character specification
    if task_actor then
        debug_logger.debug("CHAR_REFRESH: Sending character-specific request via actors")
        actors.send({ 
            id = 'YALM_REQUEST_CHARACTER_TASKS',
            character = character_name
        })
    end
    
    -- Method 2: Use file-based communication for character-specific request
    local request_file = "c:/MQ2/logs/yalm2_character_request.txt"
    local file = io.open(request_file, "w")
    if file then
        file:write(string.format("REQUEST_CHARACTER_TASKS\n%s\n%d\n", character_name, os.time()))
        file:close()
        debug_logger.debug("CHAR_REFRESH: Character request file created for %s", character_name)
    else
        debug_logger.error("CHAR_REFRESH: Failed to create character request file for %s", character_name)
    end
    
    debug_logger.info("CHAR_REFRESH: Character-specific request sent for %s", character_name)
end

-- Aggregate all individual character response files into consolidated task data
tasks.aggregate_all_character_responses = function()
    debug_logger.info("STARTUP: Aggregating individual character response files...")
    
    -- Clear existing data
    task_data.characters = {}
    task_data.quest_items = {}
    
    local characters_loaded = 0
    local total_tasks = 0
    
    -- Look for all character response files
    local response_pattern = "c:/MQ2/logs/yalm2_response_"
    local test_names = {"Forestess", "Tarnook", "Lumarra", "Astraean", "Calystris", "Ceeles", "Echoveil", "Kaelor", "Lunarra", "Malrik", "Vaeloraa", "Lyricen", "Vexxuss"}
    
    for _, char_name in ipairs(test_names) do
        local char_file = response_pattern .. char_name .. ".json"
        local file = io.open(char_file, "r")
        if file then
            local content = file:read("*all")
            file:close()
            
            if content and #content > 0 then
                debug_logger.info("STARTUP: Processing character file: %s (%d bytes)", char_file, #content)
                
                -- Parse this character's data (simplified JSON parsing)
                local char_task_count_str = content:match('"task_count":%s*(%d+)') or "0"
                local char_task_count = tonumber(char_task_count_str)
                
                if char_task_count > 0 then
                    -- Store character data (simplified)
                    task_data.characters[char_name] = {
                        tasks = {}, -- Will be populated by extract_quest_items_from_response
                        last_updated = os.time(),
                        task_count = char_task_count
                    }
                    
                    -- Extract quest items from this character's data
                    tasks.extract_quest_items_from_response(content)
                    
                    characters_loaded = characters_loaded + 1
                    total_tasks = total_tasks + char_task_count
                    debug_logger.info("STARTUP: Loaded %s (%d tasks)", char_name, char_task_count)
                end
                
                -- Clean up this character's response file
                os.remove(char_file)
            end
        end
    end
    
    debug_logger.info("STARTUP: Aggregation complete - %d characters, %d total tasks", characters_loaded, total_tasks)
    
    if characters_loaded > 0 then
        debug_logger.info("STARTUP: Successfully aggregated task data from individual character files")
        return true
    else
        debug_logger.warn("STARTUP: No character data found to aggregate")
        return false
    end
end

-- Update quest items based on task data
tasks.update_quest_items = function()
    Write.Info("Updating quest items from character task data...")
    task_data.quest_items = {}
    
    local total_objectives = 0
    local quest_item_count = 0
    
    -- Analyze ALL character tasks (not just missing tasks) since we now have full data
    for character_name, char_data in pairs(task_data.characters) do
        if char_data.tasks and #char_data.tasks > 0 then
            Write.Debug("Processing tasks for %s (%d tasks)", character_name, #char_data.tasks)
            
            for _, task in ipairs(char_data.tasks) do
                if task.objectives then
                    for _, objective in ipairs(task.objectives) do
                        total_objectives = total_objectives + 1
                        
                        if objective.objective and objective.objective ~= "? ? ?" and objective.objective ~= "" then
                            -- Only process LOOT/COLLECT objectives, not DELIVER/SPEAK/KILL objectives
                            local is_loot_objective = objective.objective:match("^Loot ") or objective.objective:match("^Collect ")
                            
                            if is_loot_objective then
                                debug_logger.info("QUEST_UPDATE: Processing loot objective: '%s' [Status: %s] for %s", objective.objective, objective.status or "unknown", character_name)
                            else
                                debug_logger.debug("QUEST_UPDATE: Skipping non-loot objective: '%s' for %s", objective.objective, character_name)
                            end
                            
                            if is_loot_objective then
                                local potential_item = tasks.extract_quest_item_name(objective.objective)
                                if potential_item then
                                    -- Check if character still needs this (not completed)
                                    -- "Done" = completed, "0/3" = incomplete, "" = unknown/future
                                    local needs_item = (objective.status ~= "Done" and objective.status ~= "")
                                    
                                    if needs_item then
                                    if not task_data.quest_items[potential_item] then
                                        task_data.quest_items[potential_item] = {
                                            needed_by = {},
                                            task_name = task.task_name,
                                            objective = objective.objective
                                        }
                                        quest_item_count = quest_item_count + 1
                                    end
                                    
                                    -- Add character to needed_by list if not already there
                                    local already_added = false
                                    for _, char in ipairs(task_data.quest_items[potential_item].needed_by) do
                                        if char == character_name then
                                            already_added = true
                                            break
                                        end
                                    end
                                    
                                    if not already_added then
                                        table.insert(task_data.quest_items[potential_item].needed_by, character_name)
                                        Write.Info("Quest item: %s needed by %s (task: %s)", potential_item, character_name, task.task_name)
                                    end
                                end
                            end
                            end -- Close the is_loot_objective if block
                        end
                    end
                end
            end
        end
    end
    
    -- Also process missing tasks data if available
    for task_name, task_info in pairs(task_data.missing_tasks) do
        if task_info.objectives then
            for _, objective_info in ipairs(task_info.objectives) do
                local objective_name = objective_info.objective_name
                local potential_item = tasks.extract_quest_item_name(objective_name)
                if potential_item then
                    -- Find characters who still need this objective
                    local needed_by = {}
                    for _, char_data in ipairs(objective_info.characters) do
                        if char_data.status ~= "Done" then
                            table.insert(needed_by, char_data.character)
                        end
                    end
                    
                    if #needed_by > 0 then
                        if not task_data.quest_items[potential_item] then
                            task_data.quest_items[potential_item] = {
                                needed_by = needed_by,
                                task_name = task_name,
                                objective = objective_name
                            }
                            quest_item_count = quest_item_count + 1
                        end
                    end
                end
            end
        end
    end
    
    -- Show quest items found in character processing
    local quest_item_summary = {}
    for item_name, item_info in pairs(task_data.quest_items) do
        if item_info.needed_by and #item_info.needed_by > 0 then
            quest_item_summary[item_name] = table.concat(item_info.needed_by, ", ")
        end
    end
    
    Write.Info("Quest items updated: %d items identified from %d objectives across %d characters", 
        quest_item_count, total_objectives, 
        (function() local count = 0; for _ in pairs(task_data.characters) do count = count + 1 end; return count end)())
        
    for item_name, needed_by_list in pairs(quest_item_summary) do
        Write.Info("  📦 %s needed by: %s", item_name, needed_by_list)
    end
end

-- Extract quest items directly from TaskHUD response content with character tracking
tasks.extract_quest_items_from_response = function(content)
    Write.Debug("Extracting quest items directly from response...")
    debug_logger.info("STARTUP: QUEST_EXTRACTION_START: Processing TaskHUD response (length: %d)", #content)
    
    -- CRITICAL: Clear old cached quest items to prevent stale data
    task_data.quest_items = {}
    Write.Debug("Cleared old quest items cache")
    debug_logger.debug("STARTUP: CACHE_CLEARED: Removed all previous quest item data")
    
    local quest_items_found = {}
    local total_objectives = 0
    local completed_objectives = 0
    
    -- Extract character names from JSON structure for targeted parsing
    local character_names = {}
    for character_name in content:gmatch('"([^"]+)":%s*{%s*"task_count"') do
        table.insert(character_names, character_name)
    end
    
    Write.Debug("Processing objectives for %d characters", #character_names)
    
    -- Process each character's objectives using structured approach
    for _, character_name in ipairs(character_names) do
        -- Find this character's section start and end positions in the JSON
        local char_start_pattern = '"' .. character_name:gsub("%-", "%%-") .. '":%s*{'
        local char_start = content:find(char_start_pattern)
        
        if char_start then
            -- Find the end of this character's section (next character or end of characters)
            local next_char_start = nil
            for _, other_char in ipairs(character_names) do
                if other_char ~= character_name then
                    local other_pattern = '"' .. other_char:gsub("%-", "%%-") .. '":%s*{'
                    local other_pos = content:find(other_pattern, char_start + 1)
                    if other_pos and (not next_char_start or other_pos < next_char_start) then
                        next_char_start = other_pos
                    end
                end
            end
            
            -- If no next character found, find the end of the characters section
            if not next_char_start then
                next_char_start = content:find('}%s*}%s*}%s*$') or #content
            end
            
            -- Extract this character's section
            local char_section = content:sub(char_start, next_char_start - 1)
            Write.Debug("Processing character %s section (length: %d)", character_name, #char_section)
            
            -- Extract objectives from this character's section
            for objective_block in char_section:gmatch('{%s*"objective":%s*"[^"]*"%s*,%s*"status":%s*"[^"]*"%s*}') do
                total_objectives = total_objectives + 1
                
                local objective_text = objective_block:match('"objective":%s*"([^"]*)"')
                local status_text = objective_block:match('"status":%s*"([^"]*)"')
                        
                        -- Only process objectives that are NOT completed
                        local is_completed = (status_text == "Done")
                        
                        if is_completed then
                            completed_objectives = completed_objectives + 1
                        elseif objective_text and objective_text ~= "? ? ?" and objective_text ~= "" and status_text and status_text ~= "" and status_text ~= "Done" then
                            Write.Info("Processing active objective for %s: '%s' [Status: %s]", character_name, objective_text, status_text)
                            
                            -- Only process LOOT/COLLECT objectives, not DELIVER/SPEAK/KILL objectives
                            local is_loot_objective = objective_text:match("^Loot ") or objective_text:match("^Collect ")
                            
                            if not is_loot_objective then
                                Write.Debug("Skipping non-loot objective: '%s' (Deliver/Kill/Speak objectives don't need item collection)", objective_text)
                            elseif status_text == "Done" then
                                Write.Debug("Skipping COMPLETED loot objective: '%s'", objective_text)
                            else
                                Write.Info("Testing ACTIVE LOOT objective for %s: '%s'", character_name, objective_text)
                                local extracted_item = tasks.extract_quest_item_name(objective_text)
                                Write.Info("Item extraction result for %s: '%s'", character_name, extracted_item or "nil")
                            
                            if extracted_item then
                                -- This objective is active (not "Done") and contains a quest item
                                Write.Info("Processing quest item objective for %s: '%s' [Status: %s] -> ITEM: %s", character_name, objective_text, status_text, extracted_item)
                                        if not quest_items_found[extracted_item] then
                                            quest_items_found[extracted_item] = {
                                                needed_by = {},
                                                task_name = "Direct Extract",
                                                objective = objective_text
                                            }
                                        end
                                        
                                        -- Add character to needed_by list if not already there
                                        local already_added = false
                                        for _, char in ipairs(quest_items_found[extracted_item].needed_by) do
                                            if char == character_name then
                                                already_added = true
                                                break
                                            end
                                        end
                                        
                                        if not already_added then
                                            table.insert(quest_items_found[extracted_item].needed_by, character_name)
                                            Write.Info("Quest item: %s needed by %s (objective: %s)", extracted_item, character_name, objective_text)
                                            Write.Debug("Current needed_by list for %s: [%s]", extracted_item, table.concat(quest_items_found[extracted_item].needed_by, ", "))
                                        else
                                            Write.Debug("Character %s already in needed_by list for %s", character_name, extracted_item)
                                        end
                                        
                                        Write.Info("Found quest item: %s (from: %s) [Status: %s] [Character: %s]", extracted_item, objective_text, status_text or "unknown", character_name)
                            else
                                -- Log collection objectives that don't match our patterns for debugging
                                if objective_text:match("[Cc]ollect") or objective_text:match("[Ll]oot") or objective_text:match("[Gg]ather") or objective_text:match("[Ff]ind") then
                                    Write.Debug("COLLECT objective with no item match: '%s' [Status: %s] [Character: %s]", objective_text, status_text or "unknown", character_name)
                                end
                            end
                        end
                        end
                    end
                end
            end
    
    -- Merge with existing quest items (update with fresh character data)
    for item_name, item_info in pairs(quest_items_found) do
        -- Always update with the fresh extraction data since it has current character needs
        task_data.quest_items[item_name] = item_info
        Write.Info("FINAL: Quest item %s needed by [%s]", item_name, table.concat(item_info.needed_by, ", "))
        Write.Debug("Updated quest item data for: %s (needed by %d characters)", item_name, #item_info.needed_by)
        
        debug_logger.quest("QUEST_ITEM_STORED: %s -> [%s] task:'%s' obj:'%s'", 
            item_name, 
            table.concat(item_info.needed_by, ", "),
            item_info.task_name or "Unknown",
            item_info.objective or "Unknown")
    end
    
    local item_count = 0
    for _ in pairs(quest_items_found) do item_count = item_count + 1 end
    
    if item_count > 0 then
        Write.Info("Found %d quest items that need collecting", item_count)
        debug_logger.info("STARTUP: QUEST_EXTRACTION_COMPLETE: Found %d quest items that need collecting", item_count)
    else
        Write.Info("No quest items currently need collecting")
        debug_logger.info("STARTUP: QUEST_EXTRACTION_COMPLETE: No quest items currently need collecting")
    end
end

-- Extract potential quest item name from objective text
tasks.extract_quest_item_name = function(objective_text)
    if not objective_text then 
        debug_logger.debug("EXTRACT_ITEM_NAME: Null objective text provided")
        return nil 
    end
    
    Write.Debug("Attempting to extract item name from: '%s'", objective_text)
    debug_logger.debug("EXTRACT_ITEM_NAME: Processing '%s'", objective_text)
    
    -- Initialize item_name as local variable to prevent persistence between calls
    local item_name = nil
    
    -- Look for patterns like "Collect X ItemName" or "Loot X ItemName"
    -- Handle both numbers and text quantities like "a few", "several", etc.
    -- Also handle "from..." suffixes that specify mob sources
    -- Note: "from" can be followed by "the", "a", or directly by mob names
    
    -- Loot patterns with "from" suffix (most specific first)
    if not item_name then
        item_name = objective_text:match("Loot %d+ (.+) from")
        if item_name then Write.Debug("Pattern 'Loot %%d+ (.+) from' matched: '%s'", item_name) end
    end
    if not item_name then
        item_name = objective_text:match("Loot a (.+) from")
        if item_name then Write.Debug("Pattern 'Loot a (.+) from' matched: '%s'", item_name) end
    end
    if not item_name then
        item_name = objective_text:match("Loot some (.+) from")
        if item_name then Write.Debug("Pattern 'Loot some (.+) from' matched: '%s'", item_name) end
    end
    
    -- Collect patterns with "from" suffix
    if not item_name then
        item_name = objective_text:match("Collect %d+ (.+) from")
        if item_name then Write.Debug("Pattern 'Collect %%d+ (.+) from' matched: '%s'", item_name) end
    end
    if not item_name then
        item_name = objective_text:match("Collect a few (.+) from")
        if item_name then Write.Debug("Pattern 'Collect a few (.+) from' matched: '%s'", item_name) end
    end
    if not item_name then
        item_name = objective_text:match("Collect some (.+) from")
        if item_name then Write.Debug("Pattern 'Collect some (.+) from' matched: '%s'", item_name) end
    end
    
    -- Standard collect patterns (without "from")
    if not item_name then
        item_name = objective_text:match("Collect %d+ (.+)")
        if item_name then Write.Debug("Pattern 'Collect %%d+ (.+)' matched: '%s'", item_name) end
    end
    if not item_name then
        item_name = objective_text:match("Collect a few (.+)")
        if item_name then Write.Debug("Pattern 'Collect a few (.+)' matched: '%s'", item_name) end
    end
    if not item_name then
        item_name = objective_text:match("Collect some (.+)")
    end
    if not item_name then
        item_name = objective_text:match("Collect (.+)")  -- Generic collect pattern
    end
    
    -- Standard loot patterns (without "from") 
    if not item_name then
        item_name = objective_text:match("Loot %d+ (.+)")
    end
    if not item_name then
        item_name = objective_text:match("Loot a (.+)")
    end
    if not item_name then
        item_name = objective_text:match("Loot (.+)")  -- Generic loot pattern
    end
    if not item_name then
        item_name = objective_text:match("Gather %d+ (.+)")
    end
    if not item_name then
        item_name = objective_text:match("Gather (.+)")
    end
    if not item_name then
        item_name = objective_text:match("Find %d+ (.+)")
    end
    if not item_name then
        item_name = objective_text:match("Find (.+)")
    end
    
    -- Convert plural forms to singular for item names
    if item_name then
        Write.Debug("Before conversion: '%s'", item_name)
        
        -- Handle common EverQuest plural patterns
        local lowercase_item = item_name:lower()
        if lowercase_item:match("(.+) samples?$") then
            local base = item_name:match("(.+) [Ss]amples?$")
            if base then
                item_name = base .. " Sample"  -- "blighted blood samples" -> "Blighted Blood Sample"
                Write.Debug("Applied sample conversion: '%s'", item_name)
            end
        elseif item_name:lower():match("(.+)s$") and not item_name:lower():match("ss$") then
            -- Generic plural ending, but avoid words ending in 'ss'
            item_name = item_name:gsub("s$", "")
            Write.Debug("Applied generic plural conversion: '%s'", item_name)
        end
        
        -- Capitalize first letter of each word (title case)
        item_name = item_name:gsub("(%w)([%w']*)", function(first, rest)
            return string.upper(first) .. string.lower(rest)
        end)
        Write.Debug("After title case: '%s'", item_name)
    end
    
    -- If we found a potential item name, check if it matches quest item patterns
    if item_name then
        Write.Debug("Final item name to check: '%s'", item_name)
        debug_logger.debug("PATTERN_CHECK: Testing '%s' against %d patterns", item_name, #quest_item_patterns)
        
        for i, pattern in ipairs(quest_item_patterns) do
            Write.Debug("Testing pattern %d: '%s'", i, pattern)
            if item_name:match(pattern) then
                Write.Debug("Item '%s' matches pattern '%s'", item_name, pattern)
                debug_logger.quest("ITEM_EXTRACTED: '%s' matches pattern '%s' from objective '%s'", 
                    item_name, pattern, objective_text)
                return item_name
            end
        end
        Write.Debug("Item '%s' does not match any of %d quest item patterns", item_name, #quest_item_patterns)
        debug_logger.debug("NO_PATTERN_MATCH: '%s' does not match any quest patterns", item_name)
    else
        debug_logger.debug("NO_ITEM_EXTRACTED: Could not extract item name from '%s'", objective_text)
    end
    
    return nil
end

-- Check if an item is needed by any character for quests
tasks.is_quest_item = function(item_name)
    return task_data.quest_items[item_name] ~= nil
end

-- Get characters who need a specific quest item
tasks.get_characters_needing_item = function(item_name)
    debug_logger.debug("GET_CHARACTERS_NEEDING: Checking for item '%s'", item_name)
    
    local quest_info = task_data.quest_items[item_name]
    if quest_info then
        debug_logger.quest("QUEST_INFO_FOUND: %s needed by [%s] for task '%s' - objective: %s", 
            item_name, 
            quest_info.needed_by and table.concat(quest_info.needed_by, ", ") or "none",
            quest_info.task_name or "Unknown",
            quest_info.objective or "Unknown")
        return quest_info.needed_by, quest_info.task_name, quest_info.objective
    else
        debug_logger.debug("NO_QUEST_INFO: Item '%s' not found in quest data", item_name)
    end
    return {}, nil, nil
end

-- Get all quest items currently being tracked
tasks.get_all_quest_items = function()
    return task_data.quest_items
end

-- Refresh task data for a specific character after they receive loot
tasks.refresh_character_after_loot = function(character_name, item_name)
    debug_logger.quest("LOOT_REFRESH: %s received %s, refreshing their task data", character_name, item_name)
    Write.Info("Character %s received quest item %s - refreshing their task status", character_name, item_name)
    
    -- Request updated task data for this character only
    tasks.request_character_task_update(character_name)
    
    -- Give TaskHUD a moment to process and update
    debug_logger.debug("LOOT_REFRESH: Waiting for %s task data update...", character_name)
    
    -- Wait a brief moment for the update to process
    local start_time = os.time()
    local timeout = 3 -- 3 seconds max
    local updated = false
    
    while (os.time() - start_time) < timeout and not updated do
        -- Check if we have fresh data (simple check - could be enhanced)
        if task_data.characters[character_name] and 
           (os.time() - task_data.characters[character_name].last_updated) < 5 then
            updated = true
            debug_logger.info("LOOT_REFRESH: %s task data appears updated", character_name)
            break
        end
        -- Small delay before checking again
        mq.delay(500)
    end
    
    if not updated then
        debug_logger.warn("LOOT_REFRESH: %s task data did not update within timeout", character_name)
        Write.Warn("Task refresh timeout for %s - continuing with existing data", character_name)
    end
    
    -- Rebuild quest items cache with updated data
    tasks.update_quest_items()
    debug_logger.info("LOOT_REFRESH: Quest items cache updated after %s loot", character_name)
end

-- Get task data for debugging
tasks.get_task_data = function()
    return task_data
end

-- Clean up old task data
tasks.cleanup_old_data = function()
    local current_time = os.time()
    local timeout = 300000 -- 5 minutes
    
    for character, char_data in pairs(task_data.characters) do
        if current_time - char_data.last_updated > timeout then
            Write.Debug("Removing old task data for %s", character)
            task_data.characters[character] = nil
        end
    end
end

-- Check for TaskHUD response via file system
tasks.check_taskhud_response = function()
    debug_logger.debug("STARTUP: Checking for TaskHUD response via file...")
    
    -- Look for ANY recent response file, not just the master looter's file
    -- This handles cases where the master looter is not in the group that TaskHUD is monitoring
    local my_character = mq.TLO.Me.DisplayName()
    debug_logger.info("STARTUP: Looking for response file for character: '%s'", my_character)
    local response_file = "c:/MQ2/logs/yalm2_response_" .. my_character .. ".json"
    debug_logger.debug("STARTUP: Looking for response file: %s", response_file)
    local file = io.open(response_file, "r")
    
        -- If master looter's file doesn't exist, look for ANY recent response file
        -- This is actually the PREFERRED method since TaskHUD may not always create files for all characters
        if not file then
            debug_logger.info("STARTUP: Master looter (%s) not in TaskHUD response - using centralized multi-character data", my_character)
            debug_logger.info("STARTUP: Searching for ANY recent TaskHUD response file...")
            
            -- Find the most recent response file from any character (contains multi-character data)
            local most_recent_file = nil
            local most_recent_time = 0
            
            -- Look for any yalm2_response_*.json files
            local response_pattern = "c:/MQ2/logs/yalm2_response_"
            local test_names = {"Forestess", "Tarnook", "Lumarra", "Astraean", "Calystris", "Ceeles", "Echoveil", "Kaelor", "Lunarra", "Malrik", "Vaeloraa", "Lyricen"}
            for _, char_name in ipairs(test_names) do
                local test_file = response_pattern .. char_name .. ".json"
                local test_handle = io.open(test_file, "r")
                if test_handle then
                    test_handle:close()
                    -- Use the first available file (all contain the same multi-character data)
                    most_recent_file = test_file
                    debug_logger.info("STARTUP: Found centralized response file: %s", test_file)
                    break
                end
            end
            
            if most_recent_file then
                response_file = most_recent_file
                file = io.open(response_file, "r")
                debug_logger.info("STARTUP: Found individual character file: %s", response_file)
                
                -- Check if this is a small individual file or large multi-character file
                local content = file:read("*all")
                file:close()
                
                if #content < 10000 then -- Individual character file (small)
                    debug_logger.info("STARTUP: Individual character file detected (%d bytes) - aggregating all character files", #content)
                    return tasks.aggregate_all_character_responses()
                else -- Multi-character file (large)
                    debug_logger.info("STARTUP: Multi-character file detected (%d bytes) - using directly", #content)
                    file = io.open(response_file, "r") -- Reopen for normal processing
                end
            else
                debug_logger.warn("STARTUP: No TaskHUD response files found - TaskHUD may not be running")
                return false
            end
        else
            debug_logger.info("STARTUP: Using direct response file for master looter: %s", my_character)
        end    if not file then
        debug_logger.debug("STARTUP: Could not open response file: %s", response_file)
        return false
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or content == "" then
        debug_logger.debug("STARTUP: Response file is empty")
        return false
    end
    
    debug_logger.info("STARTUP: Response file found, content length: %d bytes", #content)
    
    -- Parse task data from JSON response
    Write.Info("Found TaskHUD response file with content (length: %d)", #content)
    
    -- Extract task count from the content
    local task_count = content:match('"task_count":%s*(%d+)')
    if task_count then
        task_count = tonumber(task_count)
        Write.Info("TaskHUD reported %d tasks available", task_count)
        
        -- Debug: Show a portion of the response for troubleshooting
        Write.Info("Response content sample: %s", content:sub(1, 500))
        Write.Info("Response content end: %s", content:sub(-200))
        
        -- Parse character data from the multi-character response
        local character_count_str = content:match('"character_count":%s*(%d+)') or "0" 
        local character_count = tonumber(character_count_str)
        debug_logger.info("STARTUP: Response includes %d characters", character_count)
        
        -- Check if we're getting the new multi-character format or old single format
        if content:match('"characters":%s*{') then
            Write.Info("Detected new multi-character response format")
            
            -- Parse each character's task data from the "characters" object
            -- Find the characters section and parse it
            local characters_start = content:find('"characters":%s*{')
            if characters_start then
                Write.Info("Found characters section at position %d", characters_start)
                
                -- Parse each character and their tasks/objectives
                local character_count_found = 0
                for character_name in content:gmatch('"([A-Za-z]+)":%s*{%s*"task_count"') do
                    character_count_found = character_count_found + 1
                    Write.Info("Found character: %s", character_name)
                    
                    -- Extract task count
                    local pattern = '"' .. character_name .. '":%s*{%s*"task_count":%s*(%d+)'
                    local char_task_count_str = content:match(pattern) or "0"
                    local char_task_count = tonumber(char_task_count_str)
                    
                    -- Parse tasks for this character
                    local char_tasks = {}
                    local char_section_pattern = '"' .. character_name .. '":%s*{.-"tasks":%s*%[(.-)%]'
                    local tasks_section = content:match(char_section_pattern)
                    
                    if tasks_section then
                        Write.Debug("Parsing tasks section for %s", character_name)
                        
                        -- Simple task extraction - find all task_name instances for this character
                        local task_count = 0
                        for task_name in tasks_section:gmatch('"task_name":%s*"([^"]*)"') do
                            task_count = task_count + 1
                            local task_obj = {
                                task_name = task_name,
                                objectives = {}
                            }
                            
                            -- For now, just track task names - we'll enhance objective parsing next
                            table.insert(char_tasks, task_obj)
                            Write.Debug("  Found task: %s", task_name)
                            
                            if task_count >= 3 then break end -- Limit parsing to avoid issues
                        end
                    else
                        Write.Debug("No tasks section found for %s", character_name)
                    end
                    
                    task_data.characters[character_name] = {
                        tasks = char_tasks,
                        last_updated = os.time(),
                        task_count = char_task_count
                    }
                    
                    Write.Info("  %s has %d tasks (%d parsed)", character_name, char_task_count, #char_tasks)
                end
                
                Write.Info("Total characters parsed: %d", character_count_found)
            else
                Write.Warn("Could not find characters section in response")
            end
        else
            Write.Info("Detected legacy single-character response format")
            -- Fall back to single character (current Master Looter)
        end
        
        -- Also ensure we have the main character data
        local my_character = mq.TLO.Me.DisplayName()
        if not task_data.characters[my_character] then
            task_data.characters[my_character] = {
                tasks = {},
                last_updated = os.time(),
                task_count = task_count
            }
            debug_logger.info("STARTUP", "Created task_data entry for main character: %s", my_character)
        end
        
        -- Extract quest items directly from raw response content
        tasks.extract_quest_items_from_response(content)
        
        -- Note: update_quest_items() is not needed since direct extraction handles quest item population
        -- tasks.update_quest_items()
        
        -- Clean up the response file
        os.remove(response_file)
        debug_logger.info("STARTUP: Successfully processed TaskHUD response (%d characters, %d total tasks)", character_count, task_count)
        debug_logger.info("STARTUP: Response file used: %s", response_file)
        debug_logger.info("STARTUP: Multi-character quest data loaded - system ready for quest-aware loot distribution")
        
        -- Log the number of characters loaded into memory
        local loaded_chars = 0
        for _ in pairs(task_data.characters) do
            loaded_chars = loaded_chars + 1
        end
        debug_logger.info("STARTUP: Characters loaded into task_data: %d", loaded_chars)
        
        return true
    else
        Write.Warn("Could not parse task count from response file")
        Write.Debug("Response content preview: %s", content:sub(1, 200))
        
        -- Clean up anyway
        os.remove(response_file)
        return false
    end
end

return tasks