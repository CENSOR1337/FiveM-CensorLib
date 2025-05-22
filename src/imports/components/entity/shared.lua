--- Provides a unified interface for creating and managing game entities (vehicles, peds, objects).
-- This module abstracts the underlying FiveM natives for entity creation, deletion,
-- and lifecycle management, offering an object-oriented approach.
-- It handles asynchronous model loading and provides delegates for creation/destruction events.
-- @module entity

--- @type table Cache of native FiveM functions used by this module.
-- @local
local native = {
    create_thread_now = Citizen.CreateThreadNow,
    citizen_await = Citizen.Await,
    create_vehicle_server_setter = CreateVehicleServerSetter,
    create_vehicle = CreateVehicle,
    create_ped = CreatePed,
    create_object_no_offset = CreateObjectNoOffset,
    set_entity_coords = SetEntityCoords,
    set_entity_rotation = SetEntityRotation,
    does_entity_exist = DoesEntityExist,
    delete_entity = DeleteEntity,
}

--- @type table Maps entity type names to internal numeric identifiers.
-- @field vehicle number Identifier for vehicle entities.
-- @field ped number Identifier for ped entities.
-- @field object number Identifier for object entities.
-- @local
local entity_types = {
    vehicle = 1,
    ped = 2,
    object = 3,
}

--- Helper function to create a vehicle, handling server/client differences.
-- @param model string|number The model hash or name of the vehicle.
-- @param position vector3 The initial position of the vehicle.
-- @param rotation vector3 The initial rotation of the vehicle (typically only Z is used for initial spawn heading).
-- @param is_networked boolean True if the vehicle should be networked (client-only consideration).
-- @return number The handle of the created vehicle.
-- @local
local function create_vehicle_internal(model, position, rotation, is_networked)
    local entity_handle

    if lib.is_server then
        -- Note: CreateVehicleServerSetter is specific and might have different behavior.
        -- Standard server-side vehicle creation is just CreateVehicle.
        -- Assuming CreateVehicleServerSetter is a custom native or specific use case.
        entity_handle = native.create_vehicle_server_setter(model, "automobile", position.x, position.y, position.z, rotation.z or 0.0)
    else
        entity_handle = native.create_vehicle(model, position.x, position.y, position.z, rotation.z or 0.0, is_networked, false)
    end

    return entity_handle
end

--- @class EntityObject Base class for managed game entities.
-- Provides methods for creation, destruction, and lifecycle events.
-- @field model string|number The model hash or name of the entity.
-- @field is_networked boolean True if the entity is intended to be networked.
-- @field handle number The native handle of the game entity. Defaults to -1 until created.
-- @field destroyed boolean True if this entity object has been marked for destruction.
-- @field delegate_on_created DelegateObject Delegate triggered when the entity is successfully created.
-- @field delegate_on_destroyed DelegateObject Delegate triggered when the entity is destroyed.
local entity_prototype = {}
entity_prototype.__index = entity_prototype
entity_prototype.__instances = {} -- Tracks all active EntityObject instances by their handle.

-- Cleanup all managed entities when the resource stops.
lib.resource.on_stop(function()
    for handle, instance in pairs(entity_prototype.__instances) do
        if instance.destroy and type(instance.destroy) == "function" then
            instance:destroy()
        end
    end
    entity_prototype.__instances = {} -- Clear the tracking table
end)

