--[[
    Collection Scanner - Standalone Script
    =======================================
    
    Scans the current character's collection achievements and stores
    the results in the shared YALM2 collection database.
    
    Usage:
        /lua run yalm2/collectscan
        
    Or to run on all characters via DanNet:
        /dgga /lua run yalm2/collectscan
    
    This can be run on ANY character, whether or not they are running YALM2.
    The database is shared, so YALM2's master looter can use this data
    to intelligently distribute collectibles to characters who need them.
]]

local mq = require("mq")
local collection_scanner = require("yalm2.lib.collectionscanner")

-- Initialize Write if available, otherwise use print
local Write
local success, write_module = pcall(require, "yalm2.lib.Write")
if success then
    Write = write_module
else
    Write = {
        Info = function(fmt, ...) print(string.format("[CollectScan] " .. fmt, ...)) end,
        Error = function(fmt, ...) print(string.format("[CollectScan ERROR] " .. fmt, ...)) end,
        Warn = function(fmt, ...) print(string.format("[CollectScan WARN] " .. fmt, ...)) end,
    }
end

Write.Info("\ay[Collection Scanner]\ax Starting scan for \ag%s\ax on \ao%s\ax", 
    mq.TLO.Me.Name(), mq.TLO.EverQuest.Server())

-- Run the scan
if collection_scanner.init() then
    local needed = collection_scanner.scan_character()
    
    -- Get progress summary
    local progress = collection_scanner.get_character_progress(mq.TLO.Me.Name(), mq.TLO.EverQuest.Server())
    
    Write.Info("\ay[Collection Scanner]\ax Scan complete!")
    Write.Info("  Total collectibles: \ay%d\ax", progress.total)
    Write.Info("  Already collected:  \ag%d\ax", progress.collected)
    Write.Info("  Still needed:       \ar%d\ax", progress.needed)
    
    -- Show per-expansion breakdown if there's data
    if progress.total > 0 then
        Write.Info("")
        Write.Info("By expansion:")
        
        -- Sort expansions for display
        local exp_order = {"RoF", "CotF", "TDS", "TBM", "EoK", "RoS", "TBL", "ToV", "CoV", "ToL", "NoS", "LS", "TOB", "SoR"}
        for _, exp in ipairs(exp_order) do
            local data = progress.by_expansion[exp]
            if data then
                local pct = math.floor((data.collected / data.total) * 100)
                local color = "\ar"  -- Red for < 50%
                if pct >= 100 then
                    color = "\ag"  -- Green for complete
                elseif pct >= 75 then
                    color = "\ay"  -- Yellow for 75%+
                elseif pct >= 50 then
                    color = "\ao"  -- Orange for 50%+
                end
                Write.Info("  %s: %s%d/%d (%d%%)\ax", exp, color, data.collected, data.total, pct)
            end
        end
    end
else
    Write.Error("Failed to initialize collection database!")
end

Write.Info("\ay[Collection Scanner]\ax Done. Data saved to collection_needs.db")
