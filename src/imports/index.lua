--- Core library functionalities and utilities.
-- This file initializes the global `lib` table, providing a common set of functions
-- and properties for both server-side and client-side scripting. It includes event
-- handling, timers, and environment detection.
-- @module lib

--[[ Init ]]
assert(_VERSION:find("5.4"), "^1[ Please enable Lua 5.4 ]^0")

--- @type table Native functions cache.
-- @local
local native = {
    register_net_event = RegisterNetEvent,
    add_event_handler = AddEventHandler,
    remove_event_handler = RemoveEventHandler,
    trigger_event = TriggerEvent,
    trigger_server_event = TriggerServerEvent,
    trigger_client_event = TriggerClientEvent,
    is_duplicity_version = IsDuplicityVersion,
    get_invoking_resource = GetInvokingResource,
}
--- @type boolean True if the current environment is server-side.
-- @local
local is_server = native.is_duplicity_version()

--- Binds a listener to an event that will only execute once.
-- @param is_network boolean True if it's a network event, false for local.
-- @param eventname string The name of the event.
-- @param listener function The function to execute.
-- @return table The event handle.
-- @local
local function bind_once(is_network, eventname, listener)
    local event
    local fn = function(...)
        lib.off(event)
        listener(...)
    end

    event = is_network and native.register_net_event(eventname, fn) or native.add_event_handler(eventname, fn)

    return event
end

--- Registers a handler for a remote event (from the opposite service).
-- Ensures the callback is only executed for actual remote invocations.
-- @param eventName string The name of the event.
-- @param cb function The callback function.
-- @return table The event handle.
-- @local
local function on_remote(eventName, cb)
    local remote_cb = function(...)
        if not (native.get_invoking_resource()) then -- invoking resource is nil if it's a remote event
            return cb(...)
        end
    end

    return native.register_net_event(eventName, remote_cb)
end

---@field is_server boolean True if the current script is running on the server.
lib.is_server = is_server
---@field is_client boolean True if the current script is running on the client.
lib.is_client = not is_server
---@field service string "server" or "client" indicating the current service.
lib.service = is_server and "server" or "client"
---@field service_inversed string "client" or "server" indicating the opposite service.
lib.service_inversed = is_server and "client" or "server"

--- Creates a recurring timer.
-- @param handler function The function to execute at each interval.
-- @param delay number The delay in milliseconds between executions.
-- @return table A timer object.
-- @see lib.timer.new
lib.set_interval = function(handler, delay)
    return lib.timer.new(handler, delay, true)
end

--- Creates a timer that executes once after a delay.
-- @param handler function The function to execute.
-- @param delay number The delay in milliseconds before execution.
-- @return table A timer object.
-- @see lib.timer.new
lib.set_timeout = function(handler, delay)
    return lib.timer.new(handler, delay, false)
end

--- Registers a handler to be executed on every game tick.
-- @param handler function The function to execute on each tick.
-- @return table A timer object.
-- @see lib.timer.new
lib.on_tick = function(handler)
    return lib.timer.new(handler, 0, true)
end

--- Registers a handler to be executed on the next game tick.
-- @param handler function The function to execute on the next tick.
-- @return table A timer object.
-- @see lib.timer.new
lib.on_next_tick = function(handler)
    return lib.timer.new(handler, 0, false)
end

--- Registers an event handler for a local event.
-- @function lib.on
-- @param eventname string The name of the event.
-- @param listener function The function to execute when the event is triggered.
-- @return table The event handle.
lib.on = native.add_event_handler

--- Removes an event handler for a local event.
-- @function lib.off
-- @param eventname string The name of the event. (Note: LDoc typically expects the handle, but native RemoveEventHandler takes eventname)
-- @param listener function The listener function to remove.
lib.off = native.remove_event_handler

--- Triggers a local event.
-- @function lib.emit
-- @param eventname string The name of the event.
-- @param ... any Arguments to pass to the event listeners.
lib.emit = native.trigger_event

--- Triggers an event on the opposite service (client to server, or server to client).
-- Dynamically named `emit_client` on server, or `emit_server` on client.
-- @function lib.emit_client (on server) / lib.emit_server (on client)
-- @param eventname string The name of the event.
-- @param ... any Arguments to pass to the event listeners.
lib[("emit_%s"):format(lib.service_inversed)] = lib.is_server and native.trigger_client_event or native.trigger_server_event

--- Triggers a client event for all clients (server-only).
-- @function lib.emit_all_clients
-- @param eventname string The name of the event.
-- @param ... any Arguments to pass to the event listeners.
-- @return nil Returns nil if called on client.
lib.emit_all_clients = lib.is_server and function(eventname, ...) return native.trigger_client_event(eventname, -1, ...) end or nil

--- Registers an event handler that only executes once for a local event.
-- @param eventname string The name of the event.
-- @param listener function The function to execute.
-- @return table The event handle.
lib.once = function(eventname, listener) return bind_once(false, eventname, listener) end

--- Registers an event handler for an event from the opposite service.
-- Dynamically named `on_client` on server, or `on_server` on client.
-- @function lib.on_client (on server) / lib.on_server (on client)
-- @param eventname string The name of the event.
-- @param listener function The function to execute.
-- @return table The event handle.
lib[("on_%s"):format(lib.service_inversed)] = on_remote

--- Registers an event handler that only executes once for an event from the opposite service.
-- Dynamically named `once_client` on server, or `once_server` on client.
-- @function lib.once_client (on server) / lib.once_server (on client)
-- @param eventname string The name of the event.
-- @param listener function The function to execute.
-- @return table The event handle.
lib[("once_%s"):format(lib.service_inversed)] = function(eventname, listener) return bind_once(true, eventname, listener) end

--- Generates a UUID (Universally Unique Identifier).
-- @function lib.uuid
-- @return string A UUID string.
-- @see lib.random.uuid
lib.uuid = lib.random.uuid

-- common functions
--- Returns the first non-nil value from the arguments.
-- @function lib.coalesce
-- @param ... any A variable number of arguments to check.
-- @return any The first non-nil argument, or nil if all are nil.
-- @see lib.common.coalesce
lib.coalesce = lib.common.coalesce