--- Base constructor for a new managed entity.
-- This is typically called by the constructors of specific entity types (Vehicle, Ped, Object).
-- @param model string|number The model name (string) or hash (number) of the entity.
-- @param position vector3 A table {x, y, z} or vector3 for the entity's initial position.
-- @param rotation vector3 A table {x, y, z} or vector3 for the entity's initial rotation.
-- @param entity_type_id number Internal numeric ID for the entity type (from `entity_types`).
-- @param is_network boolean (Optional) If the entity should be network-synced. Defaults to true on server, false on client if nil.
-- @return EntityObject A new EntityObject instance.
-- @nodoc (Internal use by derived classes)
function entity_prototype.new(model, position, rotation, entity_type_id, is_network)
    lib.validate.type.assert(model, "string", "number", "Entity model")
    lib.validate.type.assert(position, "vector3", "vector4", "table", "Entity position")
    lib.validate.type.assert(rotation, "vector3", "vector4", "table", "Entity rotation")

    if is_network == nil then
        is_network = lib.is_server -- Default to networked on server, local on client
    else
        lib.validate.type.assert(is_network, "boolean", "Entity is_network flag")
    end

    local self = setmetatable({}, entity_prototype)
    self.model = type(model) == "number" and model or joaat(model)
    self.is_networked = is_network
    self.handle = -1
    self.destroyed = false
    self.delegate_on_created = lib.delegate()
    self.delegate_on_destroyed = lib.delegate()

    -- Asynchronous initialization
    native.create_thread_now(function()
        if not lib.is_server then
            lib.streaming.model.request(self.model).await()
        end

        if self.destroyed then -- Check if destroy() was called before creation completed
            if not lib.is_server then lib.streaming.model.clear(self.model) end
            return
        end

        if entity_type_id == entity_types.vehicle then
            self.handle = create_vehicle_internal(self.model, position, rotation, self.is_networked)
        elseif entity_type_id == entity_types.ped then
            self.handle = native.create_ped(4, self.model, position.x, position.y, position.z, rotation.z or 0.0, self.is_networked, false)
        elseif entity_type_id == entity_types.object then
            self.handle = native.create_object_no_offset(self.model, position.x, position.y, position.z, self.is_networked, false, false)
        else
            error("Unknown entity type ID: " .. tostring(entity_type_id), 2)
        end

        if self.handle and self.handle ~= 0 and native.does_entity_exist(self.handle) then
            entity_prototype.__instances[self.handle] = self
            -- Set final coords/rotation as creation might not always place it perfectly or if using server setters.
            native.set_entity_coords(self.handle, position.x, position.y, position.z, false, false, false, true) -- last arg 'clearArea'
            native.set_entity_rotation(self.handle, rotation.x or 0.0, rotation.y or 0.0, rotation.z or 0.0, 2, true) -- order 2 (YXZ), last arg 'andApplyMatrix'
            self.delegate_on_created:broadcast(self)
        else
            -- Handle creation failure
            if not lib.is_server then lib.streaming.model.clear(self.model) end
            self.destroyed = true -- Mark as destroyed if creation failed
            self.delegate_on_destroyed:broadcast(self) -- Notify of "destruction" due to failure
        end

        -- Clear model only if client and creation was successful or if it failed before handle was set
        if not lib.is_server and (self.handle == -1 or not native.does_entity_exist(self.handle)) then
             -- if handle is still -1 or entity does not exist, it means creation failed or was aborted.
             lib.streaming.model.clear(self.model)
        end
    end)

    return self
end

--- Registers a callback to be invoked once the entity has been successfully created.
-- If the entity is already valid when called, the callback is invoked immediately.
-- The callback is automatically unbound after its first invocation.
-- @param callback function The function to call. Receives the EntityObject instance as its first argument.
-- @usage
-- myEntity:on_created(function(entity)
--   print("Entity " .. entity.handle .. " created!")
-- end)
function entity_prototype:on_created(callback)
    lib.validate.type.assert(callback, "function", "on_created callback")

    if self:is_valid() then
        callback(self)
        return
    end

    if self.destroyed then return end -- Don't add listener if already marked for destruction

    local delegate_handle
    delegate_handle = self.delegate_on_created:add(function()
        callback(self)
        self.delegate_on_created:remove(delegate_handle) -- Auto-remove after firing
    end)
end

--- Registers a callback to be invoked once the entity is destroyed (or fails to create).
-- If the entity is already marked as destroyed, the callback is invoked immediately.
-- The callback is automatically unbound after its first invocation.
-- @param callback function The function to call. Receives the EntityObject instance as its first argument.
-- @usage
-- myEntity:on_destroyed(function(entity)
--   print("Entity " .. entity.handle .. " destroyed.")
-- end)
function entity_prototype:on_destroyed(callback)
    lib.validate.type.assert(callback, "function", "on_destroyed callback")

    if self.destroyed then
        callback(self)
        return
    end

    local delegate_handle
    delegate_handle = self.delegate_on_destroyed:add(function()
        callback(self)
        self.delegate_on_destroyed:remove(delegate_handle) -- Auto-remove after firing
    end)
end

--- Pauses the current thread until the entity has been successfully created.
-- @return boolean True if creation was successful (always true if it resumes).
-- @usage
-- Citizen.CreateThread(function()
--   myEntity:wait_for_creation()
--   print("Entity is ready to use:", myEntity.handle)
-- end)
function entity_prototype:wait_for_creation()
    if self:is_valid() then return true end
    if self.destroyed then return false end -- Already destroyed/failed

    local p = promise.new()
    self:on_created(function()
        p:resolve(true)
    end)
    -- Add a timeout or a check for destruction to prevent infinite wait
    self:on_destroyed(function()
        if p:getStatus() == promise.PENDING then p:resolve(false) end
    end)

    return native.citizen_await(p)
end

--- Checks if the underlying game entity currently exists.
-- @return boolean True if the entity handle is valid and the entity exists in the game world.
function entity_prototype:is_valid()
    return self.handle ~= -1 and native.does_entity_exist(self.handle)
end

