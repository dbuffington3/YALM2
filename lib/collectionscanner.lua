--- Collection Scanner Module for YALM2
--- Scans character achievement data for collectibles and stores needs in SQLite
--- Each character runs a scan to populate the database, YALM2 queries during loot distribution

local mq = require("mq")
local lfs = require("lfs")
local sql = require("lsqlite3")
local Write = require("yalm2.lib.Write")
local debug_logger = require("yalm2.lib.debug_logger")

local collection_scanner = {}

-- Database file path (shared across all characters)
local db_path = mq.configDir .. "/YALM2/collection_needs.db"
local db_handle = nil

-- ======================================================================================================================
-- Achievement Data - Master Scavenger achievements by expansion
-- ======================================================================================================================

local collectionSets = {
    { expansion = "RoF",  name = "Master Scavenger of Fear (Rain of Fear)" },
    { expansion = "CotF", name = "Call of the Forsaken Master Scavenger"   },
    { expansion = "TDS",  name = "Master Scavenger of The Darkened Sea"    },
    { expansion = "TBM",  name = "Master Scavenger of The Broken Mirror"   },
    { expansion = "EoK",  name = "Empires of Kunark Master Scavenger"      },
    { expansion = "RoS",  name = "Ring of Scale Master Scavenger"          },
    { expansion = "TBL",  name = "Burning Lands Master Scavenger"          },
    { expansion = "ToV",  name = "Torment of Velious Master Scavenger"     },
    { expansion = "CoV",  name = "Tundra Excavator"                        },
    { expansion = "ToL",  name = "Shadow Seeker"                           },
    { expansion = "NoS",  name = "Night Seeker"                            },
    { expansion = "LS",   name = "Song Seeker"                             },
    { expansion = "TOB",  name = "Scale Seeker"                            },
    { expansion = "SoR",  name = "Storm Chaser"                            }
}

-- Table to map objective names to actual achievement names for cases where they are different
local correctedAchievementNameTable = {
    ["Lesser Things"]                       = "Lesser Things (Gates of Kor-Sha)",
    ["Missing Mementos"]                    = "Missing Mementos (Ethernere Tainted West Karana)",
    ["Miniature Meals"]                     = "Miniature Meals (Ethernere Tainted West Karana)",
    ["Matronymic Markers"]                  = "Matronymic Markers (Neriak - Fourth Gate)",
    ["Military Missives"]                   = "Military Missives (Bixie Warfront)",
    ["Miraculous Mixtures"]                 = "Miraculous Mixtures (Neriak - Fourth Gate)",
    ["Chasing Cazic"]                       = "Chasing Cazic (Rain of Fear)",
    ["At the Source"]                       = "At the Source (Shard's Landing)",
    ["Tracker's Guide to Shard's Landing"]  = "A Tracker's Guide to Shard's Landing (Shard's Landing)",
    ["Heralds of War"]                      = "Heralds of War (Zeixshi-Kar's Awakening)",
    ["Down to the Last Dwarf"]              = "Down to the Last Dwarf (The Crystal Caverns)",
    ["Chilling with the Giants"]            = "Chilling with the Giants (Kael Drakkel)",
    ["Cleaning Up Cazic"]                   = "Cleaning Up Cazic (Rain of Fear)",
    ["Digging for Dragons"]                 = "Digging for Dragons (The Breeding Grounds)",
    ["Nature is Weird"]                     = "Nature is Weird (Evantil, the Vile Oak)",
    ["This Little Piggy"]                   = "This Little Piggy (Grelleth's Palace)",
    ["Death is Only the Beginning"]         = "Death is Only the Beginning (Chapterhouse of the Fallen)",
    ["Eye Won!"]                            = "Eye Won! (Valley of King Xorbb)",
}

