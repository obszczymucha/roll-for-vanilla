RollFor = RollFor or {}
local m = RollFor

if m.ItemUtils then return end

local red, white = m.colors.red, m.colors.white

local M = {}

---@class LT
---@field Item "Item"
---@field SoftRessedItem "SoftRessedItem"
---@field HardRessedItem "HardRessedItem"
---@field Coin "Coin"
---@field DroppedItem "DroppedItem"
---@field SoftRessedDroppedItem "SoftRessedDroppedItem"
---@field HardRessedDroppedItem "HardRessedDroppedItem"

---@type LT
local LootType = {
  Item = "Item",
  SoftRessedItem = "SoftRessedItem",
  HardRessedItem = "HardRessedItem",
  Coin = "Coin",
  DroppedItem = "DroppedItem",
  SoftRessedDroppedItem = "SoftRessedDroppedItem",
  HardRessedDroppedItem = "HardRessedDroppedItem"
}

M.LootType = LootType

---@alias LootType
---| "Item"
---| "SoftRessedItem"
---| "HardRessedItem"
---| DroppedLootType

---@alias DroppedLootType
---| CoinType
---| DroppedItemType

---@alias CoinType
---| "Coin"

---@alias DroppedItemType
---| "DroppedItem"
---| "SoftRessedDroppedItem"
---| "HardRessedDroppedItem"

---@class BT
---@field BindOnPickup "BindOnPickup"
---@field BindOnEquip "BindOnEquip"
---@field Soulbound "Soulbound"
---@field Quest "Quest"
---@field None "None"

---@type BT
local BindType = {
  BindOnPickup = "BindOnPickup",
  BindOnEquip = "BindOnEquip",
  Soulbound = "Soulbound",
  Quest = "Quest",
  None = "None"
}

M.BindType = BindType

---@alias BindType
---| "BindOnPickup"
---| "BindOnEquip"
---| "Soulbound"
---| "Quest"
---| "None"

---@alias ItemQuality
---| 0 -- Poor
---| 1 -- Common
---| 2 -- Uncommon
---| 3 -- Rare
---| 4 -- Epic
---| 5 -- Legendary

---@alias ItemLink string
---@alias TooltipItemLink string
---@alias ItemTexture string

---@class Item
---@field id number
---@field name string
---@field link ItemLink
---@field quality ItemQuality?
---@field texture string?
---@field classes table<number, PlayerClass>?
---@field type "Item"

---@class DroppedItem : Item
---@field tooltip_link TooltipItemLink
---@field quantity number
---@field bind BindType?
---@field type "DroppedItem"

---@class HardRessedDroppedItem : DroppedItem
---@field type "HardRessedDroppedItem"

---@class SoftRessedDroppedItem : DroppedItem
---@field sr_players RollingPlayer[]
---@field type "SoftRessedDroppedItem"

---@class Coin
---@field texture string
---@field amount_text string
---@field type "Coin"

---@alias MasterLootDistributableItem DroppedItem|HardRessedDroppedItem|SoftRessedDroppedItem

---@alias MakeItemFn fun(
---  id: number,
---  name: string,
---  link: ItemLink,
---  quality: ItemQuality,
---  texture: string ): Item

---@alias MakeDroppedItemFn fun(
---  id: number,
---  name: string,
---  link: ItemLink,
---  tooltip_link: TooltipItemLink,
---  quality: ItemQuality,
---  quantity: number,
---  texture: string,
---  bind: BindType,
---  classes: table<number, PlayerClass>|nil ): DroppedItem

---@alias MakeSoftRessedDroppedItemFn fun(
---  item: DroppedItem,
---  sr_players: RollingPlayer[] ): SoftRessedDroppedItem

---@alias MakeHardRessedDroppedItemFn fun(
---  item: DroppedItem ): HardRessedDroppedItem

---@class ItemUtils
---@field get_item_id fun( item_link: ItemLink ): number?
---@field get_item_name fun( item_link: ItemLink ): string
---@field parse_link fun( item_link: string ): ItemLink? -- Sometimes we need to parse the link from the "[Item Name]x4." string.
---@field parse_all_links fun( item_links: string ): ItemLink[]
---@field get_tooltip_link fun( item_link: ItemLink ): TooltipItemLink
---@field bind_abbrev fun( bind: BindType ): string?
---@field make_item MakeItemFn
---@field make_dropped_item MakeDroppedItemFn
---@field make_softres_dropped_item MakeSoftRessedDroppedItemFn
---@field make_hardres_dropped_item MakeHardRessedDroppedItemFn
---@field make_coin fun( texture: string, amount_text: string ): Coin

