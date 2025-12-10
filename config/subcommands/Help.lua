local configuration = require("yalm2.config.configuration")

local utils = require("yalm2.lib.utils")

local function action(type, subcommands, global_settings, char_settings, args)
	local loot_subcommands = {
		subcommands = {},
	}

	for _, subcommand in pairs(global_settings.subcommands) do
		if subcommands[subcommand.trigger] then
			loot_subcommands.subcommands[subcommand.name] = subcommand
			utils.merge(loot_subcommands.subcommands[subcommand.name], subcommands[subcommand.trigger])
		end
	end

	Write.Help("\at[\ax\ay/yalm2 %s help\ax\at]\ax", type)

	configuration.print_type_help(loot_subcommands, "subcommands", type)
end

return { action_func = action }
