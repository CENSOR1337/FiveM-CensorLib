--- Manages interactions with the NUI (Native UI) interface in FiveM.
-- This module provides functionalities for sending messages to NUI,
-- registering callbacks from NUI, managing NUI focus, and handling NUI readiness.
-- This module is client-only.
-- @module nui
-- @client

--- @type table Cache of native FiveM functions related to NUI.
-- @local
local native = {
    send_nui_message = SendNuiMessage,
    set_nui_focus = SetNuiFocus,
    is_nui_focused = IsNuiFocused,
    register_nui_callback = RegisterNuiCallback, -- Renamed from RegisterNUICallback for consistency. Assuming it's RegisterNUICallback.
}

--- @type table Holds the methods that will be part of the `nui` module's interface.
-- @local
local nui_methods = {}

--- @type boolean Tracks whether the NUI interface has signaled it is ready.
-- @local
local is_nui_ready = false
--- @type DelegateObject Delegate that fires when NUI becomes ready.
-- @local
local on_nui_ready_delegate = lib.delegate()

--- Sends a JSON-encoded message to the NUI interface.
-- If NUI is not yet ready, the message is queued and sent once NUI signals readiness.
-- The message is structured with an `action` (the event name) and `args` (a list of arguments).
-- @param name string The name of the NUI event/action to trigger in the NUI JavaScript environment.
-- @param ... any Arguments to send with the event. These will be packed into an array.
-- @usage lib.nui.emit("showHud", true, { playerName = "Player1" })
function nui_methods.emit(name, ...)
    lib.validate.type.assert(name, "string", "NUI event name for emit")

    local payload = {
        action = name,
        args = { ... }, -- Pack varargs into an array
    }
    -- Defensively encode to prevent errors if json is not available (though it should be in FiveM)
    local success, json_payload = pcall(json.encode, payload)
    if not success then
        print(("[nui] Error encoding JSON payload for event '%s': %s"):format(name, tostring(json_payload)))
        return
    end

    if is_nui_ready then
        native.send_nui_message(json_payload)
    else
        -- Queue the message if NUI is not ready
        local temp_listener_id
        temp_listener_id = on_nui_ready_delegate:add(function()
            native.send_nui_message(json_payload)
            on_nui_ready_delegate:remove(temp_listener_id) -- Self-remove after sending
        end)
    end
end

--- Registers a callback function to handle events sent from the NUI interface.
-- When the NUI JavaScript calls `SendNUIMessage` with a corresponding `action` (which is `name` here),
-- the provided `listener` function is invoked.
-- The listener receives unpacked arguments from the NUI message.
-- The listener's return values are sent back to NUI via a NUI callback acknowledgement (`cb`).
-- @param name string The name of the NUI event to listen for.
-- @param listener function The Lua function to handle the NUI event.
--                   It receives arguments sent from NUI and can return values back to NUI.
-- @usage
-- lib.nui.on("uiActionComplete", function(dataFromUI)
--   print("NUI action completed with data:", dataFromUI)
--   return { serverResponse = "Data received" } -- This goes back to NUI
-- end)
function nui_methods.on(name, listener)
    lib.validate.type.assert(name, "string", "NUI event name for on")
    lib.validate.type.assert(listener, "function", "NUI event listener")

    -- Assuming RegisterNUICallback is the correct native name
    native.register_nui_callback(name, function(data, cb)
        -- NUI data often comes as a table. If it's an array-like table from JS, unpack it.
        -- If it's an object from JS, it's a table. Consider if unpacking is always desired.
        -- For now, assume data is an array or single object to be unpacked.
        local results
        if type(data) == "table" and data[1] ~= nil then -- Check if it's array-like
             results = { listener(table.unpack(data)) }
        else -- Assume single object or primitive
            results = { listener(data) }
        end

        if #results == 0 or (results[1] == nil and #results == 1) then -- No return values or single nil
            cb({ ok = true }) -- Basic acknowledgement
        else
            -- Send back the first result, or all results if your NUI expects an array
            -- For simplicity, sending back an object with a 'results' field if multiple, or direct if single.
            -- Or always wrap in a 'results' table for consistency.
            -- The original code wrapped in { results = results }, which means NUI gets { ok=true, results = {actual_results_array} }
            cb({ ok = true, results = results })
        end
    end)
