--- Provides utilities for creating and converting color representations.
-- This module allows creation of color objects from RGBA, RGB, or HEX values,
-- and conversion of these objects to different formats.
-- @module color

--- @class ColorObject Represents a color with R, G, B, and Alpha components.
-- Color component values are clamped between 0 and 255.
-- @field r number The red component (0-255).
-- @field g number The green component (0-255).
-- @field b number The blue component (0-255).
-- @field a number The alpha component (0-255).
-- @usage
-- local myColor = lib.color.rgb(255, 128, 0)
-- print(myColor:hex()) -- Outputs "FF8000"
-- local transparentRed = lib.color.hex("#FF00007F")
-- local r, g, b, a = transparentRed:rgba() -- unpacks to table
-- print(a) -- Outputs 127

local color_prototype = {}
color_prototype.__index = color_prototype

--- Clamps a color component value to the range 0-255 and floors it.
-- @param value number The color component value.
-- @return number The clamped and floored integer value.
-- @local
local function clamp_color_value(value)
    return math.max(0, math.min(255, math.floor(value)))
end

--- Returns the RGB components of the color.
-- @return table A table with `r`, `g`, `b` keys.
-- @usage local components = myColor:rgb() print(components.r)
function color_prototype:rgb()
    return { r = self.r, g = self.g, b = self.b }
end

--- Returns the RGBA components of the color.
-- @return table A table with `r`, `g`, `b`, `a` keys.
-- @usage local components = myColor:rgba() print(components.a)
function color_prototype:rgba()
    return { r = self.r, g = self.g, b = self.b, a = self.a }
end

--- Converts the color to a HEX string.
-- If alpha is 255 (fully opaque), the format is RRGGBB.
-- Otherwise, the format is RRGGBBAA.
-- @return string The HEX representation of the color.
-- @usage local hexString = myColor:hex()
function color_prototype:hex()
    if (self.a == 255) then
        return string.format("%02X%02X%02X", self.r, self.g, self.b)
    end

    return string.format("%02X%02X%02X%02X", self.r, self.g, self.b, self.a)
end

--- Creates a new ColorObject from RGBA values.
-- @param r number The red component (0-255).
-- @param g number The green component (0-255).
-- @param b number The blue component (0-255).
-- @param a number The alpha component (0-255), defaults to 255 if nil.
-- @return ColorObject A new color object.
-- @see lib.color.rgb
-- @see lib.color.hex
-- @usage local myColor = lib.color.rgba(255, 0, 0, 128) -- semi-transparent red
function color_prototype.from_rgba(r, g, b, a)
    lib.validate.type.assert(r, "number", "color.from_rgba: r")
    lib.validate.type.assert(g, "number", "color.from_rgba: g")
    lib.validate.type.assert(b, "number", "color.from_rgba: b")
    -- Allow 'a' to be nil for default, then assert if not nil
    if a ~= nil then
        lib.validate.type.assert(a, "number", "color.from_rgba: a")
    end

    local new_color_instance = {}
    new_color_instance.r = clamp_color_value(r)
    new_color_instance.g = clamp_color_value(g)
    new_color_instance.b = clamp_color_value(b)
    new_color_instance.a = clamp_color_value(a or 255)

    -- The metatable should point to the color_prototype for methods.
    -- The __index in the metatable for an instance should refer to the prototype.
    return setmetatable(new_color_instance, color_prototype)
end

--- Creates a new ColorObject from RGB values (alpha defaults to 255).
-- @param r number The red component (0-255).
-- @param g number The green component (0-255).
-- @param b number The blue component (0-255).
-- @return ColorObject A new color object.
-- @see lib.color.rgba
-- @see lib.color.hex
-- @usage local myColor = lib.color.rgb(0, 255, 0) -- opaque green
function color_prototype.from_rgb(r, g, b)
    return color_prototype.from_rgba(r, g, b, 255)
end

--- Creates a new ColorObject from a HEX string.
-- Supports formats like "#RRGGBB", "RRGGBB", "#RRGGBBAA", or "RRGGBBAA".
-- @param hex string The HEX color string.
-- @return ColorObject A new color object.
-- @see lib.color.rgba
-- @see lib.color.rgb
-- @usage
-- local red = lib.color.hex("#FF0000")
-- local transparentGreen = lib.color.hex("00FF007F")
function color_prototype.from_hex(hex)
    lib.validate.type.assert(hex, "string", "color.from_hex: hex")

    hex = hex:gsub("#", ""):upper()

    assert(#hex == 6 or #hex == 8, "Invalid hex color format. Must be RRGGBB or RRGGBBAA (length " .. #hex .. ")")

    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    local a = #hex == 8 and tonumber(hex:sub(7, 8), 16) or 255

    assert(r and g and b and a, "Invalid hex color values in string: " .. hex)

    return color_prototype.from_rgba(r, g, b, a)
end

-- Assign static factory functions to the lib_module
lib_module.rgba = color_prototype.from_rgba
lib_module.rgb = color_prototype.from_rgb
lib_module.hex = color_prototype.from_hex
-- To allow ColorObject instances to call methods like myColor:hex()
-- we need to ensure that the metatable of instances correctly points to color_prototype.
-- The current color.from_rgba already does this.
-- The global `color` table is not directly used for instances in the new structure.
-- The `lib_module` itself acts as the entry point for factory functions.
