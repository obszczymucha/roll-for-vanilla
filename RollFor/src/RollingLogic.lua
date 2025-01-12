RollFor = RollFor or {}
local m = RollFor

if m.RollingLogic then return end

local M = {}

local getn = table.getn
local info = m.pretty_print
local RS = m.Types.RollingStrategy

---@alias SoftresRollsAvailableCallback fun( rollers: RollingPlayer[] )

---@alias RollingFinishedCallback fun(
---  item: Item,
---  item_count: number,
---  winning_rolls: Roll[],
---  rerolling: boolean? )

---@class RollingLogic
---@field roll fun( rolling_strategy: RollingStrategy )
---@field cancel_rolling fun()
---@field on_softres_rolls_available SoftresRollsAvailableCallback
---@field on_rolling_finished RollingFinishedCallback
---@field is_rolling fun(): boolean
---@field on_roll fun( player_name: string, roll_value: number, min: number, max: number )
---@field stop_accepting_rolls fun( manual_stop: boolean )
---@field show_sorted_rolls fun( limit: number? )

---@param announce AnnounceFn
---@param ace_timer AceTimer
---@param roll_controller RollController
---@param rolling_strategy_factory RollingStrategyFactory
---@param master_loot_candidates MasterLootCandidates
---@param winner_tracker WinnerTracker
---@return RollingLogic
function M.new( announce, ace_timer, roll_controller, rolling_strategy_factory, master_loot_candidates, winner_tracker, config )
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
    announce( string.format( "SR rolls remaining: %s", message ) )
  end

  local function roll( strategy )
    if m_rolling_strategy and m_rolling_strategy.is_rolling() then
      m.err( "Rolling is already in progress." )
      return
    end

    m_rolling_strategy = strategy
    m_rolling_strategy.announce_rolling()
  end

  local function is_rolling()
    return m_rolling_strategy and m_rolling_strategy.is_rolling() or false
  end

  ---param winning_rolls Roll[]
  local function count_top_rolls( winning_rolls )
    local roll_count = getn( winning_rolls or {} )
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
      roll_controller.winners_found( item, winners, RS.TieRoll )
    end

    local roll_type = tied_rolls[ 1 ].roll_type
    local roll_value = tied_rolls[ 1 ].roll

    ---@type RollingPlayer[]
    local players = m.map( tied_rolls,
      ---@param tied_roll Roll
      function( tied_roll )
        return tied_roll.player
      end )

    roll_controller.tie( players, roll_type, roll_value, rerolling, getn( winning_rolls ) == 0 or false )

    local strategy = rolling_strategy_factory.tie_roll( players, item, count, on_rolling_finished, roll_type )
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

      print("chuj")
      if not rerolling and config.auto_raid_roll() and m_rolling_strategy and m_rolling_strategy.get_rolling_strategy() ~= RS.SoftResRoll then
        print("chuj2")
        m_rolling_strategy = nil
        local strategy = rolling_strategy_factory.raid_roll( item, item_count )

        if m_rolling_strategy then
          roll( strategy )
        end
      elseif m_rolling_strategy and not m_rolling_strategy.is_rolling() then
        info( string.format( "Rolling for %s has finished.", item.link ) )
      end

      return
    end

    if winning_roll_count > item_count then
      there_was_a_tie( item, item_count, winning_rolls, rerolling or false, on_rolling_finished )
      return
    end

    local function handle_winners()
      local strategy = m_rolling_strategy and m_rolling_strategy.get_rolling_strategy()

      if not strategy then
        m.err( "Rolling strategy is missing." )
        return
      end

      local winners = m.map( winning_rolls,
        ---@param winning_roll Roll
        function( winning_roll )
          return master_loot_candidates.transform_to_winner( winning_roll.player, item, winning_roll.roll_type, winning_roll.roll, rerolling )
        end )

      roll_controller.winners_found( item, winners, strategy )

      m.map( winners, function( winner )
        winner_tracker.track( winner.name, item.link, winner.roll_type, winner.roll, strategy ) -- TODO: remove from here and subscribe to the event.
      end )

      roll_controller.finish()
    end

    handle_winners()

    if not is_rolling() then
      info( string.format( "Rolling for %s has finished.", item.link ) )
    end
  end

  local function cancel_rolling()
    if not m_rolling_strategy then return end
    m_rolling_strategy.cancel_rolling()
  end

  ---@param player_name string
  ---@param roll_value number
  ---@param min number
  ---@param max number
  local function on_roll( player_name, roll_value, min, max )
    if m_rolling_strategy and m_rolling_strategy.is_rolling() then
      m_rolling_strategy.on_roll( player_name, roll_value, min, max )
    end
  end

  ---@param manual_stop boolean
  local function stop_accepting_rolls( manual_stop )
    if m_rolling_strategy then m_rolling_strategy.stop_accepting_rolls( manual_stop ) end
  end

  ---@param limit number
  local function show_sorted_rolls( limit )
    if m_rolling_strategy then m_rolling_strategy.show_sorted_rolls( limit ) end
  end

  return {
    roll = roll,
    cancel_rolling = cancel_rolling,
    on_rolling_finished = on_rolling_finished,
    on_softres_rolls_available = on_softres_rolls_available,
    is_rolling = is_rolling,
    on_roll = on_roll,
    stop_accepting_rolls = stop_accepting_rolls,
    show_sorted_rolls = show_sorted_rolls
  }
end

m.RollingLogic = M
return M
