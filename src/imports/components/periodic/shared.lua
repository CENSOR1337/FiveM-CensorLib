--- Manages collections of functions that are executed periodically at a specified tick rate.
-- This module allows creating `PeriodicObject` instances, to which multiple handler functions
-- can be added. These handlers are then all called together at the defined interval.
-- @module periodic

--- @class PeriodicObject Represents a manager for a list of functions to be called periodically.
-- It groups multiple handler functions and executes them at a common interval.
-- If all handlers are removed, the underlying timer is destroyed.
-- @field handlers table Internal storage for handler functions.
--   @field handlers.fn table A dictionary mapping unique IDs to handler functions.
--   @field handlers.list table A list of handler functions, rebuilt when `fn` changes. Used for iteration.
--   @field handlers.length number The current number of active handlers in `list`.
-- @field b_reassign_table boolean Flag indicating if `handlers.list` needs to be rebuilt.
-- @field id number Counter for generating unique IDs for handlers.
-- @field tick_rate number The interval in milliseconds at which handlers are executed.
-- @field interval table|nil The timer object returned by `lib.set_interval`, if active.
local periodic_prototype = {}
periodic_prototype.__index = periodic_prototype

--- Creates a new PeriodicObject.
-- @param tick_rate number (Optional) The interval in milliseconds at which to execute the
--                    added handler functions. Defaults to 0 (every game tick).
-- @return PeriodicObject A new periodic task manager object.
-- @usage
-- local five_second_ticker = lib.periodic.new(5000)
-- local game_tick_checker = lib.periodic() -- Defaults to tick_rate 0
function periodic_prototype.new(tick_rate)
    tick_rate = lib.coalesce(tick_rate, 0)
    lib.validate.type.assert(tick_rate, "number", "Periodic tick_rate")

    local self = {}
    self.handlers = {
        fn = {},      -- Stores id -> function
        list = {},    -- Stores functions for quick iteration
        length = 0,   -- Length of handlers.list
    }
    self.b_reassign_table = false -- Flag to rebuild handlers.list
    self.id = 10 -- Initial ID for handlers
    self.tick_rate = tick_rate
    self.interval = nil -- Stores the timer object from lib.set_interval

    return setmetatable(self, periodic_prototype)
end

--- Adds a handler function to be executed periodically.
-- If this is the first handler added, it starts the underlying interval timer.
-- @param fn_handler function The function to be called at each interval.
-- @return number A unique ID for the added handler, which can be used to remove it later.
-- @usage
-- local handler_id = my_periodic_obj:add(function()
--   print("Tick!")
-- end)
function periodic_prototype:add(fn_handler)
    lib.validate.type.assert(fn_handler, "function", "Periodic handler")

    self.id = self.id + 1
    self.handlers.fn[self.id] = fn_handler
    self.b_reassign_table = true -- Mark for rebuild

    if not self.interval then
        self.interval = lib.set_interval(function()
            if self.b_reassign_table then
                table.wipe(self.handlers.list)
                self.handlers.length = 0
                for _, func_val in pairs(self.handlers.fn) do
                    self.handlers.list[#self.handlers.list + 1] = func_val
                end
                self.handlers.length = #self.handlers.list
                self.b_reassign_table = false -- Rebuild complete

                if self.handlers.length == 0 then
                    if self.interval then -- Check if interval still exists (could be destroyed by clear/destroy)
                        self.interval:destroy()
                        self.interval = nil
                    end
                    return -- No handlers left, stop processing
                end
            end

            -- Optimized iteration over the cached list
            local current_list = self.handlers.list
            for i = 1, self.handlers.length do
                current_list[i]() -- Call the handler
            end
        end, self.tick_rate)
    end
    return self.id
end

--- Removes a specific handler function using its ID.
-- If no handlers remain after removal, the underlying interval timer is stopped if `add` is called again and length is 0.
-- The timer is explicitly stopped during the interval callback if length becomes 0.
-- @param id number The unique ID of the handler to remove (returned by `add`).
-- @usage my_periodic_obj:remove(handler_id)
function periodic_prototype:remove(id)
    lib.validate.type.assert(id, "number", "Periodic handler ID for removal")

    if self.handlers.fn[id] then
        self.handlers.fn[id] = nil
        self.b_reassign_table = true -- Mark for rebuild
    end
end

--- Removes all handler functions from this periodic object.
-- The underlying interval timer will be stopped during the next rebuild phase if it's running.
-- @usage my_periodic_obj:clear()
function periodic_prototype:clear()
    table.wipe(self.handlers.fn)
    -- handlers.list is wiped during rebuild, no need to wipe here
    self.b_reassign_table = true
    -- If interval is running and no handlers are left, it will be destroyed in the next tick's rebuild phase.
    -- To stop it immediately, one might add:
    -- if self.interval and self.handlers.length == 0 then -- This length is pre-rebuild though
    --    self.interval:destroy()
    --    self.interval = nil
    -- end
    -- However, the current logic handles this robustly within the interval callback.
end

--- Destroys the periodic object, clearing all handlers and stopping the timer.
-- This is an alias for `clear()`, as the timer destruction is handled when the handler list becomes empty.
-- For immediate timer destruction, one might enhance this, but current logic is safe.
-- @usage my_periodic_obj:destroy()
function periodic_prototype:destroy()
    self:clear()
    -- To ensure immediate timer stop if not relying on the next tick's rebuild:
    if self.interval then
        self.interval:destroy()
        self.interval = nil
    end
end

---@type PeriodicModule
-- @field new fun(tick_rate?:number):PeriodicObject Creates a new PeriodicObject.
-- Also callable directly via `lib.periodic(...)` as a shortcut for `new(tick_rate)`.
lib_module = setmetatable({
    new = periodic_prototype.new,
}, {
    __call = function(_, ...) -- Allows lib.periodic(...)
        return periodic_prototype.new(...)
    end,
})
