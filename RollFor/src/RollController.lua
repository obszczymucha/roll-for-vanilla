RollFor = RollFor or {}
local m = RollFor

if m.RollController then return end

local M = m.Module.new( "RollController" )
local RS = m.Types.RollingStrategy
local S = m.Types.RollingStatus

function M.new( roll_tracker )
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

  local function preview( item )
    roll_tracker.preview( RS.SoftResRoll, item, 1, nil, item.sr_players )
    local color = get_color( item.quality )

    M.debug.add( "border_color" )
    notify_subscribers( "border_color", { color = color } )
    M.debug.add( "preview" )
    notify_subscribers( "preview", { item = item } )
  end

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
    roll_tracker.add_ignored( player_name, player_class, roll_type, roll, reason )
    notify_subscribers( "ignored_roll" )
  end

  local function tie( tied_players, roll_type, roll )
    M.debug.add( "tie" )
    roll_tracker.tie( tied_players, roll_type, roll )
    notify_subscribers( "tie" )
  end

  local function tie_start()
    M.debug.add( "tie_start" )
    roll_tracker.tie_start()
    notify_subscribers( "tie_start" )
  end

  local function tick( seconds_left )
    M.debug.add( "tick" )
    roll_tracker.tick( seconds_left )
    notify_subscribers( "tick" )
  end

  local function finish( winner )
    M.debug.add( "finish" )
    roll_tracker.finish( winner )
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

  local function loot_awarded( item_link )
    roll_tracker.clear()
    M.debug.add( "loot_awarded" )
    notify_subscribers( "loot_awarded", item_link )
    process_next_item()
  end

  local function award_loot( player, item, rolling_strategy, origin )
    M.debug.add( "award_loot" )
    notify_subscribers( "award_loot", { player = player, item = item, rolling_strategy = rolling_strategy, origin = origin } )
  end

  local function loot_opened()
    M.debug.add( "loot_opened" )
    notify_subscribers( "loot_opened" )
  end

  local function loot_closed()
    M.debug.add( "loot_closed" )
    notify_subscribers( "loot_closed" )
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

  return {
    preview = preview,
    start = start,
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
    award_loot = award_loot,
    loot_opened = loot_opened,
    loot_closed = loot_closed,
    player_already_has_unique_item = player_already_has_unique_item,
    player_has_full_bags = player_has_full_bags,
    player_not_found = player_not_found,
    cant_assign_item_to_that_player = cant_assign_item_to_that_player,
    rolling_popup_closed = rolling_popup_closed,
    loot_award_popup_closed = loot_award_popup_closed
  }
end

m.RollController = M
return M
