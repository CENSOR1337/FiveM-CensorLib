--- Provides utilities for interacting with FiveM resources, including the current resource
-- and other specified resources. It offers an object-oriented way to handle
-- resource-specific events (local, client-server, server-client) and callbacks,
-- automatically prefixing event names with the resource name.
-- @module resource

--- @type table Cache of native FiveM functions.
-- @local
local native = {
    get_current_resource_name = GetCurrentResourceName,
    get_resource_state = GetResourceState,
}

--- @type table Standard event names for resource lifecycle events.
-- @local
local eventnames = {
    on_resource_start = "onResourceStart", -- Name of the FiveM event when a resource starts
    on_resource_stop = "onResourceStop",   -- Name of the FiveM event when a resource stops
}

--- @class ResourceObject Represents a specific FiveM resource, providing methods
-- for event handling and callbacks scoped to that resource.
-- Event names used with this object's methods are automatically prefixed with `resource_name:`.
-- @field name string The name of the resource this object represents.
-- @field callback table A specialized callback interface for this resource.
--   Allows registering and triggering `lib.callback` events prefixed with the resource name.
local resource_prototype = {}
resource_prototype.__index = resource_prototype

--- Creates a new ResourceObject instance for a given resource name.
-- This constructor is typically used internally by the module when accessing
-- `lib.resource.resource_name`.
-- @param resource_name string The name of the resource.
-- @return ResourceObject A new ResourceObject instance.
-- @nodoc (Not typically called directly by users, accessed via `lib.resource.resourceName`)
function resource_prototype.new(resource_name)
    lib.validate.type.assert(resource_name, "string", "Resource name")
    local self = setmetatable({}, resource_prototype)
    self.name = resource_name

    -- Create a resource-specific callback interface
    self.callback = setmetatable({
        --- Registers a lib.callback handler, automatically prefixing the event name.
        -- @param eventname string The event name (will be prefixed).
        -- @param ... any Arguments to pass to `lib.callback.register`.
        -- @return any Return value from `lib.callback.register`.
        register = function(eventname_unprefixed, ...)
            return lib.callback.register(self:prefix(eventname_unprefixed), ...)
        end,
    }, {
        -- Allows calling self.callback("eventName", ...) to trigger a lib.callback
        __call = function(_, eventname_unprefixed, ...)
            return lib.callback(self:prefix(eventname_unprefixed), ...)
        end,
    })

    -- This complex metatable setup allows methods of ResourceObject to be called
    -- directly on the object (e.g., `myResourceInstance:on(...)`)
    -- or via the main module proxy (e.g., `lib.resource.myResourceName:on(...)`).
    -- The proxy part is handled by lib_module's __index. This metatable here
    -- is primarily for the ResourceObject instances themselves.
    -- The original code had a more intricate __index here, which seemed overly complex
    -- if methods are defined directly on resource_prototype. Simplified for clarity.
    return self
end

--- Prefixes a given event name (or any number of strings) with the resource's name.
-- Example: if resource name is "myResource" and eventname is "myEvent", returns "myResource:myEvent".
-- @param ... string One or more string parts to be joined by ":" after the resource name.
-- @return string The prefixed event name.
-- @usage local prefixedName = myResource:prefix("customEvent", "subEvent") -- "resourceName:customEvent:subEvent"
function resource_prototype:prefix(...)
    local args = { ... }
    table.insert(args, 1, self.name)
    return table.concat(args, ":")
end

--- Registers a local event handler, automatically prefixing the event name with the resource name.
-- @param eventname string The event name (will be prefixed).
-- @param callback function The callback function for the event.
-- @return table The event handle from `lib.on`.
function resource_prototype:on(eventname, callback)
    return lib.on(self:prefix(eventname), callback)
end

--- Registers a one-time local event handler, automatically prefixing the event name.
-- @param eventname string The event name (will be prefixed).
-- @param callback function The callback function.
-- @return table The event handle from `lib.once`.
function resource_prototype:once(eventname, callback)
    return lib.once(self:prefix(eventname), callback)
end

--- Emits a local event, automatically prefixing the event name.
-- @param eventname string The event name (will be prefixed).
-- @param ... any Arguments to pass to the event listeners.
-- @return any Return value from `lib.emit`.
function resource_prototype:emit(eventname, ...)
    return lib.emit(self:prefix(eventname), ...)
end

-- Server-specific methods
if lib.is_server then
    --- (Server-only) Emits an event to a specific client, automatically prefixing the event name.
    -- @param eventname string The event name (will be prefixed).
    -- @param client string|number The target client's source ID.
    -- @param ... any Arguments to pass to the client event.
    -- @return any Return value from `lib.emit_client`.
    function resource_prototype:emit_client(eventname, client, ...)
        return lib.emit_client(self:prefix(eventname), client, ...)
    end

    --- (Server-only) Emits an event to all clients, automatically prefixing the event name.
    -- @param eventname string The event name (will be prefixed).
    -- @param ... any Arguments to pass to the client event.
    -- @return any Return value from `lib.emit_all_clients`.
    function resource_prototype:emit_all_clients(eventname, ...)
        return lib.emit_all_clients(self:prefix(eventname), ...)
    end

    --- (Server-only) Registers a handler for an event from any client, automatically prefixing the event name.
    -- @param eventname string The event name (will be prefixed).
    -- @param callback function The callback function.
    -- @return table The event handle from `lib.on_client`.
    function resource_prototype:on_client(eventname, callback)
        return lib.on_client(self:prefix(eventname), callback)
    end

    --- (Server-only) Registers a one-time handler for an event from any client, automatically prefixing.
    -- @param eventname string The event name (will be prefixed).
    -- @param callback function The callback function.
    -- @return table The event handle from `lib.once_client`.
    function resource_prototype:once_client(eventname, callback)
        return lib.once_client(self:prefix(eventname), callback)
    end
