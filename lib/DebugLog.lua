local mq = require("mq")
local os = require("os")

local DebugLog = {}

local log_file_path = nil
local log_file_handle = nil

-- Initialize debug log file (recreated on each startup)
function DebugLog.initialize(character_name)
	local log_dir = "C:\\MQ2\\logs"
	log_file_path = string.format("%s\\yalm2_debug_%s.log", log_dir, character_name or "unknown")
	
	-- Close existing handle if open
	if log_file_handle then
		log_file_handle:close()
	end
	
	-- Create new log file (overwrite existing)
	log_file_handle = io.open(log_file_path, "w")
	if log_file_handle then
		local timestamp = os.date("%Y-%m-%d %H:%M:%S")
		log_file_handle:write(string.format("[%s] YALM2 Debug Log Started for %s\n", timestamp, character_name or "unknown"))
		log_file_handle:write(string.format("[%s] =====================================\n", timestamp))
		log_file_handle:flush()
		return true
	end
	return false
end

-- Write debug message to log file
function DebugLog.write(level, message, ...)
	if not log_file_handle then
		return
	end
	
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local formatted_message = string.format(message, ...)
	local log_line = string.format("[%s] [%s] %s\n", timestamp, level, formatted_message)
	
	log_file_handle:write(log_line)
	log_file_handle:flush()
end

-- Convenience functions
function DebugLog.info(message, ...)
	DebugLog.write("INFO", message, ...)
end

function DebugLog.debug(message, ...)
	DebugLog.write("DEBUG", message, ...)
end

function DebugLog.error(message, ...)
	DebugLog.write("ERROR", message, ...)
end

function DebugLog.warn(message, ...)
	DebugLog.write("WARN", message, ...)
end

-- Log item analysis
function DebugLog.log_item_analysis(item_name, item_id, item_data, decision, reasoning)
	DebugLog.write("ITEM_ANALYSIS", "=== ITEM ANALYSIS START ===")
	DebugLog.write("ITEM_ANALYSIS", "Item Name: %s", item_name or "unknown")
	DebugLog.write("ITEM_ANALYSIS", "Item ID: %s", tostring(item_id or "unknown"))
	
	if item_data then
		for key, value in pairs(item_data) do
			DebugLog.write("ITEM_ANALYSIS", "  %s: %s", tostring(key), tostring(value))
		end
	end
	
	DebugLog.write("ITEM_ANALYSIS", "Decision: %s", decision or "unknown")
	DebugLog.write("ITEM_ANALYSIS", "Reasoning: %s", reasoning or "no reasoning provided")
	DebugLog.write("ITEM_ANALYSIS", "=== ITEM ANALYSIS END ===")
end

-- Close log file
function DebugLog.close()
	if log_file_handle then
		local timestamp = os.date("%Y-%m-%d %H:%M:%S")
		log_file_handle:write(string.format("[%s] YALM2 Debug Log Closed\n", timestamp))
		log_file_handle:close()
		log_file_handle = nil
	end
end

return DebugLog