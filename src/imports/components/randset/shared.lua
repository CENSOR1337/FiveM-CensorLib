--- Provides a "random set" or "chance pool" functionality.
-- This module allows creating a collection of items where each item has an associated
-- "chance" or "weight". It can then randomly select an item from this set,
-- respecting the chances of each item.
-- @module randset

--- @class ChancePoolObject Represents a pool of items, each with a specific chance of being selected.
-- Items are added with a numerical chance value. The `random()` method then selects
-- an item based on these chances using a cumulative probability distribution.
-- @field pool table Internal storage for items. It's a dictionary mapping unique keys (numbers)
--               to tables, where each table is `{ chance = number, data = any, chance_end = number }`.
-- @field key number An internal counter to generate unique keys for items in the pool.
-- @field cumulative number The sum of all chances of items currently in the pool. Used for random selection.
local chance_pool_prototype = {}
chance_pool_prototype.__index = chance_pool_prototype

--- Creates a new, empty ChancePoolObject.
-- @param ... any (Not used) Placeholder for potential future arguments, currently ignored.
-- @return ChancePoolObject A new chance pool object.
-- @usage
-- local lootTable = lib.randset.chance_pool.new()
-- -- or using the callable module:
-- local anotherLootTable = lib.randset.chance_pool()
function chance_pool_prototype.new(...)
    local self = setmetatable({}, chance_pool_prototype)
    self.pool = {}         -- Stores item_key -> { chance, data, chance_end }
    self.key = 10          -- Initial key for item IDs, will be incremented
    self.cumulative = 0    -- Sum of all chances
    return self
end

--- Recalculates the cumulative chances for all items in the pool.
-- This is called internally after adding or removing items. It updates the
-- `chance_end` for each item, which is used by the `random()` method.
-- @local
function chance_pool_prototype:calculate_cumulative()
    self.cumulative = 0
    local current_cumulative = 0 -- Use a local accumulator for clarity
    for _, item_data in pairs(self.pool) do -- Iterate over values (item data tables)
        current_cumulative = current_cumulative + item_data.chance
        item_data.chance_end = current_cumulative
    end
    self.cumulative = current_cumulative -- Assign the final sum
end

--- Adds an item to the chance pool with a specified chance.
-- The `data` can be any value you want to retrieve when this item is selected.
-- After adding, cumulative chances are recalculated.
-- @param chance number The numerical chance (or weight) for this item. Must be positive.
-- @param data any The actual data/item to be stored and potentially returned by `random()`.
-- @return number A unique key assigned to this item within the pool, which can be used to remove it.
-- @usage
-- local commonItemId = lootTable:add_item(100, "Common Sword")
-- local rareItemId = lootTable:add_item(10, "Rare Shield")
function chance_pool_prototype:add_item(chance, data)
    lib.validate.type.assert(chance, "number", "Item chance")
    assert(chance > 0, "Item chance must be a positive number")
    assert(data ~= nil, "Item data is required") -- Allow false, 0 as data

    self.key = self.key + 1
    self.pool[self.key] = { chance = chance, data = data }
    self:calculate_cumulative()
    return self.key
end

--- Removes an item from the chance pool using its key.
-- After removal, cumulative chances are recalculated.
-- @param key number The unique key of the item to remove (returned by `add_item`).
-- @usage lootTable:remove_item(commonItemId)
function chance_pool_prototype:remove_item(key)
    lib.validate.type.assert(key, "number", "Item key for removal")

    if self.pool[key] then
        self.pool[key] = nil
        self:calculate_cumulative()
    end
end

--- Randomly selects an item from the pool based on the chances of each item.
-- Returns `nil` if the pool is empty or if all items have a chance of zero.
-- @return any The `data` of the selected item, or `nil` if no item could be selected.
-- @usage
-- local selectedLoot = lootTable:random()
-- if selectedLoot then
--   print("You got:", selectedLoot)
-- end
function chance_pool_prototype:random()
    if self.cumulative == 0 then return nil end -- No items or all chances are zero

    -- math.random() returns [0,1). Multiply by cumulative to get a value in [0, cumulative_chance_sum).
    -- Adding a small epsilon or ensuring math.random(0, self.cumulative) if the native supports it might be more robust
    -- for edge cases, but standard math.random() * total usually works if chances are integers.
    -- If chances can be floats, this is fine.
    local random_value = math.random() * self.cumulative

    -- Iterate through the pool (order doesn't strictly matter here due to chance_end)
    for _, item_data in pairs(self.pool) do
        -- An item is chosen if random_value falls within its segment of the cumulative distribution.
        -- The segment starts after the previous item's chance_end (or 0) and ends at its own chance_end.
        -- So, if random_value is less than or equal to item_data.chance_end, it falls in this item's range
        -- (assuming items are checked in an order consistent with how chance_end was calculated,
        -- or more simply, just checking <= chance_end works because chance_end is strictly increasing for positive chances).
        if random_value <= item_data.chance_end then
            return item_data.data
        end
    end
    -- Should ideally not be reached if cumulative > 0 and math.random() behaves as expected,
    -- unless floating point inaccuracies cause random_value to be exactly self.cumulative
    -- and the last item's check fails. Or if all items have chance 0 (covered by cumulative check).
    -- Can add a fallback to the last item if needed, but usually not necessary.
    return nil
end

---@type RandSetModule
-- @field new fun(...?:any):ChancePoolObject Creates a new ChancePoolObject.
-- Also callable directly via `lib.randset.chance_pool(...)` as a shortcut for `new()`.
lib_module.chance_pool = setmetatable(
    { new = chance_pool_prototype.new },
    {
        __call = function(t, ...) -- t is lib_module.chance_pool itself
            return chance_pool_prototype.new(...)
        end,
    }
)
