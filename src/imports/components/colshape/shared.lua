--- Manages and creates various types of collision shapes (colshapes).
-- This module provides classes for creating Circle, Sphere, and Polygon colshapes,
-- along with methods for checking if a position is inside them and for drawing
-- debug visualizations (client-only). It utilizes the `glm` library for polygon calculations.
-- @module colshape
-- @see glm

-- a huge courtesy to overextended team for usage of glm library

local glm = require "glm"
--- @type function Shortcut to glm.polygon.contains.
-- @local
local glm_polygon_contains = glm.polygon.contains

local numdeci = function(value) return value + 0.0 end -- Ensures float representation

--- @type table Cache of native FiveM functions.
-- @local
local native = {
    draw_marker = DrawMarker,
    draw_box = DrawBox, -- Not used in current snippet, but kept if part of original intent
    player_ped_id = PlayerPedId,
    get_entity_coords = GetEntityCoords,
    draw_line = DrawLine,
    draw_poly = DrawPoly,
    world3d_to_screen2d = World3dToScreen2d,
    set_text_scale = SetTextScale,
    set_text_colour = SetTextColour,
    set_text_dropshadow = SetTextDropshadow,
    set_text_edge = SetTextEdge,
    set_text_outline = SetTextOutline,
    set_text_entry = SetTextEntry,
    add_text_component_string = AddTextComponentString,
    draw_text = DrawText,
}

--- Draws 3D text at a given point for debugging. (Client-only)
-- @param text string The text to draw.
-- @param point vector3 The world coordinates (x, y, z) where the text should be drawn.
-- @local
local function draw_text_3d_dbg(text, point)
    local on_screen, x, y = native.world3d_to_screen2d(point.x, point.y, point.z)
    if not (on_screen) then return end

    native.set_text_scale(0.0, 0.25)
    native.set_text_colour(255, 255, 255, 255)
    native.set_text_dropshadow(0, 0, 0, 0, 255)
    native.set_text_edge(2, 0, 0, 0, 150)
    native.set_text_outline()
    native.set_text_entry("STRING")
    native.add_text_component_string(text)
    native.draw_text(x, y)
end

--- Draws a debug marker and distance text for a colshape's origin. (Client-only)
-- @param colshape ColshapeBase The colshape object (must have an `origin` field).
-- @local
local function draw_origin_dbg(colshape)
    local origin = colshape.origin
    local position = GetEntityCoords(PlayerPedId(), false)
    local dist = #(origin.xyz - position) -- Assuming origin is vec3, .xyz is fine. If origin can be vec4, ensure proper access.
    native.draw_marker(28, origin.x, origin.y, origin.z, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.5, 255, 0, 0, 255, false, false, 2, false, nil, nil, false)
    draw_text_3d_dbg(("%.4f"):format(dist), origin)
end

--- Wraps a colshape class definition to provide a callable constructor and an `is_a` method.
-- @param class table The colshape class table (e.g., `colshape_circle`).
-- @return table A metatable-wrapped version of the class, callable as a constructor.
-- @local
local function colshape_classwarp(class, ...)
    return setmetatable({
        new = class.new,
        --- Checks if an object is an instance of this specific colshape class.
        -- @param self table The wrapped class itself.
        -- @param obj table The object to check.
        -- @return boolean True if `obj` is an instance of this class.
        is_a = function(self, obj)
            return getmetatable(obj) == class
        end,
    }, {
        -- Allows calling the wrapped class table directly as a constructor.
        __call = function(t, ...)
            return t.new(...)
        end,
    })
end

--- @class ColshapeBase Base class for all colshapes.
-- Not intended to be instantiated directly but provides common structure.
-- @field origin vector3 The calculated center or origin point of the colshape.
local colshape_prototype = {}
colshape_prototype.__index = colshape_prototype

--- Base constructor for colshapes. Initializes common properties.
-- @return ColshapeBase A new base colshape instance.
-- @nodoc (Not directly used, part of specific colshape constructors)
function colshape_prototype.new()
    local self = {}
    self.origin = vec(0.0, 0.0, 0.0) -- Default origin

    return setmetatable(self, colshape_prototype)
end

--- Checks if a given 3D position is inside the colshape.
-- This is a placeholder and should be overridden by specific colshape types.
-- @param position vector3 The position (x, y, z) to check.
-- @return boolean Always returns false for the base class.
function colshape_prototype:is_position_inside(position)
    return false
end

--- Draws a debug visualization of the colshape's origin. (Client-only)
-- Calls `draw_origin_dbg` internally. Specific colshape types should extend this
-- to draw their specific shape.
function colshape_prototype:draw_debug()
    if (lib.is_server) then return end
    draw_origin_dbg(self)
