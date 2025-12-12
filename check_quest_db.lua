-- Quick database check script
local sql = require("lsqlite3")
local mq = require("mq")

local db_path = mq.configDir .. "/YALM2/quest_tasks.db"
print(string.format("Checking database: %s", db_path))

local db = sql.open(db_path)
if not db then
    print("ERROR: Could not open database")
    mq.exit()
end

-- List all tables
print("\n=== TABLES ===")
for row in db:nrows("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;") do
    print(string.format("  - %s", row.name))
end

-- Check quest_objectives table
print("\n=== quest_objectives TABLE ===")
local count = 0
for row in db:nrows("SELECT objective, task_name, item_name, matched_at FROM quest_objectives ORDER BY objective;") do
    count = count + 1
    print(string.format("%d. Objective: %s", count, row.objective))
    print(string.format("   Task: %s", row.task_name))
    print(string.format("   Item: %s", row.item_name))
    print(string.format("   Matched: %s", row.matched_at or "nil"))
end

if count == 0 then
    print("(No objectives cached yet)")
else
    print(string.format("\nTotal cached objectives: %d", count))
end

-- Check quest_tasks table (sample)
print("\n=== quest_tasks TABLE (sample - first 5) ===")
local task_count = 0
for row in db:nrows("SELECT character, task_name, objective, status, item_name FROM quest_tasks LIMIT 5;") do
    task_count = task_count + 1
    print(string.format("%d. Character: %s", task_count, row.character))
    print(string.format("   Task: %s", row.task_name))
    print(string.format("   Objective: %s", row.objective))
    print(string.format("   Status: %s", row.status))
    print(string.format("   Item: %s", row.item_name or "nil"))
end

-- Get total count of quest_tasks
local total_tasks = 0
for row in db:nrows("SELECT COUNT(*) as cnt FROM quest_tasks;") do
    total_tasks = row.cnt
end
print(string.format("\nTotal quest_tasks records: %d", total_tasks))

db:close()
print("\nDone!")
