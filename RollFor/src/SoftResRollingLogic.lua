RollFor = RollFor or {}
local m = RollFor

if m.SoftResRollingLogic then return end

local M = {}

local getn = m.getn
local map = m.map
local take = m.take
local hl = m.colors.hl
local RT = m.Types.RollType ---@type RT
local roll_type = m.Types.RollType.SoftRes
local strategy = m.Types.RollingStrategy.SoftResRoll
local available_rolls = m.RollingLogicUtils.available_rolls
local consume_roll = m.RollingLogicUtils.consume_roll
local best_roll_per_player = m.RollingLogicUtils.best_roll_per_player
local count_top_roll_winners = m.RollingLogicUtils.count_top_roll_winners
local players_with_available_rolls = m.RollingLogicUtils.players_with_available_rolls
local winner_found = m.RollingLogicUtils.winner_found

---@type MakeRollFn
local make_roll = m.Types.make_roll

local State = { AfterRoll = 1, TimerStopped = 2, ManualStop = 3 }

---@param chat Chat
---@param ace_timer AceTimer
---@param players RollingPlayer[]
---@param item Item
---@param item_count number
---@param item_quantity number
---@param seconds number
---@param on_rolling_finished RollingFinishedCallback
---@param on_softres_rolls_available fun( rollers: RollingPlayer[] )
---@param config Config
---@param winner_tracker WinnerTracker
---@param master_loot_candidates MasterLootCandidates
---@param controller RollControllerFacade
---@param bonus_roll_registry ResistanceBonusRollRegistry
function M.new(
    chat,
    ace_timer,
    players,
    item,
    item_count,
    item_quantity,
    seconds,
    on_rolling_finished,
    on_softres_rolls_available,
    config,
    winner_tracker,
    master_loot_candidates,
    controller,
    bonus_roll_registry
)
  local rolls = {}
  local rolling = false
  local seconds_left = seconds
  local timer
  local player_count = getn( players )

  -- What this rolling has spent, so a cancel can hand it all back. Only a cancel refunds:
  -- a rolling that merely finishes without an award keeps its spends.
  ---@type BonusRollToken[]
  local spent_tokens = {}

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
      if available_rolls( v ) > 0 then return winner_found( players, rolls, item_count, config.roll_threshold( roll_type ).value ) end
    end

    return true
  end

  local function find_player( player_name )
    for _, player in ipairs( players ) do
      if player.name == player_name then return player end
    end
  end

  ---@param player RollingPlayer
  ---@param roll number
  local function spend_bonus_roll( player, roll )
    local token = m.RollingLogicUtils.spend_bonus_roll( bonus_roll_registry, chat, item, player, roll )
    if token then table.insert( spent_tokens, token ) end
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

    local candidates = best_roll_per_player( rolls )
    local top_roll_winner_count = count_top_roll_winners( candidates, item_count )
    local winner_rolls = take( candidates, top_roll_winner_count > item_count and top_roll_winner_count or item_count )

    on_rolling_finished( item, item_count, item_quantity, winner_rolls )
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

    -- Which pool this roll comes out of is the only thing bonus rolls change here. The
    -- soft-res allowance is spent first; everything past it is a bonus roll.
    local roll_type_used = consume_roll( player )

    if not roll_type_used then
      chat.info( m.msg.rolls_exhausted( player.name, player.class, roll ) )
      controller.roll_was_ignored( player.name, player.class, roll_type, roll, "Rolled too many times." )
      return
    end

    if roll_type_used == RT.BonusRoll then spend_bonus_roll( player, roll ) end

    table.insert( rolls, make_roll( player, roll_type_used, roll ) )
    controller.roll_was_accepted( player.name, player.class, roll_type_used, roll )

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

  -- The raid announcement has to say what a player's allowance actually is, and the two
  -- pools don't add up into one number: "Drutree [3 rolls]" would read as three soft-res
  -- rolls. So they're reported split -- "Drutree [1 roll +1 bonus]" -- and a player with
  -- one plain soft-res roll and nothing else stays the bare name it has always been.
  ---@param player RollingPlayer
  local function format_name_with_rolls( player )
    if player_count == item_count then return player.name end

    local bonus_rolls = player.bonus_rolls or 0
    local bonus = bonus_rolls > 0 and string.format( " +%s bonus", bonus_rolls ) or ""

    if player.rolls <= 1 and bonus == "" then return player.name end

    local rolls_str = string.format( "%s roll%s", player.rolls, player.rolls == 1 and "" or "s" )

    return string.format( "%s [%s%s]", player.name, rolls_str, bonus )
  end

  local function start_rolling()
    local count_str = item_count > 1 and string.format( "%sx", item_count ) or ""

    -- One fact per sentence, in the order the raid needs them: what is up, how many win,
    -- who is in. The period is a separator between them rather than a terminator, so it
    -- only appears when something actually follows -- which is what keeps the wording the
    -- same whether the roll call rides along or gets lifted out into raid chat.
    local x_rolls_win = item_count > 1 and string.format( " %d top rolls win.", item_count ) or ""

    if player_count > item_count then
      local roll_call = map( players, format_name_with_rolls )

      -- The item link alone is a third of the chat limit, and every bonus roll annotation
      -- is another ~18 bytes on top of a name, so the roll call is built against what the
      -- fixed parts leave over instead of being formatted and hoped for.
      local prefix = string.format( "Roll for %s%s.%s SR by ", count_str, item.link, x_rolls_win )
      local messages = m.split_message( prefix, roll_call )

      if getn( messages ) == 1 then
        chat.announce( messages[ 1 ], true )
      else
        -- Too many soft-ressers to fit, so the two stop competing for the same line. The
        -- raid warning keeps what everyone has to see -- the item and how many win -- and
        -- the roll call follows in raid chat, where several lines are not an assault.
        local header = string.format( "Roll for %s%s (SR)%s", count_str, item.link,
          x_rolls_win ~= "" and string.format( ".%s", x_rolls_win ) or "" )

        chat.announce( header, true )

        for _, message in ipairs( m.split_message( "SR by ", roll_call ) ) do
          chat.announce( message )
        end
      end

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

    -- A rolling the ML canceled never happened, so the bonus rolls it spent go back.
    bonus_roll_registry.refund( spent_tokens )
    spent_tokens = {}

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
