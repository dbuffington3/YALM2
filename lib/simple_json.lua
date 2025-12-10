--- Simple JSON parser for Lucy data
--- Handles basic JSON objects with string/number values

local SimpleJSON = {}

function SimpleJSON.decode(json_str)
    local data = {}
    
    -- Remove outer braces and whitespace
    local content = json_str:match("^%s*{(.-)}%s*$")
    if not content then
        error("Invalid JSON format")
    end
    
    -- Split by commas, but be careful of nested quotes
    local in_quotes = false
    local current_field = ""
    local start_pos = 1
    
    for i = 1, #content do
        local char = content:sub(i, i)
        
        if char == '"' and content:sub(i-1, i-1) ~= '\\' then
            in_quotes = not in_quotes
        elseif char == ',' and not in_quotes then
            -- Found a field separator
            local field_str = content:sub(start_pos, i-1):match("^%s*(.-)%s*$")
            SimpleJSON.parse_field(field_str, data)
            start_pos = i + 1
        end
    end
    
    -- Handle last field
    local field_str = content:sub(start_pos):match("^%s*(.-)%s*$")
    SimpleJSON.parse_field(field_str, data)
    
    return data
end

function SimpleJSON.parse_field(field_str, data)
    -- Parse "key": "value" or "key": value
    local key, value = field_str:match('^"([^"]+)"%s*:%s*(.+)$')
    if not key then
        return -- Skip malformed fields
    end
    
    -- Parse value
    if value:match('^".*"$') then
        -- String value - remove quotes
        value = value:match('^"(.*)"$')
    elseif value:match('^%-?%d+%.?%d*$') then
        -- Numeric value
        value = tonumber(value) or value
    elseif value == "true" then
        value = true
    elseif value == "false" then
        value = false
    elseif value == "null" then
        value = nil
    else
        -- Keep as string if we can't parse it
        value = value:gsub('^"(.*)"$', '%1')
    end
    
    data[key] = value
end

return SimpleJSON