-- Table of suffixes to be added to children of specified parent achievements
local parentSuffixTable = {
    ["Digging Deep"]                                              = " (The Ry`Gorr Mines)",
    ["Islands In The Sky"]                                        = " (Stratos)",
    ["Trials By Fire"]                                            = " (Plane of Smoke)",
    ["Pyre Place"]                                                = " (Empyr: Realms of Ash)",
    ["Houses of Fire"]                                            = " (Aalishai: Palace of Embers)",
    ["Houses of Air"]                                             = " (Esianti: Palace of the Winds)",
    ["Houses of Stone"]                                           = " (Mearatas: The Stone Demesne)",
    ["Small Hills"]                                               = " (Gnome Memorial Mountain)",
    ["The Over Under"]                                            = " (The Overthere)",
    ["Fire In the Sky"]                                           = " (The Skyfire Mountains)",
    ["Cryptic Excavation"]                                        = " (The Howling Stones)",
    ["Treasure Hunting"]                                          = " (Sathir's Tomb)",
    ["Taking a Peak"]                                             = " (Veeshan's Peak)",
    ["Reunification"]                                             = " (Lceanium)",
    ["Where the Obulus Once Stood"]                               = " (The Scorched Woods)",
    ["Trailblazing"]                                              = " (Frontier Mountains)",
    ["Underground Frontier"]                                      = " (The Temple of Droga)",
    ["Di`Zok Keepsakes"]                                          = " (Chardok)",
    ["Sathir's Court"]                                            = " (Kor-Sha Laboratory)",
    ["Relics of Health"]                                          = " (Plane of Health)",
    ["Reborn of Faith"]                                           = " (Sul Vius: Demiplane of Life)",
    ["Reborn into Faith"]                                         = " (Sul Vius: Demiplane of Decay)",
    ["Relics of Decay"]                                           = " (Crypt of Decay)",
    ["Relics of Sul"]                                             = " (Crypt of Sul)",
    ["Riding the Storm Out"]                                      = " (Tempest Temple)",
    ["Secrets Beneath the Ocean"]                                 = " (Katta Castrum: Deluge)",
    ["Island Fragments"]                                          = " (Brother Island)",
    ["Cavern Collectibles"]                                       = " (Caverns of Endless Song)",
    ["Dwarven Depths"]                                            = " (Degmar, the Lost Castle)",
    ["The Lost of This Land"]                                     = " (Thuliasaur Island)",
    ["Far, Wide and Deep"]                                        = " (Combine Dredge)",
    ["Arx Anthology"]                                             = " (Arx Mentis)",
    ["The Source of the Ethernere"]                               = " (The Western Plains of Karana)",
    ["Dead Relics"]                                               = " (The Dead Hills)",
    ["Bixie Hive Hodgepodge"]                                     = " (Bixie Warfront)",
    ["The Darklight Palace"]                                      = " (Neriak - Fourth Gate)",
    ["Less is More"]                                              = " (Ethernere Tainted West Karana)",
    ["Rotten Remains"]                                            = " (Tower of Rot)",
    ["Burning Bibelots"]                                          = " (Argin-Hiz)",
    ["Digging for Dragons"]                                       = " (The Breeding Grounds)",
    ["At the Source (Shard's Landing)"]                           = " (Shard's Landing)",
    ["Heralds of War (Zeixshi-Kar's Awakening)"]                  = " (Zeixshi-Kar's Awakening)",
    ["Down to the Last Dwarf (The Crystal Caverns)"]              = " (The Crystal Caverns)",
    ["Chilling with the Giants (Kael Drakkel)"]                   = " (Kael Drakkel)",
    ["Digging for Dragons (The Breeding Grounds)"]                = " (The Breeding Grounds)",
    ["Nature is Weird (Evantil, the Vile Oak)"]                   = " (Evantil, the Vile Oak)",
    ["This Little Piggy (Grelleth's Palace)"]                     = " (Grelleth's Palace)",
    ["Death is Only the Beginning (Chapterhouse of the Fallen)"]  = " (Chapterhouse of the Fallen)",
    ["Eye Won! (Valley of King Xorbb)"]                           = " (Valley of King Xorbb)",
}

-- ======================================================================================================================
-- Database Functions
-- ======================================================================================================================

--- Get or create the database connection
local function get_db()
    if db_handle then
        return db_handle
    end
    
    -- Ensure directory exists
    local dir = mq.configDir .. "/YALM2"
    if not lfs.attributes(dir, "mode") then
        lfs.mkdir(dir)
    end
    
    local db = sql.open(db_path)
    if not db then
        Write.Error("[CollectionDB] Failed to open database: %s", db_path)
        return nil
    end
    
    -- Set pragmas for safety and performance
    db:exec("PRAGMA journal_mode = DELETE")
    db:exec("PRAGMA synchronous = NORMAL")
    db:exec("PRAGMA cache_size = 10000")
    
    -- Create collection_needs table
    local create_sql = [[
        CREATE TABLE IF NOT EXISTS collection_needs (
            character_name TEXT NOT NULL,
            server_name TEXT NOT NULL,
            item_name TEXT NOT NULL,
            collection_name TEXT NOT NULL,
            expansion TEXT NOT NULL,
            needed INTEGER NOT NULL DEFAULT 1,
            last_updated INTEGER,
            PRIMARY KEY (character_name, server_name, item_name)
        )
    ]]
    
    local result = db:exec(create_sql)
    if result ~= sql.OK then
        Write.Error("[CollectionDB] Failed to create collection_needs table: %s", db:errmsg())
        db:close()
        return nil
    end
    
    -- Create index for fast item lookups during looting
    db:exec("CREATE INDEX IF NOT EXISTS idx_item_needed ON collection_needs (item_name, needed)")
    
    db_handle = db
    return db_handle
