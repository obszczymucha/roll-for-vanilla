RollFor = RollFor or {}
local m = RollFor

if m.NonSoftResRollingLogic then return end

local M = {}
local count_elements = m.count_elements
local pretty_print = m.pretty_print
local merge = m.merge
local take = m.take
local rlu = m.RollingLogicUtils
local RollType = m.Types.RollType
local RollingStrategy = m.Types.RollingStrategy

---@type MakeRollFn
local make_roll = m.Types.make_roll

---@diagnostic disable-next-line: deprecated
local getn = table.getn

---@param players RollingPlayer[]
local function have_all_players_rolled( players )
  for _, v in pairs( players ) do
    if v.rolls > 0 then return false end
  end

  return true
end

---@param announce AnnounceFn
---@param ace_timer AceTimer
---@param players RollingPlayer[]
---@param item Item
---@param item_count number
---@param info string?
---@param seconds number
---@param on_rolling_finished RollingFinishedCallback
---@param config Config
---@param roll_controller RollController
function M.new( announce, ace_timer, players, item, item_count, info, seconds, on_rolling_finished, config, roll_controller )
  local mainspec_rollers, mainspec_rolls = players, {}
  local offspec_rollers, offspec_rolls = rlu.copy_rollers( mainspec_rollers ), {}
  local tmog_rollers, tmog_rolls = rlu.copy_rollers( mainspec_rollers ), {}
  local rolling = false
  local seconds_left = seconds
  local timer

  local ms_threshold = config.ms_roll_threshold()
  local os_threshold = config.os_roll_threshold()
  local tmog_threshold = config.tmog_roll_threshold()
  local tmog_rolling_enabled = config.tmog_rolling_enabled()

  local function sort_rolls()
    table.sort( mainspec_rolls, function( a, b )
      return a.roll > b.roll
    end )

    table.sort( offspec_rolls, function( a, b )
      return a.roll > b.roll
    end )

    table.sort( tmog_rolls, function( a, b )
      return a.roll > b.roll
    end )
  end

  local function have_all_rolls_been_exhausted()
    local mainspec_roll_count = getn( mainspec_rolls )
    local offspec_roll_count = getn( offspec_rolls )
    local tmog_roll_count = getn( tmog_rolls )
    local total_roll_count = mainspec_roll_count + offspec_roll_count + tmog_roll_count

    if item_count == getn( tmog_rollers ) and have_all_players_rolled( tmog_rollers ) or
        item_count == getn( offspec_rollers ) and have_all_players_rolled( offspec_rollers ) or
        item_count == getn( mainspec_rollers ) and total_roll_count == getn( mainspec_rollers ) then
      return true
    end

    return have_all_players_rolled( mainspec_rollers )
  end

  local function find_player( player_name )
    for _, player in ipairs( players ) do
      if player.name == player_name then return player end
    end
  end

  local function stop_listening()
    rolling = false

    if timer then
      ace_timer:CancelTimer( timer )
      timer = nil
    end
  end

  local function find_winner()
    stop_listening()

    local mainspec_roll_count = count_elements( mainspec_rolls )
    local offspec_roll_count = count_elements( offspec_rolls )
    local tmog_roll_count = count_elements( tmog_rolls )

    if mainspec_roll_count == 0 and offspec_roll_count == 0 and tmog_roll_count == 0 then
      on_rolling_finished( item, item_count, {} )
      return
    end

    sort_rolls()

    local all_rolls = merge( {}, mainspec_rolls, offspec_rolls, tmog_rolls )
    local winners = take( all_rolls, item_count )

    on_rolling_finished( item, item_count, winners )
  end

  local function on_roll( player_name, roll, min, max )
    if not rolling or min ~= 1 or (max ~= tmog_threshold and max ~= os_threshold and max ~= ms_threshold) then return end
    if max == tmog_threshold and not tmog_rolling_enabled then return end

    local ms_roll = max == ms_threshold
    local os_roll = max == os_threshold
    local roll_type = ms_roll and RollType.MainSpec or os_roll and RollType.OffSpec or RollType.Transmog
    local player = find_player( player_name )

    if not rlu.has_rolls_left( ms_roll and mainspec_rollers or os_roll and offspec_rollers or tmog_rollers, player_name ) then
      pretty_print( string.format( "|cffff9f69%s|r exhausted their rolls. This roll (|cffff9f69%s|r) is ignored.", player_name, roll ) )
      roll_controller.add_ignored( player_name, player.class, roll_type, roll, "Rolled too many times." )
      return
    end

    player.rolls = player.rolls - 1
    local t = ms_roll and mainspec_rolls or os_roll and offspec_rolls or tmog_rolls
    table.insert( t, make_roll( player, roll_type, roll ) )
    roll_controller.add( player.name, player.class, roll_type, roll )

    if have_all_rolls_been_exhausted() then find_winner() end
  end

  local function stop_accepting_rolls()
    find_winner()
  end

  local function on_timer()
    seconds_left = seconds_left - 1

    if seconds_left <= 0 then
      stop_accepting_rolls()
      return
    elseif seconds_left == 3 then
      announce( "Stopping rolls in 3" )
    elseif seconds_left < 3 then
      announce( tostring( seconds_left ) )
    end

    roll_controller.tick( seconds_left )
  end

  local function accept_rolls()
    rolling = true
    timer = ace_timer.ScheduleRepeatingTimer( M, on_timer, 1.7 )
    roll_controller.start( RollingStrategy.NormalRoll, item, item_count, info, seconds )
    roll_controller.show()
  end

  local function announce_rolling()
    local count_str = item_count > 1 and string.format( "%sx", item_count ) or ""
    local tmog_info = config.tmog_rolling_enabled() and string.format( " or /roll %s (TMOG)", config.tmog_roll_threshold() ) or ""
    local default_ms = config.ms_roll_threshold() ~= 100 and string.format( "%s ", config.ms_roll_threshold() ) or ""
    local roll_info = string.format( " /roll %s(MS) or /roll %s (OS)%s", default_ms, config.os_roll_threshold(), tmog_info )
    local info_str = info and info ~= "" and string.format( " %s", info ) or roll_info
    local x_rolls_win = item_count > 1 and string.format( ". %d top rolls win.", item_count ) or ""

    announce( string.format( "Roll for %s%s:%s%s", count_str, item.link, info_str, x_rolls_win ), true )
    accept_rolls()
  end

  local function show_sorted_rolls( limit )
    local function show( prefix, sorted_rolls )
      if getn( sorted_rolls ) == 0 then return end

      pretty_print( string.format( "%s rolls:", prefix ) )
      local i = 0

      for _, v in ipairs( sorted_rolls ) do
        if limit and limit > 0 and i > limit then return end

        pretty_print( string.format( "[|cffff9f69%d|r]: %s", v.roll, v.player.name ) )
        i = i + 1
      end
    end

    local total_mainspec_rolls = count_elements( mainspec_rolls )
    local total_offspec_rolls = count_elements( offspec_rolls )

    if total_mainspec_rolls + total_offspec_rolls == 0 then
      pretty_print( "No rolls found." )
      return
    end

    sort_rolls()
    show( "Mainspec", mainspec_rolls )
    show( "Offspec", offspec_rolls )
    show( "Transmog", tmog_rolls )
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
    get_rolling_strategy = function() return m.Types.RollingStrategy.NormalRoll end
  }
end

m.NonSoftResRollingLogic = M
return M
