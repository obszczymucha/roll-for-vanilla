RollFor = RollFor or {}
local m = RollFor

if m.TieRollingLogic then return end

local M = {}
local map = m.map
local count_elements = m.count_elements
local pretty_print = m.pretty_print
local take = m.take
local rlu = m.RollingLogicUtils
local RollType = m.Types.RollType
local hl = m.colors.hl

---@diagnostic disable-next-line: deprecated
local getn = table.getn

function M.new( announce, players, item, count, on_rolling_finished, roll_type, config, group_roster, roll_controller )
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
      return
    end

    local sorted_rolls = map( rlu.sort_rolls( rolls, roll_type ), function( v )
      v.roll_type = roll_type
      return v
    end )
    local winners = take( sorted_rolls, count )

    on_rolling_finished( item, count, winners, true )
  end

  local function on_roll( player_name, roll, min, max )
    local ms_threshold = config.ms_roll_threshold()
    local os_threshold = config.os_roll_threshold()
    local tmog_threshold = config.tmog_roll_threshold()

    if not rolling or min ~= 1 or (max ~= tmog_threshold and max ~= os_threshold and max ~= ms_threshold) then return end

    local ms_roll = max == ms_threshold
    local os_roll = max == os_threshold
    local actual_roll_type = ms_roll and RollType.MainSpec or os_roll and RollType.OffSpec or RollType.Transmog

    if actual_roll_type ~= roll_type and not (actual_roll_type == RollType.MainSpec and roll_type == RollType.SoftRes) then
      local roll_threshold_str = config.roll_threshold( roll_type ).str
      pretty_print( string.format( "|cffff9f69%s|r didn't %s. This roll (|cffff9f69%s|r) is ignored.", player_name, hl( roll_threshold_str ), roll ) )
      return
    end

    if not rlu.has_rolls_left( rollers, player_name ) then
      pretty_print( string.format( "|cffff9f69%s|r exhausted their rolls. This roll (|cffff9f69%s|r) is ignored.", player_name, roll ) )
      return
    end

    rlu.subtract_roll( rollers, player_name )
    rlu.record_roll( rolls, player_name, roll )

    local player = group_roster.find_player( player_name )
    roll_controller.add( player_name, player and player.class, roll_type, roll )

    if have_all_rolls_been_exhausted() then find_winner() end
  end

  local function show_sorted_rolls( limit )
    local function show( prefix, sorted_rolls )
      pretty_print( string.format( "%s rolls:", prefix ) )
      local i = 0

      for _, v in ipairs( sorted_rolls ) do
        if limit and limit > 0 and i > limit then return end

        pretty_print( string.format( "[|cffff9f69%d|r]: %s", v[ "roll" ], m.prettify_table( v[ "players" ] ) ) )
        i = i + 1
      end
    end

    show( "Tie", rlu.sort_rolls( rolls, roll_type ) )
  end

  local function print_rolling_complete( canceled )
    pretty_print( string.format( "Rolling for %s has %s.", item.link, canceled and "been canceled" or "finished" ) )
  end

  local function stop_accepting_rolls()
    stop_listening()
    find_winner()
  end

  local function cancel_rolling()
    stop_listening()
    print_rolling_complete( true )
    announce( string.format( "Rolling for %s has been canceled.", item.link ) )
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
    get_rolling_strategy = function() return m.Types.RollingStrategy.TieRoll end
  }
end

m.TieRollingLogic = M
return M