end

--- Registers a listener function to be called when the NUI interface signals it is ready.
-- If NUI is already ready when this is called, the listener is invoked immediately.
-- Listeners are automatically unbound after one execution.
-- @param listener function The function to call once NUI is ready.
-- @usage
-- lib.nui.on_ready(function()
--   print("NUI is now ready for interaction.")
--   lib.nui.emit("initialSetup", { configValue = 123 })
-- end)
function nui_methods.on_ready(listener)
    lib.validate.type.assert(listener, "function", "NUI on_ready listener")

    if is_nui_ready then
        listener()
    else
        local temp_listener_id
        temp_listener_id = on_nui_ready_delegate:add(function()
            listener()
            on_nui_ready_delegate:remove(temp_listener_id) -- Self-remove after firing
        end)
    end
end

--- Sets the NUI focus and cursor visibility.
-- @param has_focus boolean True to give NUI focus, false to remove it.
-- @param has_cursor boolean True to show the mouse cursor, false to hide it.
-- @usage
-- -- To show UI and allow interaction:
-- lib.nui.focus(true, true)
-- -- To hide UI and return control to game:
-- lib.nui.focus(false, false)
function nui_methods.focus(has_focus, has_cursor)
    lib.validate.type.assert(has_focus, "boolean", "NUI focus state")
    lib.validate.type.assert(has_cursor, "boolean", "NUI cursor state")
    native.set_nui_focus(has_focus, has_cursor)
end

--- Signals that the NUI interface is ready for interaction.
-- This is typically called by your NUI JavaScript environment once it has loaded,
-- often via an event registered with `lib.nui.on("setNuiReadyState", lib.nui.set_ready)`.
-- It broadcasts the `on_nui_ready_delegate`.
-- @usage
-- -- In NUI Javascript, after UI is loaded:
-- -- fetch(`https://${GetParentResourceName()}/setNuiReadyState`, { method: 'POST' });
-- -- Lua side (typically in a client script that sets up NUI handlers):
-- -- lib.nui.on("setNuiReadyState", lib.nui.set_ready)
function nui_methods.set_ready()
    if is_nui_ready then return end -- Prevent multiple broadcasts if called again
    is_nui_ready = true
    on_nui_ready_delegate:broadcast()
    on_nui_ready_delegate:empty() -- Clear listeners after broadcast as they are one-time
end

---@type NuiModule
-- @field emit fun(name:string, ...:any) Sends a message to NUI.
-- @field on fun(name:string, listener:function) Registers a callback from NUI.
-- @field on_ready fun(listener:function) Registers a callback for when NUI is ready.
-- @field focus fun(has_focus:boolean, has_cursor:boolean) Sets NUI focus and cursor visibility.
-- @field set_ready fun() Signals that NUI is ready (usually called from NUI via an event).
-- @field is_ready boolean (Read-only) True if NUI has signaled readiness.
-- @field is_focus boolean (Read-only) True if NUI currently has focus (alias for `is_focused`).
-- @field is_focused boolean (Read-only) True if NUI currently has focus.
local nui_interface = setmetatable({}, {
    __index = function(_, key)
        if key == "is_ready" then
            return is_nui_ready
        elseif key == "is_focus" or key == "is_focused" then
            return native.is_nui_focused()
        end
        return nui_methods[key] -- Access methods from nui_methods table
    end,
    -- If you want to allow setting properties directly on lib.nui (not typical for this structure)
    -- __newindex = function(_, key, value)
    --     rawset(nui_methods, key, value) -- Or handle error for read-only properties
    -- end
})

lib_module = nui_interface
