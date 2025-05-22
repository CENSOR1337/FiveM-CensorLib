-- Adjust package.path to allow requiring modules from 'src' directory
-- This assumes busted is run from the project root.
package.path = package.path .. ';./src/?.lua;./src/imports/components/?.lua;./src/imports/components/?/shared.lua'

-- Mock the lib table and its dependencies that common/shared.lua might use, if any.
-- For common.lua, it doesn't seem to have direct 'lib' dependencies in its functions.
_G.lib = _G.lib or {}
_G.lib.validate = _G.lib.validate or {
    type = {
        assert = function(value, ...)
            -- Simplified mock for testing purposes
            local types = {...}
            local value_type = type(value)
            local found = false
            for _, t in ipairs(types) do
                if value_type == t then
                    found = true
                    break
                end
            end
            if not found then
                error("Type validation failed: expected one of " .. table.concat(types, ", ") .. ", got " .. value_type)
            end
        end
    }
}


local common = require("common.shared") -- Path relative to src/imports/components/

describe("Common Component", function()
  describe("coalesce", function()
    it("should return the first non-nil value", function()
      assert.are.equal(1, common.coalesce(nil, 1, 2))
      assert.are.equal("hello", common.coalesce(nil, nil, "hello", "world"))
      assert.is_true(common.coalesce(nil, true, false))
      assert.is_false(common.coalesce(false, true))
    end)

    it("should return nil if all values are nil", function()
      assert.is_nil(common.coalesce(nil, nil, nil))
    end)

    it("should return nil if no arguments are provided", function()
      assert.is_nil(common.coalesce())
    end)

    it("should handle a mix of types", function()
      local t = {}
      assert.are.equal(123, common.coalesce(nil, 123, "string"))
      assert.are.equal("string", common.coalesce(nil, "string", 123))
      assert.are.same(t, common.coalesce(nil, t, false))
    end)

    it("should return the first value if it's not nil", function()
      assert.are.equal(1, common.coalesce(1, 2, 3))
      assert.are.equal("first", common.coalesce("first", nil, "third"))
    end)
  end)
end)
