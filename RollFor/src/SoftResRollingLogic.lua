RollFor = RollFor or {}
local m = RollFor

if m.SoftResRollingLogic then return end

local M = {}
local map = m.map
local take = m.take
local hl = m.colors.hl
local roll_type = m.Types.RollType.SoftRes
local strategy = m.Types.RollingStrategy.SoftResRoll

---@type MakeRollFn
local make_roll = m.Types.make_roll

---@diagnostic disable-next-line: deprecated
local getn = table.getn

local State = { AfterRoll = 1, TimerStopped = 2, ManualStop = 3 }

local function has_everyone_rolled( rollers, rolls )
  local rolled_player_names = {}
  map( rolls, function( roll ) rolled_player_names[ roll.player.name ] = true end )

  for _, roller in ipairs( rollers ) do
    if not rolled_player_names[ roller.name ] then return false end
  end

  return true
end

local function players_with_available_rolls( rollers )
  return m.filter( rollers, function( roller ) return roller.rolls > 0 end )
end

local function count_top_roll_winners( rolls, item_count )
  local roll_count = getn( rolls )
  if roll_count == 0 then return 0 end

  local function split_by_roll()
    local result = {}
    local last_roll

    for _, roll in ipairs( rolls ) do
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

  for _, r in ipairs( split_by_roll() ) do
    result = result + getn( r )
    if result >= item_count then return result end
  end

  return result
end

local function is_the_winner_the_only_player_with_extra_rolls( rollers, rolls, item_count )
  local top_roll_count = count_top_roll_winners( rolls, item_count )
  local rollers_with_remaining_rolls = players_with_available_rolls( rollers )
  local roller_count = getn( rollers_with_remaining_rolls )
  local roll_count = getn( rolls )

  if top_roll_count > 1 or roller_count == 0 or roller_count > 1 or roll_count == 0 then return false end

  return rollers_with_remaining_rolls[ 1 ].name == rolls[ 1 ].player.name
end

local function winner_found( rollers, rolls, item_count )
  return has_everyone_rolled( rollers, rolls ) and is_the_winner_the_only_player_with_extra_rolls( rollers, rolls, item_count )
end

---@param chat Chat
---@param ace_timer AceTimer
---@param players RollingPlayer[]
---@param item Item
---@param item_count number
---@param seconds number
---@param on_rolling_finished RollingFinishedCallback
---@param on_softres_rolls_available fun( rollers: RollingPlayer[] )
---@param config Config
---@param winner_tracker WinnerTracker
---@param master_loot_candidates MasterLootCandidates
---@param controller RollControllerFacade
function M.new(
    chat,
    ace_timer,
    players,
    item,
    item_count,
    seconds,
    on_rolling_finished,
    on_softres_rolls_available,
    config,
    winner_tracker,
    master_loot_candidates,
    controller
)
  local rolls = {}
  local rolling = false
  local seconds_left = seconds
  local timer
  local player_count = getn( players )

  local function sort_rolls()
    table.sort( rolls, function( a, b )
      if a.roll == b.roll then
        return a.player.name < b.player.name
      else
        return a.roll > b.roll
      end
    end )
  end

  local function have_all_rolls_been_exhausted()
    for _, v in ipairs( players ) do
      if v.rolls > 0 then return winner_found( players, rolls, item_count ) end
    end

    return true
  end

  local function find_player( player_name )
    for _, player in ipairs( players ) do
      if player.name == player_name then return player end
    end
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
    sort_rolls()

    local rolls_exhausted = have_all_rolls_been_exhausted()

    if state == State.AfterRoll and not rolls_exhausted then return end

    if state == State.ManualStop and not rolls_exhausted or rolls_exhausted then
      stop_listening()
    end

    local roll_count = getn( rolls )

    if state == State.TimerStopped and not rolls_exhausted then
      stop_timer()
      on_softres_rolls_available( players_with_available_rolls( players ) )
      return
    end

    if state == State.ManualStop and roll_count > 0 then
      stop_listening()
    end

    local top_roll_winner_count = count_top_roll_winners( rolls, item_count )
    local winner_rolls = take( rolls, top_roll_winner_count > item_count and top_roll_winner_count or item_count )

    on_rolling_finished( item, item_count, winner_rolls )
  end

  ---@param roller Player
  ---@param roll number
  ---@param min number
  ---@param max number
  local function on_roll( roller, roll, min, max )
    if not rolling or min ~= 1 then return end

    local player = find_player( roller.name )

    if not player then
      chat.info( m.msg.did_not_soft_res( roller.name, roller.class, item.link, roll ) )
      controller.roll_was_ignored( roller.name, nil, roll_type, roll, "Did not soft-res." )
      return
    end

    local ms_threshold = config.ms_roll_threshold()
    local ms_roll = max == ms_threshold

    if not ms_roll then
      chat.info( m.msg.invalid_sr_roll( player.name, player.class, item.link, "/roll", roll ) )
      controller.roll_was_ignored( player.name, player.class, roll_type, roll, "Didn't /roll." )
      return
    end

    if player.rolls == 0 then
      chat.info( m.msg.rolls_exhausted( player.name, player.class, roll ) )
      controller.roll_was_ignored( player.name, player.class, roll_type, roll, "Rolled too many times." )
      return
    end

    if player.sr_plus then
      roll = roll + player.sr_plus
    end

    player.rolls = player.rolls - 1
    table.insert( rolls, make_roll( player, roll_type, roll ) )
    controller.roll_was_accepted( player.name, player.class, roll_type, roll )

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
    end

    controller.tick( seconds_left )
  end

  local function accept_rolls()
    rolling = true
    timer = ace_timer.ScheduleRepeatingTimer( M, on_timer, 1.7 )
  end

  local function format_name_with_rolls( player )
    if player_count == item_count then return player.name end
    local roll_count = player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
    local sr_plus = player.sr_plus and string.format( " (+%d)", player.sr_plus ) or ""
    return string.format( "%s%s%s", player.name, roll_count, sr_plus )
  end

  local function start_rolling()
    local count_str = item_count > 1 and string.format( "%sx", item_count ) or ""
    local x_rolls_win = item_count > 1 and string.format( ". %d top rolls win.", item_count ) or ""
    local ressed_by = m.prettify_table( map( players, format_name_with_rolls ) )

    if player_count ~= item_count then
      chat.announce( string.format( "Roll for %s%s: SR by %s%s", count_str, item.link, ressed_by, x_rolls_win ), true )
      accept_rolls()
      return
    end

    local winners = m.map( players,
      ---@param player RollingPlayer
      function( player )
        local winner = master_loot_candidates.transform_to_winner( player, item, roll_type, nil )
        winner_tracker.track( winner.name, item.link, roll_type, nil, strategy ) -- TODO: remove from here and subscribe to the event
        return winner
      end )

    controller.winners_found( item, item_count, winners, strategy )
    controller.finish()
  end

  local function show_sorted_rolls( limit )
    sort_rolls()
    chat.info( "SR rolls:" )

    for i, v in ipairs( rolls ) do
      if limit and limit > 0 and i > limit then return end
      chat.info( string.format( "[%s]: %s", hl( v.roll ), m.colorize_player_by_class( v.player.name, v.player.class ) ) )
    end
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
    get_type = function() return strategy end
  }
end

m.SoftResRollingLogic = M
return M