end

--- @class ColshapeCircle : ColshapeBase Represents a 2D circular colshape (ignores Z axis for containment).
-- @field radius number The radius of the circle.
-- @field position vector2 The 2D center (x, y) of the circle.
-- @field origin vector3 The 3D origin, with Z set to 0 for consistency in `draw_origin_dbg`.
local colshape_circle = {}
colshape_circle.__index = colshape_circle
setmetatable(colshape_circle, { __index = colshape_prototype }) -- Inherit from ColshapeBase

--- Creates a new 2D circular colshape.
-- @param position vector3|vector4|table A table or vector with x, y components for the center. Z is ignored for position but used for origin.
-- @param radius number The radius of the circle.
-- @return ColshapeCircle A new circle colshape object.
function colshape_circle.new(position, radius)
    lib.validate.type.assert(position, "vector3", "vector4", "table")
    lib.validate.type.assert(radius, "number")

    local self = setmetatable(colshape_prototype.new(), colshape_circle)
    self.radius = numdeci(radius)
    self.position = vec(position.x, position.y) -- Store as vec2 for 2D checks
    self.origin = vec(position.x, position.y, position.z or 0.0) -- Store original Z for debug or make it 0

    return self
end

--- Checks if a 2D position is inside the circle (ignores Z axis).
-- @param position vector3|vector4|table The position (x, y, z) to check. Only x and y are used.
-- @return boolean True if the 2D point is within the circle's radius.
function colshape_circle:is_position_inside(position)
    local point = vec(position.x, position.y)
    return #(point - self.position) <= self.radius
end

--- Draws the circle colshape as a marker. (Client-only)
-- @param r number Red color component (0-255).
-- @param g number Green color component (0-255).
-- @param b number Blue color component (0-255).
-- @param a number Alpha component (0-255).
function colshape_circle:draw(r, g, b, a)
    if (lib.is_server) then return end
    local pos = self.position
    local rad = self.radius
    -- Draws a flat cylinder marker that extends very far up and down to appear as a 2D circle from top view.
    native.draw_marker(1, pos.x, pos.y, (self.origin.z or 0.0) - 1.0, 0, 0, 0, 0, 0, 0, rad * 2.0, rad * 2.0, 2.0, r, g, b, a, false, false, 2, false, nil, nil, false)
end

--- Draws a debug visualization of the circle colshape. (Client-only)
-- Shows the origin, and the circle colored based on whether the local player is inside.
function colshape_circle:draw_debug()
    if (lib.is_server) then return end
    colshape_prototype.draw_debug(self) -- Call base to draw origin

    local ped = native.player_ped_id()
    local coords = native.get_entity_coords(ped)
    local is_local_ped_inside = self:is_position_inside(coords)
    local color = is_local_ped_inside and { r = 0, g = 255, b = 0, a = 75 } or { r = 0, g = 0, b = 255, a = 75 }
    self:draw(color.r, color.g, color.b, color.a)
end

--- @class ColshapeSphere : ColshapeBase Represents a 3D spherical colshape.
-- @field radius number The radius of the sphere.
-- @field position vector3 The 3D center (x, y, z) of the sphere.
-- @field origin vector3 Same as `position` for spheres.
local colshape_sphere = {}
colshape_sphere.__index = colshape_sphere
setmetatable(colshape_sphere, { __index = colshape_prototype }) -- Inherit from ColshapeBase

--- Creates a new 3D spherical colshape.
-- @param position vector3|vector4|table A table or vector with x, y, z components for the center.
-- @param radius number The radius of the sphere.
-- @return ColshapeSphere A new sphere colshape object.
function colshape_sphere.new(position, radius)
    lib.validate.type.assert(position, "vector3", "vector4", "table")
    lib.validate.type.assert(radius, "number")

    local self = setmetatable(colshape_prototype.new(), colshape_sphere)
    self.radius = numdeci(radius)
    self.position = vec(position.x, position.y, position.z)
    self.origin = self.position -- For spheres, origin is the same as position

    return self
end

--- Checks if a 3D position is inside the sphere.
-- @param position vector3|vector4|table The position (x, y, z) to check.
-- @return boolean True if the point is within the sphere's radius.
function colshape_sphere:is_position_inside(position)
    return #(vec(position.x, position.y, position.z) - self.position) <= self.radius
end

--- Draws the sphere colshape as a marker. (Client-only)
-- @param r number Red color component (0-255).
-- @param g number Green color component (0-255).
-- @param b number Blue color component (0-255).
-- @param a number Alpha component (0-255).
function colshape_sphere:draw(r, g, b, a)
    if (lib.is_server) then return end
    local f_radius = numdeci(self.radius)
    native.draw_marker(28, self.position.x, self.position.y, self.position.z, 0,0,0,0,0,0, f_radius, f_radius, f_radius, r,g,b,a, false, false, 0, false, nil,nil,false)
