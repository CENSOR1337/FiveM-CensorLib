--- Provides a delegate system for managing and broadcasting events to listeners.
-- This module allows creating delegate objects that can have multiple listener functions
-- bound to them. When the delegate is broadcast, all its listeners are invoked.
-- @module delegate

local table_wipe = table.wipe -- Used for clearing the listeners table efficiently.

--- @class DelegateObject Represents a delegate that manages a list of listener functions.
-- Listeners can be added (bound) or removed (unbound), and a broadcast will
-- invoke all currently bound listeners with the provided arguments.
-- @field listener_id number Internal counter to generate unique IDs for listeners.
-- @field listeners table A list of listener entries, where each entry is a table
--                       containing `id` (number) and `listener` (function).
local delegate_prototype = {}
delegate_prototype.__index = delegate_prototype

--- Creates a new DelegateObject.
-- @return DelegateObject A new, empty delegate object.
-- @usage local myEvent = lib.delegate.new()
-- -- or using the callable module directly:
-- local anotherEvent = lib.delegate()
function delegate_prototype.new()
    local self = setmetatable({}, delegate_prototype)
    self.listener_id = 10 -- Initial ID, will be incremented.
    self.listeners = {}   -- Stores {id = unique_id, listener = function}
    return self
end

--- Returns the number of listeners currently bound to the delegate.
-- @return number The count of active listeners.
-- @usage local count = myEvent:size()
function delegate_prototype:size()
    return #self.listeners
end

--- Binds a listener function to this delegate.
-- When the delegate is broadcast, this listener will be invoked.
-- @param listener function The function to be called when the delegate is broadcast.
-- @return number A unique ID for the bound listener, which can be used to unbind it later.
-- @usage
-- local function onMyEvent(arg1, arg2) print("Event fired:", arg1, arg2) end
-- local listenerId = myEvent:bind(onMyEvent)
function delegate_prototype:bind(listener)
    lib.validate.type.assert(listener, "function", "Delegate listener")
    self.listener_id = self.listener_id + 1
    local listener_info = { id = self.listener_id, listener = listener }
    self.listeners[#self.listeners + 1] = listener_info
    return listener_info.id
end

--- Unbinds a listener from this delegate using its unique ID.
-- If the listener ID is found, it is removed and will no longer be invoked.
-- @param id number The unique ID of the listener to remove (returned by `bind`).
-- @usage myEvent:unbind(listenerId)
function delegate_prototype:unbind(id)
    lib.validate.type.assert(id, "number", "Listener ID for unbind")
    for i = #self.listeners, 1, -1 do -- Iterate backwards for safe removal
        local listener_info = self.listeners[i]
        if listener_info.id == id then
            table.remove(self.listeners, i)
            break
        end
    end
end

--- Alias for `bind`.
-- @function DelegateObject:add
-- @see DelegateObject:bind
delegate_prototype.add = delegate_prototype.bind

--- Alias for `unbind`.
-- @function DelegateObject:remove
-- @see DelegateObject:unbind
delegate_prototype.remove = delegate_prototype.unbind

--- Broadcasts an event to all bound listeners.
-- All arguments passed to broadcast after the delegate object itself
-- will be passed directly to each listener function.
-- @param ... any Arguments to pass to each listener function.
-- @usage myEvent:broadcast("Hello", 123)
function delegate_prototype:broadcast(...)
    -- Iterate over a copy in case a listener modifies the listeners table (e.g., unbinds itself)
    local current_listeners = {}
    for i = 1, #self.listeners do
        current_listeners[i] = self.listeners[i]
    end

    for i = 1, #current_listeners do
        local listener_info = current_listeners[i]
        -- Check if listener still exists in original table, in case it was removed by a previous listener
        local still_exists = false
        for _, l_info_orig in ipairs(self.listeners) do
            if l_info_orig.id == listener_info.id then
                still_exists = true
                break
            end
        end
        if still_exists then
            listener_info.listener(...)
        end
    end
end

--- Removes all listeners from this delegate.
-- After calling this, the delegate will have no bound listeners.
-- @usage myEvent:empty()
function delegate_prototype:empty()
    self.listeners = table_wipe(self.listeners) -- Efficiently clear the table
    -- Reset listener_id if desired, though not strictly necessary as IDs will continue to be unique.
    -- self.listener_id = 10
end

--- Exports the delegate functionality.
-- Provides `new()` for explicit creation and is callable directly as a shortcut for `new()`.
-- @type DelegateModule
-- @field new fun():DelegateObject Creates a new DelegateObject.
-- @usage
-- local myDelegate = lib.delegate.new()
-- -- or
-- local myOtherDelegate = lib.delegate()
lib_module = setmetatable({ new = delegate_prototype.new }, {
    __call = function()
        return delegate_prototype.new()
    end
})
