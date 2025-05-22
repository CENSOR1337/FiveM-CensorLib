--- Provides functionality for creating and managing timers.
-- This module allows scheduling functions to be executed after a delay, either once
-- or repeatedly (like an interval). Timers are managed as objects that can be destroyed.
-- @module timer

local native_wait = Wait -- Using Wait for delays, ensure it's available or use Citizen.Wait
local citizen_create_thread_now = Citizen.CreateThreadNow

--- @class TimerObject Represents a timer that executes a handler function.
-- Timers can be one-shot or looping (interval). They can be destroyed to prevent further execution.
-- @field delay number The delay in milliseconds before the handler is executed (or between executions for loops).
-- @field is_destroyed boolean True if the timer has been destroyed, false otherwise.
-- @field is_loop boolean True if the timer should repeat, false if it's a one-shot timer.
-- @field fn_handler function The actual function to be called by the timer.
-- @field handler function (Internal) The wrapper function that includes the delay and calls `fn_handler`.
-- @field id number|nil (Internal) The thread ID if the timer is running in its own thread. (Note: The original code assigns `ref` to `self.id` but `ref` is not defined in that context. Citizen.CreateThreadNow does not return a ref directly that is useful for stopping it like a native timer ID. Destruction is handled by `is_destroyed` flag.)
local timer_prototype = {}
timer_prototype.__index = timer_prototype

--- Creates a new timer.
-- The timer starts automatically upon creation, running in a new thread.
-- @param handler function The function to execute when the timer fires.
-- @param delay number (Optional) The delay in milliseconds before the first execution,
--                  or between executions if `is_loop` is true. Defaults to 0.
-- @param is_loop boolean (Optional) If true, the timer will repeat indefinitely until destroyed.
--                    If false or nil, the timer will execute only once. Defaults to false.
-- @return TimerObject A new timer object.
-- @usage
-- -- Execute once after 1 second:
-- local oneShot = lib.timer.new(function() print("One second passed!") end, 1000)
--
-- -- Execute every 500ms:
-- local repeating = lib.timer.new(function() print("Tick!") end, 500, true)
-- -- To stop it later:
-- -- repeating:destroy()
--
-- -- Direct call using module as function:
-- local directTimer = lib.timer(function() print("Direct call timer") end, 200)
function timer_prototype.new(handler, delay, is_loop)
    lib.validate.type.assert(handler, "function", "Timer handler")
    if delay ~= nil then lib.validate.type.assert(delay, "number", "Timer delay") end
    if is_loop ~= nil then lib.validate.type.assert(is_loop, "boolean", "Timer is_loop flag") end

    local self = {}
    self.delay = delay or 0
    self.is_destroyed = false
    self.is_loop = is_loop or false -- Defaults to false if nil or explicitly false
    self.fn_handler = handler
    self.id = nil -- Will hold the pseudo-thread reference if needed, though not directly used for stopping

    -- Internal handler that waits for the delay then executes the user's function
    self.handler_wrapper = function()
        if self.delay > 0 then -- Only wait if delay is positive
            native_wait(self.delay)
        end
        if self.is_destroyed then return end -- Check again after wait
        self.fn_handler()
    end

    -- Each timer runs in its own thread
    citizen_create_thread_now(function()
        -- The original code assigned `ref` to `self.id`, but `ref` is not a parameter of the thread function.
        -- For LDoc purposes, we'll assume `self.id` is for informational purposes or future extension,
        -- as thread cancellation is not done via this ID with Citizen.CreateThreadNow.
        -- self.id = GetCurrentThreadId() -- Example if an actual thread ID was needed.

        if self.is_loop then
            while not self.is_destroyed do
                self.handler_wrapper()
                if self.delay == 0 and not self.is_destroyed then
                    -- If it's a zero-delay loop (like on_tick), yield to prevent blocking everything.
                    native_wait(0)
                end
            end
        else
            self.handler_wrapper()
            -- One-shot timers effectively destroy themselves after execution by not looping.
            -- Mark as destroyed to prevent accidental reuse if :destroy() wasn't called.
            self.is_destroyed = true
        end
    end)

    return setmetatable(self, timer_prototype)
end

--- Destroys the timer, preventing any further executions.
-- If the timer is currently waiting for its delay, it will complete that wait
-- but will not execute the handler function afterwards if `is_destroyed` is true.
-- For looping timers, it stops the loop.
-- @usage myTimer:destroy()
function timer_prototype:destroy()
    if self.is_destroyed then return end
    self.is_destroyed = true
    -- Note: The thread itself will exit once its loop condition (not self.is_destroyed) is met
    -- or after its single execution if not a loop. There's no explicit thread killing here,
    -- relies on the flag check within the thread.
end

---@type TimerModule
-- @field new fun(handler:function, delay?:number, is_loop?:boolean):TimerObject Creates a new TimerObject.
-- Also callable directly via `lib.timer(...)` as a shortcut for `new(...)`.
lib_module = setmetatable({
    new = timer_prototype.new,
}, {
    __call = function(_, ...) -- Allows lib.timer(...)
        return timer_prototype.new(...)
    end,
})
