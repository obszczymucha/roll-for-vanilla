---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.AutoMasterLoot then return end

local M = {}

function M.new( config, boss_list )
  local function on_player_target_changed()
    if not config.auto_master_loot() then return end

    local target_name = modules.target_name()
    if not target_name then return end

    local zone_name = modules.api.GetRealZoneText()
    local bosses = boss_list[ zone_name ] or {}
    local is_a_boss = modules.table_contains_value( bosses, target_name )

    if is_a_boss and not modules.is_master_loot() and modules.is_player_a_leader() then
      modules.api.SetLootMethod( "master", modules.my_name() )
    end
  end

  return {
    on_player_target_changed = on_player_target_changed
  }
end

modules.AutoMasterLoot = M
return M
