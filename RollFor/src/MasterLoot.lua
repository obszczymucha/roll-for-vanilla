RollFor = RollFor or {}
local m = RollFor

if m.MasterLoot then return end

local M = {}
local pretty_print = m.pretty_print
local hl = m.colors.hl
local clear_table = m.clear_table

---@diagnostic disable-next-line: deprecated
local getn = table.getn

function M.new( master_loot_candidates, award_item, master_loot_frame, loot_list )
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
      award_item( m_confirmed.player.name, m_confirmed.item.id, m_confirmed.item.link )
      reset_confirmation()
    end

    m_slot_cache[ slot ] = nil
  end

  local function on_confirm( player, item )
    local loot_item = loot_list.find_item( item.id )
    if not loot_item then return end

    if not player.value then
      pretty_print( "Player is not eligible for this item." )
      return
    end

    m_confirmed = { item = item, slot = loot_item.slot, player = player }
    m_slot_cache[ loot_item.slot ] = item
    m.api.GiveMasterLoot( loot_item.slot, player.value )
    master_loot_frame.hide()
  end

  local function show_loot_candidates_frame( item )
    master_loot_frame.create()
    master_loot_frame.hide()

    local candidates = master_loot_candidates.get()

    if getn( candidates ) == 0 then
      -- This happened before.
      m.pretty_print( "Game API didn't return any loot candidates.", m.colors.red )
      return
    end

    master_loot_frame.create_candidate_frames( candidates, item )
    master_loot_frame.show( item.link )
  end

  local function on_loot_opened()
    if not m.is_player_master_looter() then
      return
    end

    reset_confirmation()
  end

  local function on_loot_closed()
    clear_table( m_slot_cache )
    master_loot_frame.hide()
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
    on_loot_slot_cleared = on_loot_slot_cleared
  }
end

m.MasterLoot = M
return M
