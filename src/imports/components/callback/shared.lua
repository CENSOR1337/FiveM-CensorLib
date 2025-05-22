--- Manages remote callbacks between server and client.
-- This module provides a system for registering and triggering callbacks across the
-- network, allowing for asynchronous request-response patterns. It supports
-- callbacks from server to client and client to server, with an optional await
-- mechanism using promises.
-- @module callback
local promise = promise
local citizen_await = Citizen.Await
local table_unpack = table.unpack
local is_server = lib.is_server
--- @type function Local event registration function, aliased based on service.
-- @local
local on_remote = is_server and lib.on_client or lib.on_server

--- @type string Prefix for callback event names.
-- @local
local prefix = "cslib.cb"
--- @type number Default timeout for awaitable callbacks in milliseconds.
-- @local
local timeout_time = 10 * 1000 -- 10 seconds

--- @type string Event name for invoking a received callback. Dynamically includes current resource name.
-- @local
local invoke_event = ("cslib.cb.invoke:%s"):format(lib.resource.name)
--- @type table Stores pending callback listeners, keyed by unique ID.
-- @local
local pending_callbacks = {}

-- Listener for the invoke_event, executes the actual callback function
-- once it's received back from the target service.
on_remote(invoke_event, function(id, ...)
    if not (is_server) then
        -- Basic validation for client-side, ensure source exists if it's a client-to-client scenario (though typically client-server)
        if source == "" then return end
    end

    local listener = pending_callbacks[id]

    if not (listener) then return end

    pending_callbacks[id] = nil -- Remove listener after execution (one-time callback)

    listener(...)
end)

--- Creates and stores a unique listener for a callback.
-- @param eventname string The base event name for context.
-- @param listener function The actual callback function to execute.
-- @param src string|number (Server-only) The target client source ID.
-- @return string The unique ID generated for this callback.
-- @local
local function create_listener(eventname, listener, src)
    local id

    repeat
        if (is_server) then
            id = ("%s:%s:%s"):format(eventname, math.random(0, 1000000), src)
        else
            id = ("%s:%s"):format(eventname, math.random(0, 1000000))
        end
    until not pending_callbacks[id] -- Ensure ID is unique

    pending_callbacks[id] = listener

    return id
end

--- Registers a handler for a specific callback event name.
-- When this event is triggered from the remote service, the provided listener
-- will be executed with the arguments passed by the remote trigger.
-- The listener's return values will be sent back to the original requester.
-- @param eventname string The unique name for this callback type.
-- @param listener function The function to execute when this callback is triggered.
--                         It receives arguments from the trigger and its return values
--                         are sent back as the callback response.
-- @return table The event handle from `on_remote`.
-- @usage
-- -- Server-side: Register a callback provider
-- lib.callback.register("getUserData", function(userId)
--   local user = users[userId]
--   return user and user.name, user and user.age
-- end)
--
-- -- Client-side: Trigger the callback (see __call usage)
-- lib.callback("getUserData", 123):then(function(name, age)
--   print("User:", name, age)
-- end)
local function register_callback(eventname, listener)
    local cb_eventname = ("%s:%s"):format(prefix, eventname)

    return on_remote(cb_eventname, function(id, ...)
        local src = source -- Source of the request

        if (is_server) then
            -- Server emits back to specific client source
            lib.emit_client(invoke_event, src, id, listener(...))
        else
            -- Client emits back to server
            lib.emit_server(invoke_event, id, listener(...))
        end
    end)
end

--- Triggers a callback to the server and provides a listener for the response.
-- (Internal use, typically exposed via __call metamethod for awaitable behavior)
-- @param eventname string The name of the callback event to trigger on the server.
-- @param listener function The function to execute with the server's response.
-- @param ... any Arguments to send to the server-side callback handler.
-- @local
local function trigger_callback_to_server(eventname, listener, ...)
    lib.validate.type.assert(listener, "function", "table") -- Can be function or delegate table

    local callback_id = create_listener(eventname, listener)
    local cb_eventname = ("%s:%s"):format(prefix, eventname)

    lib.emit_server(cb_eventname, callback_id, ...)
end

--- Triggers a callback to a specific client and provides a listener for the response.
-- (Internal use, typically exposed via __call metamethod for awaitable behavior)
-- @param eventname string The name of the callback event to trigger on the client.
-- @param src string|number The target client's source ID.
-- @param listener function The function to execute with the client's response.
-- @param ... any Arguments to send to the client-side callback handler.
-- @local
local function trigger_callback_to_client(eventname, src, listener, ...)
    lib.validate.type.assert(src, "number", "string")
    lib.validate.type.assert(listener, "function", "table") -- Can be function or delegate table

    local callback_id = create_listener(eventname, listener, src)
    local cb_eventname = ("%s:%s"):format(prefix, eventname)

    lib.emit_client(cb_eventname, src, callback_id, ...)
