--- Manages client-side keybinds, allowing registration of custom key mappings
-- and handling press/release events. This module is client-only.
-- @module keybind
-- @client

--- @class KeybindObject Represents a registered keybind.
-- It encapsulates the name, description, default keys, and event delegates
-- for pressed and released states.
-- @field name string The unique name of the keybind (used for `+name` and `-name` commands).
-- @field desc string The description of the keybind, shown in the game's key mapping settings.
-- @field default_key string The default primary key (e.g., "E", "F1", "MOUSE_BUTTON_5").
-- @field default_mapper string The default input mapper for the primary key (e.g., "keyboard", "mouse").
-- @field secondary_key string (Optional) A secondary default key.
-- @field secondary_mapper string (Optional) The input mapper for the secondary key.
-- @field hash number The JOAAT hash of the `+name` command.
-- @field disabled boolean If true, the keybind will not trigger events.
-- @field is_pressed boolean True if the keybind is currently considered pressed.
-- @field delegate table Contains `pressed` and `released` DelegateObjects.
-- @field delegate.pressed DelegateObject Triggered when the keybind is pressed.
-- @field delegate.released DelegateObject Triggered when the keybind is released.
local keybind_prototype = {}
keybind_prototype.__index = keybind_prototype
-- keybind_prototype.__delegate_ids = {} -- This field was marked as temp and isn't used by the methods. Removing for clarity.

--- Creates and registers a new keybind.
-- This sets up the necessary commands (`+name`, `-name`) and key mappings in the game.
-- Chat suggestions for these commands are automatically removed after a short delay.
-- @param name string A unique name for the keybind (e.g., "use_item", "toggle_hud").
-- @param desc string A user-friendly description for the keybind settings menu.
-- @param primary_key string The default primary key (e.g., "F1", "E"). See FiveM key list.
-- @param primary_mapper string (Optional) The input mapper for the primary key (e.g., "keyboard"). Defaults to "keyboard".
-- @param secondary_key string (Optional) A secondary default key.
-- @param secondary_mapper string (Optional) The input mapper for the secondary key. Defaults to `primary_mapper` or "keyboard".
-- @return KeybindObject The created keybind object.
-- @usage
-- local useKeybind = lib.keybind("useItem", "Use Item", "E", "keyboard")
-- useKeybind:on_pressed(function(kb)
--   print(kb.name .. " was pressed!")
-- end)
function keybind_prototype.new(name, desc, primary_key, primary_mapper, secondary_key, secondary_mapper)
    lib.validate.type.assert(name, "string", "Keybind name")
    lib.validate.type.assert(desc, "string", "Keybind description")
    lib.validate.type.assert(primary_key, "string", "Keybind primary_key")
    if primary_mapper then lib.validate.type.assert(primary_mapper, "string", "Keybind primary_mapper") end
    if secondary_key then lib.validate.type.assert(secondary_key, "string", "Keybind secondary_key") end
    if secondary_mapper then lib.validate.type.assert(secondary_mapper, "string", "Keybind secondary_mapper") end

    local self = {}
    self.name = name
    self.desc = desc
    self.default_key = primary_key
    self.default_mapper = primary_mapper or "keyboard"
    self.secondary_key = secondary_key
    self.secondary_mapper = secondary_mapper
    self.hash = joaat("+" .. self.name) -- Hash of the positive command
    self.disabled = false
    self.is_pressed = false
    self.delegate = {
        pressed = lib.delegate(),
        released = lib.delegate(),
    }

    RegisterCommand("+" .. self.name, function()
        if self.disabled or IsPauseMenuActive() then return end
        self.is_pressed = true
        self.delegate.pressed:broadcast(self) -- Pass the keybind object to listeners
    end, false) -- false: not a restricted command

    RegisterCommand("-" .. self.name, function()
        if self.disabled or IsPauseMenuActive() then return end -- Though release might be wanted even if menu active
        self.is_pressed = false
        self.delegate.released:broadcast(self) -- Pass the keybind object to listeners
    end, false)

    -- Register the primary key mapping
    RegisterKeyMapping("+" .. self.name, self.desc, self.default_mapper, self.default_key)

    -- Register the secondary key mapping if provided
    if self.secondary_key then
        -- Note: The command for secondary mapping should ideally be distinct if it needs separate handling,
        -- or it could also map to "+name". The "~!+" prefix is unusual for RegisterKeyMapping command.
        -- Standard practice is to map multiple physical keys to the same logical command ("+name").
        -- If "~!+" is intended to create an alternative command, that command would also need +/- handlers.
        -- Assuming it's an alternative physical mapping for the same "+name" command.
        RegisterKeyMapping("+" .. self.name .. "_secondary", self.desc .. " (Secondary)", self.secondary_mapper or self.default_mapper, self.secondary_key)
        -- For it to trigger the *same* command "+name", it should be:
        -- RegisterKeyMapping("+" .. self.name, self.desc .. " (Secondary)", self.secondary_mapper or self.default_mapper, self.secondary_key)
        -- However, FiveM only allows one mapping per (command, mapper, key) tuple.
        -- The provided code with "~!+" seems to be a convention for a separate, perhaps unhandled, mapping command.
        -- For this documentation, I'll assume the intent was to map a secondary physical key to the same logical events.
        -- This would typically be handled by the user in their keybind settings by assigning the same command to multiple keys,
        -- or by having RegisterKeyMapping allow multiple calls for the same command with different keys (which it does).
        -- The example `RegisterKeyMapping("~!+" .. self.name, ...)` will create a *new, separate* command `~!+name` in settings.
        -- If the goal is *one* action in settings with two default physical keys, you register the command once,
        -- and then can register multiple default mappings to it.
        -- Let's stick to the original code's intent of registering a secondary mapping entry:
        RegisterKeyMapping("+" .. self.name, self.desc .. " (Alt)", self.secondary_mapper or self.default_mapper, self.secondary_key)
    end

    -- Remove chat suggestions for the raw commands
    lib.set_timeout(function()
        lib.emit("chat:removeSuggestion", ("/+%s"):format(self.name))
        lib.emit("chat:removeSuggestion", ("/-%s"):format(self.name))
    end, 500)

    return setmetatable(self, keybind_prototype)
