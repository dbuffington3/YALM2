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
	Write.Help("\t  \ay/yalm2 help\ax -- Display this help output")
	Write.Help("\t  \ay/yalm2 reload\ax -- Reloads yalm2")
	Write.Help("\t  \ay/yalm2 nativequest\ax -- Toggle native quest system on/off")
	Write.Help("\t  \ay/yalm2 taskrefresh\ax -- Force refresh of quest data")
	Write.Help("\t  \ay/yalm2 dannetdiag\ax -- Run DanNet connectivity diagnostics")
	Write.Help("\t  \ay/yalm2 simulate <item_name>\ax -- Simulate looting an item by name")
	Write.Help("\t  \ay/yalm2 simulate id <item_id>\ax -- Simulate looting an item by ID")
	Write.Help("\t  \ay/yalm2 simulate quest <item_name>\ax -- Simulate quest item")

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
	elseif command == "taskrefresh" then
		Write.Debug("Manual quest refresh requested")
		native_tasks.refresh_all_characters()
		Write.Info("Quest data refresh requested")
	elseif command == "dannetdiag" then
		Write.Info("Running DanNet connectivity diagnostics...")
		local dannet_diag = require("yalm2.diagnostics.dannet_discovery")
		dannet_diag.run_full_diagnostics()
	elseif command == "simulate" then
		-- Loot simulator command
		if #args < 2 then
			Write.Error("Usage: /yalm2 simulate <item_name>")
			Write.Error("       /yalm2 simulate id <item_id>")
			Write.Error("       /yalm2 simulate quest <item_name>")
			return
		end
		
		local simulator = require("yalm2.core.loot_simulator")
		local sub_command = args[2]
		
		if sub_command == "id" then
			-- Simulate by item ID
			if #args < 3 then
				Write.Error("Usage: /yalm2 simulate id <item_id>")
				return
			end
			simulator.simulate_loot(args[3], true, false)
		elseif sub_command == "quest" then
			-- Simulate as quest item
			local item_name = table.concat(args, " ", 3)
			if item_name == "" then
				Write.Error("Usage: /yalm2 simulate quest <item_name>")
				return
			end
			simulator.simulate_loot(item_name, false, true)
		else
			-- Simulate by item name (combine remaining args as item name)
			local item_name = table.concat(args, " ", 2)
			simulator.simulate_loot(item_name, false, false)
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

local function clear_character_logs()
	-- Clear all character logs on startup (like we do with the debug log)
	local log_dir = "c:/MQ2/logs/"
	local log_pattern = "^bristle_.*%.log$"
	
	-- Try to clear logs using PowerShell on Windows
	local cmd = 'powershell -Command "Get-ChildItem \\"c:\\MQ2\\logs\\" -Filter \\"bristle_*.log\\" | Remove-Item -ErrorAction SilentlyContinue"'
	os.execute(cmd)
end

local function initialize()
	-- Clear character logs on startup
	clear_character_logs()
	
	-- Clean up any existing native quest instances on startup
	Write.Info("Cleaning up any existing native quest scripts...")
	mq.cmd('/dgga /lua stop yalm2/yalm2_native_quest')
	mq.cmd('/lua stop yalm2/yalm2_native_quest')
	mq.delay(1000)  -- Give time for cleanup

	utils.plugin_check()

	YALM2_Database.database = assert(YALM2_Database.OpenDatabase())
	
	-- Fix the Write prefix to show YALM2 instead of YALM (due to module caching)
	Write.prefix = "\at[\ax\apYALM2\ax\at]\ax"

	if not mq.TLO.Me.UseAdvancedLooting() then
		Write.Error("You must have AdvLoot enabled")
		mq.exit()
	end

	mq.bind("/yalm2", cmd_handler)

	global_settings, char_settings = settings.init_settings()

	Write.loglevel = global_settings.settings.log_level
	
	-- Initialize quest interface with native quest system and database
	quest_interface.initialize(global_settings, native_tasks, YALM2_Database)
	
	-- Initialize native quest detection system
	Write.Info("Using native quest detection system")
	debug_logger.info("INIT: Using native quest system")
	local success = native_tasks.initialize()
	if not success then
		Write.Error("Native quest system initialization failed - cannot continue")
		debug_logger.error("INIT: Native quest system initialization failed")
		mq.exit()
	end
	Write.Info("Native quest system initialized successfully")
	debug_logger.info("INIT: Native quest system ready")
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
		
		-- Process native quest system background tasks
		native_tasks.process()
	end

	mq.doevents()
	mq.delay(global_settings.settings.frequency)
	end
end

-- Cleanup function for graceful shutdown
local function cleanup()
	Write.Info("YALM2 shutting down...")
	
	-- Global cleanup of native quest instances
	Write.Info("Cleaning up native quest instances on all characters...")
	mq.cmd('/dgga /lua stop yalm2/yalm2_native_quest')
	mq.cmd('/lua stop yalm2/yalm2_native_quest')
	
	-- Shutdown native quest collectors
	native_tasks.shutdown_collectors()
	
	Write.Info("YALM2 shutdown complete")
end

-- Note: MQ2 will call cleanup automatically when script ends

main()
