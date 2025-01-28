RollFor = RollFor or {}
local m = RollFor

if m.LootController then return end

local getn = table.getn

local M = m.Module.new( "LootController" )

---@class LootController
---@field show fun()
---@field update fun( preview_fn: RollControllerPreviewFn )
---@field hide fun()

---@param player_info PlayerInfo
---@param loot_facade LootFacade
---@param loot_list LootList
---@param loot_frame LootFrame
---@param roll_controller RollController
---@param softres GroupAwareSoftRes
function M.new( player_info, loot_facade, loot_list, loot_frame, roll_controller, softres )
  local selected_item_name = nil

  local function show()
    M.debug.add( "show" )
    loot_frame.show()
  end

  ---@param item DroppedItem
  local function select_item( item )
    local count = loot_list.count( item.id )
    local sr_players = softres.get( item.id )
    local sr_player_count = getn( sr_players )

    selected_item_name = item.name
    roll_controller.preview( item, count == sr_player_count and count or 1 )
  end

  local function update()
    M.debug.add( "update" )

    local items = loot_list.get_items() ---@type (DroppedItem|Coin)[]
    ---@type LootFrameItem[]
    local result = {}

    local index = 1

    for _, item in pairs( items ) do
      local is_coin = item.type == "Coin"
      local item_to_select = item

      ---@type LootFrameItem
      table.insert( result, {
        index = index,
        texture = item.texture,
        name = is_coin and item.amount_text or item.name,
        quality = item.quality or 0,
        quantity = item.quantity,
        click_fn = function()
          if item_to_select.type == "Coin" or not player_info.is_master_looter() then return end
          select_item( item_to_select ); update()
        end,
        is_selected = selected_item_name and selected_item_name == item.name or false,
        is_enabled = not selected_item_name or selected_item_name == item.name or false,
        slot = loot_list.get_slot( is_coin and "Coin" or item.id ),
        tooltip_link = item.tooltip_link,
        comment = nil,
        comment_tooltip = nil
      } )

      index = index + 1
    end

    loot_frame.update( result )
  end

  local function hide()
    M.debug.add( "hide" )
    loot_frame.hide()
  end

  local function deselect()
    M.debug.add( "deselect" )
    selected_item_name = nil
    update()
  end

  local function on_loot_opened()
    M.debug.add( "loot_opened" )
    selected_item_name = nil
    show()
    update()
  end

  local function on_loot_slot_cleared( slot )
    M.debug.add( string.format( "loot_slot_cleared(%s)", slot ) )
    update()
  end

  local function on_loot_closed()
    M.debug.add( "loot_closed" )
    hide()
  end

  loot_facade.subscribe( "LootOpened", on_loot_opened )
  loot_facade.subscribe( "LootClosed", on_loot_closed )
  loot_facade.subscribe( "LootSlotCleared", on_loot_slot_cleared )
  roll_controller.subscribe( "LootFrameDeselect", deselect )

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
