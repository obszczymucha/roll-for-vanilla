RollFor = RollFor or {}
local m = RollFor

if m.LootFacadeListener then return end

local IU = m.ItemUtils

local M = {}

---@param loot_facade LootFacade
---@param auto_loot AutoLoot
---@param dropped_loot_announce DroppedLootAnnounce
---@param master_loot MasterLoot
---@param auto_group_loot AutoGroupLoot
---@param loot_frame LootFrame
---@param roll_controller RollController
---@param loot_auto_process LootAutoProcess
---@param player_info PlayerInfo
function M.new(
    loot_facade,
    auto_loot,
    dropped_loot_announce,
    master_loot,
    auto_group_loot,
    loot_frame,
    roll_controller,
    loot_auto_process,
    player_info
)
  loot_facade.subscribe( "LootOpened", function()
    auto_loot.on_loot_opened()
    dropped_loot_announce.on_loot_opened()
    master_loot.on_loot_opened()
    auto_group_loot.on_loot_opened()
    loot_frame.show()
    roll_controller.loot_opened()
    loot_auto_process.on_loot_opened()
  end )

  loot_facade.subscribe( "LootClosed", function()
    master_loot.on_loot_closed()
    roll_controller.loot_closed()
    loot_frame.hide()
    loot_auto_process.on_loot_closed()
  end )

  loot_facade.subscribe( "LootSlotCleared", function( slot )
    master_loot.on_loot_slot_cleared( slot )
    auto_group_loot.on_loot_slot_cleared()
    loot_frame.update()
  end )

  -- This covers the scenario where the master looter assigns the loot and then moves immediately,
  -- causing the loot frame to close. In normal circumstances, when the last item gets assigned,
  -- the LOOT_SLOT_CLEARED fires and then LOOT_CLOSED event follows. In this case, however,
  -- LOOT_CLOSED fires first, because of the player movement and the LOOT_SLOT_CLEARED doesn't
  -- (because we're not looting anymore).
  local function on_chat_msg_loot( message )
    for player_name, link_with_optional_quantity in string.gmatch( message, "(.-) receives loot: (.*)" ) do
      local item_link = IU.parse_link( link_with_optional_quantity )
      local item_id = item_link and IU.get_item_id( item_link )

      if item_id and item_link then
        master_loot.on_loot_received( player_name, item_id, item_link )
      end

      return
    end

    for link_with_optional_quantity in string.gmatch( message, "You receive loot: (.*)" ) do
      local item_link = IU.parse_link( link_with_optional_quantity )
      local item_id = item_link and IU.get_item_id( item_link )

      if item_id and item_link then
        master_loot.on_loot_received( player_info.get_name(), item_id, item_link )
      end

      return
    end
  end

  loot_facade.subscribe( "ChatMsgLoot", on_chat_msg_loot )
end

m.LootFacadeListener = M
return M
