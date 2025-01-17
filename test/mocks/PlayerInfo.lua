local M = {}

---@param name string?
---@param class string?
---@param is_master_looter boolean?
---@param is_leader boolean?
function M.new( name, class, is_master_looter, is_leader )
  ---@type PlayerInfo
  return {
    get_name = function() return name or "PrincessKenny" end,
    get_class = function() return class or "Warrior" end,
    is_master_looter = function() return is_master_looter or false end,
    is_leader = function() return is_leader or false end
  }
end

return M
