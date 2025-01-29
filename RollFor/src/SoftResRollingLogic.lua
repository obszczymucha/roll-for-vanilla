RollFor = RollFor or {}
local m = RollFor

if m.SoftResRollingLogic then return end

local M = {}
local map = m.map
local count_elements = m.count_elements
local pretty_print = m.pretty_print
local take = m.take
local rlu = m.RollingLogicUtils
local RollType = m.Types.RollType
local RollingStrategy = m.Types.RollingStrategy

---@diagnostic disable-next-line: deprecated
local getn = table.getn

local State = { AfterRoll = 1, TimerStopped = 2, ManualStop = 3 }

local function is_the_winner_the_only_player_with_extra_rolls( rollers, rolls )
  local extra_rolls = rlu.players_with_available_rolls( rollers )
  if getn( extra_rolls ) > 1 then return false end

  local sorted_rolls = rlu.sort_rolls( rolls )
  return getn( sorted_rolls[ 1 ].players ) == 1 and sorted_rolls[ 1 ].players[ 1 ] == extra_rolls[ 1 ].name
end

local function winner_found( rollers, rolls )
  return rlu.has_everyone_rolled( rollers, rolls ) and is_the_winner_the_only_player_with_extra_rolls( rollers, rolls )
end

function M.new( announce, ace_timer, group_roster, sr_players, item, count, seconds, on_rolling_finished, on_softres_rolls_available, roll_controller, config )
  local rolls = {}
  local rolling = false
  local seconds_left = seconds
  local timer

  local function have_all_rolls_been_exhausted()
    for _, v in ipairs( sr_players ) do
      if v.rolls > 0 then return winner_found( sr_players, rolls ) end
    end

    return true
  end

  local function stop_timer()
    if timer then
      ace_timer:CancelTimer( timer )
      timer = nil
    end
  end

  local function stop_listening()
    rolling = false
    stop_timer()
  end

  local function find_winner( state )
    local rolls_exhausted = have_all_rolls_been_exhausted()

    if state == State.AfterRoll and not rolls_exhausted then return end

    if state == State.ManualStop and not rolls_exhausted or rolls_exhausted then
      stop_listening()
    end

    local roll_count = count_elements( rolls )

    if state == State.TimerStopped and not rolls_exhausted then
      stop_timer()
      on_softres_rolls_available( rlu.players_with_available_rolls( sr_players ) )
      return
    end

    if state == State.ManualStop and roll_count > 0 then
      stop_listening()
    end

    local sorted_rolls = rlu.sort_rolls( rolls, RollType.SoftRes )
    local winners = take( sorted_rolls, count )

    on_rolling_finished( item, count, winners )
  end

  local function on_roll( player_name, roll, min, max )
    local ms_threshold = config.ms_roll_threshold()
    local os_threshold = config.os_roll_threshold()
    local tmog_threshold = config.tmog_roll_threshold()

    if not rolling or min ~= 1 or (max ~= tmog_threshold and max ~= os_threshold and max ~= ms_threshold) then return end
    local player = group_roster.find_player( player_name )
    local ms_roll = max == ms_threshold
    local os_roll = max == os_threshold
    local roll_type = ms_roll and RollType.MainSpec or os_roll and RollType.OffSpec or RollType.Transmog

    if not rlu.can_roll( sr_players, player_name ) then
      pretty_print( string.format( "|cffff9f69%s|r did not SR %s. This roll (|cffff9f69%s|r) is ignored.", player_name, item.link, roll ) )
      roll_controller.add_ignored( player_name, player and player.class, roll_type, roll, "Did not soft-res." )
      return
    end

    if not ms_roll then
      pretty_print( string.format( "|cffff9f69%s|r did SR %s, but didn't roll MS. This roll (|cffff9f69%s|r) is ignored.", player_name, item.link, roll ) )
      roll_controller.add_ignored( player_name, player and player.class, roll_type, roll, "Didn't roll MS." )
      return
    end

    if not rlu.has_rolls_left( sr_players, player_name ) then
      pretty_print( string.format( "|cffff9f69%s|r exhausted their rolls. This roll (|cffff9f69%s|r) is ignored.", player_name, roll ) )
      roll_controller.add_ignored( player_name, player and player.class, roll_type, roll, "Rolled too many times." )
      return
    end

    rlu.subtract_roll( sr_players, player_name )
    rlu.record_roll( rolls, player_name, roll )
    roll_controller.add( player_name, player and player.class, RollType.SoftRes, roll )

    find_winner( State.AfterRoll )
  end

  local function stop_accepting_rolls( force )
    find_winner( force and State.ManualStop or State.TimerStopped )
  end

  -- TODO: Duplicated in NonSoftResRollingLogic (perhaps consolidate).
  local function on_timer()
    seconds_left = seconds_left - 1

    if seconds_left <= 0 then
      stop_accepting_rolls()
      return
    elseif seconds_left == 3 then
      announce( "Stopping rolls in 3" )
    elseif seconds_left < 3 then
      announce( seconds_left )
    end

    roll_controller.tick( seconds_left )
  end

  local function accept_rolls()
    rolling = true
    timer = ace_timer.ScheduleRepeatingTimer( M, on_timer, 1.7 )
    roll_controller.start( RollingStrategy.SoftResRoll, item, count, nil, seconds, sr_players )
    roll_controller.show()
  end

  local function announce_rolling()
    local name_with_rolls = function( player )
      if getn( sr_players ) == count then return player.name end
      local roll_count = player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
      -- add support for player.note
      local note = player.note != "" and string.format( " (%s)", player.note ) or ""
      return string.format( "%s%s%s", player.name, note, roll_count )
    end

    local count_str = count > 1 and string.format( "%sx", count ) or ""
    local x_rolls_win = count > 1 and string.format( ". %d top rolls win.", count ) or ""
    local ressed_by = m.prettify_table( map( sr_players, name_with_rolls ) )

    if count == getn( sr_players ) then
      announce( string.format( "%s soft-ressed %s.", ressed_by, item.link ), true )
      roll_controller.start( RollingStrategy.SoftResRoll, item, count, nil, nil, sr_players )
      roll_controller.show()
      on_rolling_finished( item, 0, { ressed_by }, false, true )
    else
      announce( string.format( "Roll for %s%s: (SR by %s)%s", count_str, item.link, ressed_by, x_rolls_win ), true )
      accept_rolls()
    end
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

    show( "SR", rlu.sort_rolls( rolls, RollType.SoftRes ) )
  end

  local function print_rolling_complete( canceled )
    pretty_print( string.format( "Rolling for %s has %s.", item.link, canceled and "been canceled" or "finished" ) )
  end

  local function cancel_rolling()
    stop_listening()
    print_rolling_complete( true )
    announce( string.format( "Rolling for %s has been canceled.", item.link ) )
  end

  local function is_rolling()
    return rolling
  end

  return {
    announce_rolling = announce_rolling,
    on_roll = on_roll,
    show_sorted_rolls = show_sorted_rolls,
    stop_accepting_rolls = stop_accepting_rolls,
    cancel_rolling = cancel_rolling,
    is_rolling = is_rolling,
    get_rolling_strategy = function() return m.Types.RollingStrategy.SoftResRoll end
  }
end

m.SoftResRollingLogic = M
return M
