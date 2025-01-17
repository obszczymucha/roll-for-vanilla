RollFor = RollFor or {}
local m = RollFor

if m.PlayerInfo then return end

---@class PlayerInfo
---@field get_name fun(): string
---@field get_class fun(): string
---@field is_master_looter fun(): boolean
---@field is_leader fun(): boolean

local M = {}

---@param api table
function M.new( api )
  local function get_name()
    return api.UnitName( "player" )
  end

  local function get_class()
    return api.UnitClass( "player" )
  end

  local function is_master_looter()
    if not api.IsInGroup() then return false end

    local loot_method, id = api.GetLootMethod()
    if loot_method ~= "master" or not id then return false end
    if id == 0 then return true end

    if api.IsInRaid() then
      local name = api.GetRaidRosterInfo( id )
      return name == get_name()
    end

    return api.UnitName( "party" .. id ) == get_name()
  end

  local function is_leader()
    return api.UnitIsPartyLeader( "player" )
  end

  ---@type PlayerInfo
  return {
    get_name = get_name,
    get_class = get_class,
    is_master_looter = is_master_looter,
    is_leader = is_leader
  }
end

m.PlayerInfo = M
return M
