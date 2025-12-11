#!/usr/bin/env lua
--- TEST_GLOBALS.lua
--- Test whether quest-related global variables have values during runtime
--- Run this after some quest items drop to see what data is available

local mq = require("mq")
require("mq.ImGui")
local config = require("yalm2.config.configuration")
local inspect = require("yalm2.lib.inspect")

mq.imgui.Init("TEST_GLOBALS", "Test Global Variables")

Write = require("yalm2.lib.Write")
local debug_logger = require("yalm2.lib.debug_logger")

local should_close = false

function ImGuiTest()
    if mq.imgui.Begin("Global Variable Status##test", true) then
        if mq.imgui.BeginTable("Globals", 2) then
            mq.imgui.TableSetupColumn("Variable")
            mq.imgui.TableSetupColumn("Status")
            mq.imgui.TableHeadersRow()
            
            -- Check _G.YALM2_QUEST_DATA
            mq.imgui.TableNextColumn()
            mq.imgui.Text("_G.YALM2_QUEST_DATA")
            mq.imgui.TableNextColumn()
            if _G.YALM2_QUEST_DATA then
                mq.imgui.TextColored(0xFF00FF00, "EXISTS")
                if _G.YALM2_QUEST_DATA.quest_items then
                    local count = 0
                    for _ in pairs(_G.YALM2_QUEST_DATA.quest_items) do count = count + 1 end
                    mq.imgui.TextColored(0xFF00FF00, "  quest_items: %d items", count)
                else
                    mq.imgui.TextColored(0xFFFF0000, "  quest_items: nil")
                end
                if _G.YALM2_QUEST_DATA.timestamp then
                    mq.imgui.Text("  timestamp: %d", _G.YALM2_QUEST_DATA.timestamp)
                end
            else
                mq.imgui.TextColored(0xFFFF0000, "NIL (not set)")
            end
            
            -- Check _G.YALM2_QUEST_ITEMS_WITH_QTY
            mq.imgui.TableNextColumn()
            mq.imgui.Text("_G.YALM2_QUEST_ITEMS_WITH_QTY")
            mq.imgui.TableNextColumn()
            local qty_val = _G.YALM2_QUEST_ITEMS_WITH_QTY or ""
            if qty_val:len() > 0 then
                mq.imgui.TextColored(0xFF00FF00, "EXISTS (len=%d)", qty_val:len())
                mq.imgui.Text("  Value: %s", qty_val:sub(1, 100))
            else
                mq.imgui.TextColored(0xFFFF0000, "EMPTY or NIL")
            end
            
            mq.imgui.EndTable()
        end
        
        mq.imgui.Separator()
        mq.imgui.TextWrapped("Drop some quest items to see if the globals get populated. The debug log will show [GLOBAL CHECK] lines.")
        
        if mq.imgui.Button("Close") then
            should_close = true
        end
        
        mq.imgui.End()
    end
    
    return not should_close
end

Write.Info("TEST_GLOBALS: Initialized. Drop quest items and watch debug log for [GLOBAL CHECK] messages.")
Write.Info("TEST_GLOBALS: Press Escape or click Close to exit.")

while true do
    if ImGuiTest() == false then break end
    mq.delay(100)
end

Write.Info("TEST_GLOBALS: Exiting")
