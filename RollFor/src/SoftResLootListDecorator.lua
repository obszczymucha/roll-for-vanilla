RollFor = RollFor or {}
local m = RollFor
if m.SoftResLootListDecorator then return end

local M = {}

---@type LT
local LT = m.ItemUtils.LootType

---@diagnostic disable-next-line: deprecated
local getn = table.getn

---@type MakeSoftRessedDroppedItemFn
local make_softres_dropped_item = m.ItemUtils.make_softres_dropped_item

---@type MakeHardRessedDroppedItemFn
local make_hardres_dropped_item = m.ItemUtils.make_hardres_dropped_item

---@class SoftResLootList
---@field get_items fun(): (SoftRessedDroppedItem|HardRessedDroppedItem)[]
---@field get_source_guid fun(): string
---@field get_slot fun( item_id: number ): number?
---@field is_looting fun(): boolean
---@field count fun( item_id: number ): number

---@param loot_list LootList
---@param softres GroupedSoftRes
function M.new( loot_list, softres )
  local function sort( a, b )
    if a == nil then return false end
    if b == nil then return true end

    if a.type == LT.Coin and b.type ~= LT.Coin then return false end
    if b.type == LT.Coin and a.type ~= LT.Coin then return true end

    local sr_a = a.sr_players and getn( a.sr_players ) or 0
    local sr_b = b.sr_players and getn( b.sr_players ) or 0
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
    local result = m.map( loot_list.get_items(), function( item )
      if type( item ) ~= "table" then return item end -- Fucking lua50 and its "n".

      local hr = softres.is_item_hardressed( item.id )

      if hr then
        return make_hardres_dropped_item( item )
      else
        return make_softres_dropped_item( item, softres.get( item.id ) )
      end
    end )

    table.sort( result, sort )

    for i, item in ipairs( result ) do
      item.index = i
    end

    return result
  end

  local decorator = m.clone( loot_list )
  decorator.get_items = get_items

  return decorator
end

m.SoftResLootListDecorator = M
return M
