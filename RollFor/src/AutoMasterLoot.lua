RollFor = RollFor or {}
local m = RollFor

if m.AutoMasterLoot then return end

local M = {}

function M.new( config, boss_list )
  local function on_player_target_changed()
    if not config.auto_master_loot() then return end

    local target_name = m.target_name()
    if not target_name then return end

    local zone_name = m.api.GetRealZoneText()
    local bosses = boss_list[ zone_name ] or {}
    local is_a_boss = m.table_contains_value( bosses, target_name )

    if is_a_boss and not m.is_master_loot() and m.is_player_a_leader() then
      m.api.SetLootMethod( "master", m.my_name() )
    end
  end

  return {
    on_player_target_changed = on_player_target_changed
  }
end

m.AutoMasterLoot = M
return M
