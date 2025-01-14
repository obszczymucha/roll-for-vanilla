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

  local function get_slot( item_id )
    for slot, item in pairs( M.items or {} ) do
      if item.id == item_id then
        return slot
      end
    end
  end

  local function count( item_id )
    local result = 0

    for _, item in pairs( M.items ) do
      if item.id == item_id then
        result = result + 1
      end
    end

    return result
  end

  return {
    get_items = get_items,
    get_source_guid = get_source_guid,
    get_slot = get_slot,
    count = count
  }
end

m.LootList = M
return M
