--- Manages localization and translation of strings.
-- This module provides functionality to load language dictionaries from JSON files,
-- set a default language, and retrieve translated strings with optional variable substitution.
--
-- **Adding Translations:**
-- To add translations, create JSON files in the `locales/` directory of your resource
-- (e.g., `locales/en.json`, `locales/es.json`). Each file should contain a flat
-- JSON object where keys are the original strings (or unique IDs) and values are
-- their translations for that language.
-- Example `locales/en.json`:
-- ```json
-- {
--   "welcome_message": "Hello, ${name}! Welcome to the server.",
--   "items_in_inventory": "You have ${count} items in your inventory."
-- }
-- ```
--
-- **Variable Substitution:**
-- Translated strings can include placeholders in the format `${variable_name}`.
-- These placeholders are replaced with values from a table passed to the localization function.
-- @module locale

--- @type string The default language code (e.g., "en") used if no specific language is requested or if a translation is missing.
-- @local
local default_lang = "en"
--- @type table Stores loaded language dictionaries, keyed by language code.
-- Each dictionary is a table of string_id -> translated_string.
-- @local
local dictionary = {}

local string_gsub = string.gsub -- Local alias for performance
--- @type function Reference to the main localization function, defined later.
-- @local
local locale_func_ref

--- @type table Cache of native FiveM functions.
-- @local
local native = {
    load_resource_file = LoadResourceFile,
}

--- Loads a language dictionary from its JSON file into the `dictionary` cache.
-- If the file doesn't exist or is invalid, an error is printed and the dictionary for that language remains empty or unchanged.
-- @param lang string The language code (e.g., "en") corresponding to the JSON file name (e.g., "en.json").
-- @local
local function load_dict(lang)
    lib.validate.type.assert(lang, "string", "load_dict language code")

    local file_content = native.load_resource_file(lib.resource.name, ("locales/%s.json"):format(lang))
    if not file_content then
        print(("[%s] locales/%s.json does not exist or could not be loaded."):format(lib.resource.name, lang))
        dictionary[lang] = {} -- Ensure an empty table exists to prevent repeated load attempts for this session
        return
    end

    local success, locales_data = pcall(json.decode, file_content)
    if not success or type(locales_data) ~= "table" then
        print(("[%s] Failed to decode locales/%s.json: %s"):format(lib.resource.name, lang, success and "Invalid JSON structure" or locales_data))
        dictionary[lang] = {}
        return
    end

    local lang_dictionary = {}
    for locale_id, translated_text in pairs(locales_data) do
        if type(locale_id) == "string" and type(translated_text) == "string" then
            lang_dictionary[locale_id] = translated_text
        else
            print(("[%s] Invalid locale entry in %s.json: ID '%s' (type %s), Text type %s. Both must be strings."):format(lib.resource.name, lang, tostring(locale_id), type(locale_id), type(translated_text)))
        end
    end
    dictionary[lang] = lang_dictionary
end

--- Retrieves a translated string for a given ID and optionally substitutes variables.
-- If the language dictionary for the specified (or default) language is not loaded,
-- it attempts to load it first. If the string ID is not found in the dictionary,
-- a message indicating this is returned.
-- @param id string The unique ID of the string to translate (key in the JSON file).
-- @param vars table (Optional) A table of key-value pairs for variable substitution.
--               Keys in the table should match placeholder names in the translated string (e.g., `vars.name` for `${name}`).
-- @param lang string (Optional) The language code to use for this translation. Defaults to the current `default_lang`.
-- @return string The translated (and substituted) string, or an error message if not found.
-- @usage
-- -- Assuming 'locales/en.json' has: { "greeting": "Hello, ${name}!" }
-- lib.locale.set_language("en")
-- local message = lib.locale("greeting", { name = "Player" })
-- print(message) -- Output: Hello, Player!
--
-- local specific_message = lib.locale("greeting", { name = "Usuario" }, "es") -- Assuming 'es.json' exists
locale_func_ref = function(id, vars, lang)
    lib.validate.type.assert(id, "string", "Locale ID")
    if vars ~= nil then lib.validate.type.assert(vars, "table", "Locale variables") end
    if lang ~= nil then lib.validate.type.assert(lang, "string", "Locale language code") end

    local target_lang = lib.coalesce(lang, default_lang)

    if not dictionary[target_lang] then
        load_dict(target_lang)
        -- Check again after load attempt, it might be an empty table if load failed
        if not dictionary[target_lang] then
            return ("\"%s\" dictionary for lang '%s' could not be loaded."):format(id, target_lang)
        end
    end
    local lang_dict_cache = dictionary[target_lang]

    local locale_string_template = lang_dict_cache[id]
    if not locale_string_template then
        return ("\"%s\" was not found in the \"%s\" dictionary."):format(id, target_lang)
    end

    if vars then
        -- Replace placeholders like ${variable} or $variable
        locale_string_template = string_gsub(locale_string_template, "%${([%w_]+)}", function(var_name)
            return tostring(vars[var_name]) -- Convert var to string, use tostring for safety
        end)
    end

    return locale_string_template
end

--- Sets the default language for translations.
-- This language will be used by `locale()` if no specific language is provided to it.
-- @param lang string The language code to set as default (e.g., "en").
-- @usage lib.locale.set_language("es")
local function set_language(lang)
    lib.validate.type.assert(lang, "string", "set_language language code")
    default_lang = lang
    -- Optionally, preload the new default language dictionary
    -- if not dictionary[default_lang] then
    --     load_dict(default_lang)
    -- end
end

---@type LocaleModule
-- @field set_language fun(lang:string) Sets the default language.
-- @field set_lang fun(lang:string) Alias for `set_language`.
-- @field loc fun(id:string, vars?:table, lang?:string):string Retrieves a translated string. Also callable directly via `lib.locale(...)`.
lib_module = setmetatable({
    set_language = set_language,
    set_lang = set_language, -- Alias
    loc = locale_func_ref,
}, {
    -- Allows calling lib.locale(...) directly
    __call = function(_, ...)
        return locale_func_ref(...)
    end,
})
