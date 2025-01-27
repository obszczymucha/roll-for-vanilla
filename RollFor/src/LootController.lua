RollFor = RollFor or {}
local m = RollFor

if m.LootController then return end

local M = m.Module.new( "LootController" )

---@class LootController
---@field show fun()
---@field update fun( preview_fn: RollControllerPreviewFn )
---@field hide fun()

---@param player_info PlayerInfo
---@param loot_list LootList
---@param loot_frame LootFrame
function M.new( player_info, loot_list, loot_frame )
  local selected_item_name = nil

  local function show()
    M.debug.add( "show" )
    loot_frame.show()
  end

  ---@param item DroppedItem
  ---@param preview_fn RollControllerPreviewFn
  local function select_item( item, preview_fn )
    selected_item_name = item.name
    preview_fn( item, 1 )
  end

  ---@param preview_fn RollControllerPreviewFn
  local function update( preview_fn )
    M.debug.add( "update" )

    local items = loot_list.get_items() ---@type (DroppedItem|Coin)[]
    ---@type LootFrameItem[]
    local result = {}

    for i, item in ipairs( items ) do
      local is_coin = item.type == "Coin"
      local item_to_select = item
      ---@type LootFrameItem
      table.insert( result, {
        index = i,
        texture = item.texture,
        name = is_coin and item.amount_text or item.name,
        quality = item.quality or 0,
        quantity = item.quantity,
        click_fn = function()
          if item_to_select.type == "Coin" or not player_info.is_master_looter() then return end
          select_item( item_to_select, preview_fn ); update( preview_fn )
        end,
        is_selected = selected_item_name and selected_item_name == item.name or false,
        is_enabled = not selected_item_name or selected_item_name == item.name or false,
        slot = loot_list.get_slot( is_coin and "Coin" or item.id ),
        tooltip_link = item.tooltip_link,
        comment = nil,
        comment_tooltip = nil
      } )
    end

    loot_frame.update( result )
  end

  local function hide()
    M.debug.add( "hide" )
    loot_frame.hide()
  end

  local function deselect()
    selected_item_name = nil
  end

  ---@type LootController
  return {
    show = show,
    update = update,
    hide = hide,
    deselect = deselect
  }
end

m.LootController = M
return M
