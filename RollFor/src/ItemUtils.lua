RollFor = RollFor or {}
local m = RollFor

if m.ItemUtils then return end

local M = {}

M.interface = {
  get_item_id = "function",
  get_item_name = "function",
  parse_all_links = "function",
  get_tooltip_link = "function",
  make_item = "function",
  make_distributable_item = "function"
}

---@alias ItemQuality
---| 0 -- Poor
---| 1 -- Common
---| 2 -- Uncommon
---| 3 -- Rare
---| 4 -- Epic
---| 5 -- Legendary

---@alias ItemLink string
---@alias TooltipItemLink string

---@class Item
---@field id number
---@field name string
---@field link ItemLink
---@field quality ItemQuality | nil
---@field texture string | nil

---@class DistributableItem : Item
---@field slot number

---@class ItemUtils
---@field get_item_id fun( item_link: ItemLink ): number | nil
---@field get_item_name fun( item_link: ItemLink ): string
---@field parse_all_links fun( item_links: string ): ItemLink[]
---@field get_tooltip_link fun( item_link: ItemLink ): TooltipItemLink
---@field make_item fun( id: number, name: string, link: ItemLink, quality: ItemQuality, texture: string ): Item
---@field make_distributable_item fun( id: number, name: string, link: ItemLink, quality: ItemQuality, texture: string, slot: number ): DistributableItem

---@param item_link ItemLink
---@return number | nil
function M.get_item_id( item_link )
  for item_id in string.gmatch( item_link, "|c%x%x%x%x%x%x%x%x|Hitem:(%d+):.+|r" ) do
    return tonumber( item_id )
  end

  return nil
end

---@param item_link ItemLink
---@return string
function M.get_item_name( item_link )
  local result = string.gsub( item_link, "|c%x%x%x%x%x%x%x%x|Hitem:%d+.*|h%[(.*)%]|h|r", "%1" )
  return result
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

---@param id number
---@param name string
---@param link ItemLink
---@param quality ItemQuality | nil
---@param texture string | nil
---@return Item
function M.make_item( id, name, link, quality, texture )
  return { id = id, name = name, link = link, quality = quality, texture = texture }
end

---@param id number
---@param name string
---@param link ItemLink
---@param quality ItemQuality | nil
---@param texture string | nil
---@param slot number | nil
---@return DistributableItem
function M.make_distributable_item( id, name, link, quality, texture, slot )
  return { id = id, name = name, link = link, quality = quality, texture = texture, slot = slot }
end

m.ItemUtils = M
return M
