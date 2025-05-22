--- Provides a leveled and formatted printing utility for the console.
-- This module extends standard printing by adding severity levels (ERROR, WARN, INFO, VERBOSE, DEBUG),
-- automatic prefixing with the resource name and severity, and JSON encoding for table arguments.
-- The active print level can be controlled by a convar `resource_name:print_level`.
-- Inspired by and courtesy of the overextended team.
-- @module print

--- @type table Maps print level names to numeric severity.
-- Lower numbers indicate higher severity.
-- @local
local prefix_levels = {
    error = 1,
    warn = 2,
    info = 3,
    verbose = 4,
    debug = 5,
}

--- @type table Stores formatted string prefixes for each print level, including color codes.
-- Indexed by the numeric severity from `prefix_levels`.
-- @local
local prefixes_str = {
    "^1[ERROR]",   -- Red
    "^3[WARN]",    -- Yellow
    "^7[INFO]",    -- White
    "^4[VERBOSE]", -- Blueish/Grayish (depends on console color scheme for ^4)
    "^6[DEBUG]",   -- Magenta/Pink
}

--- Custom handler for JSON encoding exceptions, particularly for functions.
-- If a function is encountered during JSON encoding, its string representation is returned.
-- @param reason string The reason for the exception (not directly used here).
-- @param value any The value that caused the exception.
-- @return string String representation of the value (especially for functions) or the original reason.
-- @local
local function handle_json_exception(reason, value)
    if type(value) == "function" then return tostring(value) end
    return reason -- For other unhandled types, return the original error reason
end

--- @type table Options for `json.encode` to ensure consistent and readable table output.
-- Includes sorted keys, indentation, and the custom exception handler.
-- @local
local json_opts = { sort_keys = true, indent = true, exception = handle_json_exception }

--- @type number The current active print level, determined by the convar. Default is 3 (INFO).
-- Messages with a severity level numerically higher than this will not be printed.
-- @local
local print_level = prefix_levels.info -- Default to INFO level

--- @type string The name of the convar used to control the print level.
-- Formatted as "resource_name:print_level".
-- @local
local convar_key = ("%s:print_level"):format(lib.resource.name)

--- Updates the `print_level` based on the current value of the convar.
-- This function is called initially and whenever the convar changes.
-- @local
local function update_print_level_from_convar()
    local convar_value_str = GetConvar(convar_key, "info")
    print_level = prefix_levels[convar_value_str:lower()] or prefix_levels.info -- Default to INFO if invalid
end

-- Initialize print_level and set up a listener for convar changes.
update_print_level_from_convar()
AddConvarChangeListener(convar_key, update_print_level_from_convar)

--- @type string Template for formatting print messages.
-- Includes resource name prefix, severity prefix placeholder, and message placeholder.
-- Color codes: ^5 for resource name, ^7 for message body.
-- @local
local print_template = ("^5[%s] %%s %%s^7"):format(lib.resource.name)

--- Core printing function that handles formatting, JSON encoding, and level checking.
-- @param in_level number The numeric severity level of the message.
-- @param ... any The arguments to print. Tables are JSON encoded. Other types are converted to strings.
-- @local
local function lib_print(in_level, ...)
    if in_level > print_level then return end -- Only print if message level is important enough

    local in_args = { ... }
    local processed_args = {}

    for i = 1, #in_args do
        local arg = in_args[i]
        if type(arg) == "table" then
            processed_args[i] = json.encode(arg, json_opts)
        else
            processed_args[i] = tostring(arg)
        end
    end

    -- Format: [ResourceName] [LEVEL_PREFIX] arg1  arg2  arg3...
    print(print_template:format(prefixes_str[in_level], table.concat(processed_args, "\t")))
end

--- Prints an ERROR level message. Severity 1.
-- Messages are prefixed with `[resource_name] [ERROR]`. Color: Red.
-- @param ... any Arguments to print. Tables are JSON encoded.
-- @usage lib.print.error("Critical failure in system:", { component = "X" })
lib_module.error = function(...) lib_print(prefix_levels.error, ...) end

--- Prints a WARN level message. Severity 2.
-- Messages are prefixed with `[resource_name] [WARN]`. Color: Yellow.
-- @param ... any Arguments to print. Tables are JSON encoded.
-- @usage lib.print.warn("Potential issue detected.", "Check logs.")
lib_module.warn = function(...) lib_print(prefix_levels.warn, ...) end

--- Prints an INFO level message. Severity 3. (Default level)
-- Messages are prefixed with `[resource_name] [INFO]`. Color: White.
-- @param ... any Arguments to print. Tables are JSON encoded.
-- @usage lib.print.info("User", userId, "connected.")
lib_module.info = function(...) lib_print(prefix_levels.info, ...) end

--- Prints a VERBOSE level message. Severity 4.
-- Messages are prefixed with `[resource_name] [VERBOSE]`. Color: Blueish/Grayish.
-- Only shown if `print_level` convar is set to "verbose" or "debug".
-- @param ... any Arguments to print. Tables are JSON encoded.
-- @usage lib.print.verbose("Step", i, "completed with data:", data_table)
lib_module.verbose = function(...) lib_print(prefix_levels.verbose, ...) end

--- Prints a DEBUG level message. Severity 5.
-- Messages are prefixed with `[resource_name] [DEBUG]`. Color: Magenta/Pink.
-- Only shown if `print_level` convar is set to "debug".
-- @param ... any Arguments to print. Tables are JSON encoded.
-- @usage lib.print.debug("Current state:", { x = 10, y = 20 })
lib_module.debug = function(...) lib_print(prefix_levels.debug, ...) end
