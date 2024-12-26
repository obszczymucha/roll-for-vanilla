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

  return {
    get_items = get_items,
    get_source_guid = get_source_guid,
  }
end

m.LootList = M
return M
