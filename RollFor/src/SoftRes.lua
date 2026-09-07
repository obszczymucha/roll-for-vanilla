RollFor = RollFor or {}
local m = RollFor

if m.SoftRes then return end

local M = {}

---@class ItemData
---@field item_id ItemId
---@field item_quantity number

---@param item_id ItemId
---@param item_quantity number?
---@return ItemData
function M.softres_item_data( item_id, item_quantity )
  return {
    item_id = item_id,
    item_quantity = item_quantity or 1
  }
end

-- The entire core-facing contract. Six read methods -- consumers use nothing else.
-- `import`, `clear` and `persist` are internal to whichever source is registered through
-- `SoftResSource` and are deliberately not part of this annotation: today's leftover leak
-- of the softres.it JSON shape (`import fun( data: RaidResData )`) belongs to the source,
-- not to core.
---@class SoftRes
---@field get fun( item_data: ItemData ): Roller[]
---@field get_all_rollers fun(): Roller[]
---@field is_player_softressing fun( player_name: string, item_data: ItemData? ): boolean
---@field get_items fun(): ItemData[]
---@field get_hr_item_ids fun(): ItemId[]
---@field is_item_hardressed fun( item_id: ItemId ): boolean

---@class GroupAwareSoftRes
---@field get fun( item_data: ItemData ): RollingPlayer[]
---@field get_all_rollers fun(): RollingPlayer[]
---@field is_player_softressing fun( player_name: string, item_data: ItemData? ): boolean
---@field get_items fun(): ItemData[]
---@field get_hr_item_ids fun(): ItemId[]
---@field is_item_hardressed fun( item_id: ItemId ): boolean

-- Returned when no soft-res source is registered. A new table every call: decorators
-- clone and mutate what they wrap, so a shared singleton would end up corrupted by the
-- first one that did.
---@return SoftRes
function M.null()
  return {
    get = function() return {} end,
    get_all_rollers = function() return {} end,
    is_player_softressing = function() return false end,
    get_items = function() return {} end,
    get_hr_item_ids = function() return {} end,
    is_item_hardressed = function() return false end
  }
end

m.SoftRes = M
return M
