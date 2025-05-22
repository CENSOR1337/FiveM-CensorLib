-- Adjust package.path to allow requiring modules from 'src' directory
package.path = package.path .. ';./src/?.lua;./src/imports/components/?.lua;./src/imports/components/?/shared.lua'

-- Mock the lib table and its dependencies that math/shared.lua might use.
-- Specifically, lib.validate.type.assert is used.
_G.lib = _G.lib or {}
_G.lib.validate = _G.lib.validate or {
    type = {
        assert = function(value, ...)
            -- Simplified mock for testing purposes
            local types = {...}
            local value_type = type(value)
            local found = false
            -- The last argument to assert can be a custom message, so ignore it for type checking.
            local num_types_to_check = #types
            if type(types[#types]) == "string" and #types > 1 then -- Heuristic: if last arg is string and there's more than one type expected
                -- Check if it's a common type name, if not, it might be a message
                local common_lua_types = {string=true, number=true, boolean=true, table=true, function_type=true, nil_type=true, userdata=true, thread=true}
                if not common_lua_types[types[#types]:lower()] then
                    num_types_to_check = #types -1
                end
            end

            for i = 1, num_types_to_check do
                if value_type == types[i] then
                    found = true
                    break
                end
            end
            if not found then
                local type_list = {}
                for i=1, num_types_to_check do table.insert(type_list, types[i]) end
                error("Type validation failed: expected one of " .. table.concat(type_list, ", ") .. ", got " .. value_type)
            end
        end
    }
}

local math_ext = require("math.shared")

describe("Math Component", function()
  describe("lerp", function()
    it("should interpolate correctly for t = 0, 0.5, 1", function()
      assert.are.equal(10, math_ext.lerp(10, 20, 0))
      assert.are.equal(15, math_ext.lerp(10, 20, 0.5))
      assert.are.equal(20, math_ext.lerp(10, 20, 1))
    end)

    it("should handle negative numbers", function()
      assert.are.equal(-10, math_ext.lerp(-10, -20, 0))
      assert.are.equal(-15, math_ext.lerp(-10, -20, 0.5))
      assert.are.equal(-5, math_ext.lerp(0, -10, 0.5))
    end)

    it("should extrapolate when t is outside [0,1]", function()
      assert.are.equal(0, math_ext.lerp(10, 20, -1))
      assert.are.equal(30, math_ext.lerp(10, 20, 2))
    end)
  end)

  describe("clamp", function()
    it("should return val if within bounds", function()
      assert.are.equal(5, math_ext.clamp(5, 0, 10))
    end)

    it("should return lower bound if val is less than lower", function()
      assert.are.equal(0, math_ext.clamp(-5, 0, 10))
    end)

    it("should return upper bound if val is greater than upper", function()
      assert.are.equal(10, math_ext.clamp(15, 0, 10))
    end)

    it("should swap bounds if lower > upper", function()
      assert.are.equal(5, math_ext.clamp(5, 10, 0))
      assert.are.equal(10, math_ext.clamp(15, 10, 0)) -- val > new upper (original lower)
      assert.are.equal(0, math_ext.clamp(-5, 10, 0))  -- val < new lower (original upper)
    end)

    it("should handle bounds being equal", function()
      assert.are.equal(5, math_ext.clamp(3, 5, 5))
      assert.are.equal(5, math_ext.clamp(5, 5, 5))
      assert.are.equal(5, math_ext.clamp(7, 5, 5))
    end)
  end)

  describe("groupdigits", function()
    it("should group digits with default separator (,)", function()
      assert.are.equal("1,234,567", math_ext.groupdigits(1234567))
      assert.are.equal("123,456", math_ext.groupdigits(123456))
      assert.are.equal("12,345", math_ext.groupdigits(12345))
      assert.are.equal("1,234", math_ext.groupdigits(1234))
      assert.are.equal("123", math_ext.groupdigits(123))
    end)

    it("should handle numbers with decimals", function()
      assert.are.equal("1,234,567.89", math_ext.groupdigits(1234567.89))
      assert.are.equal("0.123", math_ext.groupdigits(0.123))
      assert.are.equal("-1,234.56", math_ext.groupdigits(-1234.56))
    end)

    it("should use custom separator", function()
      assert.are.equal("1 234 567", math_ext.groupdigits(1234567, " "))
      assert.are.equal("1.234.567", math_ext.groupdigits(1234567, "."))
    end)

    it("should handle strings with non-digits (prefix/suffix)", function()
      assert.are.equal("$1,234.56", math_ext.groupdigits("$1234.56"))
      assert.are.equal("€1,234,567.89 EUR", math_ext.groupdigits("€1234567.89 EUR"))
      assert.are.equal("Value: 123", math_ext.groupdigits("Value: 123"))
    end)
    
    it("should handle numbers as strings", function()
      assert.are.equal("1,234,567", math_ext.groupdigits("1234567"))
    end)

    it("should return original string if no digits found after potential prefix", function()
        assert.are.equal("abc", math_ext.groupdigits("abc"))
        assert.are.equal("$abc", math_ext.groupdigits("$abc"))
    end)
  end)

  describe("round", function()
    it("should round to 0 decimal places by default or if places is 0/nil/negative", function()
      assert.are.equal(3, math_ext.round(3.14159))
      assert.are.equal(4, math_ext.round(3.7))
      assert.are.equal(3, math_ext.round(3.14159, 0))
      assert.are.equal(4, math_ext.round(3.5)) -- .5 rounds up
      assert.are.equal(3, math_ext.round(3, nil))
      assert.are.equal(3, math_ext.round(3.14, -1))
    end)

    it("should round to specified positive decimal places", function()
      assert.are.equal(3.14, math_ext.round(3.14159, 2))
      assert.are.equal(3.142, math_ext.round(3.14159, 3))
      assert.are.equal(10.57, math_ext.round(10.5678, 2))
      assert.are.equal(0.33, math_ext.round(0.33333, 2))
    end)

    it("should handle .5 values correctly (rounds up at the rounding position)", function()
      assert.are.equal(4, math_ext.round(3.5, 0))
      assert.are.equal(3.15, math_ext.round(3.145, 2))
      assert.are.equal(3.1, math_ext.round(3.05, 1))
      assert.are.equal(3.2, math_ext.round(3.15, 1))
    end)

    it("should handle negative numbers correctly", function()
      assert.are.equal(-3, math_ext.round(-3.14159))
      assert.are.equal(-4, math_ext.round(-3.7))
      assert.are.equal(-3, math_ext.round(-3.5)) -- -3.5 rounds to -3 (based on floor(x+0.5))
      assert.are.equal(-3.14, math_ext.round(-3.14159, 2))
      assert.are.equal(-3.14, math_ext.round(-3.145, 2)) -- Actual: -3.14, due to floor(x+0.5) logic
    end)

    it("should handle string inputs that are valid numbers", function()
      assert.are.equal(3, math_ext.round("3.14"))
      assert.are.equal(3.14, math_ext.round("3.14159", "2"))
    end)

    it("should error on non-numeric string value after tonumber fails", function()
      assert.has_error(function() math_ext.round("not a number") end, "math.round: If value is a string, it must be convertible to a number")
    end)
    
    it("should error on non-numeric places string after tonumber fails", function()
      assert.has_error(function() math_ext.round(3.14, "not a place") end, "math.round: If places is a string, it must be convertible to a number")
    end)

    -- The lib.validate.type.assert mock will catch these if tonumber conversion doesn't error first.
    it("should error with type validation for non-convertible value", function()
        assert.has_error(function() math_ext.round(true) end, "Type validation failed: expected one of number, got boolean")
    end)

    it("should error with type validation for non-convertible places", function()
        assert.has_error(function() math_ext.round(3.14, {}) end, "Type validation failed: expected one of number, got table")
    end)
  end)
end)
