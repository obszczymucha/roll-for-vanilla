RollFor = RollFor or {}
local m = RollFor

if m.RollingLogic then return end

local M = {}

local getn = m.getn
local RS = m.Types.RollingStrategy

---@alias SoftresRollsAvailableCallback fun( rollers: RollingPlayer[] )

---@alias RollingFinishedCallback fun(
---  item: Item,
---  item_count: number,
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

    local transform = function( player )
      local rolls = player.rolls == 1 and "1 roll" or string.format( "%s rolls", player.rolls )
      return string.format( "%s (%s)", player.name, rolls )
    end

    roll_controller.waiting_for_rolls()
    local message = m.prettify_table( remaining_rollers, transform )
    chat.announce( string.format( "SR rolls remaining: %s", message ) )
  end

  ---@param strategy RollingStrategy
  ---@param item Item?
  ---@param item_count number?
  ---@param seconds number?
  ---@param message string?
  ---@param rolling_players RollingPlayer[]?
  local function roll( strategy, item, item_count, seconds, message, rolling_players )
    if m_rolling_strategy and m_rolling_strategy.is_rolling() then
      m.err( "Rolling is already in progress." )
      return
    end

    m_rolling_strategy = strategy

    if item and item_count then
      roll_controller.rolling_started( strategy.get_type(), item, item_count, seconds, message, rolling_players )
    end

    m_rolling_strategy.start_rolling()
  end

  local function is_rolling()
    return m_rolling_strategy and m_rolling_strategy.is_rolling() or false
  end

  ---param winning_rolls Roll[]
  local function count_top_rolls( winning_rolls )
    local roll_count = winning_rolls and getn( winning_rolls ) or 0
    if roll_count == 0 then return 0 end

    local top_roll = winning_rolls[ 1 ].roll
    local result = 1

    for i = 2, roll_count do
      if winning_rolls[ i ].roll == top_roll then result = result + 1 end
    end

    return result
  end

  ---@param rolls Roll[]
  ---@param item_count number
  ---@return Roll[], Roll[]
  local function split_winners_and_tied_rollers( rolls, item_count )
    local top_roll_count = count_top_rolls( rolls )
    if top_roll_count >= item_count then return {}, rolls end

    local winning_rolls, tied_rolls = {}, {}

    for i, top_roll in ipairs( rolls ) do
      if i <= top_roll_count then
        table.insert( winning_rolls, top_roll )
      else
        table.insert( tied_rolls, top_roll )
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
  ---@param rolls Roll[]
  ---@param rerolling boolean
  local function there_was_a_tie( item, item_count, rolls, rerolling, on_rolling_finished )
    local winning_rolls, tied_rolls = split_winners_and_tied_rollers( rolls, item_count )
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

    local roll_type = tied_rolls[ 1 ].roll_type
    local roll_value = tied_rolls[ 1 ].roll

    ---@type RollingPlayer[]
    local players = m.map( tied_rolls,
      ---@param tied_roll Roll
      function( tied_roll )
        return tied_roll.player
      end )

    roll_controller.there_was_a_tie( players, item, count, roll_type, roll_value, rerolling, getn( winning_rolls ) == 0 or false )

    local strategy = strategy_factory.tie_roll( players, item, count, on_rolling_finished, roll_type, facade )
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
  ---@param winning_rolls Roll[]
  ---@param rerolling boolean?
  ---@type RollingFinishedCallback
  local function on_rolling_finished( item, item_count, winning_rolls, rerolling )
    local winning_roll_count = getn( winning_rolls )

    if winning_roll_count == 0 then
      roll_controller.finish()

      if not rerolling and config.auto_raid_roll() and m_rolling_strategy and m_rolling_strategy.get_type() ~= RS.SoftResRoll then
        -- At some point item_count gets to 0.
        if item_count == 0 then
          m.trace( "Item count is 0." )
        end

        m_rolling_strategy = nil
        roll_controller.start( "RaidRoll", item, item_count )
      elseif m_rolling_strategy and not m_rolling_strategy.is_rolling() then
        chat.info( string.format( "Rolling for %s finished.", item.link ) )
      end

      return
    end

    if winning_roll_count > item_count then
      there_was_a_tie( item, item_count, winning_rolls, rerolling or false, on_rolling_finished )
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

  ---@param data RollControllerStartData
  local function start( data )
    ---@return RollingStrategy?
    ---@return RollingPlayer[]?
    local function make_strategy()
      local seconds = data.seconds or config.default_rolling_time_seconds()

      if data.strategy_type == RS.SoftResRoll then
        return strategy_factory.softres_roll(
          data.item,
          data.item_count,
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

    local strategy, rolling_players = make_strategy()
    if not strategy then return end

    winner_tracker.start_rolling( data.item.link )
    roll( strategy, data.item, data.item_count, data.seconds, data.message, rolling_players )
  end

  roll_controller.subscribe( "finish_rolling_early", finish_rolling_early )
  roll_controller.subscribe( "cancel_rolling", cancel_rolling )
  roll_controller.subscribe( "start", start )

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
