---@diagnostic disable-next-line: undefined-global
local modules = LibStub( "RollFor-Modules" )
if modules.TieRollingLogic then return end

local M = {}
local map = modules.map
local count_elements = modules.count_elements
local pretty_print = modules.pretty_print
local take = modules.take
local rlu = modules.RollingLogicUtils

---@diagnostic disable-next-line: deprecated
local getn = table.getn

function M.new( announce, players, item, count, on_rolling_finished )
  local rollers, rolls = map( players, rlu.one_roll ), {}
  local rolling = false

  local function stop_listening()
    rolling = false
  end

  local function have_all_rolls_been_exhausted()
    local roll_count = count_elements( rolls )

    if getn( rollers ) == count and roll_count == getn( rollers ) then
      return true
    end

    for _, v in pairs( rollers ) do
      if v.rolls > 0 then return false end
    end

    return true
  end

  local function find_winner()
    stop_listening()
    local roll_count = count_elements( rolls )

    if roll_count == 0 then
      on_rolling_finished( item, count, {}, true )
    end

    local sorted_rolls = rlu.sort_rolls( rolls )
    local winners = take( sorted_rolls, count )

    on_rolling_finished( item, count, winners, true )
  end

  local function on_roll( player_name, roll, min, max )
    if not rolling or min ~= 1 or max ~= 100 then return end

    if not rlu.has_rolls_left( rollers, player_name ) then
      pretty_print( string.format( "|cffff9f69%s|r exhausted their rolls. This roll (|cffff9f69%s|r) is ignored.", player_name, roll ) )
      return
    end

    rlu.subtract_roll( rollers, player_name )
    rlu.record_roll( rolls, player_name, roll )

    if have_all_rolls_been_exhausted() then find_winner() end
  end

  local function show_sorted_rolls( limit )
    local function show( prefix, sorted_rolls )
      pretty_print( string.format( "%s rolls:", prefix ) )
      local i = 0

      for _, v in ipairs( sorted_rolls ) do
        if limit and limit > 0 and i > limit then return end

        pretty_print( string.format( "[|cffff9f69%d|r]: %s", v[ "roll" ], modules.prettify_table( v[ "players" ] ) ) )
        i = i + 1
      end
    end

    show( "Tie", rlu.sort_rolls( rolls ) )
  end

  local function print_rolling_complete( cancelled )
    pretty_print( string.format( "Rolling for %s has %s.", item.link, cancelled and "been cancelled" or "finished" ) )
  end

  local function stop_accepting_rolls()
    stop_listening()
    find_winner()
  end

  local function cancel_rolling()
    stop_listening()
    print_rolling_complete( true )
  end

  local function is_rolling()
    return rolling
  end

  local function announce_rolling( text )
    rolling = true
    announce( text )
  end

  return {
    announce_rolling = announce_rolling,
    on_roll = on_roll,
    show_sorted_rolls = show_sorted_rolls,
    stop_accepting_rolls = stop_accepting_rolls,
    cancel_rolling = cancel_rolling,
    is_rolling = is_rolling,
    get_rolling_strategy = function() return modules.Types.RollingStrategy.TieRoll end
  }
end

modules.TieRollingLogic = M
return M
