RollFor = RollFor or {}
local m = RollFor

if m.SoftResDataTransformer then return end

local M = {}

-- The input is a data from softres.it/raidres.fly.dev format.
-- The output is a map of item_ids.
-- If the item is soft ressed the map contains a list of players
-- including their player_name and the number of rolls.
-- The item data can be enriched with item link and name.
-- The player data can then be enriched with player_class or
-- any additional information needed to process rolls.
function M.transform( data )
  local result = {}
  local hard_reserves = data.hardreserves or {}
  local soft_reserves = data.softreserves or {}

  local function find_player( player_name, players )
    for _, player in ipairs( players ) do
      if player.name == player_name then
        return player
      end
    end
  end

  for _, sr in ipairs( soft_reserves or {} ) do
    local player_name = sr.name
    local item_ids = sr.items or {}

    for _, item in ipairs( item_ids ) do
      local item_id = item.id

      if item_id then
        result[ item_id ] = result[ item_id ] or {
          soft_ressed = true,
          quality = item.quality or 4,
          players = {}
        }

        local player = find_player( player_name, result[ item_id ].players )

        if not player then
          table.insert( result[ item_id ].players, { name = player_name, rolls = 1, note = item.note or "" } ) -- added in a note function which will be added to item drop announcements for each player
        else
          player.rolls = player.rolls + 1
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