end

--- Handles the logic for an awaitable callback trigger.
-- This function sends the event and arguments to the remote service,
-- then waits for a response or a timeout.
-- @param eventname string The callback event name.
-- @param src string|number|nil The target source (for server-to-client calls).
--                            On client, this is the first vararg if provided,
--                            otherwise arguments start from `...`.
-- @param ... any Arguments for the callback.
-- @return any The values returned from the remote callback, or nil on timeout.
-- @local
local function trigger_callback_await(eventname, src, ...)
    local function handler(...)
        local p = promise.new()
        local actual_args -- To hold arguments for the remote call

        local response_handler = function(...)
            p:resolve({
                success = true,
                params = { ... },
            })
        end

        if (is_server) then
            -- Server to Client: src is explicitly the target client
            actual_args = { ... } -- Varargs are the actual arguments for the client
            trigger_callback_to_client(eventname, src, response_handler, table_unpack(actual_args))
        else
            -- Client to Server: src is the first vararg if it's not a function (listener)
            -- If src is a function, it means no specific server target, just eventname and args.
            -- However, this await function expects src to be the eventname, and ... to be args.
            -- The actual remote target for client->server is always the server itself.
            -- The `src` parameter in this function for client-side is actually the first argument intended for the server.
            -- So, we pack eventname, src, and ... to send to the server.
            -- No, this is simpler: src is the eventname, ... are the args.
            -- The first argument to this function on client is eventname.
            -- The second argument (src) is the first actual data argument for the server.
            -- The remaining varargs (...) are subsequent data arguments.
            -- If ... is empty, then src is the only argument.
            -- Let's correct the argument interpretation for client->server call:
            -- eventname is passed as the first param to trigger_callback_await.
            -- src here is the first data argument for the server.
            -- ... are the rest of the data arguments.
            local all_args = { src, ... } -- src is the first data arg, ... are the rest
            trigger_callback_to_server(eventname, response_handler, table_unpack(all_args))
        end

        lib.set_timeout(function()
            if p:getStatus() == promise.PENDING then -- Only resolve if not already done
                 pending_callbacks[response_handler] = nil -- Attempt to clean up if timed out. ID is tricky here.
                p:resolve({ success = false })
            end
        end, timeout_time)

        return citizen_await(p)
    end

    -- The varargs to trigger_callback_await are (eventname, [src_if_server], ...actual_args_for_remote)
    -- The handler then receives these.
    -- For client: handler(eventname, arg1, arg2, ...)
    -- For server: handler(eventname, target_client_src, arg1, arg2, ...)
    -- The `src` parameter in trigger_callback_await for client calls is the first actual data argument.
    -- The `...` are the rest of the data arguments.
    -- So, when calling handler, we pass all args: handler(eventname, src, ...)
    -- The handler then correctly unpacks them for trigger_callback_to_client/server.

    local return_values = handler(eventname, src, ...) -- Pass all relevant args to handler

    if not (return_values.success) then return end -- Timeout or other issue

    return table_unpack(return_values.params)
end

--- Main module table for callback functionalities.
-- Exposes `register` for setting up callback listeners.
-- Is callable directly to trigger an awaitable callback.
-- @type CallbackModule
-- @field register function Registers a handler for a specific callback event name.
-- @usage
-- -- To register a callback provider (e.g., on server)
-- lib.callback.register("getUserName", function(userId)
--   return "User_" .. userId
-- end)
--
-- -- To trigger and await a callback (e.g., on client)
-- Citizen.CreateThreadNow(function()
--   local name = lib.callback("getUserName", 123)
--   print("Received name:", name) -- Output: Received name: User_123
--
--   -- Server to specific client
--   -- On Server:
--   -- local clientName = lib.callback("getClientName", clientSourceId)
--   -- print("Client responded with:", clientName)
--   -- On Client (registered handler):
--   -- lib.callback.register("getClientName", function() return "PlayerRenderName" end)
-- end)
--
-- -- Using .then() for non-await (via lib.async wrapper)
-- lib.callback("getUserName", 123):then(function(name)
--   print("Received name (async):", name)
-- end)
lib_module = setmetatable({
    register = register_callback,
}, {
    -- When lib.callback(...) is called directly.
    -- On client: lib.callback("eventName", arg1, arg2, ...)
    -- On server: lib.callback("eventName", targetClientSrc, arg1, arg2, ...)
    __call = function(_, eventname, ...)
        -- trigger_callback_await expects (eventname, src_or_first_arg, ...other_args)
        -- The first vararg from ... will be treated as 'src' by trigger_callback_await
        -- and the rest as further arguments.
        return lib.async(trigger_callback_await)(eventname, ...)
    end,
})
