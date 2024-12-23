RollFor = RollFor or {}
local m = RollFor

if m.AwardedLoot then return end

local M = {}

---@diagnostic disable-next-line: deprecated
local getn = table.getn

function M.new( db )
  db.awarded_items = db.awarded_items or {}

  local function award( player_name, item_id )
    table.insert( db.awarded_items, { player_name = player_name, item_id = item_id } )
  end

  local function has_item_been_awarded( player_name, item_id )
    for _, item in pairs( db.awarded_items ) do
      if item.player_name == player_name and item.item_id == item_id then return true end
    end

    return false
  end

  local function clear()
    m.clear_table( db.awarded_items )
  end

  local function unaward( player_name, item_id )
    for i = getn( db.awarded_items ), 1, -1 do
      local awarded_item = db.awarded_items[ i ]

      if awarded_item.player_name == player_name and awarded_item.item_id == item_id then
        table.remove( db.awarded_items, i )
        return
      end
    end
  end

  return {
    award = award,
    unaward = unaward,
    has_item_been_awarded = has_item_been_awarded,
    clear = clear
  }
end

m.AwardedLoot = M
return M
