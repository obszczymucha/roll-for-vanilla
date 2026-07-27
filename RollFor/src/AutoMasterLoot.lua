RollFor = RollFor or {}
local m = RollFor

if m.AutoMasterLoot then return end

local M = {}

---@class AutoMasterLoot
---@field on_player_target_changed fun( arg1: string )
---@field on_softres_import fun()
---@field on_party_loot_method_changed fun()

---@param config Config
---@param boss_list BossList
---@param player_info PlayerInfo
function M.new( config, boss_list, player_info )
  local should_change_threshold = false

  local function on_player_target_changed( arg1 )
    if not config.auto_master_loot() then return end

    local target_name = m.target_name()
    if not target_name or m.target_dead() then return end

    local zone_name = m.api.GetRealZoneText()
    local bosses = boss_list[ zone_name ] or {}
    local is_a_boss = m.table_contains_value( bosses, target_name )

    -- On Turtle, PLAYER_TARGET_CHANGED gets emitted with some float number as an argument automatically.
    -- We don't want to respond to these events.
    local auto_target = tonumber( arg1 )

    if is_a_boss and not auto_target and not m.is_master_loot() and player_info.is_leader() then
      m.set_loot_method( "master", player_info.get_name() )
    end
  end

  local function threshold_matches()
    local threshold = config.master_loot_threshold()
    return threshold and m.api.GetLootThreshold() == threshold
  end

  local function change_threshold()
    local threshold = config.master_loot_threshold()
    m.api.SetLootThreshold( threshold )
    should_change_threshold = false
  end

  local function on_softres_import()
    if not config.auto_master_loot() then return end

    local ml, leader = m.is_master_loot(), player_info.is_leader()

    if not ml and leader then
      should_change_threshold = not threshold_matches()
      m.set_loot_method( "master", player_info.get_name() )
    elseif ml and leader and not threshold_matches() then
      should_change_threshold = true
      change_threshold()
    end
  end

  local function on_party_loot_method_changed()
    if not should_change_threshold then return end
    if not m.is_master_loot() or not player_info.is_master_looter() then return end
    if threshold_matches() then return end

    change_threshold()
  end

  return {
    on_player_target_changed = on_player_target_changed,
    on_softres_import = on_softres_import,
    on_party_loot_method_changed = on_party_loot_method_changed
  }
end

m.AutoMasterLoot = M
return M
