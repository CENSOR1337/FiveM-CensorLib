--- Manages client-side asset streaming for various game asset types.
-- This module provides a consistent interface for requesting, checking the load status,
-- and clearing different types of streamable assets like animation dictionaries, models,
-- animation sets, texture dictionaries, PTFX assets, Scaleform movies, and weapon assets.
-- All request operations are asynchronous and return a promise-like object.
-- @module streaming
-- @client

--- @type table Cache of native FiveM functions related to asset streaming.
-- @local
local native = {
    citizen_wait = Citizen.Wait,
    -- Animation Dictionaries
    does_anim_dict_exist = DoesAnimDictExist,
    has_anim_dict_loaded = HasAnimDictLoaded,
    request_anim_dict = RequestAnimDict,
    remove_anim_dict = RemoveAnimDict,
    -- Models
    is_model_valid = IsModelValid,
    has_model_loaded = HasModelLoaded,
    request_model = RequestModel,
    set_model_as_no_longer_needed = SetModelAsNoLongerNeeded,
    -- Animation Sets
    has_anim_set_loaded = HasAnimSetLoaded,
    remove_anim_set = RemoveAnimSet,
    request_anim_set = RequestAnimSet,
    -- Streamed Texture Dictionaries
    has_streamed_texture_dict_loaded = HasStreamedTextureDictLoaded,
    request_streamed_texture_dict = RequestStreamedTextureDict,
    set_streamed_texture_dict_as_no_longer_needed = SetStreamedTextureDictAsNoLongerNeeded,
    -- Named PTFX Assets
    has_named_ptfx_asset_loaded = HasNamedPtfxAssetLoaded,
    request_named_ptfx_asset = RequestNamedPtfxAsset,
    remove_named_ptfx_asset = RemoveNamedPtfxAsset,
    -- Scaleform Movies
    has_scaleform_movie_loaded = HasScaleformMovieLoaded,
    request_scaleform_movie = RequestScaleformMovie,
    set_scaleform_movie_as_no_longer_needed = SetScaleformMovieAsNoLongerNeeded,
    -- Weapon Assets
    has_weapon_asset_loaded = HasWeaponAssetLoaded,
    request_weapon_asset = RequestWeaponAsset,
    remove_weapon_asset = RemoveWeaponAsset,
}

--- Creates a wrapped interface for a specific type of streamable asset.
-- This factory function returns an object with `request`, `clear`, `has_loaded`, and `is_valid` methods.
-- The `request` method is asynchronous and uses `lib.async`.
-- @param request_fn function The actual function that requests the asset (e.g., `request_model_internal`).
-- @param clear_fn function The function to call to mark the asset as no longer needed (e.g., `SetModelAsNoLongerNeeded`).
-- @param has_loaded_fn function The function to check if the asset is loaded (e.g., `HasModelLoaded`).
-- @param is_valid_fn function (Optional) The function to check if the asset identifier is valid (e.g., `IsModelValid`).
--                       If not provided, `is_valid` will default to a function that errors "not implemented".
-- @return table An object with methods for managing the specific asset type.
--   @field request fun(...:any):AsyncResult Asynchronously requests the asset. Returns an object with `await()` and `then()` methods.
--   @field clear fun(...:any) Marks the asset as no longer needed.
--   @field has_loaded fun(...:any):boolean Checks if the asset is currently loaded.
--   @field is_valid fun(...:any):boolean Checks if the asset identifier is valid.
-- @local
local function create_streaming_interface(request_fn, clear_fn, has_loaded_fn, is_valid_fn)
    return {
        request = setmetatable({}, {
            __call = function(_, ...) -- Allows calling .request(...) directly
                return lib.async(request_fn)(...)
            end,
        }),
        clear = clear_fn,
        has_loaded = has_loaded_fn,
        is_valid = is_valid_fn or function() error("is_valid not implemented for this asset type") end,
    }
end

--- Generic internal function to request a streamable asset and wait for it to load.
-- This function is wrapped by `lib.async` in the `create_streaming_interface`.
-- @param asset_has_loaded_fn function The native function to check if the asset has loaded (e.g., `HasModelLoaded`).
-- @param asset_request_fn function The native function to request the asset (e.g., `RequestModel`).
-- @param ... any Arguments to pass to both `asset_has_loaded_fn` and `asset_request_fn` (e.g., model hash, anim dict name).
-- @return boolean True if the asset was successfully loaded (or was already loaded).
-- @local
local function request_streaming_internal(asset_has_loaded_fn, asset_request_fn, ...)
    if asset_has_loaded_fn(...) then
        return true
    end

    asset_request_fn(...)

    while not asset_has_loaded_fn(...) do
        native.citizen_wait(0) -- Yield thread until loaded
    end

    return true
end

-- Specific request functions for each asset type, to be wrapped by lib.async via create_streaming_interface.

--- Internal: Requests an animation dictionary.
-- @param anim_dict_name string The name of the animation dictionary.
-- @return boolean True if loaded.
-- @local
local function request_anim_dict_internal(anim_dict_name)
    lib.validate.type.assert(anim_dict_name, "string", "Animation dictionary name")
    assert(native.does_anim_dict_exist(anim_dict_name), ("Animation dictionary \"%s\" does not exist."):format(anim_dict_name))
    return request_streaming_internal(native.has_anim_dict_loaded, native.request_anim_dict, anim_dict_name)
end

