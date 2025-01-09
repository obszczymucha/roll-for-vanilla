RollFor = RollFor or {}
local m = RollFor

if m.SoftResDataTransformer then return end

local M = {}

local make_roller = m.Types.make_roller

---@alias RaidResData table -- TODO: document this

---@class SoftRessedItem
---@field rollers Roller[]
---@field quality number
---@field soft_ressed boolean
---@field hard_ressed boolean

---@alias SoftResData table<ItemId, SoftRessedItem>

-- The input is a data from softres.it/raidres.fly.dev format.
-- The output is a map of item_ids.
-- If the item is soft ressed the map contains a list of players
-- including their player_name and the number of rolls.
-- The item data can be enriched with item link and name.
-- The player data can then be enriched with player_class or
-- any additional information needed to process rolls.
---@param data RaidResData
---@return SoftResData
function M.transform( data )
  local result = {}
  local hard_reserves = data.hardreserves or {}
  local soft_reserves = data.softreserves or {}

  local function find_roller( roller_name, rollers )
    for _, roller in ipairs( rollers ) do
      if roller.name == roller_name then
        return roller
      end
    end
  end

  for _, sr in ipairs( soft_reserves or {} ) do
    local roller_name = sr.name
    local item_ids = sr.items or {}

    for _, item in ipairs( item_ids ) do
      local item_id = item.id

      if item_id then
        result[ item_id ] = result[ item_id ] or {
          soft_ressed = true,
          quality = item.quality,
          rollers = {}
        }

        local roller = find_roller( roller_name, result[ item_id ].rollers )

        if not roller then
          table.insert( result[ item_id ].rollers, make_roller( roller_name, 1 ) )
        else
          roller.rolls = roller.rolls + 1
        end
      end
    end
  end

  for _, item in ipairs( hard_reserves or {} ) do
    local item_id = item.id

    if item_id then
      result[ item_id ] = {
        hard_ressed = true,
        quality = item.quality
      }
    end
  end

  return result
end

m.SoftResDataTransformer = M
return M
