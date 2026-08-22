RollFor = RollFor or {}
local m = RollFor

if m.ResistanceRegistry then return end

local M = {}

local getn = m.getn

-- Indices match UnitResistance() and the RESISTANCE<n>_NAME globals.
---@alias ResistanceType number

M.ResistanceType = {
  Armor = 0,
  Holy = 1,
  Fire = 2,
  Nature = 3,
  Frost = 4,
  Shadow = 5,
  Arcane = 6
}

-- Every magic school. Armor is not one of them.
local all_resistance_types = {
  M.ResistanceType.Holy,
  M.ResistanceType.Fire,
  M.ResistanceType.Nature,
  M.ResistanceType.Frost,
  M.ResistanceType.Shadow,
  M.ResistanceType.Arcane
}

-- The schools a buff report covers.
local buffed_resistance_types = { M.ResistanceType.Shadow, M.ResistanceType.Fire }

local Shadow, Fire = M.ResistanceType.Shadow, M.ResistanceType.Fire

-- Anyone wearing this much fire resistance is in a fire set, not a shadow one.
local FIRE_OVERRIDE_THRESHOLD = 150

-- Values are max rank. UnitBuff doesn't report rank, so max rank is assumed.
local RESISTANCE_BUFF_VALUE = m.vanilla and 60 or 70
local WILD_VALUE = 25
local FLASK_VALUE = 35

-- Any one of these grants the same amount and they don't stack with each other.
local shadow_buffs = { "Prayer of Shadow Protection", "Shadow Protection", "Shadow Resistance Aura" }
local fire_buffs = { "Fire Resistance Aura" }

-- TEMPORARY: the fallback when a school has none of the buffs above. To be
-- removed once those are confirmed to be detected in the field.
local wild_buffs = { "Gift of the Wild", "Mark of the Wild" }

-- A consumable, so it stacks on top of whatever else is up.
local FLASK = "Flask of Chromatic Wonder"

---@param present table<string, boolean>
---@param names string[]
---@return string?
local function first_present( present, names )
  for i = 1, getn( names ) do
    if present[ names[ i ] ] then return names[ i ] end
  end

  return nil
end

---@alias ResistanceBuffs table<ResistanceType, number>

---@param present table<string, boolean>
---@param buffs string[] -- the buffs granting the full amount for this school
---@return number
local function resolve_school( present, buffs )
  local value = 0

  if first_present( present, buffs ) then
    value = RESISTANCE_BUFF_VALUE
  elseif first_present( present, wild_buffs ) then
    value = WILD_VALUE
  end

  if present[ FLASK ] then value = value + FLASK_VALUE end

  return value
end

---@class ResistanceRegistry
---@field resolve fun( buff_names: string[] ): ResistanceBuffs
---@field default_reported_type fun( totals: ResistanceTotals, threshold: number? ): ResistanceType, number
---@field all_resistance_types fun(): ResistanceType[]
---@field buffed_resistance_types fun(): ResistanceType[]

---@return ResistanceRegistry
function M.new()
  -- Turns a list of buff names into how much resistance they grant per school.
  ---@param buff_names string[]
  ---@return ResistanceBuffs
  local function resolve( buff_names )
    local present = {}

    for i = 1, getn( buff_names ) do
      present[ buff_names[ i ] ] = true
    end

    return {
      [ Shadow ] = resolve_school( present, shadow_buffs ),
      [ Fire ] = resolve_school( present, fire_buffs )
    }
  end

  -- What to report when no school was asked for: shadow, unless the gear says
  -- they're here for a fire fight.
  ---@param totals ResistanceTotals
  ---@param threshold number?
  ---@return ResistanceType, number
  local function default_reported_type( totals, threshold )
    local fire = totals[ Fire ] or 0

    if fire > (threshold or FIRE_OVERRIDE_THRESHOLD) then return Fire, fire end

    return Shadow, totals[ Shadow ] or 0
  end

  ---@type ResistanceRegistry
  return {
    resolve = resolve,
    default_reported_type = default_reported_type,
    all_resistance_types = function() return all_resistance_types end,
    buffed_resistance_types = function() return buffed_resistance_types end
  }
end

m.ResistanceRegistry = M
return M