--- Internal: Requests a model.
-- @param model_id string|number The model name or hash.
-- @return boolean True if loaded.
-- @local
local function request_model_internal(model_id)
    lib.validate.type.assert(model_id, "string", "number", "Model ID")
    local model_hash = type(model_id) == "number" and model_id or joaat(model_id)
    assert(native.is_model_valid(model_hash), ("Model \"%s\" (hash: %u) is not valid."):format(tostring(model_id), model_hash))
    return request_streaming_internal(native.has_model_loaded, native.request_model, model_hash)
end

--- Internal: Requests an animation set.
-- @param anim_set_name string The name of the animation set.
-- @return boolean True if loaded.
-- @local
local function request_anim_set_internal(anim_set_name)
    lib.validate.type.assert(anim_set_name, "string", "Animation set name")
    return request_streaming_internal(native.has_anim_set_loaded, native.request_anim_set, anim_set_name)
end

--- Internal: Requests a streamed texture dictionary.
-- @param txd_name string The name of the texture dictionary.
-- @return boolean True if loaded.
-- @local
local function request_streamed_texture_dict_internal(txd_name)
    lib.validate.type.assert(txd_name, "string", "Streamed texture dictionary name")
    return request_streaming_internal(native.has_streamed_texture_dict_loaded, native.request_streamed_texture_dict, txd_name)
end

--- Internal: Requests a named PTFX asset.
-- @param ptfx_asset_name string The name of the PTFX asset.
-- @return boolean True if loaded.
-- @local
local function request_named_ptfx_asset_internal(ptfx_asset_name)
    lib.validate.type.assert(ptfx_asset_name, "string", "PTFX asset name")
    return request_streaming_internal(native.has_named_ptfx_asset_loaded, native.request_named_ptfx_asset, ptfx_asset_name)
end

--- Internal: Requests a Scaleform movie.
-- @param scaleform_name string The name of the Scaleform movie.
-- @return boolean True if loaded.
-- @local
local function request_scaleform_movie_internal(scaleform_name)
    lib.validate.type.assert(scaleform_name, "string", "Scaleform movie name")
    return request_streaming_internal(native.has_scaleform_movie_loaded, native.request_scaleform_movie, scaleform_name)
end

--- Internal: Requests a weapon asset.
-- @param weapon_hash number The hash of the weapon asset.
-- @return boolean True if loaded.
-- @local
local function request_weapon_asset_internal(weapon_hash)
    lib.validate.type.assert(weapon_hash, "number", "Weapon asset hash")
    -- No IsWeaponAssetValid native, assume valid if request is made.
    return request_streaming_internal(native.has_weapon_asset_loaded, native.request_weapon_asset, weapon_hash, false, 0) -- Last 2 args for RequestWeaponAsset
end

---@section Asset Types
-- Each field provides methods (`request`, `clear`, `has_loaded`, `is_valid`) for a specific asset type.
-- @usage
-- -- Requesting a model:
-- lib.streaming.model.request("adder"):await()
-- print("Adder model loaded:", lib.streaming.model.has_loaded("adder"))
-- lib.streaming.model.clear("adder")
--
-- -- Requesting an animation dictionary:
-- local success = lib.streaming.anim_dict.request("amb@world_human_bum_slump@male@laying_on_left_side@base"):await()
-- if success then
--    -- Use anim dict
--    lib.streaming.anim_dict.clear("amb@world_human_bum_slump@male@laying_on_left_side@base")
-- end

--- Interface for managing animation dictionaries.
-- @type StreamingAssetInterface
lib_module.anim_dict = create_streaming_interface(request_anim_dict_internal, native.remove_anim_dict, native.has_anim_dict_loaded, native.does_anim_dict_exist)

--- Interface for managing models.
-- @type StreamingAssetInterface
lib_module.model = create_streaming_interface(request_model_internal, native.set_model_as_no_longer_needed, native.has_model_loaded, native.is_model_valid)

--- Interface for managing animation sets.
-- `is_valid` is not implemented for this asset type by FiveM natives.
-- @type StreamingAssetInterface
lib_module.anim_set = create_streaming_interface(request_anim_set_internal, native.remove_anim_set, native.has_anim_set_loaded)

--- Interface for managing streamed texture dictionaries.
-- `is_valid` is not implemented for this asset type by FiveM natives.
-- @type StreamingAssetInterface
lib_module.streamed_texture_dict = create_streaming_interface(request_streamed_texture_dict_internal, native.set_streamed_texture_dict_as_no_longer_needed, native.has_streamed_texture_dict_loaded)

--- Interface for managing named PTFX assets.
-- `is_valid` is not implemented for this asset type by FiveM natives.
-- @type StreamingAssetInterface
lib_module.named_ptfx_asset = create_streaming_interface(request_named_ptfx_asset_internal, native.remove_named_ptfx_asset, native.has_named_ptfx_asset_loaded)

--- Interface for managing Scaleform movies.
-- `is_valid` is not implemented for this asset type by FiveM natives.
-- @type StreamingAssetInterface
lib_module.scaleform_movie = create_streaming_interface(request_scaleform_movie_internal, native.set_scaleform_movie_as_no_longer_needed, native.has_scaleform_movie_loaded)

--- Interface for managing weapon assets.
-- `is_valid` is not implemented for this asset type by FiveM natives.
-- @type StreamingAssetInterface
lib_module.weapon_asset = create_streaming_interface(request_weapon_asset_internal, native.remove_weapon_asset, native.has_weapon_asset_loaded)
