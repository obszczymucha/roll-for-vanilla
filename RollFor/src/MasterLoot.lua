RollFor = RollFor or {}
local m = RollFor

if m.MasterLoot then return end

local M = m.Module.new( "MasterLoot" )
local pretty_print = m.pretty_print
local hl = m.colors.hl
local clear_table = m.clear_table
local err = m.err

---@diagnostic disable-next-line: deprecated
local getn = table.getn

---@class MasterLoot
---@field on_loot_opened fun()
---@field on_loot_closed fun()
---@field on_recipient_inventory_full fun()
---@field on_player_is_too_far fun()
---@field on_unknown_error_message fun( message: string )
---@field on_confirm fun( player: ItemCandidate|Winner, item: DroppedItem )
---@field show_loot_candidates_frame fun( item: DroppedItem, strategy: RollingStrategyType )
---@field on_loot_slot_cleared fun( slot: number )
---@field on_loot_received fun( player_name: string, item_id: number, item_link: string )

---@param master_loot_candidates MasterLootCandidates
---@param loot_award_callback LootAwardCallback
---@param master_loot_frame MasterLootCandidateSelectionFrame
---@param loot_list LootList
---@param player_info PlayerInfo
---@return MasterLoot
function M.new( master_loot_candidates, loot_award_callback, master_loot_frame, loot_list, player_info )
  ---@type { player: ItemCandidate|Winner, item: Item }
  local m_confirmed = nil
  local m_slot_cache = {}

  local function reset_confirmation()
    m_confirmed = nil
  end

  -- We are storing the item in the slot cache (m_slot_cache) and ML confirmation (m_confirmed).
  -- This is to correlate the loot award event which we have to do using LOOT_SLOT_CLEARED,
  -- because CHAT_MSG_LOOT doesn't seem to be synced with LOOT_ events.
  -- Normally one would expect CHAT_MSG_LOOT to happen before LOOT_SLOT_CLEARED, or at least
  -- before LOOT_CLOSED, but this is what happened once:
  -- LOOT_OPENED -> LOOT_SLOT_CLEARED -> LOOT_CLOSED -> CHAT_MSG_LOOT.
  -- It's safer and simpler to just rely on LOOT_ events.
  local function on_loot_slot_cleared( slot )
    if not m_slot_cache[ slot ] or not m_confirmed then return end

    local cached_item = m_slot_cache[ slot ]

    if cached_item.id == m_confirmed.item.id then
      loot_award_callback.on_loot_awarded( m_confirmed.player.name, m_confirmed.item.id, m_confirmed.item.link )
      reset_confirmation()
    end

    m_slot_cache[ slot ] = nil
  end

  ---@param player ItemCandidate|Winner
  ---@param item Item
  local function on_confirm( player, item )
    local slot = loot_list.get_slot( item.id )
    if not slot then return end

    if player.type ~= "ItemCandidate" and not (player.type == "Winner" and player.is_on_master_loot_candidate_list) then
      err( "Player is not eligible for this item." )
      return
    end

    m_confirmed = { item = item, player = player }
    m_slot_cache[ slot ] = item

    local index = master_loot_candidates.get_index( player.name )

    if not index then
      err( "Player is not in the loot candidates list." )
      return
    end

    m.api.GiveMasterLoot( slot, index )
    master_loot_frame.hide()
  end

  ---@param item DroppedItem
  ---@param strategy RollingStrategyType
  local function show_loot_candidates_frame( item, strategy )
    master_loot_frame.create()
    master_loot_frame.hide()

    local candidates = master_loot_candidates.get()

    if getn( candidates ) == 0 then
      -- This happened before.
      m.pretty_print( "Game API didn't return any loot candidates.", m.colors.red )
      return
    end

    master_loot_frame.create_candidate_frames( candidates, item, strategy )
    master_loot_frame.show( item.link )
  end

  local function on_loot_opened()
    clear_table( m_slot_cache )

    if not player_info.is_master_looter() then
      return
    end

    reset_confirmation()
  end

  local function on_loot_closed()
    -- Do not clear items when the loot window is closed.
    -- It's possible that the item was master looted and the master looter moved the character quickly,
    -- which in turn closed the loot window. This can trigger LOOT_CLOSED and we don't want to clear
    -- the items in that case. When the loot is closed the LOOT_SLOT_CLEARED doesn't fire for us, so
    -- we need to additionally check the CHAT_MSG_LOOT below.
    -- clear_table( m_slot_cache )
    master_loot_frame.hide()
  end

  local function on_loot_received( player_name, item_id, item_link )
    local is_looting = loot_list.is_looting()
    if m_confirmed and is_looting then return end
    if not m_confirmed then return end
    if m_confirmed.item.id ~= item_id then return end

    loot_award_callback.on_loot_awarded( player_name, item_id, item_link )
    reset_confirmation()
  end

  local function on_recipient_inventory_full()
    if m_confirmed then
      pretty_print( string.format( "%s%s bags are full.", hl( m_confirmed.player.name ), m.possesive_case( m_confirmed.player.name ) ), "red" )
      reset_confirmation()
    end
  end

  local function on_player_is_too_far()
    if m_confirmed then
      pretty_print( string.format( "%s is too far to receive the item.", hl( m_confirmed.player.name ) ), "red" )
      reset_confirmation()
    end
  end

  local function on_unknown_error_message( message )
    if m_confirmed then
      if message ~= "You are too far away!" and message ~= "You must be in a raid group to enter this instance" then
        pretty_print( message, "red" )
      end

      reset_confirmation()
    end
  end

  return {
    on_loot_opened = on_loot_opened,
    on_loot_closed = on_loot_closed,
    on_recipient_inventory_full = on_recipient_inventory_full,
    on_player_is_too_far = on_player_is_too_far,
    on_unknown_error_message = on_unknown_error_message,
    on_confirm = on_confirm,
    show_loot_candidates_frame = show_loot_candidates_frame,
    on_loot_slot_cleared = on_loot_slot_cleared,
    on_loot_received = on_loot_received
  }
end

m.MasterLoot = M
return M
