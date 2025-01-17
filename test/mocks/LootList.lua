---@param items (DroppedItem|SoftRessedDroppedItem|HardRessedDroppedItem)[]
return function( items )
  local M = {}

  local getn = table.getn

  function M.new()
    local function get_items()
      return items or {}
    end

    local function get_source_guid()
      return M.source_guid or "PrincessKenny"
    end

    local function get_slot( item_id )
      for slot, item in pairs( items or {} ) do
        if item.id == item_id then
          return slot
        end
      end
    end

    local function count( item_id )
      local result = 0

      for _, item in pairs( get_items() ) do
        if item.id == item_id then
          result = result + 1
        end
      end

      return result
    end

    ---@type SoftResLootList
    return {
      ---@diagnostic disable-next-line: assign-type-mismatch
      get_items = get_items,
      get_source_guid = get_source_guid,
      get_slot = get_slot,
      count = count,
      is_looting = function() return items and getn( get_items() ) > 0 and true or false end
    }
  end

  return M
end
