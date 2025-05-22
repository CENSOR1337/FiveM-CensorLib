--- Provides data validation utilities, primarily focused on type checking.
-- This module allows checking if a value matches one or more expected Lua types.
-- It can be used to either get a boolean result of the validation or to directly
-- assert the validation, causing an error if it fails.
-- @module validate

local lua_assert = assert -- Local alias for Lua's assert function.
local validate_methods = {} -- Internal table to store validation methods.

--- Checks if the type of a given value matches one of the specified expected types.
-- @param value any The value to check.
-- @param ... string One or more strings representing the expected Lua type(s)
--                 (e.g., "string", "number", "table", "function", "boolean", "nil", "userdata", "thread").
-- @return boolean True if the value's type matches at least one of the expected types.
-- @return string|nil An error message if validation fails (value's type does not match any expected type),
--                    otherwise nil. If no types are provided to check against, returns true.
-- @usage
-- local isValid, errMsg = lib.validate.type(myVar, "string", "number")
-- if not isValid then print(errMsg) end
--
-- local isTable = lib.validate.type({}, "table") -- true
function validate_methods.type(value, ...)
    local expected_types = { ... }
    if #expected_types == 0 then
        -- No types specified to validate against; consider it trivially valid.
        return true
    end

    local allowed_types_map = {}
    for i = 1, #expected_types do
        local validate_type_str = expected_types[i]
        -- Internal assertion: ensure the type strings themselves are valid.
        lua_assert(type(validate_type_str) == "string", "Validate type names must be strings.")
        allowed_types_map[validate_type_str] = true
    end

    local value_actual_type = type(value)
    local matches_expected_type = (allowed_types_map[value_actual_type] == true)

    if not matches_expected_type then
        local required_types_str = table.concat(expected_types, " or ")
        local error_message = ("Validation failed: Expected type(s) '%s', but got '%s'."):format(required_types_str, value_actual_type)
        return false, error_message
    end

    return true
end

---@class ValidateMethodInterface
-- This represents a validation method (like `type`) that can be called directly
-- to get a boolean result, or can have `.assert(...)` called on it.
-- @field assert fun(...) Asserts that the validation passes, errors if not.

---@type ValidateModule
-- Provides access to validation methods. Each method (e.g., `lib.validate.type`)
-- can be called directly for a boolean result or via its `.assert` property
-- (e.g., `lib.validate.type.assert(...)`) to error on failure.
-- @usage
-- -- Direct call for boolean result:
-- local isStr, errMsg = lib.validate.type("hello", "string")
-- if isStr then print("It's a string!") end
--
-- -- Assert call (errors if not a number):
-- lib.validate.type.assert(123, "number", "Input must be a number for this operation.")
-- -- The third argument to .assert is an optional custom message part for the error.
lib_module = setmetatable({}, {
    __index = function(_, method_name)
        local actual_method = validate_methods[method_name]
        lua_assert(actual_method, ("Validation method 'validate.%s' not found."):format(method_name))

        -- Create a callable table for the specific method (e.g., lib.validate.type)
        return setmetatable({}, {
            -- Allows calling lib.validate.type(...)
            __call = function(_, ...)
                return actual_method(...)
            end,
            -- Allows accessing lib.validate.type.assert
            __index = function(self_callable_method_table, key)
                if key == "assert" then
                    return function(value_to_validate, ...)
                        -- The varargs here are first the expected types, then optionally a custom error message part.
                        local expected_types_and_custom_msg = { ... }
                        local custom_error_message_suffix = ""

                        -- Check if the last argument is intended as a custom message part.
                        -- This is a heuristic: if more args are given to .assert than .type would normally take for types.
                        -- A more robust way would be to define how many type args .type takes, or expect custom message
                        -- as a specific parameter. For now, assume any "extra" string might be a custom message.
                        -- This part is tricky because `validate.type` itself takes `...` for types.
                        -- Let's assume the `actual_method` (e.g. validate.type) is called with all args passed to .assert
                        -- and it correctly separates its own concerns. The error message from it will be used.

                        local result, error_message_from_method = actual_method(value_to_validate, ...)
                        -- The original code for .assert took varargs and passed them all to the method.
                        -- If a custom message is desired for assert, it's usually an *additional* parameter.
                        -- The error_message from the method is usually quite good.
                        -- For this implementation, we'll use the error_message from the method directly.
                        -- If you want to allow an *additional* custom message for assert:
                        -- local args_for_method = {...}
                        -- local custom_msg_for_assert
                        -- if #args_for_method > count_of_expected_types_for_method then
                        --    custom_msg_for_assert = table.remove(args_for_method)
                        -- end
                        -- local result, error_message_from_method = actual_method(value_to_validate, table.unpack(args_for_method))
                        -- lua_assert(result, custom_msg_for_assert or error_message_from_method)

                        lua_assert(result, error_message_from_method)
                    end
                end
                return nil
            end,
        })
    end,
})
