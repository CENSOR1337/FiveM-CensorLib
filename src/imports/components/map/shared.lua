--- Provides an ordered map (dictionary) data structure.
-- This module implements a map where keys maintain their insertion order.
-- It supports basic map operations like set, get, delete, has, clear, and iteration.
-- Keys can be strings, numbers, or booleans.
-- @module map

local table_wipe = table.wipe -- For efficient table clearing

--- @class OrderedMap Represents an ordered map.
-- Stores key-value pairs in insertion order.
-- @field data table Internal list storing `{key, value}` pairs in order.
-- @field index table Internal lookup table mapping keys to their position in `data`.
-- @field size number The number of key-value pairs in the map.
local ordered_map_prototype = {}
ordered_map_prototype.__index = ordered_map_prototype

--- Creates a new, empty OrderedMap instance.
-- @return OrderedMap A new OrderedMap object.
-- @usage local myMap = lib.map.new()
function ordered_map_prototype.new()
    local self = setmetatable({}, ordered_map_prototype)
    self.data = {}  -- Stores {key=k, value=v} tables
    self.index = {} -- Maps key to its numeric index in self.data
    self.size = 0
    return self
end

--- Creates a new OrderedMap from an array of key-value pairs.
-- Each element in the input array should be a table containing two elements: `[1]` as key and `[2]` as value.
-- @param array table An array of tables, where each inner table is `{key, value}`.
-- @return OrderedMap A new OrderedMap populated with the items from the array.
-- @usage
-- local data = { {"name", "Player"}, {"score", 100} }
-- local myMap = lib.map.from_array(data)
-- -- Alternatively, using the callable module directly:
-- -- local myMap = lib.map({ {"name", "Player"}, {"score", 100} })
function ordered_map_prototype.from_array(array)
    lib.validate.type.assert(array, "table", "OrderedMap.from_array input")

    local self = ordered_map_prototype.new()
    for i = 1, #array do
        local entry = array[i]
        lib.validate.type.assert(entry, "table", ("OrderedMap.from_array entry #%d"):format(i))
        assert(#entry == 2, ("OrderedMap.from_array entry #%d requires a table with two elements {key, value}"):format(i))
        self:set(entry[1], entry[2])
    end
    return self
end

--- Clears all entries from the map.
-- Resets the map to an empty state.
-- @usage myMap:clear()
function ordered_map_prototype:clear()
    table_wipe(self.data)
    table_wipe(self.index)
    self.size = 0
end

--- Deletes an entry from the map by its key.
-- If the key exists, the entry is removed, and subsequent entries are re-indexed.
-- @param key string|number|boolean The key of the entry to delete.
-- @return boolean True if the entry existed and was removed, false otherwise.
-- @usage local wasDeleted = myMap:delete("score")
function ordered_map_prototype:delete(key)
    lib.validate.type.assert(key, "string", "number", "boolean", "OrderedMap:delete key")

    local pos = self.index[key]
    if not pos then return false end

    -- Remove element from data array
    table.remove(self.data, pos)
    self.index[key] = nil -- Remove from direct lookup
    self.size = self.size - 1

    -- Rebuild index for elements that were shifted
    -- Only elements after the removed one need their index updated.
    for i = pos, self.size do
        local entry = self.data[i]
        self.index[entry.key] = i
    end

    return true
end

--- Iterates over the map and calls a function for each key-value pair in insertion order.
-- @param func function The function to call for each pair. It receives `key` and `value` as arguments.
-- @usage
-- myMap:for_each(function(key, value)
--   print(key, value)
-- end)
function ordered_map_prototype:for_each(func)
    lib.validate.type.assert(func, "function", "OrderedMap:for_each callback")

    for i = 1, self.size do
        local entry = self.data[i]
        if entry then -- Check if entry exists, though it should with correct size mgmt
            func(entry.key, entry.value)
        end
    end
end

--- Retrieves a value from the map by its key.
-- @param key string|number|boolean The key of the value to retrieve.
-- @return any The value associated with the key, or `nil` if the key is not found.
-- @usage local score = myMap:get("score")
function ordered_map_prototype:get(key)
    lib.validate.type.assert(key, "string", "number", "boolean", "OrderedMap:get key")

    local pos = self.index[key]
    return pos and self.data[pos] and self.data[pos].value or nil
end

--- Checks if a key exists in the map.
-- @param key string|number|boolean The key to check for.
-- @return boolean True if the key exists, false otherwise.
-- @usage if myMap:has("name") then print("Name exists!") end
function ordered_map_prototype:has(key)
    lib.validate.type.assert(key, "string", "number", "boolean", "OrderedMap:has key")
    return self.index[key] ~= nil
end

--- Sets a value for a key in the map.
-- If the key already exists, its value is updated.
-- If the key does not exist, a new entry is added to the end of the map.
-- @param key string|number|boolean The key to set.
-- @param value any The value to associate with the key.
-- @usage
-- myMap:set("level", 5)
-- myMap:set("name", "New Player")
function ordered_map_prototype:set(key, value)
    lib.validate.type.assert(key, "string", "number", "boolean", "OrderedMap:set key")

    local pos = self.index[key]
    if pos then
        -- Key exists, update value
        self.data[pos].value = value
    else
        -- Key does not exist, add new entry
        local entry = { key = key, value = value }
        table.insert(self.data, entry)
        self.size = self.size + 1
        self.index[key] = self.size -- New entry is at the end, so its index is the new size
    end
end

---@type OrderedMapModule
-- @field new fun():OrderedMap Creates a new, empty OrderedMap.
-- @field from_array fun(array:table):OrderedMap Creates a new OrderedMap from an array of key-value pairs.
-- Also callable directly via `lib.map({...})` as a shortcut for `from_array`.
lib_module = setmetatable({
    new = ordered_map_prototype.new,
    from_array = ordered_map_prototype.from_array,
}, {
    -- Allows calling lib.map({...}) as a shortcut for from_array
    __call = function(_, array_data)
        lib.validate.type.assert(array_data, "table", "lib.map() call")
        return ordered_map_prototype.from_array(array_data)
    end,
})
