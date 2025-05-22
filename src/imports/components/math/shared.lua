--- Provides a collection of mathematical utility functions.
-- These functions extend the standard Lua `math` library with common operations
-- like linear interpolation, clamping, number formatting, and rounding.
-- @module math

-- Retain the original local math = math to ensure standard math functions are accessible
-- if this module is ever run in an environment where 'math' isn't a global or needs extension.
local math_ext = {} -- Use a new table for our extensions to avoid modifying global math table directly

--- Linearly interpolates between two values.
-- Calculates a value between `a` and `b` based on the interpolation factor `t`.
-- @param a number The starting value.
-- @param b number The ending value.
-- @param t number The interpolation factor (usually between 0.0 and 1.0).
--               If `t` is 0, returns `a`. If `t` is 1, returns `b`.
-- @return number The interpolated value.
-- @usage local mid_point = lib.math.lerp(10, 20, 0.5) -- Result: 15
function math_ext.lerp(a, b, t)
    lib.validate.type.assert(a, "number", "math.lerp 'a'")
    lib.validate.type.assert(b, "number", "math.lerp 'b'")
    lib.validate.type.assert(t, "number", "math.lerp 't'")
    return a + (b - a) * t
end

--- Clamps a value between a lower and upper bound.
-- If `val` is less than `lower`, `lower` is returned. If `val` is greater than `upper`, `upper` is returned.
-- Otherwise, `val` is returned. The function automatically swaps `lower` and `upper` if they are in the wrong order.
-- @param val number The value to clamp.
-- @param lower number The lower bound.
-- @param upper number The upper bound.
-- @return number The clamped value.
-- @usage
-- local clamped_val = lib.math.clamp(15, 0, 10) -- Result: 10
-- local another_val = lib.math.clamp(5, 0, 10)  -- Result: 5
function math_ext.clamp(val, lower, upper)
    lib.validate.type.assert(val, "number", "math.clamp 'val'")
    lib.validate.type.assert(lower, "number", "math.clamp 'lower'")
    lib.validate.type.assert(upper, "number", "math.clamp 'upper'")
    if lower > upper then lower, upper = upper, lower end -- Swap if boundaries supplied the wrong way
    return math.max(lower, math.min(upper, val)) -- Standard math.max/min are fine here
end

--- Formats a number by grouping digits with a separator.
-- For example, converts `1234567` to `"1,234,567"`.
-- Credit: overextended (http://richard.warburton.it)
-- @param number number|string The number to format. If a string, it's converted to a number first if possible.
-- @param separator string (Optional) The separator to use for grouping. Defaults to ",".
-- @return string The formatted number string.
-- @usage
-- local formatted = lib.math.groupdigits(1234567.89) -- Result: "1,234,567.89"
-- local custom_sep = lib.math.groupdigits(10000, " ") -- Result: "10 000"
function math_ext.groupdigits(number, separator)
    lib.validate.type.assert(number, "number", "string", "math.groupdigits 'number'")
    if separator ~= nil then lib.validate.type.assert(separator, "string", "math.groupdigits 'separator'") end

    local num_str = tostring(number)
    local left, num_part, right = string.match(num_str, "^([^%d]*%d)(%d*)(.-)$")
    -- If the number doesn't match the expected pattern (e.g., it's just ".5" or non-numeric after prefix)
    if not left then return num_str end

    return left .. (num_part:reverse():gsub("(%d%d%d)", "%1" .. (separator or ",")):reverse()) .. right
end

--- Rounds a number to a specified number of decimal places.
-- If `places` is not provided or is 0, rounds to the nearest integer.
-- If `places` is positive, rounds to that many decimal places.
-- Credit: overextended
-- @param value number|string The number to round. If a string, it's converted to a number first.
-- @param places number (Optional) The number of decimal places to round to.
--                 If positive, rounds to this many decimal places.
--                 If zero or negative or nil, rounds to the nearest integer.
-- @return number The rounded number.
-- @usage
-- local rounded_int = lib.math.round(3.14159)      -- Result: 3
-- local rounded_dec = lib.math.round(3.14159, 2)  -- Result: 3.14
-- local rounded_up  = lib.math.round(3.7)         -- Result: 4
function math_ext.round(value, places)
    if type(value) == "string" then
        local num = tonumber(value)
        assert(num ~= nil, "math.round: If value is a string, it must be convertible to a number")
        value = num
    end
    lib.validate.type.assert(value, "number", "math.round 'value'")

    if places ~= nil then
        if type(places) == "string" then
            local num_places = tonumber(places)
            assert(num_places ~= nil, "math.round: If places is a string, it must be convertible to a number")
            places = num_places
        end
        lib.validate.type.assert(places, "number", "math.round 'places'")

        if places > 0 then
            local mult = 10 ^ places
            return math.floor(value * mult + 0.5) / mult
        end
    end
    -- Rounds to nearest integer if places is nil, 0, or negative
    return math.floor(value + 0.5)
end

-- Assign the extended functions to lib_module.
-- This ensures that they are accessed via lib.math.lerp, etc.
-- and avoids modifying the global 'math' table or causing conflicts
-- with LDoc's interpretation of 'math' as the standard Lua library.
return math_ext