end

--- Initialize the database
function collection_scanner.init()
    return get_db() ~= nil
end

--- Close the database connection
function collection_scanner.close()
    if db_handle then
        db_handle:close()
        db_handle = nil
    end
end

-- ======================================================================================================================
-- Achievement Parsing Functions
-- ======================================================================================================================

local function getCorrectedAchievementName(name)
    if correctedAchievementNameTable[name] then
        return correctedAchievementNameTable[name], true
    else
        return name, false
    end
end

local function getCorrectedObjectiveIndex(name, index)
    if name == 'The Deep Darkened Sea' then return index + 4 end
    return index
end

--- Recursively parse achievements and collect all collectible items with their status
--- @param results table - Table to store results {item_name = {collection_name, expansion, needed}}
--- @param parent table - Parent node context
--- @param name string - Achievement/objective name
--- @param expansion string - Current expansion code
--- @param collectionName string - Current collection name
local function parseAchievementForItems(results, parent, name, expansion, collectionName)
    local correctedName, corrected = getCorrectedAchievementName(name)
    if not corrected then
        local suffix = parent and parent.suffix
        if suffix then correctedName = correctedName .. suffix end
    end
    
    -- Try to get the achievement by name
    local achievement = mq.TLO.Achievement(correctedName)
    
    -- If not an achievement, it's a collectible item (leaf node)
    if achievement() == nil then
        -- This is a collectible! Check if the objective is completed
        local objective = parent and parent.objective
        local needed = 1  -- Assume needed by default
        
        if objective and objective.Completed and objective.Completed() then
            needed = 0  -- Already collected
        end
        
        results[correctedName] = {
            collection_name = collectionName or "Unknown",
            expansion = expansion,
            needed = needed
        }
    else
        -- This is an achievement, recurse into its objectives
        local objectiveCount = achievement.ObjectiveCount()
        if objectiveCount and objectiveCount > 0 then
            -- Determine the current collection name (leaf achievement name)
            local currentCollection = collectionName or correctedName
            
            -- Build parent context for children
            local parentContext = {
                suffix = parentSuffixTable[correctedName],
                objective = nil
            }
            
            -- Try 0-based indexing first
            if achievement.ObjectiveByIndex(getCorrectedObjectiveIndex(correctedName, 0))() ~= nil then
                for index = 0, objectiveCount - 1 do
                    local obj = achievement.ObjectiveByIndex(getCorrectedObjectiveIndex(correctedName, index))
                    parentContext.objective = obj
                    parseAchievementForItems(results, parentContext, obj.Description(), expansion, correctedName)
                end
            else
                -- Try 1-based indexing
                for index = 1, objectiveCount do
                    local obj = achievement.ObjectiveByIndex(getCorrectedObjectiveIndex(correctedName, index))
                    parentContext.objective = obj
                    parseAchievementForItems(results, parentContext, obj.Description(), expansion, correctedName)
                end
            end
        end
    end
end

-- ======================================================================================================================
-- Public API Functions
-- ======================================================================================================================

