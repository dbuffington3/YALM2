--- Test Command: Verify MQ2 Variable Communication
--- Tests if variables can be set and read between scripts

local mq = require("mq")
local Write = require("yalm2.lib.Write")
local native_tasks = require("yalm2.core.native_tasks")

local function action(global_settings, char_settings, args)
	local cmd = args[1] and args[1]:lower() or "help"
	
	if cmd == "set" then
		Write.Info("=== TEST: Setting MQ2 Variable ===")
		local test_value = native_tasks.test_set_mq2_variable()
		Write.Info("Set YALM2_Test_Var to: %s", test_value)
		
	elseif cmd == "read" then
		Write.Info("=== TEST: Reading MQ2 Variable ===")
		local value = native_tasks.test_read_mq2_variable()
		if value then
			Write.Info("Read YALM2_Test_Var: %s", value)
		else
			Write.Info("Failed to read variable")
		end
		
	elseif cmd == "monitor" then
		local var_name = args[2] or "YALM2_Test_Var"
		local duration = tonumber(args[3] or 30)
		Write.Info("=== TEST: Monitoring Variable ===")
		Write.Info("Variable: %s, Duration: %d seconds", var_name, duration)
		native_tasks.test_monitor_variable(var_name, duration)
		
	elseif cmd == "quest" then
		Write.Info("=== TEST: Monitoring YALM2_Quest_Items ===")
		local duration = tonumber(args[2] or 30)
		Write.Info("Monitoring quest data for %d seconds...", duration)
		native_tasks.test_monitor_variable("YALM2_Quest_Items", duration)
		
	elseif cmd == "help" then
		Write.Info("=== Test Communication Commands ===")
		Write.Info("/yalm2 testcomm set        - Set a test variable")
		Write.Info("/yalm2 testcomm read       - Read the test variable")
		Write.Info("/yalm2 testcomm monitor [var] [seconds]  - Monitor a variable for changes")
		Write.Info("/yalm2 testcomm quest [seconds]          - Monitor quest data")
		Write.Info("")
		Write.Info("Example: /yalm2 testcomm quest 60")
		Write.Info("         /yalm2 testcomm monitor YALM2_Quest_Count 30")
	else
		Write.Info("Unknown command: %s", cmd)
		Write.Info("Use '/yalm2 testcomm help' for options")
	end
end

return {
	command = "TestComm",
	alias = "test",
	description = "Test MQ2 variable communication",
	action = action
}
