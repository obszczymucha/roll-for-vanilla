RollFor = RollFor or {}
local m = RollFor

if m.LootAutoProcess then return end

local M = {}

---@type LT
local LT = m.ItemUtils.LootType
local clear_table = m.clear_table

---@class LootAutoProcess
---@field on_loot_opened fun()
---@field on_loot_slot_cleared fun( slot: number )
---@field on_loot_closed fun()

---@param config Config
---@param roll_tracker RollTracker
---@param loot_list LootList
---@param roll_controller RollController
---@param player_info PlayerInfo
---@return LootAutoProcess
function M.new( config, roll_tracker, loot_list, roll_controller, player_info )
  local loot_cache = {}
  -- local selected_loot_list_item

  local function process_next_item()
    local threshold = m.api.GetLootThreshold()
    local data = roll_tracker.get()
    local items = loot_list.get_items()
    local item_count = #items

    if item_count == 0 then return end

    local is_coin = items[ 1 ].type == LT.Coin
    local first_item = not is_coin and items[ 1 ]

    if first_item and first_item.quality >= threshold and not data.status then
      local count = loot_list.count( first_item.id )
      roll_controller.preview( first_item, count )
    end
  end

  local function on_loot_slot_cleared( slot )
    loot_cache[ slot ] = nil
  end

  local function on_loot_opened()
    for _, item in ipairs( loot_list.get_items() ) do
      local slot = loot_list.get_slot( item.id )

      if slot then
        loot_cache[ slot ] = item
      end
    end

    if not config.auto_process_loot() or not player_info.is_master_looter() then return end

    if config.autostart_loot_process() then
      process_next_item()
    end
  end

  local function on_loot_closed()
    clear_table( loot_cache )
    loot_cache.n = 0
  end

  -- local function on_loot_list_item_selected( selected_item )
  --   selected_loot_list_item = selected_item
  -- end
  --
  -- local function on_loot_list_item_deselected()
  --   selected_loot_list_item = nil
  -- end

  roll_controller.subscribe( "process_next_item", process_next_item )
  -- roll_controller.subscribe( "loot_list_item_selected", on_loot_list_item_selected )
  -- roll_controller.subscribe( "loot_list_item_deselected", on_loot_list_item_deselected )

  return {
    on_loot_opened = on_loot_opened,
    on_loot_slot_cleared = on_loot_slot_cleared,
    on_loot_closed = on_loot_closed
  }
end

m.LootAutoProcess = M
return M