--- Scan current character's achievements and store collection needs in database
--- @return number - Count of items that need to be collected
function collection_scanner.scan_character()
    local db = get_db()
    if not db then
        Write.Error("[CollectionDB] Cannot scan - database not available")
        return 0
    end
    
    local character_name = mq.TLO.Me.Name()
    local server_name = mq.TLO.EverQuest.Server()
    local timestamp = os.time()
    
    Write.Info("[CollectionDB] Scanning collections for %s on %s...", character_name, server_name)
    
    -- Collect all items from all expansions
    local results = {}
    for _, expData in ipairs(collectionSets) do
        parseAchievementForItems(results, nil, expData.name, expData.expansion, nil)
    end
    
    -- Begin transaction for bulk insert
    db:exec("BEGIN TRANSACTION")
    
    -- Clear existing data for this character (full rescan)
    local delete_stmt = db:prepare("DELETE FROM collection_needs WHERE character_name = ? AND server_name = ?")
    delete_stmt:bind_values(character_name, server_name)
    delete_stmt:step()
    delete_stmt:finalize()
    
    -- Insert new data
    local insert_stmt = db:prepare([[
        INSERT INTO collection_needs (character_name, server_name, item_name, collection_name, expansion, needed, last_updated)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]])
    
    local needed_count = 0
    local total_count = 0
    
    for item_name, data in pairs(results) do
        insert_stmt:bind_values(
            character_name,
            server_name,
            item_name,
            data.collection_name,
            data.expansion,
            data.needed,
            timestamp
        )
        insert_stmt:step()
        insert_stmt:reset()
        
        total_count = total_count + 1
        if data.needed == 1 then
            needed_count = needed_count + 1
        end
    end
    
    insert_stmt:finalize()
    db:exec("COMMIT")
    
    Write.Info("[CollectionDB] Scan complete: %d items needed out of %d total collectibles", needed_count, total_count)
    debug_logger.info("COLLECTION_SCAN", "Character %s scanned: %d needed, %d total", character_name, needed_count, total_count)
    
    return needed_count
end

--- Find characters who need a specific collectible item
--- @param item_name string - The collectible item name
--- @return table - Array of {character_name, server_name, collection_name, expansion}
function collection_scanner.find_characters_needing_item(item_name)
    local db = get_db()
    if not db then
        return {}
    end
    
    local results = {}
    local stmt = db:prepare([[
        SELECT character_name, server_name, collection_name, expansion
        FROM collection_needs
        WHERE item_name = ? AND needed = 1
        ORDER BY character_name
    ]])
    
    if not stmt then
        Write.Error("[CollectionDB] Failed to prepare query: %s", db:errmsg())
        return {}
    end
    
    stmt:bind_values(item_name)
    
    for row in stmt:nrows() do
        table.insert(results, {
            character_name = row.character_name,
            server_name = row.server_name,
            collection_name = row.collection_name,
            expansion = row.expansion
        })
    end
    
    stmt:finalize()
    return results
end

--- Check if a specific character needs a specific item
--- @param character_name string
--- @param server_name string
--- @param item_name string
--- @return boolean
function collection_scanner.character_needs_item(character_name, server_name, item_name)
    local db = get_db()
    if not db then
        return false
    end
    
    local stmt = db:prepare([[
        SELECT needed FROM collection_needs
        WHERE character_name = ? AND server_name = ? AND item_name = ?
    ]])
    
    if not stmt then
        return false
    end
    
    stmt:bind_values(character_name, server_name, item_name)
    
    local needed = false
    for row in stmt:nrows() do
        needed = (row.needed == 1)
    end
    
    stmt:finalize()
    return needed
end

--- Mark an item as collected for a character (called after successful loot distribution)
--- @param character_name string
--- @param server_name string
--- @param item_name string
--- @return boolean - Success
function collection_scanner.mark_item_collected(character_name, server_name, item_name)
    local db = get_db()
    if not db then
        return false
    end
    
    local stmt = db:prepare([[
        UPDATE collection_needs
        SET needed = 0, last_updated = ?
        WHERE character_name = ? AND server_name = ? AND item_name = ?
    ]])
    
    if not stmt then
        Write.Error("[CollectionDB] Failed to prepare update: %s", db:errmsg())
        return false
    end
    
    stmt:bind_values(os.time(), character_name, server_name, item_name)
    stmt:step()
    stmt:finalize()
    
    debug_logger.info("COLLECTION_UPDATE", "Marked %s as collected for %s", item_name, character_name)
    return true
end

--- Get collection progress summary for a character
--- @param character_name string
--- @param server_name string
--- @return table - {total=N, needed=N, collected=N, by_expansion={exp={total,needed,collected}}}
function collection_scanner.get_character_progress(character_name, server_name)
    local db = get_db()
    if not db then
        return { total = 0, needed = 0, collected = 0, by_expansion = {} }
    end
    
    local result = {
        total = 0,
        needed = 0,
        collected = 0,
        by_expansion = {}
    }
    
    local stmt = db:prepare([[
        SELECT expansion, 
               COUNT(*) as total,
               SUM(CASE WHEN needed = 1 THEN 1 ELSE 0 END) as needed,
               SUM(CASE WHEN needed = 0 THEN 1 ELSE 0 END) as collected
        FROM collection_needs
        WHERE character_name = ? AND server_name = ?
        GROUP BY expansion
    ]])
    
    if not stmt then
        return result
    end
    
    stmt:bind_values(character_name, server_name)
    
    for row in stmt:nrows() do
        result.by_expansion[row.expansion] = {
            total = row.total,
            needed = row.needed,
            collected = row.collected
        }
        result.total = result.total + row.total
        result.needed = result.needed + row.needed
        result.collected = result.collected + row.collected
    end
    
    stmt:finalize()
    return result
