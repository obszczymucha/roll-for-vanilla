RollFor = RollFor or {}
local m = RollFor

if m.RollController then return end

local M = m.Module.new( "RollController" )
local S = m.Types.RollingStatus
local getn = table.getn

---@type PT
local PT = m.Types.PlayerType

---@class RollController
---@field preview fun( item: DroppedItem|HardRessedDroppedItem|SoftRessedDroppedItem, count: number )
---@field start fun( rolling_strategy: RollingStrategyType, item: Item, count: number, info: string?, seconds: number?, required_rolling_players: Player[]?)
---@field winners_found fun( item: Item, item_count: number, winners: Winner[], strategy: RollingStrategyType )
---@field finish fun()
---@field tick fun( seconds_left: number )
---@field add fun( player_name: string, player_class: string, roll_type: RollType, roll: number )
---@field add_ignored fun( player_name: string, player_class: string?, roll_type: RollType, roll: number, reason: string )
---@field cancel fun()
---@field subscribe fun( event_type: string, callback: fun( data: any ) )
---@field tie fun( tied_players: RollingPlayer[], item: Item, item_count: number, roll_type: RollType, roll: number, rerolling: boolean?, top_roll: boolean? )
---@field tie_start fun()
---@field waiting_for_rolls fun()
---@field show fun()
---@field award_aborted fun( item: Item )
---@field loot_awarded fun( player_name: string, item_id: number, item_link: string )
---@field show_master_loot_confirmation fun( player: ItemCandidate|Winner, item: DroppedItem|SoftRessedDroppedItem, rolling_strategy: RollingStrategyType )
---@field loot_opened fun()
---@field loot_closed fun()
---@field player_already_has_unique_item fun()
---@field player_has_full_bags fun()
---@field player_not_found fun()
---@field cant_assign_item_to_that_player fun()
---@field rolling_popup_closed fun()
---@field loot_award_popup_closed fun()
---@field loot_list_item_selected fun()
---@field loot_list_item_deselected fun()
---@field process_next_item fun()

