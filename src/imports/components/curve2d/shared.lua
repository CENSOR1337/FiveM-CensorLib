--- Provides functionality for creating and evaluating 2D curves.
-- This module allows the definition of different types of curves (Linear, Bezier, Constant)
-- based on a set of keys (time-value pairs). These curves can then be evaluated at any given time.
-- @module curve2d

--- Linearly interpolates between two values.
-- @param a number The first value.
-- @param b number The second value.
-- @param t number The interpolation factor (0.0 to 1.0).
-- @return number The interpolated value.
-- @local
local function lerp(a, b, t)
    return a * (1 - t) + b * t
end

--- @class CurveKey Represents a single key point in a curve.
-- A key defines a specific value at a specific time.
-- @field time number The time of the key.
-- @field value number The value of the key at that time.
local curve_key_prototype = {}
curve_key_prototype.__index = curve_key_prototype

--- Creates a new CurveKey.
-- @param in_time number The time for this key.
-- @param in_value number The value for this key.
-- @return CurveKey A new CurveKey object.
-- @usage local key1 = lib.curve2d.key(0.0, 10.0)
function curve_key_prototype.new(in_time, in_value)
    lib.validate.type.assert(in_time, "number", "CurveKey time")
    lib.validate.type.assert(in_value, "number", "CurveKey value")
    return setmetatable({ time = in_time, value = in_value }, curve_key_prototype)
end

--- @class CurveBase Base class for all curve types.
-- Manages a collection of CurveKey objects.
-- @field keys table A list of CurveKey objects, sorted by time.
local curve_base_prototype = {}
curve_base_prototype.__index = curve_base_prototype

--- Base constructor for curves. Initializes keys and sorts them.
-- @param in_keys table (Optional) A list of CurveKey objects.
-- @return CurveBase A new base curve instance.
-- @nodoc (Not directly instantiated, used by derived curve types)
function curve_base_prototype.new(in_keys)
    local self = setmetatable({}, curve_base_prototype)
    self.keys = in_keys or {}
    lib.validate.type.assert(self.keys, "table", "Curve keys")

    for i, key in ipairs(self.keys) do
        assert(getmetatable(key) == curve_key_prototype, ("Key %d is not a valid CurveKey object"):format(i))
    end

    table.sort(self.keys, function(a, b) return a.time < b.time end)
    return self
end

