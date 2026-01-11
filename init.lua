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
	Write.Help("\ax Commands Available:")
	Write.Help("\t  \ay/yalm2 help\ax -- Display this help output")
	Write.Help("\t  \ay/yalm2 reload\ax -- Reloads yalm2")
	Write.Help("\t  \ay/yalm2 nativequest\ax -- Toggle native quest system on/off")
	Write.Help("\t  \ay/yalm2 taskrefresh\ax -- Force refresh of quest data")
	Write.Help("\t  \ay/yalm2 dannetdiag\ax -- Run DanNet connectivity diagnostics")
	Write.Help("\t  \ay/yalm2 armorprogressionsetup\ax -- Configure 530 armor craft components globally")
	Write.Help("\t  \ay/yalm2 simulate <item_name>\ax -- Simulate looting an item by name")
	Write.Help("\t  \ay/yalm2 simulate id <item_id>\ax -- Simulate looting an item by ID")
	Write.Help("\t  \ay/yalm2 simulate quest <item_name>\ax -- Simulate quest item")
	Write.Help("\t  \ay/yalm2 cccu\ax -- Cross-Character Upgrade Checker")
	Write.Help("\t  \ay/yalm2 cu\ax -- Equipment Upgrade Checker (current character)")
	Write.Help("\t  \ay/yalm2 singleitem\ax -- Toggle collecting one of each low-value tradeskill item")
	Write.Help("\t  \ay/yalm2 farming on|off\ax -- Toggle farming mode (prioritizes stackable valuables)")
	Write.Help("\t  \ay/yalm2 mintier [tier]\ax -- Set minimum armor tier (ignores lower tiers, per-character)")
	Write.Help("\t  \ay/yalm2 tier\ax -- Display armor tier progression list")
	Write.Help("\t  \ay/yalm2 cleanup\ax -- Scan inventory for NO DROP items to destroy (dry run)")
	Write.Help("\t  \ay/yalm2 cleanup destroy\ax -- Actually destroy NO DROP items that shouldn't be kept")
	Write.Help("\t  \ay/yalm2 collectscan\ax -- Scan character's collection achievements to database")
	Write.Help("\t  \ay/yalm2 collectcheck <item>\ax -- Check which characters need a collectible item")

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
	elseif command == "cccu" then
		-- Cross-Character Upgrade Checker
		Write.Info("Running cross-character upgrade checker...")
		mq.cmd("/lua run yalm2/check_cross_character_upgrades")
	elseif command == "cu" then
		-- Equipment Upgrade Checker (current character)
		Write.Info("Running equipment upgrade checker...")
		mq.cmd("/dgga /lua run yalm2/check_upgrades")
	elseif command == "cleanup" then
		-- Inventory cleanup command
		local cleanup = require("yalm2.lib.inventory_cleanup")
		
		local dry_run = true
		if args[2] == "destroy" then
			dry_run = false
		end
		
		Write.Info("=== Inventory Cleanup for %s ===", mq.TLO.Me.DisplayName())
		if dry_run then
			Write.Info("Running in \ayDRY RUN\ax mode - no items will be destroyed")
			Write.Info("Use \ay/yalm2 cleanup destroy\ax to actually destroy items")
		else
			Write.Warn("Running in \arDESTROY\ax mode - items will be PERMANENTLY destroyed!")
		end
		Write.Info("")
		
		local items_to_destroy = cleanup.scan_inventory(char_settings, global_settings, dry_run)
		
		if #items_to_destroy == 0 then
			Write.Info("No NO DROP items found that should be destroyed")
		else
			Write.Info("Found \ar%d\ax NO DROP items that should be destroyed:", #items_to_destroy)
			Write.Info("")
			
			for _, entry in ipairs(items_to_destroy) do
				Write.Info("  \ar[X]\ax %s [%s]", entry.name, entry.slot)
				Write.Info("      Reason: %s", entry.reason)
			end
			
			Write.Info("")
			
			if dry_run then
				Write.Info("To destroy these items, run: \ay/yalm2 cleanup destroy\ax")
			else
				Write.Warn("Destroying %d items...", #items_to_destroy)
				local destroyed_count = cleanup.destroy_items(items_to_destroy)
				Write.Info("Destroyed \ar%d\ax items", destroyed_count)
			end
		end
	elseif command == "singleitem" then
		-- Toggle collect_one_tradeskill_sample setting (per-character)
		local loot_settings = char_settings.loot
		if not loot_settings then
			char_settings.loot = {}
			loot_settings = char_settings.loot
		end
		if not loot_settings.settings then
			loot_settings.settings = {}
		end
		
		-- Toggle the setting
		local current_value = loot_settings.settings.collect_one_tradeskill_sample or false
		loot_settings.settings.collect_one_tradeskill_sample = not current_value
		
		-- Save the settings
		settings.save_char_settings(settings.get_char_settings_filename(), char_settings)
		
		-- Display status
		if loot_settings.settings.collect_one_tradeskill_sample then
			Write.Info("Single-item collection \agENABLED\ax for %s - will collect one of each low-value tradeskill item", mq.TLO.Me.DisplayName())
		else
			Write.Info("Single-item collection \arDISABLED\ax for %s - will leave low-value tradeskill items on corpse", mq.TLO.Me.DisplayName())
		end
	elseif command == "farming" then
		-- Toggle farming mode (per-character) - forces "Ignore" for unmatched items to prioritize stackables/valuables
		local mode_arg = args[2]
		
		local loot_settings = char_settings.loot
		if not loot_settings then
			char_settings.loot = {}
			loot_settings = char_settings.loot
		end
		if not loot_settings.settings then
			loot_settings.settings = {}
		end
		
		if not mode_arg or (mode_arg ~= "on" and mode_arg ~= "off") then
			-- Display current status
			local farming_mode = loot_settings.settings.farming_mode or false
			if farming_mode then
				Write.Info("Farming mode is \agENABLED\ax for %s - looting only stackable valuables and explicit items", mq.TLO.Me.DisplayName())
			else
				Write.Info("Farming mode is \arDISABLED\ax for %s - normal looting behavior", mq.TLO.Me.DisplayName())
			end
			Write.Info("Usage: /yalm2 farming on|off")
			return
		end
		
		-- Set farming mode
		loot_settings.settings.farming_mode = (mode_arg == "on")
		
		-- Save the settings
		settings.save_char_settings(settings.get_char_settings_filename(), char_settings)
		
		-- Display status
		if loot_settings.settings.farming_mode then
			Write.Info("Farming mode \agENABLED\ax for %s", mq.TLO.Me.DisplayName())
			Write.Info("  Will loot: Stackable valuables (10pp+), high favor items (1000+), tradeskills, quest needs, explicit items")
			Write.Info("  Will ignore: Non-stackable trash items without explicit preferences")
		else
			Write.Info("Farming mode \arDISABLED\ax for %s - normal looting behavior resumed", mq.TLO.Me.DisplayName())
		end
	elseif command == "mintier" then
		-- Set minimum armor tier (per-character) - ignores armor below this tier
		local tier_value = tonumber(args[2])
		
		local loot_settings = char_settings.loot
		if not loot_settings then
			char_settings.loot = {}
			loot_settings = char_settings.loot
		end
		if not loot_settings.settings then
			loot_settings.settings = {}
		end
		
		if not tier_value then
			-- Display current setting
			local current_tier = loot_settings.settings.min_armor_tier or 0
			if current_tier > 0 then
				Write.Info("Minimum armor tier for %s: \ag%d\ax (ignoring tiers 1-%d)", mq.TLO.Me.DisplayName(), current_tier, current_tier - 1)
			else
				Write.Info("Minimum armor tier for %s: \ayNOT SET\ax (accepting all tiers)", mq.TLO.Me.DisplayName())
			end
			Write.Info("Usage: /yalm2 mintier <tier_number>  (or 0 to disable)")
			Write.Info("Example: /yalm2 mintier 5  (ignores Crude/Rough/Simple/Flawed Defiant, keeps Elaborate+ Defiant)")
			Write.Info("")
			Write.Info("Common Defiant tiers: 1=Crude, 2=Rough, 3=Simple, 4=Flawed, 5=Elaborate, 6=Intricate, 7=Ornate, 8=Elegant")
			Write.Info("Progression tiers: 10-13=HoT, 14-17=VoA, 18-21=Fear+")
			return
		end
		
		-- Validate tier
		if tier_value < 0 or tier_value > 25 then
			Write.Error("Invalid tier value: %d (must be 0-25)", tier_value)
			return
		end
		
		-- Set the tier
		loot_settings.settings.min_armor_tier = tier_value > 0 and tier_value or nil
		
		-- Save the settings
		settings.save_char_settings(settings.get_char_settings_filename(), char_settings)
		
		-- Display status
		if tier_value > 0 then
			Write.Info("Minimum armor tier set to \ag%d\ax for %s - will ignore armor tiers 1-%d", tier_value, mq.TLO.Me.DisplayName(), tier_value - 1)
			if tier_value <= 8 then
				local defiant_tiers = {"Crude", "Rough", "Simple", "Flawed", "Elaborate", "Intricate", "Ornate", "Elegant"}
				local ignored = {}
				local kept = {}
				for i = 1, 8 do
					if i < tier_value then
						table.insert(ignored, defiant_tiers[i])
					else
						table.insert(kept, defiant_tiers[i])
					end
				end
				if #ignored > 0 then
					Write.Info("  Defiant armor ignored: \ar%s\ax", table.concat(ignored, ", "))
				end
				if #kept > 0 then
					Write.Info("  Defiant armor kept: \ag%s\ax", table.concat(kept, ", "))
				end
			end
		else
			Write.Info("Minimum armor tier \ayDISABLED\ax for %s - will accept all armor tiers", mq.TLO.Me.DisplayName())
		end
	elseif command == "tier" then
		-- Display armor tier list
		Write.Info("\at[\ax\ayArmor Tier Progression\ax\at]\ax")
		Write.Info("")
		
		-- Load armor_sets module to get ARMOR_PROGRESSION
		local armor_module = require("yalm2.config.armor_sets")
		local ARMOR_PROGRESSION = armor_module.ARMOR_PROGRESSION
		
		-- Build inverted table: tier -> {set_names}
		local tier_to_sets = {}
		for set_name, data in pairs(ARMOR_PROGRESSION) do
			local tier = data.tier
			if not tier_to_sets[tier] then
				tier_to_sets[tier] = {}
			end
			table.insert(tier_to_sets[tier], set_name)
		end
		
		-- Display tiers in order
		for tier = 1, 25 do
			if tier_to_sets[tier] then
				-- Sort set names alphabetically for consistent display
				table.sort(tier_to_sets[tier])
				local sets_str = table.concat(tier_to_sets[tier], ", ")
				Write.Info("Tier \ay%2d\ax: %s", tier, sets_str)
			end
		end
		
		Write.Info("")
		Write.Info("Use \ay/yalm2 mintier <tier>\ax to set minimum armor tier for this character")
	elseif command == "collectscan" then
		-- Scan character's collection achievements
		local collection_scanner = require("yalm2.lib.collectionscanner")
		if collection_scanner.init() then
			local needed = collection_scanner.scan_character()
			Write.Info("Collection scan complete. You need \ay%d\ax more collectibles.", needed)
		else
			Write.Error("Failed to initialize collection database")
		end
	elseif command == "collectcheck" then
		-- Check which characters need a specific collectible
		if #args < 2 then
			Write.Error("Usage: /yalm2 collectcheck <item name>")
			return
		end
		-- Join remaining args as item name
		local item_name = table.concat(args, " ", 2)
		local collection_scanner = require("yalm2.lib.collectionscanner")
		if collection_scanner.init() then
			local characters = collection_scanner.find_characters_needing_item(item_name)
			if #characters > 0 then
				Write.Info("Characters needing '\ay%s\ax':", item_name)
				for _, char in ipairs(characters) do
					Write.Info("  \ag%s\ax (%s) - Collection: %s", char.character_name, char.expansion, char.collection_name)
				end
			else
				if collection_scanner.is_collectible(item_name) then
					Write.Info("No characters need '\ay%s\ax' - all have it or none scanned", item_name)
				else
					Write.Warn("'\ay%s\ax' not found in collection database. Run /yalm2 collectscan on characters first.", item_name)
				end
			end
		else
			Write.Error("Failed to initialize collection database")
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
	
	-- Display registered commands at startup
	Write.Info("Registered /yalm2 cu - Equipment Upgrade Checker")
	Write.Info("Registered /yalm2 cccu - Cross-Character Upgrade Checker")
	
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

	local last_loader_check = mq.gettime()
	local loader_check_interval = 5000  -- Check for file changes every 5 seconds instead of every frame

	while not state.terminate and mq.TLO.MacroQuest.GameState() == "INGAME" do
		if not mq.TLO.Me.Dead() then
			global_settings, char_settings = settings.reload_settings(global_settings, char_settings)

			-- Only check for file modifications every 5 seconds, not every frame
			local current_time = mq.gettime()
			if current_time - last_loader_check > loader_check_interval then
				loader.manage(global_settings.commands, configuration.types.command)
				loader.manage(global_settings.conditions, configuration.types.condition)
				loader.manage(global_settings.helpers, configuration.types.helpers)
				loader.manage(global_settings.subcommands, configuration.types.subcommand)
				last_loader_check = current_time
			end

			looting.handle_master_looting(global_settings, char_settings)
			looting.handle_solo_looting(global_settings, char_settings)
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