else -- Client-specific methods
    --- (Client-only) Emits an event to the server, automatically prefixing the event name.
    -- @param eventname string The event name (will be prefixed).
    -- @param ... any Arguments to pass to the server event.
    -- @return any Return value from `lib.emit_server`.
    function resource_prototype:emit_server(eventname, ...)
        return lib.emit_server(self:prefix(eventname), ...)
    end

    --- (Client-only) Registers a handler for an event from the server, automatically prefixing.
    -- @param eventname string The event name (will be prefixed).
    -- @param callback function The callback function.
    -- @return table The event handle from `lib.on_server`.
    function resource_prototype:on_server(eventname, callback)
        return lib.on_server(self:prefix(eventname), callback)
    end

    --- (Client-only) Registers a one-time handler for an event from the server, automatically prefixing.
    -- @param eventname string The event name (will be prefixed).
    -- @param callback function The callback function.
    -- @return table The event handle from `lib.once_server`.
    function resource_prototype:once_server(eventname, callback)
        return lib.once_server(self:prefix(eventname), callback)
    end
end

--- Registers a callback to be executed when this specific resource starts.
-- @param callback function The function to call when this resource starts.
-- @return table The event handle from `lib.on`.
-- @usage
-- lib.resource.myResourceName:on_start(function()
--   print("myResourceName has started!")
-- end)
-- -- For the current resource:
-- lib.resource:on_start(function() print("This resource started!") end)
function resource_prototype:on_start(callback)
    lib.validate.type.assert(callback, "function", "on_start callback")
    return lib.on(eventnames.on_resource_start, function(starting_resource_name)
        if self.name == starting_resource_name then
            callback()
        end
    end)
end

--- Registers a callback to be executed when this specific resource stops.
-- @param callback function The function to call when this resource stops.
-- @return table The event handle from `lib.on`.
-- @usage
-- lib.resource.myResourceName:on_stop(function()
--   print("myResourceName is stopping!")
-- end)
-- -- For the current resource:
-- lib.resource:on_stop(function() print("This resource is stopping!") end)
function resource_prototype:on_stop(callback)
    lib.validate.type.assert(callback, "function", "on_stop callback")
    return lib.on(eventnames.on_resource_stop, function(stopping_resource_name)
        if self.name == stopping_resource_name then
            callback()
        end
    end)
end

--- @type table Stores cached ResourceObject instances, keyed by resource name.
-- @local
local instances = {}

-- Create an instance for the current resource immediately.
local current_resource_name = native.get_current_resource_name()
instances[current_resource_name] = resource_prototype.new(current_resource_name)
local self_instance = instances[current_resource_name] -- This is the ResourceObject for the current resource.

--- Main module export for resource interactions.
-- Accessing `lib.resource.someResourceName` will return a `ResourceObject` for "someResourceName".
-- If `someResourceName` is not a known method of the current resource's `ResourceObject`
-- and corresponds to a running resource, a new `ResourceObject` for it is created and returned.
-- Calling methods directly on `lib.resource` (e.g., `lib.resource:on_start(...)`)
-- operates on the current resource context.
-- @type ResourceModuleProxy
-- @usage
-- -- Interact with the current resource
-- lib.resource:on_start(function() print("Current resource started") end)
-- lib.resource:emit("myLocalEvent", 123)
--
-- -- Interact with another resource named "otherScript"
-- local otherScript = lib.resource.otherScript
-- if otherScript then -- Check if resource exists/is accessible
--   otherScript:emit_client("someEventForOtherScript", targetPlayer, "data")
-- end
lib_module = setmetatable({}, {
    __index = function(t, field_name)
        -- Prioritize methods of the current resource's ResourceObject instance
        if self_instance[field_name] and type(self_instance[field_name]) == "function" then
            return function(...) -- Return a wrapper to call the method on self_instance
                return self_instance[field_name](self_instance, ...)
            end
        end
        -- If the field_name is the name of the current resource, return its instance
        if field_name == current_resource_name then
            return self_instance
        end

        -- Check if field_name corresponds to another resource's state
        local resource_state = native.get_resource_state(field_name)
        if resource_state ~= "missing" and resource_state ~= "unknown" then -- "started", "stopped", etc.
            if not instances[field_name] then
                instances[field_name] = resource_prototype.new(field_name)
            end
            return instances[field_name]
        end

        -- If it's not a method of self_instance and not another resource, error.
        -- (The original code would error here, which is reasonable)
        error(("Cannot find a method or resource named \"%s\". Current resource is \"%s\"."):format(field_name, current_resource_name), 2)
    end,
})
