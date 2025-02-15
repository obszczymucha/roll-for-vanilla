local M = {}

---@param group_roster GroupRoster?
---@param loot_list LootList?
function M.new( group_roster, loot_list )
  local function get( _, index )
    if loot_list and not loot_list.is_looting() then return end

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
