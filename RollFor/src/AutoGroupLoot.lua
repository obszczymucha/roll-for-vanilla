RollFor = RollFor or {}
local m = RollFor

if m.AutoGroupLoot then return end

local M = {}

local ignore_zones = {
  "Blackwing Lair"
}

---@class AutoGroupLoot
---@field on_loot_opened fun()
---@field on_loot_slot_cleared fun()

---@param loot_list LootList
---@param config Config
---@param boss_list BossList
---@param player_info PlayerInfo
function M.new( loot_list, config, boss_list, player_info )
  local m_target_name
  local m_item_count

  local function on_loot_opened()
    m_target_name = m.target_name()
    m_item_count = #loot_list.get_items()
  end

  local function on_loot_slot_cleared()
    if m_item_count == nil then
      -- In case this is called before on_loot_opened
      return
    end

    m_item_count = m_item_count - 1
    if m_item_count > 0 then return end
    if not m_item_count or m_item_count > 0 then return end

    local zone_name = m.api.GetRealZoneText()
    if m.table_contains_value( ignore_zones, zone_name ) then return end
    local bosses = boss_list[ zone_name ] or {}
    local is_a_boss = m.table_contains_value( bosses, m_target_name )

    if is_a_boss and config.auto_group_loot() and m.is_master_loot() and player_info.is_leader() then
      m.api.SetLootMethod( "group" )
    end
  end

  ---@type AutoGroupLoot
  return {
    on_loot_opened = on_loot_opened,
    on_loot_slot_cleared = on_loot_slot_cleared
  }
end

m.AutoGroupLoot = M
return M
