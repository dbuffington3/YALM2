-- Test database module - minimal version to diagnose function execution issue

print("[DB_TEST_MODULE] Loading test database module at startup")

local TestDB = {
	database = nil,
}

print("[DB_TEST_MODULE] TestDB table created")

TestDB.QueryDatabaseForItemName = function(item_name)
	print("[DB_TEST] QueryDatabaseForItemName called with: " .. tostring(item_name))
	return nil
end

print("[DB_TEST_MODULE] QueryDatabaseForItemName function defined")

return TestDB
