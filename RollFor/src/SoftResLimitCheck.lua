RollFor = RollFor or {}
local m = RollFor

if m.SoftResLimitCheck then return end

local M = {}

local hl = m.colors.hl

-- Black Temple soft-res budget: 3 soft-resses for the raid, and a 4th one only if it
-- lands on one of the last three bosses. Everything the catalogue doesn't place on one
-- of those three -- the first six bosses, trash, patterns, ids we don't know about --
-- spends from the 3.
local MAX_SOFT_RES = 3
local MAX_SOFT_RES_WITH_BONUS = 4

local BONUS_BOSSES = {
  [ "Mother Shahraz" ] = true,
  [ "The Illidari Council" ] = true,
  [ "Illidan Stormrage" ] = true
}

---@class SoftResLimitViolation
---@field name string
---@field regular number -- Soft-resses that spend from the 3.
---@field total number

-- Counts soft-resses, not items: raidres lets a player reserve the same item twice and
-- each reservation spends a slot, which is what `roller.rolls` holds.
---@param softres SoftRes
---@return SoftResLimitViolation[] -- Sorted by player name.
function M.find_violations( softres )
  local counts = {}

  for _, item_data in pairs( softres.get_items() ) do
    local boss = m.AutoLootDb.find_boss( item_data.item_id )
    local bonus = BONUS_BOSSES[ boss ]

    for _, roller in pairs( softres.get( item_data ) ) do
      local count = counts[ roller.name ] or { regular = 0, total = 0 }
      local rolls = roller.rolls or 1

      if not bonus then count.regular = count.regular + rolls end
      count.total = count.total + rolls
      counts[ roller.name ] = count
    end
  end

  local result = {}

  for name, count in pairs( counts ) do
    if count.regular > MAX_SOFT_RES or count.total > MAX_SOFT_RES_WITH_BONUS then
      table.insert( result, { name = name, regular = count.regular, total = count.total } )
    end
  end

  table.sort( result, function( left, right ) return left.name < right.name end )

  return result
end

---@param softres SoftRes
---@param group_roster GroupRoster
---@return string[] -- One message per violating player, sorted by name.
function M.messages( softres, group_roster )
  local result = {}

  for _, violation in ipairs( M.find_violations( softres ) ) do
    local player = group_roster.find_player( violation.name )
    local name = player and m.colorize_player_by_class( player.name, player.class ) or violation.name

    local message = violation.regular > MAX_SOFT_RES
        and string.format( "%s soft-ressed %s items outside the last 3 bosses (max %s).",
          name, hl( violation.regular ), hl( MAX_SOFT_RES ) )
        or string.format( "%s soft-ressed %s items (max %s).",
          name, hl( violation.total ), hl( MAX_SOFT_RES_WITH_BONUS ) )

    table.insert( result, message )
  end

  return result
end

---@param softres SoftRes
---@param group_roster GroupRoster
function M.report( softres, group_roster )
  for _, message in ipairs( M.messages( softres, group_roster ) ) do
    m.pretty_print( message, m.colors.orange )
  end
end

m.SoftResLimitCheck = M
return M
