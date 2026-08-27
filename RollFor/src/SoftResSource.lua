RollFor = RollFor or {}
local m = RollFor

if m.SoftResSource then return end

local M = {}

local function hl( text ) return m.colors.hl( text ) end

-- The registry a soft-res source extension registers with. Core never knows what a
-- base64 string is or which website data came from -- it knows there is *a* source, or
-- there is not, and either way it works against the same six read methods (see
-- src/SoftRes.lua). Exactly one source may be registered; a second registration is
-- refused so "which source is active" never needs an answer.

---@class SoftResSourceSpec
---@field id string -- "softres_it"
---@field title string -- "SoftRes (softres.it)"
---@field base fun(): SoftRes -- the undecorated store; the chain's base
---@field has_data fun(): boolean -- is anything actually loaded right now
---@field get_import_string fun(): string? -- optional; what Gargul is answered with

---@type SoftResSourceSpec?
local source

---@param spec SoftResSourceSpec
---@return boolean
function M.register( spec )
  if type( spec ) ~= "table" then
    m.err( "Soft-res source registration failed: the spec must be a table." )
    return false
  end

  if type( spec.id ) ~= "string" or spec.id == "" then
    m.err( "Soft-res source registration failed: 'id' must be a non-empty string." )
    return false
  end

  if type( spec.title ) ~= "string" or spec.title == "" then
    m.err( "Soft-res source registration failed: 'title' must be a non-empty string." )
    return false
  end

  if type( spec.base ) ~= "function" then
    m.err( string.format( "Soft-res source %s failed to register: 'base' must be a function.", hl( spec.id ) ) )
    return false
  end

  if type( spec.has_data ) ~= "function" then
    m.err( string.format( "Soft-res source %s failed to register: 'has_data' must be a function.", hl( spec.id ) ) )
    return false
  end

  if source then
    m.err( string.format( "Soft-res source %s is already registered, ignoring %s.", hl( source.id ), hl( spec.id ) ) )
    return false
  end

  source = spec
  return true
end

---@return SoftResSourceSpec?
function M.get()
  return source
end

---@return SoftRes
function M.base()
  if not source then return m.SoftRes.null() end
  return source.base()
end

---@return boolean
function M.has_data()
  if not source then return false end
  return source.has_data()
end

---@return string?
function M.get_import_string()
  if not source or not source.get_import_string then return nil end
  return source.get_import_string()
end

-- Called at the top of every create_components() run, so a re-composition starts from
-- nothing rather than inheriting the previous run's source. In game that is once per
-- login; in tests it is once per addon load.
function M.clear()
  source = nil
end

m.SoftResSource = M
return M