end

--- Draws a debug visualization of the sphere colshape. (Client-only)
-- Shows the origin (same as position), and the sphere colored based on whether the local player is inside.
function colshape_sphere:draw_debug()
    if (lib.is_server) then return end
    -- For sphere, draw_origin_dbg is redundant if origin is same as position and marker is drawn at position.
    -- However, calling base ensures consistency if base behavior changes.
    colshape_prototype.draw_debug(self)

    local ped = native.player_ped_id()
    local coords = native.get_entity_coords(ped)
    local is_local_ped_inside = self:is_position_inside(coords)
    local color = is_local_ped_inside and { r = 0, g = 255, b = 0, a = 75 } or { r = 0, g = 0, b = 255, a = 75 }
    self:draw(color.r, color.g, color.b, color.a)
end

--- @class ColshapePoly : ColshapeBase Represents a 3D polygonal colshape with min/max Z height.
-- @field points table A list of 2D vector-like points ({x, y}) defining the polygon's vertices.
-- @field min_z number The minimum Z height of the polygon colshape.
-- @field max_z number The maximum Z height of the polygon colshape.
-- @field polygon table The internal `glm.polygon` object.
-- @field thickness number The thickness of the polygon for containment checks, derived from Z range.
-- @field origin vector3 The calculated centroid of the polygon base at average Z height.
local colshape_poly = {}
colshape_poly.__index = colshape_poly
setmetatable(colshape_poly, { __index = colshape_prototype }) -- Inherit from ColshapeBase