---@param item_link ItemLink
---@return number?
function M.get_item_id( item_link )
  for item_id in string.gmatch( item_link, "|c%x%x%x%x%x%x%x%x|Hitem:(%d+):.+|r" ) do
    return tonumber( item_id )
  end
end

---@param item_link ItemLink
---@return string
function M.get_item_name( item_link )
  local result = string.gsub( item_link, "|c%x%x%x%x%x%x%x%x|Hitem:%d+.*|h%[(.*)%]|h|r", "%1" )
  return result
end

---@param item_link string
---@return string?
function M.parse_link( item_link )
  if not item_link then return end

  for link in string.gmatch( item_link, "|c%x%x%x%x%x%x%x%x|Hitem:%d+.-|h%[.-%]|h|r" ) do
    return link
  end
end

---@param item_links string
---@return ItemLink[]
function M.parse_all_links( item_links )
  local result = {}
  if not item_links then return result end

  for item_link in string.gmatch( item_links, "|c%x%x%x%x%x%x%x%x|Hitem:[^%]]+%]|h|r" ) do
    table.insert( result, item_link )
  end

  return result
end

---@param item_link ItemLink
---@return TooltipItemLink
function M.get_tooltip_link( item_link )
  return string.match( item_link, "|H(item:[^|]+)|h" )
end

---@param bind BindType
---@return string?
function M.bind_abbrev( bind )
  if bind == BindType.BindOnPickup or bind == BindType.Soulbound or bind == BindType.Quest then
    return red( "BoP" )
  elseif bind == BindType.BindOnEquip then
    return white( "BoE" )
  end
end

---@param id number
---@param name string
---@param link ItemLink
---@param quality ItemQuality?
---@param texture string?
---@return Item
function M.make_item( id, name, link, quality, texture )
  return {
    id = id,
    name = name,
    link = link,
    quality = quality,
    texture = texture,
    type = LootType.Item
  }
end

---@param id number
---@param name string
---@param link ItemLink
---@param tooltip_link TooltipItemLink
---@param quality ItemQuality?
---@param quantity number?
---@param texture string?
---@param bind BindType?
---@param classes table<number, PlayerClass>?
---@return DroppedItem
function M.make_dropped_item( id, name, link, tooltip_link, quality, quantity, texture, bind, classes )
  return {
    id = id,
    name = name,
    link = link,
    tooltip_link = tooltip_link,
    quality = quality,
    quantity = quantity,
    texture = texture,
    bind = bind or BindType.None,
    classes = classes,
    type = LootType.DroppedItem
  }
end

---@param item DroppedItem
---@param sr_players RollingPlayer[]
---@return SoftRessedDroppedItem
function M.make_softres_dropped_item( item, sr_players )
  ---@param a RollingPlayer
  ---@param b RollingPlayer
  local function sort( a, b ) return a.name < b.name end
  local players = sr_players or {}
  table.sort( players, sort )

  return {
    id = item.id,
    name = item.name,
    link = item.link,
    tooltip_link = item.tooltip_link,
    quality = item.quality,
    quantity = item.quantity,
    texture = item.texture,
    bind = item.bind,
    sr_players = players,
    type = LootType.SoftRessedDroppedItem
  }
end

---@param item DroppedItem
---@return HardRessedDroppedItem
function M.make_hardres_dropped_item( item )
  return {
    id = item.id,
    name = item.name,
    link = item.link,
    tooltip_link = item.tooltip_link,
    quality = item.quality,
    quantity = item.quantity,
    texture = item.texture,
    bind = item.bind,
    type = LootType.HardRessedDroppedItem
  }
end

---@param texture string
---@param amount_text string
---@return Coin
function M.make_coin( texture, amount_text )
  return {
    texture = texture,
    amount_text = amount_text,
    type = LootType.Coin
  }
end

m.ItemUtils = M
return M