--- Gets the last key of the curve.
-- @return table A table with `time` and `value` of the last key, or nil if no keys.
-- @usage local last = myCurve:last_key() if last then print(last.time, last.value) end
function curve_base_prototype:last_key()
    if #self.keys == 0 then return nil end
    local key = self.keys[#self.keys]
    return { time = key.time, value = key.value } -- Return a copy
end

--- Gets the first key of the curve.
-- @return table A table with `time` and `value` of the first key, or nil if no keys.
-- @usage local first = myCurve:first_key() if first then print(first.time, first.value) end
function curve_base_prototype:first_key()
    if #self.keys == 0 then return nil end
    local key = self.keys[1]
    return { time = key.time, value = key.value } -- Return a copy
end

--- Evaluates the curve at a given time.
-- This method must be implemented by derived curve types.
-- @param in_time number The time at which to evaluate the curve.
-- @return number The value of the curve at `in_time`.
-- @abstract
function curve_base_prototype:evaluate(in_time)
    error("evaluate() must be implemented by derived curve class")
end

--- @class LinearCurve : CurveBase Represents a linear interpolation curve.
-- Values between keys are interpolated linearly. Requires at least 2 keys.
local linear_class_prototype = {}
linear_class_prototype.__index = linear_class_prototype
setmetatable(linear_class_prototype, { __index = curve_base_prototype }) -- Inherit from CurveBase

--- Creates a new LinearCurve.
-- @param in_keys table A list of CurveKey objects. Must contain at least 2 keys.
-- @return LinearCurve A new linear curve object.
-- @usage local lc = lib.curve2d.linear({ lib.curve2d.key(0,0), lib.curve2d.key(1,10) })
function linear_class_prototype.new(in_keys)
    local self = curve_base_prototype.new(in_keys) -- Call base constructor
    assert(#self.keys >= 2, "LinearCurve requires at least 2 keys")
    return setmetatable(self, linear_class_prototype)
end

--- Evaluates the linear curve at a given time.
-- If time is outside the key range, it clamps to the first or last key's value.
-- @param in_time number The time at which to evaluate the curve.
-- @return number The interpolated value at `in_time`.
function linear_class_prototype:evaluate(in_time)
    if #self.keys == 0 then return 0 end -- Or error, or some default
    if in_time <= self.keys[1].time then return self.keys[1].value end
    if in_time >= self.keys[#self.keys].time then return self.keys[#self.keys].value end

    for i = 1, #self.keys - 1 do
        local k1, k2 = self.keys[i], self.keys[i + 1]
        if in_time >= k1.time and in_time <= k2.time then
            -- Avoid division by zero if k1.time == k2.time (shouldn't happen with sorted distinct times)
            if k1.time == k2.time then return k1.value end
            local t = (in_time - k1.time) / (k2.time - k1.time)
            return k1.value + t * (k2.value - k1.value) -- lerp(k1.value, k2.value, t)
        end
    end
    return self.keys[#self.keys].value -- Should be covered by initial checks, but as a fallback
end

--- @class BezierCurve : CurveBase Represents a Bezier curve.
-- Uses De Casteljau's algorithm for evaluation. Time parameter `in_time` for evaluate
-- is typically normalized (0 to 1) representing progress along the entire curve defined by keys.
-- Requires at least 2 keys.
local bezier_class_prototype = {}
bezier_class_prototype.__index = bezier_class_prototype
setmetatable(bezier_class_prototype, { __index = curve_base_prototype }) -- Inherit from CurveBase

--- Creates a new BezierCurve.
-- The keys provided act as control points for the Bezier curve.
-- @param in_keys table A list of CurveKey objects (control points). Must contain at least 2 keys.
-- @return BezierCurve A new Bezier curve object.
-- @usage local bc = lib.curve2d.bezier({k(0,0), k(0.25,10), k(0.75, -5), k(1,5)}) -- k is lib.curve2d.key
function bezier_class_prototype.new(in_keys)
    local self = curve_base_prototype.new(in_keys) -- Call base constructor
    assert(#self.keys >= 2, "BezierCurve requires at least 2 keys (e.g., start and end point for a line, more for curves)")
    return setmetatable(self, bezier_class_prototype)
end

--- Evaluates the Bezier curve at a given normalized time `t` (0 to 1).
-- Note: The `time` field of the CurveKey objects for Bezier curves might not directly map to `in_time`
-- in the same way as LinearCurve. Here, keys are control points, and `in_time` is `t`.
-- If you want to map actual time to Bezier `t`, you might need another layer or interpretation.
-- This implementation assumes `in_time` is the `t` parameter for De Casteljau's algorithm.
-- @param in_time number The normalized time parameter `t` (0.0 to 1.0) for evaluation.
--                     Values outside [0,1] are clamped.
-- @return number The value on the Bezier curve at parameter `t`.
function bezier_class_prototype:evaluate(in_time)
    if #self.keys == 0 then return 0 end
    -- Clamp in_time to be between 0 and 1 for Bezier evaluation
    local t_eval = math.max(0, math.min(1, in_time))

    local function de_casteljau_recursive(points, t)
        if #points == 1 then return points[1].value end
        local new_points = {}
        for i = 1, #points - 1 do
            -- Note: CurveKey objects have 'value', not creating new CurveKey objects here, just tables with 'value'.
            new_points[#new_points + 1] = { value = lerp(points[i].value, points[i + 1].value, t) }
        end
        return de_casteljau_recursive(new_points, t)
    end
    -- Pass self.keys directly, as they are {time=..., value=...} tables.
    -- The 'time' field of these keys is not used in De Casteljau's, only 'value'.
    return de_casteljau_recursive(self.keys, t_eval)
end

--- @class ConstantCurve : CurveBase Represents a constant (step) curve.
-- The value remains constant until the next key's time is reached. Requires at least 1 key.
local constant_class_prototype = {}
constant_class_prototype.__index = constant_class_prototype
setmetatable(constant_class_prototype, { __index = curve_base_prototype }) -- Inherit from CurveBase

--- Creates a new ConstantCurve.
-- @param in_keys table A list of CurveKey objects. Must contain at least 1 key.
-- @return ConstantCurve A new constant curve object.
-- @usage local cc = lib.curve2d.constant({ lib.curve2d.key(0,5), lib.curve2d.key(1,10) })
function constant_class_prototype.new(in_keys)
    local self = curve_base_prototype.new(in_keys) -- Call base constructor
    assert(#self.keys >= 1, "ConstantCurve requires at least 1 key")
    return setmetatable(self, constant_class_prototype)
end

--- Evaluates the constant curve at a given time.
-- Returns the value of the key active at `in_time`.
-- If time is before the first key, clamps to first key's value.
-- If time is after or at the last key, clamps to last key's value.
-- @param in_time number The time at which to evaluate the curve.
-- @return number The value of the curve at `in_time`.
function constant_class_prototype:evaluate(in_time)
    if #self.keys == 0 then return 0 end
    if in_time < self.keys[1].time then return self.keys[1].value end
    -- Iterate backwards to find the correct segment for constant curve
    for i = #self.keys, 1, -1 do
        if in_time >= self.keys[i].time then
            return self.keys[i].value
        end
    end
    -- This part should ideally not be reached if keys are sorted and in_time >= first key's time
    -- but as a fallback, return the first key's value (or last, depending on desired behavior for edge cases)
    return self.keys[1].value
end

--- Utility function to wrap a class table with a callable 'new' constructor.
-- @param class_prototype table The class prototype table containing a `new` method.
-- @return table A new table that can be called directly to invoke `class_prototype.new`.
-- @local
local function classwarp(class_prototype)
    return setmetatable({
        new = class_prototype.new,
    }, {
        __call = function(t, ...)
            return t.new(...)
        end,
    })
end

---@section Curve Constructors
-- These are callable constructors for creating curve keys and curve instances.

--- Creates a new CurveKey.
-- @function lib.curve2d.key
-- @param time number The time for this key.
-- @param value number The value for this key.
-- @return CurveKey A new CurveKey object.
lib_module.key = classwarp(curve_key_prototype)

--- Creates a new LinearCurve.
-- @function lib.curve2d.linear
-- @param keys table A list of CurveKey objects. Must contain at least 2 keys.
-- @return LinearCurve A new linear curve object.
lib_module.linear = classwarp(linear_class_prototype)

--- Creates a new BezierCurve.
-- The keys act as control points. Evaluation time is normalized (0-1).
-- @function lib.curve2d.bezier
-- @param keys table A list of CurveKey objects (control points). Must contain at least 2 keys.
-- @return BezierCurve A new Bezier curve object.
lib_module.bezier = classwarp(bezier_class_prototype)

--- Creates a new ConstantCurve.
-- @function lib.curve2d.constant
-- @param keys table A list of CurveKey objects. Must contain at least 1 key.
-- @return ConstantCurve A new constant curve object.
lib_module.constant = classwarp(constant_class_prototype)