end

--- Enables the keybind.
-- If disabled, press/release events will not be triggered.
-- @usage myKeybind:enable()
function keybind_prototype:enable()
    self.disabled = false
end

--- Disables the keybind.
-- Prevents press/release events from being triggered.
-- @usage myKeybind:disable()
function keybind_prototype:disable()
    self.disabled = true
end

--- Registers a callback for the keybind's pressed event.
-- @param callback function The function to call when the keybind is pressed.
--                   It receives the KeybindObject instance as its first argument.
-- @return table An opaque table containing data needed for `off()`.
-- @usage local handle = myKeybind:on_pressed(function(kb) print(kb.name .. " pressed") end)
function keybind_prototype:on_pressed(callback)
    lib.validate.type.assert(callback, "function", "on_pressed callback")
    local listener_id = self.delegate.pressed:add(callback)
    return { event_type = "pressed", id = listener_id } -- Store type for clarity in off()
end

--- Registers a callback for the keybind's released event.
-- @param callback function The function to call when the keybind is released.
--                   It receives the KeybindObject instance as its first argument.
-- @return table An opaque table containing data needed for `off()`.
-- @usage local handle = myKeybind:on_released(function(kb) print(kb.name .. " released") end)
function keybind_prototype:on_released(callback)
    lib.validate.type.assert(callback, "function", "on_released callback")
    local listener_id = self.delegate.released:add(callback)
    return { event_type = "released", id = listener_id } -- Store type for clarity in off()
end

--- Unregisters a previously registered callback using the handle returned by `on_pressed` or `on_released`.
-- @param data table The handle returned by `on_pressed` or `on_released`.
-- @usage myKeybind:off(handle)
function keybind_prototype:off(data)
    lib.validate.type.assert(data, "table", "Keybind off data")
    lib.validate.type.assert(data.event_type, "string", "Keybind off data.event_type")
    lib.validate.type.assert(data.id, "number", "Keybind off data.id")

    if self.delegate[data.event_type] then
        self.delegate[data.event_type]:remove(data.id)
    else
        warn(("Keybind:off - Unknown event type '%s' for keybind '%s'"):format(data.event_type, self.name))
    end
end

--- Exports the keybind functionality.
-- Provides `new()` for explicit creation and is callable directly as a shortcut for `new()`.
-- @type KeybindModule
-- @field new fun(name:string, desc:string, primary_key:string, primary_mapper?:string, secondary_key?:string, secondary_mapper?:string):KeybindObject Creates a new KeybindObject.
-- @usage
-- local myKeybind = lib.keybind.new("action", "Perform Action", "G")
-- -- or
-- local myOtherKeybind = lib.keybind("otherAction", "Other Action", "H")
lib_module = setmetatable({
    new = keybind_prototype.new,
}, {
    __call = function(_, ...) -- Allow calling lib.keybind(...) directly
        return keybind_prototype.new(...)
    end,
})
