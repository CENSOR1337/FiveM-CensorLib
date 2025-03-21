--[[ Init ]]
assert(_VERSION:find("5.4"), "^1[ Please enable Lua 5.4 ]^0")

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
local is_server = native.is_duplicity_version()

local function bind_once(is_network, eventname, listener)
    local event
    local fn = function(...)
        lib.off(event)
        listener(...)
    end

    event = is_network and native.register_net_event(eventname, fn) or native.add_event_handler(eventname, fn)

    return event
end

local function on_remote(eventName, cb)
    local remote_cb = function(...)
        if not (native.get_invoking_resource()) then -- invoking resource is nil if it's a remote event
            return cb(...)
        end
    end

    return native.register_net_event(eventName, remote_cb)
end

lib.is_server = is_server
lib.is_client = not is_server
lib.service = is_server and "server" or "client"
lib.service_inversed = is_server and "client" or "server"

lib.set_interval = function(handler, delay)
    return lib.timer.new(handler, delay, true)
end

lib.set_timeout = function(handler, delay)
    return lib.timer.new(handler, delay, false)
end

lib.on_tick = function(handler)
    return lib.timer.new(handler, 0, true)
end

lib.on_next_tick = function(handler)
    return lib.timer.new(handler, 0, false)
end

lib.on = native.add_event_handler
lib.off = native.remove_event_handler
lib.emit = native.trigger_event
lib[("emit_%s"):format(lib.service_inversed)] = lib.is_server and native.trigger_client_event or native.trigger_server_event
lib.emit_all_clients = lib.is_server and function(eventname, ...) return native.trigger_client_event(eventname, -1, ...) end or nil
lib.once = function(eventname, listener) return bind_once(false, eventname, listener) end
lib[("on_%s"):format(lib.service_inversed)] = on_remote
lib[("once_%s"):format(lib.service_inversed)] = function(eventname, listener) return bind_once(true, eventname, listener) end

lib.uuid = lib.random.uuid

-- common functions
lib.coalesce = lib.common.coalesce
