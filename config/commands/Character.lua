local configuration = require("yalm2.config.configuration")

local valid_subcommands = {
	edit = {
		args = "(name)",
		help = "Opens the config for the current %s or for the given name in your preferred editor",
	},
	help = {},
	set = {},
}

local function action(global_settings, char_settings, args)
	configuration.action(valid_subcommands, global_settings, char_settings, configuration.types.character.name, args)
end

return { action_func = action }
