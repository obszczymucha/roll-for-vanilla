---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.AutoGroupLoot then return end

local M = {}

local ignore_zones = {
  "Blackwing Lair"
}

function M.new( config, boss_list )
  local m_target_name
  local m_item_count

  local function on_loot_opened()
    m_target_name = modules.target_name()
    m_item_count = modules.api.GetNumLootItems() or 0
  end

  local function on_loot_slot_cleared()
    m_item_count = m_item_count - 1
    if m_item_count > 0 then return end
    if not m_item_count or m_item_count > 0 then return end

    local zone_name = modules.api.GetRealZoneText()
    if modules.table_contains_value( ignore_zones, zone_name ) then return end
    local bosses = boss_list[ zone_name ] or {}
    local is_a_boss = modules.table_contains_value( bosses, m_target_name )

    if is_a_boss and config.auto_group_loot() and modules.is_master_loot() and modules.is_player_a_leader() then
      modules.api.SetLootMethod( "group" )
    end
  end

  return {
    on_loot_opened = on_loot_opened,
    on_loot_slot_cleared = on_loot_slot_cleared
  }
end

modules.AutoGroupLoot = M
return M
