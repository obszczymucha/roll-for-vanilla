RollFor = RollFor or {}
local m = RollFor

if m.LootList then return end

local M = {}

function M.new()
  local function get_items()
    return M.items or {}
  end

  local function get_source_guid()
    return M.source_guid or "PrincessKenny"
  end

  local function find_item( item_id )
    for _, item in ipairs( M.items or {} ) do
      if item.id == item_id then
        return item
      end
    end
  end

  return {
    get_items = get_items,
    get_source_guid = get_source_guid,
    find_item = find_item
  }
end

m.LootList = M
return M
