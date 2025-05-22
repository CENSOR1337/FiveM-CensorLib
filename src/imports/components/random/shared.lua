--- Provides utilities for generating random data, such as random strings and UUIDs.
-- @module random

local math_random = math.random
local string_format = string.format

--- @type table Internal configuration for random string generation.
-- Stores character sets for numeric, uppercase, and lowercase characters.
-- @local
local randomize_string_config = {
    charset = {
        numeric = { len = 0, chars = {} },
        upper = { len = 0, chars = {} },
        lower = { len = 0, chars = {} },
    },
}

-- Populate character sets
do
    for i = 48, 57 do -- 0-9
        table.insert(randomize_string_config.charset.numeric.chars, string.char(i))
    end
    randomize_string_config.charset.numeric.len = #randomize_string_config.charset.numeric.chars

    for i = 65, 90 do -- A-Z
        table.insert(randomize_string_config.charset.upper.chars, string.char(i))
    end
    randomize_string_config.charset.upper.len = #randomize_string_config.charset.upper.chars

    for i = 97, 122 do -- a-z
        table.insert(randomize_string_config.charset.lower.chars, string.char(i))
    end
    randomize_string_config.charset.lower.len = #randomize_string_config.charset.lower.chars
end

--- Generates a random string of a specified length using selected character sets.
-- @param length number The desired length of the random string.
-- @param opts table (Optional) A list of character set names to use.
--             Defaults to `{"lower", "upper", "numeric"}`.
--             Valid names are "lower", "upper", "numeric".
--             `opts.op_len` can be pre-calculated as `#opts` for slight optimization if calling repeatedly with same opts table.
-- @return string The generated random string.
-- @usage
-- local random_alphanumeric = lib.random.string(10)
-- local random_numeric = lib.random.string(5, {"numeric"})
local function generate_random_string(length, opts)
    lib.validate.type.assert(length, "number", "Random string length")
    if opts ~= nil then lib.validate.type.assert(opts, "table", "Random string options") end

    if length <= 0 then
        return ""
    end

    opts = opts or { "lower", "upper", "numeric" }
    opts.op_len = opts.op_len or #opts -- Cache length of options table if not already done

    if opts.op_len == 0 then -- Ensure there's at least one charset to pick from
        return ""
    end

    local char_type_name = opts[math_random(1, opts.op_len)]
    local selected_charset = randomize_string_config.charset[char_type_name]

    if not selected_charset or selected_charset.len == 0 then
        -- Fallback or error if an invalid charset name is provided or charset is empty
        -- For simplicity, could pick another random one or default to one. Here, we'll just skip.
        return generate_random_string(length - 1, opts) -- Try again for this char, effectively reducing length if error
    end

    local new_char = selected_charset.chars[math_random(1, selected_charset.len)]
    return new_char .. generate_random_string(length - 1, opts)
end

--- @type table Internal configuration for UUID generation.
-- Stores character sets for different parts of the UUID.
-- @local
local uuid_config = {
    -- Chars for the 'y' part of xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx (8, 9, A, or B)
    variant_chars = { "8", "9", "a", "b" }, -- Simplified to always produce variant 1
    hex_chars = {},
}
uuid_config.variant_chars.len = #uuid_config.variant_chars

-- Populate hex_chars (0-9, a-f)
do
    for i = 0, 15 do
        table.insert(uuid_config.hex_chars, string_format("%x", i))
    end
    uuid_config.hex_chars.len = #uuid_config.hex_chars
end

--- Generates a random character for a specific position in a UUID string.
-- Adheres to UUID version 4 format.
-- @param position number The 1-based index in the 36-character UUID string.
-- @return string The random hexadecimal character or a fixed character (e.g., "-", "4").
-- @local
local function generate_uuid_char(position)
    if position == 9 or position == 14 or position == 19 or position == 24 then
        return "-"
    elseif position == 15 then
        return "4" -- Version 4 UUID
    elseif position == 20 then
        -- y (variant: 8, 9, a, or b)
        return uuid_config.variant_chars[math_random(1, uuid_config.variant_chars.len)]
    else
        -- x (any hex digit)
        return uuid_config.hex_chars[math_random(1, uuid_config.hex_chars.len)]
    end
end

--- Generates a Version 4 UUID (Universally Unique Identifier).
-- @return string A 36-character UUID string (e.g., "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx").
-- @usage local myId = lib.random.uuid()
local function generate_uuid()
    local id_parts = {}
    for i = 1, 36 do
        id_parts[i] = generate_uuid_char(i)
    end
    return table.concat(id_parts)
end

---@type RandomModule
-- @field string fun(length:number, opts?:table):string Generates a random string.
-- @field uuid fun():string Generates a Version 4 UUID.
lib_module.string = setmetatable(
    { new = generate_random_string },
    { __call = function(_, ...) return generate_random_string(...) end }
)
lib_module.uuid = setmetatable(
    { new = generate_uuid },
    { __call = function(_, ...) return generate_uuid(...) end }
)
