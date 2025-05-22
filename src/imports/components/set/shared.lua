--- Provides a Set data structure for managing unordered collections of unique items.
-- Items in a set can be strings, numbers, booleans, or tables (tables are compared by reference).
-- The set maintains insertion order for iteration purposes when converting to an array or using `foreach`.
-- @module set

local table_wipe = table.wipe -- For efficient table clearing

--- @class SetObject Represents a set of unique items.
-- Items are stored in an internal list to maintain order and an index table for quick lookups.
-- @field data table Internal list storing the unique items in insertion order.
-- @field index table Internal lookup table mapping items to their position (1-based index) in `data`.
-- @field length number The number of items currently in the set.
local set_prototype = {}
set_prototype.__index = set_prototype

--- Creates a new SetObject.
-- Optionally, initial items can be passed as arguments to populate the set.
-- @param ... any (Optional) Initial items to add to the set.
-- @return SetObject A new SetObject instance.
-- @usage
-- local mySet = lib.set.new()
-- local anotherSet = lib.set.new(1, "hello", true, {key="val"})
-- -- or using the callable module:
-- local callSet = lib.set("initial_item", 42)
function set_prototype.new(...)
    local self = {}
    self.data = {}   -- Stores items in order
    self.index = {}  -- Maps item -> index in self.data
    self.length = 0

    setmetatable(self, set_prototype) -- Set metatable before calling methods like :add

    local args = { ... }
    for i = 1, #args do
        self:add(args[i])
    end

    return self
end

--- Creates a new SetObject from an existing array (Lua table with sequential numeric keys).
-- Duplicate items in the array will only be added once to the set.
-- @param array table The array of items to initialize the set with.
-- @return SetObject A new SetObject instance populated with unique items from the array.
-- @usage local mySet = lib.set.from_array({1, 2, "apple", 2, "banana"})
function set_prototype.from_array(array)
    lib.validate.type.assert(array, "table", "Set.from_array input")
    local self = set_prototype.new() -- Create an empty set
    for _, value in ipairs(array) do -- Use ipairs for array-like tables
        self:add(value)
    end
    return self
end

--- Checks if a specific value is present in the set.
-- Uses the internal index for O(1) average time complexity lookup.
-- @param value any The value to check for. Valid types: string, number, boolean, table (by reference).
-- @return boolean True if the value is in the set, false otherwise.
-- @usage if mySet:contain("item1") then print("Item1 exists") end
function set_prototype:contain(value)
    -- No type validation needed here as it's a core lookup operation.
    -- Invalid types for table keys would error anyway, but we restrict on add.
    return self.index[value] ~= nil
end

--- Checks if all specified values are present in the set.
-- @param ... any A variable number of values to check for.
-- @return boolean True if all values are found in the set, false otherwise.
-- @usage if mySet:contains("a", "b", "c") then print("All present") end
function set_prototype:contains(...)
    local args = { ... }
    if #args == 0 then return true end -- Contains no items is trivially true

    for i = 1, #args do
        if not self:contain(args[i]) then return false end
    end
    return true
end

--- Appends all unique items from one or more other SetObjects to this set.
-- @param ... SetObject One or more SetObject instances whose items will be added.
-- @usage
-- local set1 = lib.set.new(1, 2)
-- local set2 = lib.set.new(2, 3)
-- set1:append(set2) -- set1 now contains {1, 2, 3}
function set_prototype:append(...)
    local args = { ... }
    for i = 1, #args do
        local other_set = args[i]
        -- Basic duck-typing check for a SetObject like structure
        lib.validate.type.assert(other_set, "table", ("Set:append argument #%d"):format(i))
        lib.validate.type.assert(other_set.data, "table", ("Set:append argument #%d .data field"):format(i))
        lib.validate.type.assert(other_set.foreach, "function", ("Set:append argument #%d .foreach method"):format(i))


        other_set:foreach(function(value_to_add)
            self:add(value_to_add) -- :add handles uniqueness
        end)
    end
end

--- Returns an array (numerically indexed table) containing all items in the set, in insertion order.
-- This creates a new table (a shallow copy of the items).
-- @return table A new array with all items from the set.
-- @usage local itemsArray = mySet:array() for _, item in ipairs(itemsArray) do print(item) end
function set_prototype:array()
    local new_array = {}
    for i = 1, self.length do
        new_array[i] = self.data[i]
    end
    return new_array
end

--- Adds a value to the set if it's not already present.
-- Valid value types are string, number, boolean, and table (tables are added by reference).
-- @param value any The value to add.
-- @usage mySet:add("newItem") mySet:add(123)
function set_prototype:add(value)
    if self:contain(value) then return end -- Value already in set

    -- Validate type before adding. nil cannot be an index.
    lib.validate.type.assert(value, "string", "number", "boolean", "table", "Set:add value")

    table.insert(self.data, value)
    self.length = self.length + 1 -- Update length before using it as index
    self.index[value] = self.length -- Store the 1-based index
end

--- Removes a value from the set if it exists.
-- @param value any The value to remove.
-- @usage mySet:remove("itemToRemove")
function set_prototype:remove(value)
    lib.validate.type.assert(value, "string", "number", "boolean", "table", "Set:remove value")
    if not self:contain(value) then return end

    local item_index_in_data = self.index[value]
    if item_index_in_data then
        table.remove(self.data, item_index_in_data)
        self.index[value] = nil -- Remove from lookup
        self.length = self.length - 1

        -- Re-index elements that came after the removed one
        for i = item_index_in_data, self.length do
            local re_indexed_value = self.data[i]
            self.index[re_indexed_value] = i
        end
    end
end

--- Returns the number of items in the set.
-- @return number The current size of the set.
-- @usage local numItems = mySet:size()
function set_prototype:size()
    return self.length
end

--- Removes all items from the set, making it empty.
-- @usage mySet:empty()
function set_prototype:empty()
    self.data = table_wipe(self.data)
    self.index = table_wipe(self.index)
    self.length = 0
end

--- Iterates over each item in the set (in insertion order) and calls a callback function.
-- @param callback function The function to call for each item. It receives the item as its argument.
-- @usage
-- mySet:foreach(function(item)
--   print("Item:", item)
-- end)
function set_prototype:foreach(callback)
    lib.validate.type.assert(callback, "function", "Set:foreach callback")
    for i = 1, self.length do
        callback(self.data[i])
    end
end

-- Aliases for common set operations
--- Alias for `contain`. Checks if a value is in the set.
-- @function SetObject:has
-- @param value any The value to check.
-- @return boolean True if the value is present.
-- @see SetObject:contain
set_prototype.has = set_prototype.contain

--- Alias for `empty`. Clears all items from the set.
-- @function SetObject:clear
-- @see SetObject:empty
set_prototype.clear = set_prototype.empty

--- Alias for `remove`. Removes a value from the set.
-- @function SetObject:delete
-- @param value any The value to remove.
-- @see SetObject:remove
set_prototype.delete = set_prototype.remove

---@type SetModule
-- @field new fun(...?:any):SetObject Creates a new SetObject.
-- @field from_array fun(array:table):SetObject Creates a new SetObject from an array.
-- Also callable directly via `lib.set(...)` as a shortcut for `new(...)`.
lib_module = setmetatable({
    new = set_prototype.new,
    from_array = set_prototype.from_array,
}, {
    -- Allows lib.set(...) to act as lib.set.new(...)
    __call = function(_, ...)
        return set_prototype.new(...)
    end,
})
