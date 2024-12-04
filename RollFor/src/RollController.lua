---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )

if modules.RollController then return end

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
    local _, _, quality = modules.api.GetItemInfo( string.format( "item:%s:0:0:0", item.id ) )
    local color = modules.api.ITEM_QUALITY_COLORS[ quality ] or { r = 0, g = 0, b = 0, a = 1 }

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
    show = show
  }
end

modules.RollController = M
return M
