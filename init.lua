--[[
yalm -- fuddles
]]
---@type Mq
local mq = require("mq")
--- @type ImGui
require("ImGui")

local PackageMan = require("mq/PackageMan")
local Utils = require("mq/Utils")

require("yalm2.lib.Write")

-- Initialize debug logging system
local debug_logger = require("yalm2.lib.debug_logger")
debug_logger.init()

local sql = PackageMan.Require("lsqlite3")
local lfs = PackageMan.Require("luafilesystem", "lfs")

require("yalm2.lib.database")

local configuration = require("yalm2.config.configuration")
local settings = require("yalm2.config.settings")
local tasks = require("yalm2.core.tasks")
local native_tasks = require("yalm2.core.native_tasks")
local quest_interface = require("yalm2.core.quest_interface")
local state = require("yalm2.config.state")

local looting = require("yalm2.core.looting")
local loader = require("yalm2.core.loader")

local utils = require("yalm2.lib.utils")

local global_settings, char_settings

local function print_help()
	Write.Help("\at[\ax\ayYet Another Loot Manager v%s\ax\at]\ax", state.version)
	Write.Help("\axCommands Available:")
	Write.Help("\t  \ay/yalm help\ax -- Display this help output")
	Write.Help("\t  \ay/yalm2 reload\ax -- Reloads yalm2")
	Write.Help("\t  \ay/yalm2 nativequest\ax -- Toggle native quest system on/off")
	Write.Help("\t  \ay/yalm2 taskrefresh\ax -- Force refresh of quest data")

	configuration.print_type_help(global_settings, configuration.types.command.settings_key)
end

local function cmd_handler(...)
	local args = { ... }

	if #args < 1 then
		print_help()
		return
	end

	local command = args[1]
	local loot_command = utils.find_by_key(global_settings.commands, "trigger", command)

	if command == "help" then
		print_help()
	elseif command == "reload" then
		Write.Info("Stopping YALM2. Please run: /lua run yalm2")
		state.terminate = true
	elseif command == "nativequest" then
		global_settings.settings.use_native_quest_system = not global_settings.settings.use_native_quest_system
		Write.Info("Native quest system %s", global_settings.settings.use_native_quest_system and "ENABLED" or "DISABLED")
		Write.Info("Reload YALM2 for this change to take effect: /yalm2 reload")
	elseif command == "taskrefresh" then
		if global_settings.settings.use_native_quest_system then
			Write.Info("Refreshing native quest data...")
			native_tasks.refresh_all_characters()
		else
			Write.Info("Refreshing external TaskHUD data...")
			if tasks.request_task_update then
				tasks.request_task_update()
			else
				Write.Warn("External TaskHUD refresh not available")
			end
		end
	elseif loot_command and loot_command.loaded then
		if not state.command_running then
			state.command_running = command
			local success, result = pcall(loot_command.func.action_func, global_settings, char_settings, args)
			if not success then
				Write.Warn("Running command failed: %s - %s", loot_command.name, result)
			end
			state.command_running = nil
		else
			Write.Warn("Cannot run a command as \ao%s\ax is still running", state.command_running)
		end
	else
		Write.Warn("That is not a valid command")
	end
end

local function initialize()
	utils.plugin_check()

	Database.database = assert(Database.OpenDatabase())
	
	-- Patch the database functions to fix the fallback logic (due to module caching)
	Database.QueryDatabaseForItemId = function(item_id)
		local item_db = nil
		-- Try new table first
		for row in Database.database:nrows(string.format("select * from raw_item_data_315 where id = %s", item_id)) do
			item_db = row
			break
		end
		-- If no result found, try old table
		if not item_db then
			for row in Database.database:nrows(string.format("select * from raw_item_data where id = %s", item_id)) do
				item_db = row
				break
			end
		end
		return item_db
	end
	
	Database.QueryDatabaseForItemName = function(item_name)
		local item_db = nil
		-- Try new table first
		for row in Database.database:nrows(string.format('select * from raw_item_data_315 where name = "%s"', item_name)) do
			item_db = row
			break
		end
		-- If no result found, try old table
		if not item_db then
			for row in Database.database:nrows(string.format('select * from raw_item_data where name = "%s"', item_name)) do
				item_db = row
				break
			end
		end
		return item_db
	end
	
	-- Fix the Write prefix to show YALM2 instead of YALM (due to module caching)
	Write.prefix = "\at[\ax\apYALM2\ax\at]\ax"

	if not mq.TLO.Me.UseAdvancedLooting() then
		Write.Error("You must have AdvLoot enabled")
		mq.exit()
	end

	mq.bind("/yalm2", cmd_handler)

	global_settings, char_settings = settings.init_settings()

	Write.loglevel = global_settings.settings.log_level
	
	-- Initialize quest interface with both systems
	quest_interface.initialize(global_settings, tasks, native_tasks)
	
	-- Initialize task awareness system
	if global_settings.settings.use_native_quest_system then
		Write.Info("Using native quest detection system")
		debug_logger.info("INIT: Using native quest system instead of external TaskHUD")
		local success = native_tasks.initialize()
		if not success then
			Write.Warn("Native quest system initialization failed - falling back to external TaskHUD")
			debug_logger.warn("INIT: Native quest system failed, falling back to TaskHUD")
			-- Initialize external system
			tasks.init()
			-- Update quest interface to use external system
			global_settings.settings.use_native_quest_system = false
			quest_interface.initialize(global_settings, tasks, native_tasks)
		else
			Write.Info("Native quest system initialized successfully")
			debug_logger.info("INIT: Native quest system ready")
		end
	else
		Write.Info("Using external TaskHUD communication")
		debug_logger.info("INIT: Using external TaskHUD system")
		tasks.init()
	end
end

local function main()
	initialize()

	while not state.terminate and mq.TLO.MacroQuest.GameState() == "INGAME" do
		if not mq.TLO.Me.Dead() then
			global_settings, char_settings = settings.reload_settings(global_settings, char_settings)

			loader.manage(global_settings.commands, configuration.types.command)
			loader.manage(global_settings.conditions, configuration.types.condition)
			loader.manage(global_settings.helpers, configuration.types.helpers)
			loader.manage(global_settings.subcommands, configuration.types.subcommand)

			looting.handle_master_looting(global_settings)
			looting.handle_solo_looting(global_settings)
			looting.handle_personal_loot()
		end

		mq.doevents()
		mq.delay(global_settings.settings.frequency)
	end
end

main()
