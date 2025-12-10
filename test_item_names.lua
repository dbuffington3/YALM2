#!/usr/bin/env lua
-- Test script to find exact item names in database

local sqlite3 = require("lsqlite3")

-- Path to the database
local db_path = "C:\\MQ2\\resources\\MQ2LinkDB.sqlite3"
print("Opening database: " .. db_path)

local db = sqlite3.open(db_path)
if not db then
    print("ERROR: Could not open database!")
    return
end

-- Test strings to search for
local test_strings = {
    "quality Orbweaver Silks",      -- Full string with descriptor
    "Orbweaver Silks",               -- Remove quality prefix
    "Orbweaver",                     -- Just the main noun
}

print("\n=== Testing different query strings ===\n")

for _, search_term in ipairs(test_strings) do
    print("Testing: '" .. search_term .. "'")
    
    -- Try exact match first
    local query = string.format('SELECT name FROM raw_item_data WHERE name = "%s" LIMIT 1', search_term)
    local found = false
    for row in db:nrows(query) do
        print("  ✓ EXACT MATCH in raw_item_data: " .. row.name)
        found = true
        break
    end
    
    if not found then
        -- Try wildcard search
        local like_term = search_term:gsub("%%", "")
        query = string.format("SELECT name FROM raw_item_data WHERE name LIKE '%%%s%%' LIMIT 5", like_term)
        local matches = 0
        for row in db:nrows(query) do
            if matches == 0 then
                print("  ✓ WILDCARD MATCHES in raw_item_data:")
            end
            print("    - " .. row.name)
            matches = matches + 1
        end
        if matches == 0 then
            print("  ✗ No matches found")
        end
    end
    print()
end

db:close()
print("Database closed.")
