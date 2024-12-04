---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )

local clear = modules.clear_table

if modules.RollTracker then return end

local M = {}

function M.new()
  local callbacks = {}
  local rolls = {}
  local ignored_rolls = {}

  local function notify_subscribers( event_type, data )
    for _, callback in ipairs( callbacks[ event_type ] or {} ) do
      callback( data )
    end
  end

  local function start( rolling_strategy, item, count, info, seconds )
    clear( rolls )
    rolls.n = 0
    clear( ignored_rolls )
    ignored_rolls.n = 0

    notify_subscribers( "start", { rolling_strategy = rolling_strategy, item = item, count = count, info = info, seconds = seconds } )
  end

  local function tick( seconds )
    notify_subscribers( "tick", { seconds = seconds } )
  end

  local function stop( data )
    notify_subscribers( "stop", data )
  end

  local function cancel()
    notify_subscribers( "cancel" )
  end

  local function add( player_name, player_class, roll_type, roll )
    rolls[ roll_type ] = rolls[ roll_type ] or {}
    local data = { player_name = player_name, player_class = player_class, roll_type = roll_type, roll = roll }
    table.insert( rolls, data )
    notify_subscribers( "roll", data )
  end

  local function add_ignored( player_name, player_class, roll_type, roll, reason )
    ignored_rolls[ roll_type ] = ignored_rolls[ roll_type ] or {}
    local data = { player_name = player_name, player_class = player_class, roll_type = roll_type, roll = roll, reason = reason }
    table.insert( ignored_rolls, data )
    notify_subscribers( "ignored_roll", data )
  end

  local function get()
    return rolls
  end

  local function subscribe( event_type, callback )
    callbacks[ event_type ] = callbacks[ event_type ] or {}
    table.insert( callbacks[ event_type ], callback )
  end

  return {
    start = start,
    tick = tick,
    add = add,
    add_ignored = add_ignored,
    stop = stop,
    get = get,
    cancel = cancel,
    subscribe = subscribe
  }
end

modules.RollTracker = M
return M
