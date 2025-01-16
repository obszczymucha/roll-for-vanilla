---@diagnostic disable-next-line: undefined-global
RollFor = RollFor or {}
local m = RollFor

if m.MasterLooter then return end

local M = {}

---@class MasterLooter
---@field is_player_master_looter fun(): boolean

---@param api table
---@param my_name string
---@return MasterLooter
function M.new( api, my_name )
  local function is_player_master_looter()
    if not api.IsInGroup() then return false end

    local loot_method, id = api.GetLootMethod()
    if loot_method ~= "master" or not id then return false end
    if id == 0 then return true end

    if api.IsInRaid() then
      local name = api.GetRaidRosterInfo( id )
      return name == my_name
    end

    return api.UnitName( "party" .. id ) == my_name
  end

  return {
    is_player_master_looter = is_player_master_looter
  }
end

m.MasterLooter = M
return M
