RollFor = RollFor or {}
local m = RollFor

if m.MasterLoot then return end

local M = m.Module.new( "MasterLoot" )
local pretty_print = m.pretty_print
local hl = m.colors.hl
local clear_table = m.clear_table
local err = m.err

---@class MasterLoot
---@field on_loot_opened fun()
---@field on_recipient_inventory_full fun()
---@field on_player_is_too_far fun()
---@field on_unknown_error_message fun( message: string )
---@field on_loot_slot_cleared fun( slot: number )
---@field on_loot_received fun( player_name: string, item_id: number, item_link: string )

---@param master_loot_candidates MasterLootCandidates
---@param loot_award_callback LootAwardCallback
---@param loot_list LootList
---@param roll_controller RollController
function M.new( master_loot_candidates, loot_award_callback, loot_list, roll_controller )
  ---@type { player: ItemCandidate|Winner, item: Item }?
  local m_confirmed = nil
  local m_slot_cache = {}

  local function reset_confirmation()
    M.debug.add( "reset_confirmation" )
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
    M.debug.add( string.format( "on_loot_slot_cleared( %s )", slot or nil ) )
    if not m_slot_cache[ slot ] or not m_confirmed then return end

    local cached_item = m_slot_cache[ slot ]

    if cached_item.id == m_confirmed.item.id then
      loot_award_callback.on_loot_awarded( m_confirmed.item.id, m_confirmed.item.link, m_confirmed.player.name, m_confirmed.player.class )
      reset_confirmation()
    end

    m_slot_cache[ slot ] = nil
  end

  ---@param data AwardConfirmedData
  local function on_confirm( data )
    local player = data.player
    local item = data.item

    M.debug.add( string.format( "on_confirm( %s [%s], %s )", player and player.name or "nil", player and player.type or "nil", item and item.id or "nil" ) )
    local slot = loot_list.get_slot( item.id )
    if not slot then return end

    if player.type ~= "ItemCandidate" and not (player.type == "Winner" and player.is_on_master_loot_candidate_list) then
      err( "Player is not eligible for this item." )
      return
    end

    m_confirmed = { item = item, player = player }
    m_slot_cache[ slot ] = item

    local index = master_loot_candidates.get_index( slot, player.name )

    if not index then
      err( "Player is not in the loot candidates list." )
      return
    end

    m.api.GiveMasterLoot( slot, index )
  end

  local function on_loot_opened()
    M.debug.add( "on_loot_opened" )
    clear_table( m_slot_cache )
    reset_confirmation()
  end

  local function on_loot_received( player_name, item_id, item_link )
    M.debug.add( string.format( "on_loot_received( %s, %s, %s )", player_name or "nil", item_id or "nil", item_link or "nil" ) )
    local is_looting = loot_list.is_looting()
    if m_confirmed and is_looting then return end
    if not m_confirmed then return end

    -- This isn't tested, because it's hard to reproduce. Not sure if it can happen. Let's keep it here to be safe.
    if m_confirmed.item.id ~= item_id then return end

    loot_award_callback.on_loot_awarded( item_id, item_link, player_name )
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

  roll_controller.subscribe( "award_confirmed", on_confirm )

  ---@type MasterLoot
  return {
    on_loot_opened = on_loot_opened,
    on_recipient_inventory_full = on_recipient_inventory_full,
    on_player_is_too_far = on_player_is_too_far,
    on_unknown_error_message = on_unknown_error_message,
    on_loot_slot_cleared = on_loot_slot_cleared,
    on_loot_received = on_loot_received
  }
end

m.MasterLoot = M
return M
