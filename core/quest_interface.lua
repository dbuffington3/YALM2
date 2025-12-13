--- Unified Quest Interface for YALM2
--- Native quest system coordinator - detects quest items from task objectives
--- and distributes them to characters who need them

local mq = require("mq")
local debug_logger = require("yalm2.lib.debug_logger")
local quest_data_store = require("yalm2.lib.quest_data_store")
local Write = require("yalm2.lib.Write")

local quest_interface = {}

-- Global reference to the native quest system
local native_tasks = nil
local quest_database = nil  -- Store database reference passed from caller

--- Initialize the quest interface with the native quest system
quest_interface.initialize = function(global_settings, native_tasks_module, database_ref)
    native_tasks = native_tasks_module
    quest_database = database_ref  -- Store the database reference
    
    debug_logger.debug("QUEST_INTERFACE: Initialized with native quest system")
    if quest_database then
        debug_logger.debug("QUEST_INTERFACE: Database reference stored")
    end
end

--- Check if an item is needed for quests
quest_interface.is_quest_item = function(item_name)
    if native_tasks and native_tasks.is_quest_item then
        return native_tasks.is_quest_item(item_name)
    else
        debug_logger.warn("QUEST_INTERFACE: native_tasks module not available")
    end
    return false
end

--- Get characters who need a specific quest item directly from MQ2 variable
--- Get characters who need a specific quest item 
--- Reads from shared quest data store populated by yalm2_native_quest.lua
quest_interface.get_quest_characters_local = function(item_name)
    local needed_by = {}
    
    -- PRIMARY: Use shared quest data store which is populated by automatic update loop
    -- The automatic loop in yalm2_native_quest.lua updates this every 3 seconds
    local quest_data = quest_data_store.get_quest_data_with_qty()
    
    -- If shared store is empty, try MQ2 variable as fallback
    if not quest_data or quest_data == "" then
        local success, var_value = pcall(function()
            -- Try the variable with quantities first
            if mq.TLO.Defined('YALM2_Quest_Items_WithQty')() then
                local raw_val = mq.TLO.YALM2_Quest_Items_WithQty
                if raw_val then
                    local str_val = tostring(raw_val)
                    if str_val and str_val ~= "nil" and str_val ~= "" then
                        debug_logger.info("QUEST_INTERFACE: MQ2 Variable YALM2_Quest_Items_WithQty accessed (len=%d)", str_val:len())
                        return str_val
                    end
                end
            end
            -- Fallback to the one without quantities
            if mq.TLO.Defined('YALM2_Quest_Items')() then
                local raw_val = mq.TLO.YALM2_Quest_Items
                if raw_val then
                    local str_val = tostring(raw_val)
                    if str_val and str_val ~= "nil" and str_val ~= "" then
                        debug_logger.info("QUEST_INTERFACE: MQ2 Variable YALM2_Quest_Items accessed (fallback, len=%d)", str_val:len())
                        return str_val
                    end
                end
            end
            return ""
        end)
        
        if success and var_value and var_value ~= "" and var_value ~= "nil" then
            quest_data = var_value
        end
    end
    
    debug_logger.debug("QUEST_INTERFACE: Looking for '%s' in quest_data (len=%d)", item_name, quest_data and quest_data:len() or 0)
    
    if quest_data and quest_data:len() > 0 then
        for item_data in quest_data:gmatch("([^|]+)") do
            -- Parse: "ItemName:char1:qty1,char2:qty2"
            local quest_item_name, char_list_str = item_data:match("^([^:]+):(.+)$")
            
            if quest_item_name and char_list_str then
                -- Check for exact match
                local exact_match = (quest_item_name == item_name or quest_item_name:lower() == item_name:lower())
                
                -- Check for plural/singular variations
                local singular_match = false
                if not exact_match then
                    -- Try removing trailing 's' from quest item name
                    local quest_singular = quest_item_name:gsub("s$", "")
                    if quest_singular ~= quest_item_name then
                        singular_match = (quest_singular == item_name or quest_singular:lower() == item_name:lower())
                        if singular_match then
                            debug_logger.debug("QUEST_INTERFACE: Matched via quest singular: '%s' -> '%s'", quest_item_name, quest_singular)
                        end
                    end
                    
                    -- Try removing trailing 's' from db item name if no match yet
                    if not singular_match then
                        local db_singular = item_name:gsub("s$", "")
                        if db_singular ~= item_name then
                            singular_match = (quest_item_name == db_singular or quest_item_name:lower() == db_singular:lower())
                            if singular_match then
                                debug_logger.debug("QUEST_INTERFACE: Matched via db singular: '%s' -> '%s'", item_name, db_singular)
                            end
                        end
                    end
                end
                
                if exact_match or singular_match then
                    -- Found matching quest item
                    -- Parse character:qty pairs from char_list_str
                    for char_qty_pair in char_list_str:gmatch("([^,]+)") do
                        local char_name, qty_str = char_qty_pair:match("^([^:]+):(.+)$")
                        if char_name and qty_str then
                            -- Only include characters who still need this item (qty > 0)
                            local qty = tonumber(qty_str) or 0
                            if qty > 0 then
                                table.insert(needed_by, char_name)
                            end
                        end
                    end
                    break
                end
            end
        end
    else
        debug_logger.warn("QUEST_INTERFACE: Quest data is empty or nil")
    end
    
    if #needed_by > 0 then
        debug_logger.debug("QUEST_INTERFACE: Found %d characters needing '%s'", #needed_by, item_name)
    else
        debug_logger.debug("QUEST_INTERFACE: No characters need '%s'", item_name)
    end
    
    return needed_by
end

--- Get characters who need a specific quest item
quest_interface.get_characters_needing_item = function(item_name)
    if native_tasks and native_tasks.get_characters_needing_item then
        local chars, task_name, objective = native_tasks.get_characters_needing_item(item_name)
        return chars or {}
    else
        debug_logger.warn("QUEST_INTERFACE: native_tasks module not available")
    end
    return {}
end

--- Get all quest items currently being tracked
quest_interface.get_all_quest_items = function()
    if native_tasks and native_tasks.get_quest_items then
        local quest_items = native_tasks.get_quest_items()
        -- Convert the native format (table with keys) to array format
        local items_array = {}
        if quest_items then
            for item_name, _ in pairs(quest_items) do
                table.insert(items_array, item_name)
            end
        end
        return items_array
    end
    return {}
end

--- Refresh quest data for a specific character after they receive loot
quest_interface.refresh_character_after_loot = function(character_name, item_name)
    -- Native system handles this internally via yalm2_native_quest.lua
    if native_tasks and native_tasks.refresh_character_after_loot then
        return native_tasks.refresh_character_after_loot(character_name, item_name)
    end
end

--- Force refresh of all quest data
quest_interface.refresh_all_characters = function()
    if native_tasks and native_tasks.refresh_all_characters then
        return native_tasks.refresh_all_characters()
    end
    return false
end

--- Get current quest system status
quest_interface.get_status = function()
    return {
        system_type = "native",
        native_available = native_tasks ~= nil,
    }
end

--- Get per-character quest item needs (quantity required per character per item)
quest_interface.get_per_character_needs = function()
    if native_tasks and native_tasks.get_per_character_needs then
        return native_tasks.get_per_character_needs()
    end
    return {}
end

--- Smart item name matching - finds actual item names in database by fuzzy matching
--- Takes the FULL objective text and extracts/matches against database
--- This solves problems like: "Loot 3 pieces of bark from the treants" → "Treant Bark"
--- VALIDATES that matched items are actual quest items (questitem=1) in the database
--- @param objective_text string - The full objective text (e.g., "Loot 3 pieces of bark from the treants")
quest_interface.find_matching_quest_item = function(objective_text)
    if not objective_text or objective_text == "" then
        return nil
    end
    
    -- Try to query the database if available
    local YALM2_Database = quest_database or _G.YALM2_Database
    if not YALM2_Database or not YALM2_Database.database then
        Write.Error("ITEM_MATCH: Database not available for fuzzy matching (quest_database: %s, _G.YALM2_Database: %s)", 
            tostring(quest_database ~= nil), tostring(_G.YALM2_Database ~= nil))
        return nil
    end
    
    -- Clean up the input: remove common words and punctuation
    local cleaned = objective_text
    -- Remove possessive markers
    cleaned = cleaned:gsub("'s", " ")
    cleaned = cleaned:gsub("'", " ")
    -- Remove leading action words only (don't remove from/the in middle of phrase - they provide context)
    cleaned = cleaned:gsub("^loot ", "", 1)
    cleaned = cleaned:gsub("^collect ", "", 1)
    cleaned = cleaned:gsub("^gather ", "", 1)
    -- Remove all numeric characters (quest objectives often have "loot 3 pieces" type phrasing)
    cleaned = cleaned:gsub("%d+", " ")
    -- Collapse multiple spaces
    cleaned = cleaned:gsub("%s+", " ")
    -- Trim
    cleaned = cleaned:gsub("^%s*(.-)%s*$", "%1")
    
    -- Generate search terms by removing words from BOTH ends progressively
    -- For "bone golem bones" we want: 
    -- Full phrase, then remove from right (bone golem), (bone)
    -- AND remove from left (golem bones), (bones)
    -- AND combinations like (golem)
    local search_terms = {}
    local words = {}
    for word in cleaned:gmatch("[^%s]+") do
        table.insert(words, word)
    end
    
    -- Define common words that should be filtered out
    -- Note: Use underscores for Lua keywords (in_, for_, and_, or_)
    local common_words_set = {
        of=true, the=true, a=true, an=true, from=true, to=true, on=true, at=true, by=true, 
        with=true, piece=true, pieces=true, bit=true, part=true, 
        item=true, thing=true, stuff=true, material=true, sample=true
    }
    
    -- Filter out common words from the words array
    local filtered_words = {}
    for _, word in ipairs(words) do
        if not common_words_set[word:lower()] then
            table.insert(filtered_words, word)
        end
    end
    
    -- Debug output for troubleshooting
    if #filtered_words == 0 then
        Write.Error("ITEM_MATCH: NO FILTERED WORDS! Cleaned='%s', Words=%s", cleaned, 
            table.concat(words, "|"))
    else
        Write.Info("ITEM_MATCH: Processing '%s' -> Filtered=%s", objective_text, 
            table.concat(filtered_words, ", "))
    end
    
    -- Add all word combinations (from both directions) - ONLY FROM FILTERED WORDS
    -- This ensures we don't search for combinations like "pieces of bark" when "pieces" and "of" are common words
    -- Prioritize multi-word searches BEFORE single words
    
    -- Full phrase (filtered words only)
    if #filtered_words > 0 then
        table.insert(search_terms, table.concat(filtered_words, " "))
        
        -- Remove from right (progressively shorter from the end, keeping 2+ words)
        for i = #filtered_words - 1, 2, -1 do
            table.insert(search_terms, table.concat(filtered_words, " ", 1, i))
        end
        
        -- Remove from left (progressively shorter from the start, keeping 2+ words)
        for i = 2, #filtered_words - 1 do
            table.insert(search_terms, table.concat(filtered_words, " ", i, #filtered_words))
        end
    end
    
    -- Now add individual filtered words (after multi-word combinations have been tried)
    for _, word in ipairs(filtered_words) do
        table.insert(search_terms, word)
    end
    
    -- Deduplicate search terms
    local seen = {}
    local unique_terms = {}
    for _, term in ipairs(search_terms) do
        if not seen[term] and term ~= "" then
            seen[term] = true
            table.insert(unique_terms, term)
        end
    end
    
    -- Try each search term in order
    for _, search_term in ipairs(unique_terms) do
        if search_term and search_term ~= "" then
            -- Strategy 1: Exact match (case-insensitive) - MUST be a quest item
            local query = string.format("SELECT * FROM raw_item_data WHERE LOWER(name) = LOWER('%s') AND questitem = 1 LIMIT 1", 
                search_term:gsub("'", "''"))
            for row in YALM2_Database.database:nrows(query) do
                return row.name
            end
        end
    end
    
    -- Strategy 2: Fuzzy/contains match with smart scoring
    -- Collect all matching items and score them by relevance
    local all_matches = {}
    
    for _, search_term in ipairs(unique_terms) do
        if search_term and search_term ~= "" and search_term:len() > 2 then
            local query = string.format("SELECT * FROM raw_item_data WHERE LOWER(name) LIKE LOWER('%%%s%%') AND questitem = 1", 
                search_term:gsub("'", "''"))
            
            for row in YALM2_Database.database:nrows(query) do
                    local item_name = row.name
                    -- Calculate relevance score
                    -- Higher score for longer search terms (more specific)
                    -- Higher score if the item name starts or ends with search term
                    local score = search_term:len()
                    
                    if item_name:lower():find("^" .. search_term:lower()) then
                        score = score + 100  -- Bonus for matching at start
                    elseif item_name:lower():find(search_term:lower() .. "$") then
                        score = score + 50   -- Bonus for matching at end
                    end
                    
                    -- Count how many words from the filtered search are in this item
                    local matching_words = 0
                    for _, word in ipairs(filtered_words) do
                        if item_name:lower():find(word:lower(), 1, true) then
                            matching_words = matching_words + 1
                        end
                    end
                    
                    -- CRITICAL: Only consider items that contain ALL filtered words
                    -- This prevents single-word matches from succeeding when multiple keywords exist
                    if #filtered_words > 0 and matching_words < #filtered_words then
                        -- Skip this item - it doesn't have all the required keywords
                    else
                        score = score + (matching_words * 20)
                        
                        -- Penalty: if the item name is much longer than the search, it might be a false match
                        local name_words = 0
                        for _ in item_name:gmatch("%S+") do
                            name_words = name_words + 1
                        end
                        if name_words > (#filtered_words * 2) then
                            score = score - 50  -- Less likely to be right match
                        end
                        
                        if not all_matches[item_name] or all_matches[item_name].score < score then
                            all_matches[item_name] = { score = score, search_term = search_term }
                        end
                    end
                end
        end
    end
    
    -- Sort matches by score (descending)
    if next(all_matches) then
        local sorted_matches = {}
        for item_name, data in pairs(all_matches) do
            table.insert(sorted_matches, { name = item_name, score = data.score, search_term = data.search_term })
        end
        
        table.sort(sorted_matches, function(a, b) return a.score > b.score end)
        
        if #sorted_matches > 0 then
            local best_match = sorted_matches[1]
            Write.Info("ITEM_MATCH: Found %d fuzzy matches for '%s', returning best match: '%s' (score: %.1f, search: '%s')", 
                #sorted_matches, objective_text, best_match.name, best_match.score, best_match.search_term)
            debug_logger.debug("ITEM_MATCH: Top 5 matches for '%s': %s", objective_text, 
                table.concat({sorted_matches[1].name, sorted_matches[2] and sorted_matches[2].name or "", 
                             sorted_matches[3] and sorted_matches[3].name or ""}, " | "))
            return best_match.name
        end
    end
    
    Write.Info("ITEM_MATCH: No quest items found matching '%s' in database", objective_text)
    return nil
end

return quest_interface