end

--- Get all scanned characters
--- @return table - Array of {character_name, server_name, last_updated, needed_count}
function collection_scanner.get_scanned_characters()
    local db = get_db()
    if not db then
        return {}
    end
    
    local results = {}
    local stmt = db:prepare([[
        SELECT character_name, server_name, 
               MAX(last_updated) as last_updated,
               SUM(CASE WHEN needed = 1 THEN 1 ELSE 0 END) as needed_count
        FROM collection_needs
        GROUP BY character_name, server_name
        ORDER BY character_name
    ]])
    
    if not stmt then
        return {}
    end
    
    for row in stmt:nrows() do
        table.insert(results, {
            character_name = row.character_name,
            server_name = row.server_name,
            last_updated = row.last_updated,
            needed_count = row.needed_count
        })
    end
    
    stmt:finalize()
    return results
end

--- Check if an item is a known collectible (exists in any character's data)
--- @param item_name string
--- @return boolean
function collection_scanner.is_collectible(item_name)
    local db = get_db()
    if not db then
        return false
    end
    
    local stmt = db:prepare("SELECT 1 FROM collection_needs WHERE item_name = ? LIMIT 1")
    if not stmt then
        return false
    end
    
    stmt:bind_values(item_name)
    local found = false
    for _ in stmt:nrows() do
        found = true
    end
    stmt:finalize()
    
    return found
end

--- Get all unique collections with progress info per character
--- Returns data grouped by collection for the UI
--- @param server_name string|nil - Filter by server (optional)
--- @return table - {collection_name = {expansion, characters = {char_name = {needed, total}}}}
function collection_scanner.get_all_collections_progress(server_name)
    local db = get_db()
    if not db then
        return {}
    end
    
    local results = {}
    
    -- Query to get per-character, per-collection stats
    local query = [[
        SELECT collection_name, expansion, character_name, server_name,
               COUNT(*) as total,
               SUM(CASE WHEN needed = 1 THEN 1 ELSE 0 END) as needed,
               SUM(CASE WHEN needed = 0 THEN 1 ELSE 0 END) as collected
        FROM collection_needs
    ]]
    
    if server_name then
        query = query .. " WHERE server_name = ?"
    end
    
    query = query .. " GROUP BY collection_name, character_name, server_name ORDER BY expansion, collection_name, character_name"
    
    local stmt = db:prepare(query)
    if not stmt then
        return {}
    end
    
    if server_name then
        stmt:bind_values(server_name)
    end
    
    for row in stmt:nrows() do
        local coll_name = row.collection_name
        
        if not results[coll_name] then
            results[coll_name] = {
                expansion = row.expansion,
                characters = {}
            }
        end
        
        results[coll_name].characters[row.character_name] = {
            needed = row.needed,
            total = row.total,
            collected = row.collected,
            server_name = row.server_name
        }
    end
    
    stmt:finalize()
    return results
end

--- Get list of unique expansions in the database
--- @return table - Array of expansion codes
function collection_scanner.get_expansions()
    local db = get_db()
    if not db then
        return {}
    end
    
    local results = {}
    local stmt = db:prepare("SELECT DISTINCT expansion FROM collection_needs ORDER BY expansion")
    if not stmt then
        return {}
    end
    
    for row in stmt:nrows() do
        table.insert(results, row.expansion)
    end
    
    stmt:finalize()
    return results
end

--- Get the expansion order table for sorting
--- @return table - Ordered array of expansion codes
function collection_scanner.get_expansion_order()
    return {"RoF", "CotF", "TDS", "TBM", "EoK", "RoS", "TBL", "ToV", "CoV", "ToL", "NoS", "LS", "TOB", "SoR"}
end

--- Get all collections as array with aggregated progress counts for UI display
--- Returns array suitable for UI iteration
--- @param server_name string|nil - Filter by server (optional)
--- @return table - Array of {collection_name, expansion, complete_count, partial_count, needs_count}
function collection_scanner.get_all_collections_for_ui(server_name)
    local db = get_db()
    if not db then
        return {}
    end
    
    -- Query to aggregate per-collection stats across all characters
    -- A character is "complete" if they have 0 items needed
    -- A character is "partial" if they have some collected but not all
    -- A character "needs" the collection if they haven't collected any
    local query = [[
        SELECT 
            collection_name,
            expansion,
            SUM(CASE WHEN needed_count = 0 THEN 1 ELSE 0 END) as complete_count,
            SUM(CASE WHEN needed_count > 0 AND collected_count > 0 THEN 1 ELSE 0 END) as partial_count,
            SUM(CASE WHEN collected_count = 0 THEN 1 ELSE 0 END) as needs_count
        FROM (
            SELECT 
                collection_name,
                expansion,
                character_name,
                SUM(CASE WHEN needed = 1 THEN 1 ELSE 0 END) as needed_count,
                SUM(CASE WHEN needed = 0 THEN 1 ELSE 0 END) as collected_count
            FROM collection_needs
    ]]
    
    if server_name then
        query = query .. " WHERE server_name = ?"
    end
    
    query = query .. [[
            GROUP BY collection_name, character_name
        ) as char_progress
        GROUP BY collection_name, expansion
        ORDER BY expansion, collection_name
    ]]
    
    local stmt = db:prepare(query)
    if not stmt then
        return {}
    end
    
    if server_name then
        stmt:bind_values(server_name)
    end
    
    local results = {}
    local ok, err = pcall(function()
        for row in stmt:nrows() do
            table.insert(results, {
                collection_name = row.collection_name,
                expansion = row.expansion,
                complete_count = row.complete_count or 0,
                partial_count = row.partial_count or 0,
                needs_count = row.needs_count or 0
            })
        end
    end)
    
    stmt:finalize()
    
    if not ok then
        -- Database likely locked, return empty
        return {}
    end
    
    return results
end

--- Get list of missing items for a collection (items that at least one character still needs)
--- @param collection_name string - The collection to check
--- @param server_name string|nil - Filter by server (optional)
--- @return string - Comma-separated list of missing item names with count needed
function collection_scanner.get_missing_items(collection_name, server_name)
    local db = get_db()
    if not db then
        return ""
    end
    
    -- Get items that are still needed, with count of how many characters need each
    local query = [[
        SELECT item_name, COUNT(*) as need_count
        FROM collection_needs
        WHERE collection_name = ? AND needed = 1
    ]]
    
    if server_name then
        query = query .. " AND server_name = ?"
    end
    
    query = query .. " GROUP BY item_name ORDER BY item_name"
    
    local stmt = db:prepare(query)
    if not stmt then
        return ""
    end
    
    if server_name then
        stmt:bind_values(collection_name, server_name)
    else
        stmt:bind_values(collection_name)
    end
    
    local items = {}
    local ok, err = pcall(function()
        for row in stmt:nrows() do
            table.insert(items, string.format("%s (%d)", row.item_name, row.need_count))
        end
    end)
    
    stmt:finalize()
    
    if not ok then
        -- Database likely locked, return empty
        return "(scanning...)"
    end
    
    return table.concat(items, ", ")
end

--- Get detailed per-character progress for a specific collection
--- @param collection_name string - The collection to get details for
--- @param server_name string|nil - Filter by server (optional)
--- @return table - Array of {character_name, items_needed, items_collected, total_items}
function collection_scanner.get_collection_details(collection_name, server_name)
    local db = get_db()
    if not db then
        return {}
    end
    
    local query = [[
        SELECT 
            character_name,
            SUM(CASE WHEN needed = 1 THEN 1 ELSE 0 END) as items_needed,
            SUM(CASE WHEN needed = 0 THEN 1 ELSE 0 END) as items_collected,
            COUNT(*) as total_items
        FROM collection_needs
        WHERE collection_name = ?
    ]]
    
    if server_name then
        query = query .. " AND server_name = ?"
    end
    
    query = query .. " GROUP BY character_name ORDER BY items_needed DESC, character_name"
    
    local stmt = db:prepare(query)
    if not stmt then
        return {}
    end
    
    if server_name then
        stmt:bind_values(collection_name, server_name)
    else
        stmt:bind_values(collection_name)
    end
    
    local results = {}
    local ok, err = pcall(function()
        for row in stmt:nrows() do
            table.insert(results, {
                character_name = row.character_name,
                items_needed = row.items_needed or 0,
                items_collected = row.items_collected or 0,
                total_items = row.total_items or 0
            })
        end
    end)
    
    stmt:finalize()
    
    if not ok then
        -- Database likely locked, return empty
        return {}
    end
    
    return results
end

return collection_scanner
