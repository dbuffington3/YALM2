#!/usr/bin/env lua

-- Simulate what we know about the task data structure
local task_data = {
    tasks = {
        Forestess = {
            {
                task_name = "Collect Orbweaver Silks",
                objectives = {
                    {
                        objective = "Collect 4 Orbweaver Silks",
                        status = "0/4"
                    }
                }
            }
        },
        Vaeloraa = {
            {
                task_name = "Collect Orbweaver Silks",
                objectives = {
                    {
                        objective = "Collect 3 Orbweaver Silks",
                        status = "0/3"
                    }
                }
            },
            {
                task_name = "Collect Tanglefang Pelts",
                objectives = {
                    {
                        objective = "Collect 2 Tanglefang Pelts",
                        status = "0/2"
                    }
                }
            }
        },
        Vexxuss = {
            {
                task_name = "Collect Orbweaver Silks",
                objectives = {
                    {
                        objective = "Collect 5 Orbweaver Silks",
                        status = "0/5"
                    }
                }
            }
        },
        Lumarra = {
            {
                task_name = "Collect Orbweaver Silks",
                objectives = {
                    {
                        objective = "Collect 2 Orbweaver Silks",
                        status = "0/2"
                    }
                }
            },
            {
                task_name = "Collect Tanglefang Pelts",
                objectives = {
                    {
                        objective = "Collect 3 Tanglefang Pelts",
                        status = "0/3"
                    }
                }
            }
        },
        Tarnook = {
            {
                task_name = "Collect Orbweaver Silks",
                objectives = {
                    {
                        objective = "Collect 6 Orbweaver Silks",
                        status = "0/6"
                    }
                }
            },
            {
                task_name = "Collect Tanglefang Pelts",
                objectives = {
                    {
                        objective = "Collect 4 Tanglefang Pelts",
                        status = "0/4"
                    }
                }
            }
        },
        Lyricen = {
            {
                task_name = "Collect Orbweaver Silks",
                objectives = {
                    {
                        objective = "Collect 3 Orbweaver Silks",
                        status = "0/3"
                    }
                }
            },
            {
                task_name = "Collect Tanglefang Pelts",
                objectives = {
                    {
                        objective = "Collect 1 Tanglefang Pelts",
                        status = "0/1"
                    }
                }
            }
        }
    }
}

-- Extract per-character needs
print("=== PER-CHARACTER QUEST ITEM NEEDS ===\n")

local item_needs = {}

for character_name, tasks in pairs(task_data.tasks) do
    print(string.format("%s:", character_name))
    
    for _, task in ipairs(tasks) do
        if task.objectives then
            for _, objective in ipairs(task.objectives) do
                -- Extract number from objective like "Collect 4 Orbweaver Silks"
                local number, item_name = objective.objective:match("(%d+)%s+(.+)$")
                
                if number and item_name then
                    print(string.format("  - %s: needs %s", item_name, number))
                    
                    -- Store for summary
                    if not item_needs[item_name] then
                        item_needs[item_name] = {}
                    end
                    item_needs[item_name][character_name] = tonumber(number)
                else
                    print(string.format("  - %s", objective.objective))
                end
            end
        end
    end
    print()
end

-- Print summary
print("\n=== SUMMARY BY ITEM ===\n")
for item_name, character_needs in pairs(item_needs) do
    local total_needed = 0
    for _, count in pairs(character_needs) do
        total_needed = total_needed + count
    end
    
    print(string.format("%s (total needed: %d):", item_name, total_needed))
    for char_name, count in pairs(character_needs) do
        print(string.format("  - %s: %d", char_name, count))
    end
    print()
end