--- Destroys the managed entity.
-- Marks the entity as destroyed, invokes `on_destroyed` listeners,
-- and deletes the game entity if it exists.
-- Subsequent calls to `is_valid()` will return false.
function entity_prototype:destroy()
    if self.destroyed then return end -- Already processed
    self.destroyed = true

    if self:is_valid() then
        native.delete_entity(self.handle)
        if entity_prototype.__instances[self.handle] then
            entity_prototype.__instances[self.handle] = nil
        end
    end
    -- If model was requested and not yet cleared (e.g. destruction before creation completed)
    if not lib.is_server then
        lib.streaming.model.clear(self.model)
    end

    self.delegate_on_destroyed:broadcast(self)
    self.delegate_on_created:empty() -- Clear any pending creation listeners
    self.delegate_on_destroyed:empty() -- Clear destruction listeners after broadcast
    self.handle = -1 -- Invalidate handle
end

--- @class ObjectEntity : EntityObject Represents a managed object (prop) entity.
local object_class_prototype = {}
object_class_prototype.__index = object_class_prototype
setmetatable(object_class_prototype, { __index = entity_prototype }) -- Inherit from EntityObject

--- Creates a new managed ObjectEntity.
-- @param model string|number The model name or hash of the object.
-- @param position vector3 The initial position.
-- @param rotation vector3 The initial rotation.
-- @param is_network boolean (Optional) Networked status. Defaults appropriately.
-- @return ObjectEntity A new object entity instance.
-- @see lib.entity.new (for general constructor pattern)
function object_class_prototype.new(model, position, rotation, is_network)
    local self = entity_prototype.new(model, position, rotation, entity_types.object, is_network)
    return setmetatable(self, object_class_prototype)
end

--- @class PedEntity : EntityObject Represents a managed ped entity.
local ped_class_prototype = {}
ped_class_prototype.__index = ped_class_prototype
setmetatable(ped_class_prototype, { __index = entity_prototype }) -- Inherit from EntityObject

--- Creates a new managed PedEntity.
-- @param model string|number The model name or hash of the ped.
-- @param position vector3 The initial position.
-- @param rotation vector3 The initial rotation (heading is typically rotation.z).
-- @param is_network boolean (Optional) Networked status. Defaults appropriately.
-- @return PedEntity A new ped entity instance.
function ped_class_prototype.new(model, position, rotation, is_network)
    local self = entity_prototype.new(model, position, rotation, entity_types.ped, is_network)
    return setmetatable(self, ped_class_prototype)
end

--- @class VehicleEntity : EntityObject Represents a managed vehicle entity.
local vehicle_class_prototype = {}
vehicle_class_prototype.__index = vehicle_class_prototype
setmetatable(vehicle_class_prototype, { __index = entity_prototype }) -- Inherit from EntityObject

--- Creates a new managed VehicleEntity.
-- @param model string|number The model name or hash of the vehicle.
-- @param position vector3 The initial position.
-- @param rotation vector3 The initial rotation (heading is typically rotation.z).
-- @param is_network boolean (Optional) Networked status. Defaults appropriately.
-- @return VehicleEntity A new vehicle entity instance.
function vehicle_class_prototype.new(model, position, rotation, is_network)
    local self = entity_prototype.new(model, position, rotation, entity_types.vehicle, is_network)
    return setmetatable(self, vehicle_class_prototype)
end

--- Utility to wrap class prototypes for callable 'new' syntax.
-- @param class_proto table The class prototype with a `new` method.
-- @return table A table that can be called to invoke `class_proto.new`.
-- @local
local function classwarp(class_proto)
    return setmetatable({
        new = class_proto.new,
    }, {
        __call = function(t, ...) -- t is this new table itself
            return t.new(...)
        end,
    })
end

---@section Entity Constructors
-- These are callable constructors for creating specific managed entity instances.
-- @usage
-- local myCar = lib.entity.vehicle("adder", vec3(100,100,70), vec3(0,0,90))
-- myCar:on_created(function(car) print("Car created:", car.handle) end)
--
-- local myPed = lib.entity.ped("a_m_m_farmer_01", vec3(105,100,70), vec3(0,0,180))
--
-- local myProp = lib.entity.object("prop_barrel_01a", vec3(110,100,70), vec3(0,0,0))

--- Creates a new PedEntity.
-- @function lib.entity.ped
-- @param model string|number Ped model.
-- @param position vector3 Initial position.
-- @param rotation vector3 Initial rotation.
-- @param is_network boolean (Optional) Networked status.
-- @return PedEntity
lib_module.ped = classwarp(ped_class_prototype)

--- Creates a new ObjectEntity.
-- @function lib.entity.object
-- @param model string|number Object model.
-- @param position vector3 Initial position.
-- @param rotation vector3 Initial rotation.
-- @param is_network boolean (Optional) Networked status.
-- @return ObjectEntity
lib_module.object = classwarp(object_class_prototype)

--- Creates a new VehicleEntity.
-- @function lib.entity.vehicle
-- @param model string|number Vehicle model.
-- @param position vector3 Initial position.
-- @param rotation vector3 Initial rotation.
-- @param is_network boolean (Optional) Networked status.
-- @return VehicleEntity
lib_module.vehicle = classwarp(vehicle_class_prototype)
