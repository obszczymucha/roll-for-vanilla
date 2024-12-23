RollFor = RollFor or {}
local m = RollFor

if m.RollController then return end

local M = {}

function M.new( roll_tracker )
  local callbacks = {}

  local function notify_subscribers( event_type, data )
    for _, callback in ipairs( callbacks[ event_type ] or {} ) do
      callback( data )
    end
  end

  local function start( rolling_strategy, item, count, info, seconds, required_rolling_players )
    roll_tracker.start( rolling_strategy, item, count, info, seconds, required_rolling_players )
    local _, _, quality = m.api.GetItemInfo( string.format( "item:%s:0:0:0", item.id ) )
    local color = m.api.ITEM_QUALITY_COLORS[ quality ] or { r = 0, g = 0, b = 0, a = 1 }

    local multiplier = 0.5
    local alpha = 0.6
    local c = { r = color.r * multiplier, g = color.g * multiplier, b = color.b * multiplier, a = alpha }

    notify_subscribers( "border_color", { color = c } )
    notify_subscribers( "start" )
  end

  local function add( player_name, player_class, roll_type, roll )
    roll_tracker.add( player_name, player_class, roll_type, roll )
    notify_subscribers( "roll" )
  end

  local function add_ignored( player_name, player_class, roll_type, roll, reason )
    roll_tracker.add_ignored( player_name, player_class, roll_type, roll, reason )
    notify_subscribers( "ignored_roll" )
  end

  local function tie( tied_players, roll_type, roll )
    roll_tracker.tie( tied_players, roll_type, roll )
    notify_subscribers( "tie" )
  end

  local function tie_start()
    roll_tracker.tie_start()
    notify_subscribers( "tie_start" )
  end

  local function tick( seconds_left )
    roll_tracker.tick( seconds_left )
    notify_subscribers( "tick" )
  end

  local function finish( winner )
    roll_tracker.finish( winner )
    notify_subscribers( "finish" )
  end

  local function cancel()
    roll_tracker.cancel()
    notify_subscribers( "cancel" )
  end

  local function subscribe( event_type, callback )
    callbacks[ event_type ] = callbacks[ event_type ] or {}
    table.insert( callbacks[ event_type ], callback )
  end

  local function waiting_for_rolls()
    roll_tracker.waiting_for_rolls()
    notify_subscribers( "waiting_for_rolls" )
  end

  local function show()
    notify_subscribers( "show" )
  end

  local function award_aborted()
    notify_subscribers( "award_aborted" )
  end

  local function loot_awarded( item_link )
    roll_tracker.clear()
    notify_subscribers( "loot_awarded", item_link )
  end

  local function award_loot( player, item_link, rolling_strategy )
    notify_subscribers( "award_loot", { player = player, item_link = item_link, rolling_strategy = rolling_strategy } )
  end

  local function loot_closed()
    notify_subscribers( "loot_closed" )
  end

  local function player_already_has_unique_item()
    notify_subscribers( "player_already_has_unique_item" )
  end

  local function player_has_full_bags()
    notify_subscribers( "player_has_full_bags" )
  end

  local function player_not_found()
    notify_subscribers( "player_not_found" )
  end

  local function cant_assign_item_to_that_player()
    notify_subscribers( "cant_assign_item_to_that_player" )
  end

  return {
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
    loot_closed = loot_closed,
    player_already_has_unique_item = player_already_has_unique_item,
    player_has_full_bags = player_has_full_bags,
    player_not_found = player_not_found,
    cant_assign_item_to_that_player = cant_assign_item_to_that_player,
  }
end

m.RollController = M
return M
