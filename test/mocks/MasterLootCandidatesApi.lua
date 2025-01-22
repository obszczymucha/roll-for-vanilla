local M = {}

---@param group_roster GroupRoster?
function M.new( group_roster )
  local function get( index )
    local players = group_roster and group_roster.get_all_players_in_my_group() or {}

    for i, player in ipairs( players ) do
      if i == index then return player.name end
    end
  end

  ---@type MasterLootCandidatesApi
  return {
    GetMasterLootCandidate = get
  }
end

return M
