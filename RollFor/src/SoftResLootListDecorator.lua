RollFor = RollFor or {}
local m = RollFor
if m.SoftResLootListDecorator then return end

local M = {}

---@type LT
local LT = m.ItemUtils.LootType

---@type MakeSoftRessedDroppedItemFn
local make_softres_dropped_item = m.ItemUtils.make_softres_dropped_item

---@type MakeHardRessedDroppedItemFn
local make_hardres_dropped_item = m.ItemUtils.make_hardres_dropped_item

---@class SoftResLootList : LootList
---@field get_items fun(): (MasterLootDistributableItem)[]
---@field get_source_guid fun(): string
---@field is_looting fun(): boolean
---@field count fun( item_id: number ): number
---@field get_by_id fun( item_id: number ): MasterLootDistributableItem?

---@param loot_list LootList
---@param softres GroupAwareSoftRes
function M.new( loot_list, softres )
  local function sort( a, b )
    if a == nil then return false end
    if b == nil then return true end

    if a.type == LT.Coin and b.type ~= LT.Coin then return false end
    if b.type == LT.Coin and a.type ~= LT.Coin then return true end

    local sr_a = a.sr_players and #a.sr_players or 0
    local sr_b = b.sr_players and #b.sr_players or 0
    local quality_a = a.quality or 0 -- coin has no quality
    local quality_b = b.quality or 0 -- coin has no quality
    local name_a = a.name or ""
    local name_b = b.name or ""

    if a.hr and not b.hr then return true end
    if b.hr and not a.hr then return false end

    if sr_a == 0 and sr_b == 0 then
      if quality_a == quality_b then
        return name_a < name_b
      end

      return quality_a > quality_b
    end

    if sr_a > 0 and sr_b == 0 then return true end
    if sr_b > 0 and sr_a == 0 then return false end

    if sr_a == 0 and sr_b ~= 0 then return true end
    if sr_b == 0 and sr_a ~= 0 then return false end

    return sr_a < sr_b
  end

  local function get_items()
    local hr_map = {}

    local result = m.map( loot_list.get_items(), function( item )
      if type( item ) ~= "table" then return item end -- Fucking lua50 and its "n".

      if item.type == LT.Coin then
        return item
      end

      local hr = softres.is_item_hardressed( item.id )
      local sr_players = softres.get( item.id )
      local sr = #sr_players > 0

      if hr and not hr_map[ item.id ] then
        hr_map[ item.id ] = true
        return make_hardres_dropped_item( item )
      elseif sr then
        return make_softres_dropped_item( item, sr_players )
      else
        return item
      end
    end )

    table.sort( result, sort )

    return result
  end

  ---@param item_id number
  ---@return MasterLootDistributableItem?
  local function get_by_id( item_id )
    for _, item in pairs( get_items() ) do
      if item.id == item_id then return item end
    end
  end

  local decorator = m.clone( loot_list )
  decorator.get_items = get_items
  decorator.get_by_id = get_by_id

  return decorator
end

m.SoftResLootListDecorator = M
return M
