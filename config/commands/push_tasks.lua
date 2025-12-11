--- Push This Character's Quest Tasks to Database
--- Command: /yalm2 push_tasks
--- Called by the master looter's refresh command on each actor
--- This character will read its quest data and write it to the shared database

local mq = require("mq")
local Write = require("yalm2.lib.Write")
local quest_db = require("yalm2.lib.quest_database")

return function(args)
    local my_char = mq.TLO.Me.CleanName()
    Write.Info("Pushing quest tasks to database for %s", my_char)
    
    -- Initialize database
    if not quest_db.init() then
        Write.Error("Failed to initialize quest database")
        return
    end
    
    -- Get this character's quest data from the native quest system
    -- This assumes the native quest data is available globally or can be loaded
    local tasks = {}
    
    -- Try to get tasks from the global YALM2_QUEST_DATA
    if _G.YALM2_QUEST_DATA and _G.YALM2_QUEST_DATA.quest_items then
        tasks = _G.YALM2_QUEST_DATA.quest_items
        Write.Info("Retrieved %d tasks from quest system", #tasks)
    else
        Write.Warning("No quest data available in this script context")
        Write.Debug("Available globals: %s", table.concat(require("yalm2.lib.inspect")(mq._G, {depth=1}), ", "))
        return
    end
    
    -- Store in database
    if quest_db.store_character_tasks(my_char, tasks) then
        Write.Info("Successfully pushed %d tasks to database", #tasks)
    else
        Write.Error("Failed to push tasks to database")
    end
end
