RollFor = RollFor or {}
local m = RollFor

if m.NonSoftResRollingLogic then return end

local M = m.Module.new( "NonSoftResRollingLogic" )

local getn = m.getn
local count_elements = m.count_elements
local merge = m.merge
local take = m.take
local rlu = m.RollingLogicUtils
local RollType = m.Types.RollType
local hl = m.colors.hl

---@type MakeRollFn
local make_roll = m.Types.make_roll

---@param players RollingPlayer[]
local function have_all_players_rolled( players )
  for _, v in ipairs( players ) do
    if v.rolls > 0 then return false end
  end

  return true
end

---@param chat Chat
---@param ace_timer AceTimer
---@param players RollingPlayer[]
---@param item Item
---@param item_count number
---@param info string?
---@param seconds number
---@param on_rolling_finished RollingFinishedCallback
---@param config Config
---@param controller RollControllerFacade
function M.new(
    chat,
    ace_timer,
    players,
    item,
    item_count,
    info,
    seconds,
    on_rolling_finished,
    config,
    controller
)
  ---@type RollingPlayer[], Roll[]
  local mainspec_rollers, mainspec_rolls = players, {}
  ---@type RollingPlayer[], Roll[]
  local offspec_rollers, offspec_rolls = rlu.copy_rollers( mainspec_rollers ), {}
  ---@type RollingPlayer[], Roll[]
  local tmog_rollers, tmog_rolls = rlu.copy_rollers( mainspec_rollers ), {}

  local rolling = false
  local seconds_left = seconds
  local timer

  local ms_threshold = config.ms_roll_threshold()
  local os_threshold = config.os_roll_threshold()
  local tmog_threshold = config.tmog_roll_threshold()
  local tmog_rolling_enabled = config.tmog_rolling_enabled()

  local function sort_rolls()
    local f = function( a, b )
      if a.roll == b.roll then
        return a.player.name < b.player.name
      else
        return a.roll > b.roll
      end
    end

    table.sort( mainspec_rolls, f )
    table.sort( offspec_rolls, f )
    table.sort( tmog_rolls, f )
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

  ---@param player_name string
  ---@param rollers RollingPlayer[]
  local function find_player( player_name, rollers )
    for _, player in ipairs( rollers ) do
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

    ---@type Roll[]
    local all_rolls = merge( {}, mainspec_rolls, offspec_rolls, tmog_rolls )
    local roll_count = getn( all_rolls )

    local function count_top_roll_winners()
      if roll_count == 0 then return 0 end

      local function split_by_roll()
        local result = {}
        local last_roll

        for _, roll in ipairs( all_rolls ) do
          if not last_roll or last_roll ~= roll.roll then
            table.insert( result, { roll } )
            last_roll = roll.roll
          else
            table.insert( result[ getn( result ) ], roll )
          end
        end

        return result
      end

      local result = 0

      for _, rolls in ipairs( split_by_roll() ) do
        result = result + getn( rolls )
        if result >= item_count then return result end
      end

      return result
    end

    local top_roll_winner_count = count_top_roll_winners()
    local winner_rolls = take( all_rolls, top_roll_winner_count > item_count and top_roll_winner_count or item_count )

    on_rolling_finished( item, item_count, winner_rolls )
  end

  ---@param roller Player
  ---@param roll number
  ---@param min number
  ---@param max number
  local function on_roll( roller, roll, min, max )
    if not rolling or min ~= 1 or (max ~= tmog_threshold and max ~= os_threshold and max ~= ms_threshold) then return end
    if max == tmog_threshold and not tmog_rolling_enabled then return end

    local ms_roll = max == ms_threshold
    local os_roll = max == os_threshold
    local roll_type = ms_roll and RollType.MainSpec or os_roll and RollType.OffSpec or RollType.Transmog
    local rollers = ms_roll and mainspec_rollers or os_roll and offspec_rollers or tmog_rollers
    local player = find_player( roller.name, rollers ) ---@type RollingPlayer

    if player.rolls == 0 then
      chat.info( m.msg.rolls_exhausted( player.name, player.class, roll ) )
      controller.roll_was_ignored( roller.name, player.class, roll_type, roll, "Rolled too many times." )
      return
    end

    player.rolls = player.rolls - 1
    local t = ms_roll and mainspec_rolls or os_roll and offspec_rolls or tmog_rolls
    table.insert( t, make_roll( player, roll_type, roll ) )
    controller.roll_was_accepted( player.name, player.class, roll_type, roll )

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
    end

    controller.tick( seconds_left )
  end

  local function accept_rolls()
    rolling = true
    timer = ace_timer.ScheduleRepeatingTimer( M, on_timer, 1.7 )
  end

  local function start_rolling()
    local count_str = item_count > 1 and string.format( "%sx", item_count ) or ""
    local tmog_info = config.tmog_rolling_enabled() and string.format( " or /roll %s (TMOG)", config.tmog_roll_threshold() ) or ""
    local default_ms = config.ms_roll_threshold() ~= 100 and string.format( "%s ", config.ms_roll_threshold() ) or ""
    local roll_info = string.format( " /roll %s(MS) or /roll %s (OS)%s", default_ms, config.os_roll_threshold(), tmog_info )
    local info_str = info and info ~= "" and string.format( " %s", info ) or roll_info
    local x_rolls_win = item_count > 1 and string.format( ". %d top rolls win.", item_count ) or ""

    chat.announce( string.format( "Roll for %s%s:%s%s", count_str, item.link, info_str, x_rolls_win ), true )
    accept_rolls()
  end

  local function show_sorted_rolls( limit )
    local function show( prefix, sorted_rolls )
      if getn( sorted_rolls ) == 0 then return end

      chat.info( string.format( "%s rolls:", prefix ) )
      local i = 0

      for _, v in ipairs( sorted_rolls ) do
        if limit and limit > 0 and i > limit then return end

        chat.info( string.format( "[%s]: %s", hl( v.roll ), v.player.name ) )
        i = i + 1
      end
    end

    local total_mainspec_rolls = count_elements( mainspec_rolls )
    local total_offspec_rolls = count_elements( offspec_rolls )

    if total_mainspec_rolls + total_offspec_rolls == 0 then
      chat.info( "No rolls found." )
      return
    end

    sort_rolls()
    show( "Mainspec", mainspec_rolls )
    show( "Offspec", offspec_rolls )
    show( "Transmog", tmog_rolls )
  end

  local function print_rolling_complete( canceled )
    chat.info( string.format( "Rolling for %s %s.", item.link, canceled and "was canceled" or "finished" ) )
  end

  local function cancel_rolling()
    stop_listening()
    print_rolling_complete( true )
    chat.announce( string.format( "Rolling for %s was canceled.", item.link ) )
  end

  local function is_rolling()
    return rolling
  end

  ---@type RollingStrategy
  return {
    start_rolling = start_rolling,
    on_roll = on_roll,
    show_sorted_rolls = show_sorted_rolls,
    stop_accepting_rolls = stop_accepting_rolls,
    cancel_rolling = cancel_rolling,
    is_rolling = is_rolling,
    get_type = function() return m.Types.RollingStrategy.NormalRoll end
  }
end

m.NonSoftResRollingLogic = M
return M
