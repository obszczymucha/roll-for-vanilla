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
---@param ace_timer NotAceTimer
function M.new( config, boss_list, player_info, ace_timer )
  local threshold_timer
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

  local function on_softres_import()
    if not config.auto_master_loot() then return end

    if not m.is_master_loot() and player_info.is_leader() then
      m.set_loot_method( "master", player_info.get_name() )
    end
  end

  local function on_party_loot_method_changed()
    if threshold_timer then return end
    if not m.is_master_loot() or not player_info.is_master_looter() then return end

    local threshold = config.master_loot_threshold()
    if not threshold or m.api.GetLootThreshold() == threshold then return end

    -- Setting the threshold while the loot method is still changing reverts the loot method.
    threshold_timer = ace_timer.ScheduleTimer( M, function()
      threshold_timer = nil

      if m.is_master_loot() and player_info.is_master_looter() and m.api.GetLootThreshold() ~= threshold then
        m.api.SetLootThreshold( threshold )
      end
    end, 0.5 )
  end

  return {
    on_player_target_changed = on_player_target_changed,
    on_softres_import = on_softres_import,
    on_party_loot_method_changed = on_party_loot_method_changed
  }
end

m.AutoMasterLoot = M
return M
