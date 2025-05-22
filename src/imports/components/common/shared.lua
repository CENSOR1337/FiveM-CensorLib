--- Provides common utility functions shared across the library.
-- This module contains miscellaneous helper functions that are broadly applicable.
-- @module common

--- Returns the first non-nil value from a list of arguments.
-- This function iterates through the provided arguments from left to right
-- and returns the first argument that is not `nil`. If all arguments are `nil`,
-- it returns `nil`.
-- @param ... any A variable number of arguments to check.
-- @return any The first non-nil argument encountered, or `nil` if all arguments are `nil`.
-- @usage
-- local name = lib.common.coalesce(nil, "Default Name", "Another Name")
-- print(name) -- Output: Default Name
--
-- local setting = lib.common.coalesce(user_preference, global_default, fallback_value)
local function coalesce(...)
    local params = { ... }
    local return_value = nil

    for i = 1, #params, 1 do
        local value = params[i]
        if (value ~= nil) then
            return_value = value
            break -- Found the first non-nil value
        end
    end

    return return_value
end

return {
    coalesce = coalesce,
}
