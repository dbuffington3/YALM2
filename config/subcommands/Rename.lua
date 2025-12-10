---@type Mq
local mq = require("mq")

local configuration = require("yalm2.config.configuration")

local function action(type, subcommands, global_settings, char_settings, args) end

return { action_func = action }
