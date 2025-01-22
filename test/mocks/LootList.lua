---@param items (MasterLootDistributableItem)[]
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

    ---@param item_id number
    local function get_slot( item_id )
      for slot, item in pairs( items or {} ) do
        if item.id == item_id then
          return slot
        end
      end
    end

    ---@param item_id number
    local function count( item_id )
      local result = 0

      for _, item in pairs( get_items() ) do
        if item.id == item_id then
          result = result + 1
        end
      end

      return result
    end

    ---@param item_id number
    ---@return MasterLootDistributableItem?
    local function get_by_id( item_id )
      for _, item in pairs( get_items() ) do
        if item.id == item_id then return item end
      end
    end

    ---@type SoftResLootList
    return {
      ---@diagnostic disable-next-line: assign-type-mismatch
      get_items = get_items,
      get_source_guid = get_source_guid,
      get_slot = get_slot,
      count = count,
      is_looting = function() return items and getn( get_items() ) > 0 and true or false end,
      get_by_id = get_by_id
    }
  end

  return M
end
