--- Refresh Quest Data from All Actors
--- Command: /yalm2 refresh
--- Broadcasts to all connected actors to sync their quest data to the database

local mq = require("mq")
local Write = require("yalm2.lib.Write")
local dannet = require("yalm2.lib.dannet")
local quest_db = require("yalm2.lib.quest_database")

return function(args)
    Write.Info("Starting quest data refresh from all actors...")
    
    -- Initialize database if needed
    if not quest_db.init() then
        Write.Error("Failed to initialize quest database")
        return
    end
    
    -- Get list of all connected actors
    local actors = dannet.get_actors()
    if not actors or #actors == 0 then
        Write.Warning("No actors available for refresh")
        return
    end
    
    Write.Info("Syncing quest data from %d actors", #actors)
    
    -- Broadcast refresh request to all actors
    -- Each actor will respond by pushing their task data to the database
    for i, actor in ipairs(actors) do
        Write.Debug("Requesting refresh from %s", actor)
        
        -- Send message to actor to push their tasks
        -- This will be handled by yalm2_native_quest.lua on each character
        mq.cmd(string.format("/dex %s /yalm2 push_tasks", actor))
        
        -- Small delay to avoid overwhelming the system
        if i < #actors then
            mq.delay(100)
        end
    end
    
    Write.Info("Refresh request sent to all actors")
    
    -- Give actors time to respond
    mq.delay(1000)
    
    -- Show status
    local status = quest_db.get_status()
    if status.valid then
        Write.Info("Database now contains %d tasks from %d characters", 
                   status.total_tasks, status.characters)
    end
end
