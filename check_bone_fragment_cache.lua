#!/usr/bin/env lua

local sql = require("lsqlite3")

local db_path = "C:\\MQ2\\config\\YALM2\\quest_tasks.db"
local db = sql.open(db_path)

if not db then
    print("Failed to open database: " .. db_path)
    return
end

print("=== Checking quest_objectives table for 'Bone Fragment' ===\n")

local query = [[
    SELECT objective, item_name, matched_at FROM quest_objectives 
    WHERE item_name LIKE '%Bone Fragment%'
    ORDER BY matched_at DESC
]]

for row in db:nrows(query) do
    print("Objective: " .. tostring(row.objective))
    print("Item Name: " .. tostring(row.item_name))
    print("Matched At: " .. tostring(row.matched_at))
    print("---")
end

print("\n=== Checking quest_tasks table for Malrik and Bone Fragment ===\n")

local query2 = [[
    SELECT character, task_name, objective, status FROM quest_tasks 
    WHERE character = 'Malrik' AND item_name LIKE '%Bone Fragment%'
    ORDER BY updated_at DESC
]]

local found_any = false
for row in db:nrows(query2) do
    found_any = true
    print("Character: " .. tostring(row.character))
    print("Task: " .. tostring(row.task_name))
    print("Objective: " .. tostring(row.objective))
    print("Status: " .. tostring(row.status))
    print("---")
end

if not found_any then
    print("No Bone Fragment tasks found for Malrik in quest_tasks table")
end

print("\n=== All objectives in cache (first 30) ===\n")

local count = 0
for row in db:nrows("SELECT COUNT(*) as cnt FROM quest_objectives") do
    count = row.cnt
end

print("Total cached objectives: " .. count .. "\n")

for row in db:nrows("SELECT objective, item_name FROM quest_objectives LIMIT 30") do
    print(row.item_name .. " <- " .. row.objective:sub(1, 60))
end

db:close()