---@param roll_tracker RollTracker
---@param master_looter MasterLooter
---@return RollController
function M.new( roll_tracker, master_looter )
  local callbacks = {}

  local function notify_subscribers( event_type, data )
    for _, callback in ipairs( callbacks[ event_type ] or {} ) do
      callback( data )
    end
  end

  local function get_color( quality )
    local color = m.api.ITEM_QUALITY_COLORS[ quality ] or { r = 0, g = 0, b = 0, a = 1 }

    local multiplier = 0.5
    local alpha = 0.6
    local c = { r = color.r * multiplier, g = color.g * multiplier, b = color.b * multiplier, a = alpha }

    return c
  end

  ---@param item DroppedItem|HardRessedDroppedItem|SoftRessedDroppedItem
  ---@param count number
  local function preview( item, count )
    roll_tracker.preview( item, count )
    local color = get_color( item.quality )

    M.debug.add( "border_color" )
    notify_subscribers( "border_color", { color = color } )
    M.debug.add( "preview" )
    notify_subscribers( "preview", { item = item } )
  end

  ---@param rolling_strategy RollingStrategyType
  ---@param item Item
  ---@param count number
  ---@param info string?
  ---@param seconds number?
  ---@param required_rolling_players Player[]?
  local function start( rolling_strategy, item, count, info, seconds, required_rolling_players )
    roll_tracker.start( rolling_strategy, item, count, info, seconds, required_rolling_players )
    local _, _, quality = m.api.GetItemInfo( string.format( "item:%s:0:0:0", item.id ) )
    local color = get_color( quality )

    M.debug.add( "border_color" )
    notify_subscribers( "border_color", { color = color } )
    M.debug.add( "start" )
    notify_subscribers( "start" )
  end

  local function add( player_name, player_class, roll_type, roll )
    M.debug.add( "roll" )
    roll_tracker.add( player_name, player_class, roll_type, roll )
    notify_subscribers( "roll" )
  end

  local function add_ignored( player_name, player_class, roll_type, roll, reason )
    M.debug.add( "ignored_roll" )
    roll_tracker.add_ignored( player_name, roll_type, roll, reason )
    notify_subscribers( "ignored_roll", {
      player_name = player_name,
      player_class = player_class,
      roll_type = roll_type,
      roll = roll,
      reason = reason
    } )
  end

  local function tie( players, item, item_count, roll_type, roll, rerolling, top_roll )
    M.debug.add( "tie" )
    roll_tracker.tie( players, roll_type, roll )
    notify_subscribers( "tie", {
      players = players,
      item = item,
      item_count = item_count,
      roll_type = roll_type,
      roll = roll,
      rerolling = rerolling,
      top_roll = top_roll
    } )
  end

  local function tie_start()
    M.debug.add( "tie_start" )
    roll_tracker.tie_start()
    notify_subscribers( "tie_start" )
  end

  local function tick( seconds_left )
    M.debug.add( "tick" )
    roll_tracker.tick( seconds_left )
    notify_subscribers( "tick", { seconds_left = seconds_left } )
  end

  ---@param item Item
  ---@param item_count number
  ---@param winners Winner[]
  ---@param strategy RollingStrategyType
  local function winners_found( item, item_count, winners, strategy )
    M.debug.add( "winners_found" )
    roll_tracker.add_winners( winners )
    notify_subscribers( "winners_found", { item = item, item_count = item_count, winners = winners, rolling_strategy = strategy } )
  end

  local function finish()
    M.debug.add( "finish" )
    roll_tracker.finish()
    notify_subscribers( "finish" )
  end

  local function cancel()
    M.debug.add( "cancel" )
    roll_tracker.cancel()
    notify_subscribers( "cancel" )
  end

  local function subscribe( event_type, callback )
    callbacks[ event_type ] = callbacks[ event_type ] or {}
    table.insert( callbacks[ event_type ], callback )
  end

  local function waiting_for_rolls()
    M.debug.add( "waiting_for_rolls" )
    roll_tracker.waiting_for_rolls()
    notify_subscribers( "waiting_for_rolls" )
  end

  local function show()
    M.debug.add( "show" )
    notify_subscribers( "show" )
  end

  local function process_next_item()
    M.debug.add( "process_next_item" )
    if not master_looter.is_player_master_looter() then return end
    notify_subscribers( "process_next_item" )
  end

  local function award_aborted( item )
    M.debug.add( "award_aborted" )
    notify_subscribers( "award_aborted", { item = item } )

    local data, current_iteration = roll_tracker.get()

    if not data or not data.status or not data.item or not current_iteration then
      process_next_item()
      return
    end
  end

  ---@param player_name string
  ---@param item_id number
  ---@param item_link string
  local function loot_awarded( player_name, item_id, item_link )
    M.debug.add( "loot_awarded" )
    roll_tracker.loot_awarded( player_name, item_id )
    notify_subscribers( "loot_awarded", { player_name = player_name, item_id = item_id, item_link = item_link } )
    process_next_item()

    local data = roll_tracker.get()

    if getn( data.winners ) == 0 then
      notify_subscribers( "all_items_awarded" )
    else
      notify_subscribers( "not_all_items_awarded" )
    end
  end

  ---@param player ItemCandidate|Winner
  ---@param item DroppedItem|SoftRessedDroppedItem
  ---@param strategy RollingStrategyType
  local function show_master_loot_confirmation( player, item, strategy )
    M.debug.add( "show_master_loot_confirmation" )
    if player.type == PT.Winner and not player.is_on_master_loot_candidate_list then return end
    notify_subscribers( "rolling_popup_hide" )
    notify_subscribers( "show_master_loot_confirmation", { player = player, item = item, rolling_strategy = strategy } )
  end

  local function loot_opened()
    M.debug.add( "loot_opened" )
    notify_subscribers( "loot_opened" )
  end

  local function loot_closed()
    M.debug.add( "loot_closed" )
    local status = roll_tracker.get().status

    notify_subscribers( "loot_closed" )

    if status and status.type == S.Preview then
      notify_subscribers( "rolling_popup_hide" )
    end
  end

  local function player_already_has_unique_item()
    M.debug.add( "player_already_has_unique_item" )
    notify_subscribers( "player_already_has_unique_item" )
  end

  local function player_has_full_bags()
    M.debug.add( "player_has_full_bags" )
    notify_subscribers( "player_has_full_bags" )
  end

  local function player_not_found()
    M.debug.add( "player_not_found" )
    notify_subscribers( "player_not_found" )
  end

  local function cant_assign_item_to_that_player()
    M.debug.add( "cant_assign_item_to_that_player" )
    notify_subscribers( "cant_assign_item_to_that_player" )
  end

  local function rolling_popup_closed()
    M.debug.add( "rolling_popup_closed" )
    notify_subscribers( "rolling_popup_closed" )

    local data = roll_tracker.get()

    if data and data.status and data.status.type == S.Preview then
      roll_tracker.clear()
    end
  end

  local function loot_award_popup_closed()
    M.debug.add( "loot_award_popup_closed" )
    notify_subscribers( "loot_award_popup_closed" )
  end

  local function loot_list_item_selected()
    M.debug.add( "loot_list_item_selected" )
    notify_subscribers( "loot_list_item_selected" )
  end

  local function loot_list_item_deselected()
    M.debug.add( "loot_list_item_deselected" )
    notify_subscribers( "loot_list_item_deselected" )
  end

  return {
    preview = preview,
    start = start,
    winners_found = winners_found,
    finish = finish,
    tick = tick,
    add = add,
    add_ignored = add_ignored,
    cancel = cancel,
    subscribe = subscribe,
    waiting_for_rolls = waiting_for_rolls,
    tie = tie,
    tie_start = tie_start,
    show = show,
    award_aborted = award_aborted,
    loot_awarded = loot_awarded,
    show_master_loot_confirmation = show_master_loot_confirmation,
    loot_opened = loot_opened,
    loot_closed = loot_closed,
    player_already_has_unique_item = player_already_has_unique_item,
    player_has_full_bags = player_has_full_bags,
    player_not_found = player_not_found,
    cant_assign_item_to_that_player = cant_assign_item_to_that_player,
    rolling_popup_closed = rolling_popup_closed,
    loot_award_popup_closed = loot_award_popup_closed,
    loot_list_item_selected = loot_list_item_selected,
    loot_list_item_deselected = loot_list_item_deselected,
  }
end

m.RollController = M
return M
