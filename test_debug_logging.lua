-- Test script for debug logging system  
local debug_logger = require("yalm2.lib.debug_logger")

-- Initialize the debug logger
debug_logger.init()

-- Test all logging levels
debug_logger.info("LOGGING_TEST: Debug logging system initialized successfully")
debug_logger.debug("DEBUG_TEST: This is a debug message")
debug_logger.warn("WARNING_TEST: This is a warning message")
debug_logger.error("ERROR_TEST: This is an error message")
debug_logger.quest("QUEST_TEST: This is a quest-specific message")

print("Debug logging test complete. Check c:/MQ2/logs/yalm2_debug.log for output.")