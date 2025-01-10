RollFor = RollFor or {}
local m = RollFor

if m.RollingLogic then return end

local M = {}

local getn = table.getn
local info = m.pretty_print
local RT = m.Types.RollType
local RS = m.Types.RollingStrategy
local hl = m.colors.hl

---@class Winners
---@field players Player[]
---@field roll_type RollType

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
---@param roll_controller RollController
---@param rolling_strategy_factory RollingStrategyFactory
---@param master_loot_candidates MasterLootCandidates
---@return RollingLogic
function M.new( announce, roll_controller, rolling_strategy_factory, master_loot_candidates, winner_tracker )
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

  --  ---@param item Item
  -- ---@param item_count number
  -- ---@param winners Winners
  -- ---@param top_roll boolean
  -- ---@param rerolling boolean?
  -- local function there_was_a_tie( item, item_count, winners, top_roll, rerolling )
  --   local players = winners.players
  --   local roll_type = winners.roll_type
  --   local top_rollers_str = m.prettify_table( players )
  --   local top_rollers_str_colored = m.prettify_table( players, hl )
  --   local roll_type_str = roll_type == RT.MainSpec and "" or string.format( " (%s)", m.roll_type_abbrev_chat( roll_type ) )
  --
  --   local message = function( rollers )
  --     return string.format( "The %shighest %sroll was %d by %s%s.", not rerolling and top_roll and "" or "next ",
  --       rerolling and "re-" or "", players.roll, rollers, roll_type_str )
  --   end
  --
  --   M.roll_controller.tie( players, roll_type, players.roll )
  --
  --   info( message( top_rollers_str_colored ) )
  --   announce( message( top_rollers_str ) )
  --
  --   local prefix = item_count > 1 and string.format( "%sx", item_count ) or ""
  --   local suffix = item_count > 1 and string.format( " %s top rolls win.", item_count ) or ""
  --
  --   m_rolling_strategy = nil
  --   local strategy = rolling_strategy_factory.tie_roll()
  --   if not strategy then return end
  --
  --   local roll_threshold_str = M.config.roll_threshold( players.roll_type ).str
  --
  --   M.ace_timer.ScheduleTimer( M,
  --     function()
  --       M.roll_controller.tie_start()
  --       announce( string.format( "%s %s for %s%s now.%s", top_rollers_str, roll_threshold_str, prefix, item.link, suffix ) )
  --       roll( strategy )
  --     end, 2 )
  -- end

  ---@param item Item
  ---@param item_count number
  ---@param winning_rolls Roll[]
  ---@type RollingFinishedCallback
  local function on_rolling_finished( item, item_count, winning_rolls, rerolling )
    ---@return Roll[]
    local function enrich_winning_rolls_with_candidate_value()
      return m.map( winning_rolls,
        ---@param winning_roll Roll
        function( winning_roll )
          local candidate = master_loot_candidates.find( winning_roll.player.name )

          if candidate and candidate.candidate_index then
            winning_roll.player.candidate_index = candidate.candidate_index
          end

          return winning_roll
        end )
    end

    ---@param winning_roll Roll
    ---@param top_roll boolean
    local announce_winner = function( winning_roll, top_roll )
      local roll_value = winning_roll.roll
      local roll_type_str = winning_roll.roll_type == RT.MainSpec and "" or string.format( " (%s)", m.roll_type_abbrev_chat( winning_roll.roll_type ) )
      local winner = winning_roll.player

      info( string.format( "%s %srolled the %shighest (%s) for %s%s.", hl( winner.name ),
        rerolling and "re-" or "", top_roll and "" or "next ", hl( roll_value ), item.link, roll_type_str ) )
      announce(
        string.format( "%s %srolled the %shighest (%d) for %s%s.", winner.name,
          rerolling and "re-" or "", top_roll and "" or "next ", roll_value, item.link, roll_type_str ) )
    end

    local winning_roll_count = getn( winning_rolls )

    if winning_roll_count == 0 then
      info( string.format( "No one rolled for %s.", item.link ) )
      announce( string.format( "No one rolled for %s.", item.link ) )
      M.roll_controller.finish()

      if not rerolling and M.config.auto_raid_roll() and m_rolling_strategy and m_rolling_strategy.get_rolling_strategy() ~= RS.SoftResRoll then
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
      -- there_was_a_tie( item, item_count, winning_rolls )
      roll_controller.finish( {} )
      return
    end

    for i, winning_roll in ipairs( winning_rolls ) do
      announce_winner( winning_roll, i == 1 )
    end

    local function handle_winners()
      local roll_winners = enrich_winning_rolls_with_candidate_value()
      local rolling_strategy = m_rolling_strategy and m_rolling_strategy.get_rolling_strategy()
      m.map( roll_winners, function( winner ) winner_tracker.track( winner, item.link, winner.roll_type, winner.roll, rolling_strategy ) end )
      roll_controller.finish( roll_winners )
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
