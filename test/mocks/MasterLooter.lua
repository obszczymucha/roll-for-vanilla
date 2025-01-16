local M = {}

---@param is_player_master_looter boolean
---@return MasterLooter
function M.new( is_player_master_looter )
  return {
    is_player_master_looter = function() return is_player_master_looter end
  }
end

return M