--- Creates a new 3D polygonal colshape.
-- @param in_points table A list of tables, each with `x` and `y` keys, defining the 2D vertices of the polygon base.
-- @param in_min_z number The minimum Z value for the colshape volume. Defaults to -10000.0.
-- @param in_max_z number The maximum Z value for the colshape volume. Defaults to 10000.0.
-- @return ColshapePoly A new polygon colshape object.
function colshape_poly.new(in_points, in_min_z, in_max_z)
    in_min_z = numdeci(in_min_z or -10000.0)
    in_max_z = numdeci(in_max_z or 10000.0)

    lib.validate.type.assert(in_points, "table")
    lib.validate.type.assert(in_min_z, "number")
    lib.validate.type.assert(in_max_z, "number")
    assert(#in_points >= 3, "ColshapePoly requires at least 3 points")

    local self = setmetatable(colshape_prototype.new(), colshape_poly)
    self.points = {} -- Stores vec3 points at average Z for internal polygon
    self.min_z = in_min_z
    self.max_z = in_max_z
    local poly_z_center = (self.min_z + self.max_z) / 2.0

    local origin_sum_x, origin_sum_y = 0.0, 0.0
    for i = 1, #in_points do
        local pt = in_points[i]
        lib.validate.type.assert(pt.x, "number", ("ColshapePoly point %d x"):format(i))
        lib.validate.type.assert(pt.y, "number", ("ColshapePoly point %d y"):format(i))
        self.points[i] = vec(pt.x, pt.y, poly_z_center) -- Use poly_z_center for glm.polygon
        origin_sum_x = origin_sum_x + pt.x
        origin_sum_y = origin_sum_y + pt.y
    end
    self.polygon = glm.polygon.new(self.points)
    -- Thickness for glm.polygon.contains is half the total height deviation from the polygon's plane.
    -- Since points are at poly_z_center, thickness is (max_z - min_z) / 2.
    self.thickness = (self.max_z - self.min_z) / 2.0

    self.origin = vec(origin_sum_x / #self.points, origin_sum_y / #self.points, poly_z_center)

    return self
end

--- Checks if a 3D position is inside the polygon colshape (considers Z range and polygon area).
-- @param position vector3|vector4|table The position (x, y, z) to check.
-- @return boolean True if the point is within the polygon's 2D area and Z height range.
function colshape_poly:is_position_inside(position)
    local point_z = numdeci(position.z)
    if point_z < self.min_z or point_z > self.max_z then
        return false -- Outside Z range
    end
    -- For glm.polygon.contains, the Z of the point should be relative to the polygon's plane (poly_z_center).
    -- Or, ensure the point passed to contains has Z = poly_z_center.
    local point_for_check = vec(position.x, position.y, (self.min_z + self.max_z) / 2.0)
    return glm_polygon_contains(self.polygon, point_for_check, self.thickness)
end

--- Draws the polygon colshape using `DrawPoly`. (Client-only)
-- @param r number Red color component (0-255).
-- @param g number Green color component (0-255).
-- @param b number Blue color component (0-255).
-- @param a number Alpha component (0-255).
-- @param draw_lines boolean If true, also draws outline lines for the polygon walls (default false).
function colshape_poly:draw(r, g, b, a, draw_lines)
    if (lib.is_server) then return end

    -- Use original point X,Y but draw from actual min_z to max_z
    local in_points = self.polygon.points -- These are vec3 at poly_z_center
    local min_z_draw = self.min_z
    local max_z_draw = self.max_z

    for i = 1, #in_points do
        local p1_2d = in_points[i] -- vec3(x,y, poly_z_center)
        local p2_2d = in_points[(i % #in_points) + 1] -- vec3(x,y, poly_z_center)

        -- Draw faces of the prism
        native.draw_poly(p1_2d.x, p1_2d.y, min_z_draw, p2_2d.x, p2_2d.y, min_z_draw, p1_2d.x, p1_2d.y, max_z_draw, r,g,b,a)
        native.draw_poly(p2_2d.x, p2_2d.y, min_z_draw, p2_2d.x, p2_2d.y, max_z_draw, p1_2d.x, p1_2d.y, max_z_draw, r,g,b,a)
        -- Draw top and bottom faces (winding order might matter for culling if not double-sided)
        native.draw_poly(p1_2d.x, p1_2d.y, max_z_draw, p2_2d.x, p2_2d.y, max_z_draw, in_points[1].x, in_points[1].y, max_z_draw, r,g,b,a) -- Part of top
        native.draw_poly(p1_2d.x, p1_2d.y, min_z_draw, p2_2d.x, p2_2d.y, min_z_draw, in_points[1].x, in_points[1].y, min_z_draw, r,g,b,a) -- Part of bottom


        if (draw_lines) then
            -- Vertical lines at each vertex
            native.draw_line(p1_2d.x, p1_2d.y, min_z_draw, p1_2d.x, p1_2d.y, max_z_draw, 255,0,0,255)
            -- Horizontal lines for top and bottom edges
            native.draw_line(p1_2d.x, p1_2d.y, min_z_draw, p2_2d.x, p2_2d.y, min_z_draw, 255,0,0,255)
            native.draw_line(p1_2d.x, p1_2d.y, max_z_draw, p2_2d.x, p2_2d.y, max_z_draw, 255,0,0,255)
        end
    end
end

--- Draws a debug visualization of the polygon colshape. (Client-only)
-- Shows the origin, and the polygon colored based on whether the local player is inside.
-- Also draws outlines for the polygon walls.
function colshape_poly:draw_debug()
    if (lib.is_server) then return end
    colshape_prototype.draw_debug(self) -- Call base to draw origin

    local ped = native.player_ped_id()
    local coords = native.get_entity_coords(ped)
    local is_local_ped_inside = self:is_position_inside(coords)
    local color = is_local_ped_inside and { r = 0, g = 255, b = 0, a = 30 } or { r = 0, g = 0, b = 255, a = 30 } -- Reduced alpha for polys
    self:draw(color.r, color.g, color.b, color.a, true)
end

---@section Colshape Constructors
-- These are callable constructors for creating colshape instances.
-- @usage
-- local myCircle = lib.colshape.circle(vec3(10.0, 20.0, 5.0), 5.0)
-- if myCircle:is_position_inside(GetEntityCoords(PlayerPedId())) then print("Inside circle") end
--
-- local mySphere = lib.colshape.sphere(vec3(0.0, 0.0, 70.0), 10.0)
--
-- local points = { {x=0,y=0}, {x=10,y=0}, {x=10,y=10}, {x=0,y=10} }
-- local myPoly = lib.colshape.poly(points, 68.0, 72.0)

--- Creates a new 2D Circle colshape.
-- @function lib.colshape.circle
-- @param position vector3|vector4|table Center of the circle (x,y used).
-- @param radius number Radius of the circle.
-- @return ColshapeCircle The created circle colshape.
lib_module.circle = colshape_classwarp(colshape_circle)

--- Creates a new 3D Sphere colshape.
-- @function lib.colshape.sphere
-- @param position vector3|vector4|table Center of the sphere (x,y,z).
-- @param radius number Radius of the sphere.
-- @return ColshapeSphere The created sphere colshape.
lib_module.sphere = colshape_classwarp(colshape_sphere)

--- Creates a new 3D Polygon colshape.
-- @function lib.colshape.poly
-- @param points table Array of 2D points {x,y} defining the polygon base.
-- @param min_z number Minimum Z height.
-- @param max_z number Maximum Z height.
-- @return ColshapePoly The created polygon colshape.
lib_module.poly = colshape_classwarp(colshape_poly)
