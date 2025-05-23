local table_wipe = table.wipe

local delegate = {}
delegate.__index = delegate

function delegate.new()
    local self = setmetatable({}, delegate)
    self.listener_id = 10
    self.listeners = {}

    return self
end

function delegate:size()
    return #self.listeners
end

function delegate:bind(listener)
    self.listener_id = self.listener_id + 1
    local listener_info = { id = self.listener_id, listener = listener }
    self.listeners[#self.listeners + 1] = listener_info

    return listener_info.id
end

function delegate:unbind(id)
    for i = 1, #self.listeners, 1 do
        local listener_info = self.listeners[i]
        if (listener_info.id == id) then
            table.remove(self.listeners, i)
            break
        end
    end
end

delegate.add = delegate.bind
delegate.remove = delegate.unbind

function delegate:broadcast(...)
    for i = 1, #self.listeners, 1 do
        local listener_info = self.listeners[i]
        listener_info.listener(...)
    end
end

function delegate:empty()
    self.listeners = table_wipe(self.listeners)
end

lib_module = setmetatable({ new = delegate.new }, { __call = function() return delegate.new() end })
