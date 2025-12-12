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
quest_interface.initialize = function(global_settings, external_tasks_module, native_tasks_module, database_ref)
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
--- Takes a partial/extracted item name and returns the best matching item from the database
--- This solves problems like: "bones" → "Golem Bones" by searching for database items
--- VALIDATES that matched items are actual quest items (questitem=1) in the database
quest_interface.find_matching_quest_item = function(partial_item_name)
    if not partial_item_name or partial_item_name == "" then
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
    local cleaned = partial_item_name
    -- Remove possessive markers
    cleaned = cleaned:gsub("'s", " ")
    cleaned = cleaned:gsub("'", " ")
    -- Remove leading articles and common words
    cleaned = cleaned:gsub("^loot ", "", 1)
    cleaned = cleaned:gsub("^collect ", "", 1)
    cleaned = cleaned:gsub("^gather ", "", 1)
    cleaned = cleaned:gsub("^the ", "", 1)
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
    
    -- Add all word combinations (from both directions)
    -- Full phrase
    table.insert(search_terms, table.concat(words, " "))
    
    -- Remove from right (progressively shorter from the end)
    for i = #words - 1, 1, -1 do
        table.insert(search_terms, table.concat(words, " ", 1, i))
    end
    
    -- Remove from left (progressively shorter from the start)
    for i = 2, #words do
        table.insert(search_terms, table.concat(words, " ", i, #words))
    end
    
    -- Add individual words
    for _, word in ipairs(words) do
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
    
    -- Strategy 2: Fuzzy/contains match - look for items containing key words
    -- Try searching for combinations of words (LIKE searches)
    for _, search_term in ipairs(unique_terms) do
        if search_term and search_term ~= "" then
            local query = string.format("SELECT * FROM raw_item_data WHERE LOWER(name) LIKE LOWER('%%%s%%') AND questitem = 1 LIMIT 10", 
                search_term:gsub("'", "''"))
            local matches = {}
            for row in YALM2_Database.database:nrows(query) do
                table.insert(matches, row.name)
            end
            
            if #matches > 0 then
                Write.Info("ITEM_MATCH: Found %d quest item fuzzy matches for '%s' (search: '%s'), returning top match: '%s'", 
                    #matches, partial_item_name, search_term, matches[1])
                debug_logger.debug("ITEM_MATCH: All fuzzy matches for '%s': %s", search_term, table.concat(matches, ", "))
                return matches[1]
            end
        end
    end
    
    Write.Info("ITEM_MATCH: No quest items found matching '%s' in database", partial_item_name)
    return nil
end

return quest_interface