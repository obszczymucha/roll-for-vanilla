RollFor = RollFor or {}
local m = RollFor

if m.SoftResPresentPlayersDecorator then return end

local M = {}

local filter = m.filter
local map = m.map
local clone = m.clone

---@class SoftRes
---@field get fun( item_id: ItemId ): Roller[]
---@field get_all_rollers fun(): Roller[]
---@field is_player_softressing fun( player_name: string, item_id: ItemId ): boolean
---@field get_item_ids fun(): ItemId[]
---@field get_item_quality fun( item_id: ItemId ): ItemQuality
---@field get_hr_item_ids fun(): ItemId[]
---@field is_item_hardressed fun( item_id: ItemId ): boolean
---@field import fun( data: RaidResData )
---@field clear fun( report: boolean )
---@field persist fun()

---@class GroupAwareSoftRes
---@field get fun( item_id: ItemId ): RollingPlayer[]
---@field get_all_rollers fun(): RollingPlayer[]
---@field is_player_softressing fun( player_name: string, item_id: ItemId ): boolean
---@field get_item_ids fun(): ItemId[]
---@field get_item_quality fun( item_id: ItemId ): ItemQuality
---@field get_hr_item_ids fun(): ItemId[]
---@field is_item_hardressed fun( item_id: ItemId ): boolean
---@field import fun( data: RaidResData )
---@field clear fun( report: boolean )
---@field persist fun()

-- I decorate given softres class with present players logic.
-- Example: "give me all players who soft-ressed and are in the group".
-- I also enrich the player data with class name.
---@param group_roster GroupRoster
---@param softres SoftRes
---@return GroupAwareSoftRes
function M.new( group_roster, softres )
  local f = group_roster.is_player_in_my_group
  local enrich_class = function( p )
    local player = group_roster.find_player( p.name )
    p.class = player and player.class
    return p
  end

  local function get( item_id )
    return map( filter( softres.get( item_id ), f, "name" ), enrich_class )
  end

  local function get_all_rollers()
    return map( filter( softres.get_all_rollers(), f, "name" ), enrich_class )
  end

  local decorator = clone( softres )
  decorator.get = get
  decorator.get_all_rollers = get_all_rollers

  return decorator
end

m.SoftResPresentPlayersDecorator = M
return M
