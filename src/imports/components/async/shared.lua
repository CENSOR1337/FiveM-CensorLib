--- Provides functionality for managing asynchronous operations.
-- This module allows wrapping a function to be executed asynchronously,
-- providing methods to handle its completion via callbacks or by awaiting its result.
-- @module async

local table_unpack = table.unpack
local table_pack = table.pack
local create_thread_now = Citizen.CreateThreadNow
local citizen_await = Citizen.Await

--- @type table Defines aliases for the `callback` method.
-- Allows `after`, `done`, or `then` to be used interchangeably with `callback`.
-- @local
local alias_fields = {
    ["after"] = "callback",
    ["done"] = "callback",
    ["then"] = "callback", -- i wish i could use this, but it's a reserved keyword
}

--- Creates an asynchronous operation from a given function.
-- The `async` function takes a handler function and returns a new function.
-- When this new function is called, it executes the original handler asynchronously.
-- It returns an object with methods (`callback`, `await`) to manage the async result.
-- @param fn_handler function The function to be executed asynchronously.
-- @return function A new function that, when called, initiates the async operation
--                  and returns an object with `callback` and `await` methods.
-- @usage
-- local my_async_op = async(function(param1)
--     Citizen.Wait(1000) -- Simulate work
--     return "Result: " .. param1
-- end)
--
-- -- Using callback
-- my_async_op("hello"):callback(function(result)
--     print(result) -- Output: Result: hello
-- end)
--
-- -- Or using await (must be within a Citizen.CreateThreadNow context)
-- Citizen.CreateThreadNow(function()
--     local result = my_async_op("world"):await()
--     print(result) -- Output: Result: world
-- end)
local function async(fn_handler)
    local is_used = false -- Flag to ensure callback/await is only used once per call

    -- The returned function that, when called, starts the async operation.
    return setmetatable({}, {
        __call = function(_, ...)
            local args = { ... } -- Arguments for the fn_handler
            local dispatcher = lib.delegate() -- For managing callbacks
            local return_packed = nil -- To store results if ready before callback/await

            -- Execute the original function in a new thread
            create_thread_now(function()
                return_packed = table_pack(fn_handler(table_unpack(args)))
                dispatcher:broadcast(table_unpack(return_packed))
            end)

            --- @type AsyncResult
            -- @field callback function Registers a callback to be executed upon completion.
            -- @field await function Pauses execution until the async operation completes and returns its result.
            -- @field after function Alias for `callback`.
            -- @field done function Alias for `callback`.
            -- @field then function Alias for `callback`.
            local async_result_object = {
                --- Registers a callback function to be executed when the asynchronous operation completes.
                -- Can only be called once per operation.
                -- @param callback function The function to call with the results of the async operation.
                -- @usage
                -- my_async_op("data"):callback(function(result1, result2)
                --   print(result1, result2)
                -- end)
                callback = function(callback_fn)
                    assert(not is_used, "async can only be used once (callback/await)")
                    is_used = true
                    lib.validate.type.assert(callback_fn, "function", "async callback")

                    if (return_packed) then -- If result is already available
                        callback_fn(table_unpack(return_packed))
                        return
                    end
                    dispatcher:add(callback_fn) -- Add to listeners if not yet resolved
                end,

                --- Awaits the completion of the asynchronous operation and returns its results.
                -- This function will pause the current thread until the operation is finished.
                -- Can only be called once per operation. Must be called from within a thread
                -- started by `Citizen.CreateThreadNow`.
                -- @return any The results returned by the original asynchronous function.
                -- @usage
                -- Citizen.CreateThreadNow(function()
                --   local result1, result2 = my_async_op("data"):await()
                --   print(result1, result2)
                -- end)
                await = function()
                    assert(not is_used, "async can only be used once (callback/await)")
                    is_used = true

                    if (return_packed) then -- If result is already available
                        return table_unpack(return_packed)
                    end

                    -- Create a promise to await the result
                    local p = promise.new()
                    dispatcher:add(function(...)
                        p:resolve({ params = { ... } }) -- Resolve with packed params for multi-return
                    end)
                    return table_unpack(citizen_await(p).params) -- Unpack results
                end,
            }

            -- Metatable for handling aliases (then, after, done)
            return setmetatable(async_result_object, {
                __index = function(self, key)
                    local alias = alias_fields[key]
                    if alias then
                        return self[alias] -- Return the actual 'callback' function
                    end
                    return rawget(self, key)
                end,
            })
        end,
    })
end

lib_module = async
