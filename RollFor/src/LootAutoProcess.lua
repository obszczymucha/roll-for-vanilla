RollFor = RollFor or {}
local m = RollFor

if m.LootAutoProcess then return end

local M = {}
---@diagnostic disable-next-line: deprecated
local getn = table.getn
local clear_table = m.clear_table

function M.new( config, roll_tracker, loot_list, roll_controller )
  local loot_cache = {}

  local function process_next_item()
    local threshold = m.api.GetLootThreshold()
    local data = roll_tracker.get()
    local items = loot_list.get_items()
    local first_item = items and getn( items ) > 0 and not items[ 1 ].coin and items[ 1 ]

    if first_item and first_item.quality >= threshold and not data.status then
      roll_controller.preview( first_item )
    end
  end

  local function on_loot_slot_cleared( slot )
    loot_cache[ slot ] = nil
  end

  local function on_loot_opened()
    for _, item in ipairs( loot_list.get_items() ) do
      loot_cache[ item.slot ] = item
    end

    if not config.auto_process_loot() or not m.is_player_master_looter() then return end

    if config.autostart_loot_process() then
      process_next_item()
    end
  end

  local function on_loot_closed()
    clear_table( loot_cache )
    loot_cache.n = 0
  end

  roll_controller.subscribe( "process_next_item", process_next_item )

  return {
    on_loot_opened = on_loot_opened,
    on_loot_slot_cleared = on_loot_slot_cleared,
    on_loot_closed = on_loot_closed,
    process_next_item = process_next_item
  }
end

m.LootAutoProcess = M
return M
