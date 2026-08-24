RollFor = RollFor or {}
local m = RollFor

if m.RollingLogic then return end

local M = {}

local getn = m.getn
local RS = m.Types.RollingStrategy
local RT = m.Types.RollType

---@alias SoftresRollsAvailableCallback fun( rollers: RollingPlayer[] )

---@alias RollingFinishedCallback fun(
---  item: Item,
---  item_count: number,
---  item_quantity: number,
---  winning_rolls: Roll[],
---  rerolling: boolean? )

---@class RollingLogic
---@field on_softres_rolls_available SoftresRollsAvailableCallback
---@field on_rolling_finished RollingFinishedCallback
---@field is_rolling fun(): boolean
---@field on_roll fun( player: Player, roll_value: number, min: number, max: number )
---@field show_sorted_rolls fun( limit: number? )

---@param chat Chat
---@param ace_timer AceTimer
---@param roll_controller RollController
---@param strategy_factory RollingStrategyFactory
---@param master_loot_candidates MasterLootCandidates
---@param winner_tracker WinnerTracker
function M.new( chat, ace_timer, roll_controller, strategy_factory, master_loot_candidates, winner_tracker, config )
  ---@type RollingStrategy | nil
  local m_rolling_strategy

  ---@param rollers RollingPlayer[]
  local function on_softres_rolls_available( rollers )
    local remaining_rollers = m.reindex_table( rollers )

    -- Both pools, separately: a player owing one soft-res roll and one bonus roll owes two
    -- rolls, but "2 rolls" would have them roll twice off an allowance they don't have.
    local transform = function( player )
      local parts = {}

      if player.rolls > 0 then
        table.insert( parts, string.format( "%s roll%s", player.rolls, player.rolls == 1 and "" or "s" ) )
      end

      local bonus_rolls = player.bonus_rolls or 0

      if bonus_rolls > 0 then
        table.insert( parts, string.format( "%s bonus roll%s", bonus_rolls, bonus_rolls == 1 and "" or "s" ) )
      end

      return string.format( "%s (%s)", player.name, table.concat( parts, ", " ) )
    end

    roll_controller.waiting_for_rolls()
    local message = m.prettify_table( remaining_rollers, transform )
    chat.announce( string.format( "SR rolls remaining: %s", message ) )
  end

  ---@param strategy RollingStrategy
  ---@param item Item?
  ---@param item_count number?
  ---@param item_quantity number?
  ---@param seconds number?
  ---@param message string?
  ---@param rolling_players RollingPlayer[]?
  ---@param pre_winners Winner[]?
  local function roll( strategy, item, item_count, item_quantity, seconds, message, rolling_players, pre_winners )
    if m_rolling_strategy and m_rolling_strategy.is_rolling() then
      m.err( "Rolling is already in progress." )
      return
    end

    m_rolling_strategy = strategy

    if item and item_count and item_quantity then
      roll_controller.rolling_started( strategy.get_type(), item, item_count, item_quantity, seconds, message, rolling_players, pre_winners )
    end

    m_rolling_strategy.start_rolling()
  end

  local function is_rolling()
    return m_rolling_strategy and m_rolling_strategy.is_rolling() or false
  end

  -- The rolls exceed the item count only when the last group of equal rolls
  -- crosses the item count boundary. That tail group is the tie - everything
  -- before it won outright.
  ---@param rolls Roll[]
  ---@return Roll[], Roll[]
  local function split_winners_and_tied_rollers( rolls )
    local roll_count = getn( rolls )
    if roll_count == 0 then return {}, {} end

    local last_roll = rolls[ roll_count ]
    local winning_rolls, tied_rolls = {}, {}

    -- Compared by tier, not by type: an SR 87 and a bonus 87 are the same contest and
    -- have to tie against each other.
    local last_tier = m.roll_type_tier( last_roll.roll_type )

    for _, r in ipairs( rolls ) do
      if r.roll == last_roll.roll and m.roll_type_tier( r.roll_type ) == last_tier then
        table.insert( tied_rolls, r )
      else
        table.insert( winning_rolls, r )
      end
    end

    return winning_rolls, tied_rolls
  end

  ---@type RollControllerFacade
  local facade = {
    roll_was_ignored = roll_controller.add_ignored,
    roll_was_accepted = roll_controller.add,
    tick = roll_controller.tick,
    winners_found = roll_controller.winners_found,
    finish = roll_controller.finish
  }

  ---@param item Item
  ---@param item_count number
  ---@param item_quantity number
  ---@param rolls Roll[]
  ---@param rerolling boolean
  local function there_was_a_tie( item, item_count, item_quantity, rolls, rerolling, on_rolling_finished )
    local winning_rolls, tied_rolls = split_winners_and_tied_rollers( rolls )
    local count = item_count

    local winners = m.map( winning_rolls,
      ---@param winning_roll Roll
      function( winning_roll )
        return master_loot_candidates.transform_to_winner( winning_roll.player, item, winning_roll.roll_type, winning_roll.roll, rerolling )
      end )

    local winner_count = getn( winners )
    count = count - winner_count

    if winner_count > 0 then
      roll_controller.winners_found( item, item_count, winners, RS.TieRoll )
    end

    -- Normalised to the tier, or a mixed tie whose first roll happened to be the bonus one
    -- would label the whole re-roll "BR".
    local roll_type = m.roll_type_tier( tied_rolls[ 1 ].roll_type )
    local roll_value = tied_rolls[ 1 ].roll

    ---@type RollingPlayer[]
    local players = m.map( tied_rolls,
      ---@param tied_roll Roll
      function( tied_roll )
        return tied_roll.player
      end )

    roll_controller.there_was_a_tie( players, item, count, roll_type, roll_value, rerolling, getn( winning_rolls ) == 0 or false )

    local strategy = strategy_factory.tie_roll( players, item, count, item_quantity, on_rolling_finished, roll_type, facade )
    if not strategy then return end

    ace_timer.ScheduleTimer( M,
      function()
        roll_controller.tie_start()
        m_rolling_strategy = nil
        roll( strategy )
      end, 2 )
  end

  ---@param item Item
  ---@param item_count number
  ---@param item_quantity number
  ---@param winning_rolls Roll[]
  ---@param rerolling boolean?
  ---@type RollingFinishedCallback
  local function on_rolling_finished( item, item_count, item_quantity, winning_rolls, rerolling )
    local winning_roll_count = getn( winning_rolls )

    if winning_roll_count == 0 then
      roll_controller.finish()

      if not rerolling and config.auto_raid_roll() and m_rolling_strategy and m_rolling_strategy.get_type() ~= RS.SoftResRoll then
        -- At some point item_count gets to 0.
        if item_count == 0 then
          m.trace( "Item count is 0." )
        end

        m_rolling_strategy = nil
        roll_controller.start( "RaidRoll", item, item_count, item_quantity )
      elseif m_rolling_strategy and not m_rolling_strategy.is_rolling() then
        chat.info( string.format( "Rolling for %s finished.", item.link ) )
      end

      return
    end

    if winning_roll_count > item_count then
      there_was_a_tie( item, item_count, item_quantity, winning_rolls, rerolling or false, on_rolling_finished )
      return
    end

    local function handle_winners()
      local strategy = m_rolling_strategy and m_rolling_strategy.get_type()

      if not strategy then
        m.err( "Rolling strategy is missing." )
        return
      end

      local winners = m.map( winning_rolls,
        ---@param winning_roll Roll
        function( winning_roll )
          return master_loot_candidates.transform_to_winner( winning_roll.player, item, winning_roll.roll_type, winning_roll.roll, rerolling )
        end )

      roll_controller.winners_found( item, item_count, winners, strategy )

      m.map( winners, function( winner )
        winner_tracker.track( winner.name, item.link, winner.roll_type, winner.roll, strategy ) -- TODO: remove from here and subscribe to the event.
      end )

      roll_controller.finish()
    end

    handle_winners()

    if not is_rolling() then
      chat.info( string.format( "Rolling for %s finished.", item.link ) )
    end
  end

  local function cancel_rolling()
    if not m_rolling_strategy then return end
    m_rolling_strategy.cancel_rolling()
    roll_controller.rolling_canceled()
  end

  ---@param player Player
  ---@param roll_value number
  ---@param min number
  ---@param max number
  local function on_roll( player, roll_value, min, max )
    if m_rolling_strategy and m_rolling_strategy.is_rolling() then
      m_rolling_strategy.on_roll( player, roll_value, min, max )
    end
  end

  local function finish_rolling_early()
    if m_rolling_strategy then m_rolling_strategy.stop_accepting_rolls( true ) end
  end

  ---@param limit number
  local function show_sorted_rolls( limit )
    if m_rolling_strategy then m_rolling_strategy.show_sorted_rolls( limit ) end
  end

  -- Fewer soft-ressers than dropped copies: each soft-resser wins one copy
  -- outright, and the remaining copies go to a normal roll. The soft-ressers
  -- already got theirs, so their rolls in the normal roll are ignored.
  ---@param data RollControllerStartData
  ---@param softressers RollingPlayer[]
  local function softres_winners_then_normal_roll( data, softressers )
    local item = data.item
    local item_count = data.item_count
    local item_quantity = data.item_quantity
    local seconds = data.seconds or config.default_rolling_time_seconds()
    local sr_count = getn( softressers )

    local sr_winners = m.map( softressers,
      ---@param player RollingPlayer
      function( player )
        local winner = master_loot_candidates.transform_to_winner( player, item, RT.SoftRes, nil )
        winner_tracker.track( winner.name, item.link, RT.SoftRes, nil, RS.SoftResRoll )
        return winner
      end )

    roll_controller.winners_found( item, item_count, sr_winners, RS.SoftResRoll )

    local remaining = item_count - sr_count

    -- When the normal roll finishes, re-announce the soft-res winners first so
    -- all winners are listed together at the end, soft-ressers ahead of rollers.
    -- They're already recorded in the tracker (see pre_winners below), so this only
    -- announces them again -- tracking is skipped to avoid duplicating them.
    ---@type RollingFinishedCallback
    local function on_normal_roll_finished( f_item, f_item_count, f_item_quantity, winning_rolls, rerolling )
      if getn( winning_rolls ) > 0 then
        roll_controller.winners_found( f_item, item_count, sr_winners, RS.SoftResRoll, true )
      end

      on_rolling_finished( f_item, f_item_count, f_item_quantity, winning_rolls, rerolling )
    end

    local normal_strategy = strategy_factory.normal_roll( item, remaining, item_quantity, nil, seconds, on_normal_roll_finished, facade, softressers )

    m_rolling_strategy = nil
    -- Pass the soft-res winners as pre_winners so they persist in the tracker (start()
    -- clears winners) and stay visible in the popup throughout the leftover normal roll.
    roll( normal_strategy, item, remaining, item_quantity, seconds, nil, nil, sr_winners )
  end

  ---@param data RollControllerStartData
  local function start( data )
    ---@return RollingStrategy?
    ---@return RollingPlayer[]?
    ---@return RollingPlayer[]?
    local function make_strategy()
      local seconds = data.seconds or config.default_rolling_time_seconds()

      if data.strategy_type == RS.SoftResRoll then
        return strategy_factory.softres_roll(
          data.item,
          data.item_count,
          data.item_quantity,
          data.message,
          seconds,
          on_rolling_finished,
          on_softres_rolls_available,
          facade
        )
      elseif data.strategy_type == RS.NormalRoll then
        return strategy_factory.normal_roll(
          data.item,
          data.item_count,
          data.item_quantity,
          data.message,
          seconds,
          on_rolling_finished,
          facade
        )
      elseif data.strategy_type == RS.RaidRoll then
        return strategy_factory.raid_roll( data.item, data.item_count, facade )
      elseif data.strategy_type == RS.InstaRaidRoll then
        return strategy_factory.insta_raid_roll( data.item, data.item_count, facade )
      end
    end

    local strategy, rolling_players, softressers = make_strategy()
    if not strategy then return end

    winner_tracker.start_rolling( data.item.link )

    if data.strategy_type == RS.SoftResRoll and softressers then
      softres_winners_then_normal_roll( data, softressers )
      return
    end

    roll( strategy, data.item, data.item_count, data.item_quantity, data.seconds, data.message, rolling_players )
  end

  roll_controller.subscribe( "finish_rolling_early", finish_rolling_early )
  roll_controller.subscribe( "cancel_rolling", cancel_rolling )
  roll_controller.subscribe( "start", start )

  -- /ssr replays the last standings, so it only makes sense once rolling has finished.
  m.slash_cmd( "ssr", function( args )
    if is_rolling() then
      chat.info( "Rolling is in progress." )
      return
    end

    for limit in string.gmatch( args or "", "(%d+)" ) do
      show_sorted_rolls( tonumber( limit ) )
      return
    end

    show_sorted_rolls( 5 )
  end )

  ---@type RollingLogic
  return {
    on_rolling_finished = on_rolling_finished,
    on_softres_rolls_available = on_softres_rolls_available,
    is_rolling = is_rolling,
    on_roll = on_roll,
    show_sorted_rolls = show_sorted_rolls
  }
end

m.RollingLogic = M
return M
