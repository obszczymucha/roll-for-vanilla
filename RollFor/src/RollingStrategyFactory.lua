RollFor = RollFor or {}
local m = RollFor

if m.RollingStrategyFactory then return end

local M = {}

---@type MakeRollingPlayerFn
local make_rolling_player = m.Types.make_rolling_player
local getn = table.getn

---@class RollingStrategy
---@field announce_rolling fun()
---@field on_roll fun( player_name: string, roll: number, min: number, max: number )
---@field show_sorted_rolls fun( limit: number? )
---@field stop_accepting_rolls fun( manual_stop: boolean )
---@field cancel_rolling fun()
---@field is_rolling fun(): boolean
---@field get_rolling_strategy fun(): RollingStrategyType -- TODO: rename to get_type()

---@class RollingStrategyFactory
---@field normal_roll fun( item: Item, item_count: number, message: string?, seconds: number, on_rolling_finished: RollingFinishedCallback ): RollingStrategy
---@field softres_roll fun( item: Item, item_count: number, message: string?, seconds: number, on_rolling_finished: RollingFinishedCallback, on_softres_rolls_available: SoftresRollsAvailableCallback ): RollingStrategy
---@field raid_roll fun( item: Item, item_count: number ): RollingStrategy
---@field insta_raid_roll fun( item: Item, item_count: number ): RollingStrategy
---@field tie_roll fun( players: RollingPlayer[], item: Item, item_count: number, on_rolling_finished: RollingFinishedCallback, roll_type: RollType ): RollingStrategy

---@param group_roster GroupRoster
---@param loot_list LootList
---@param master_loot_candidates MasterLootCandidates
---@param announce AnnounceFn
---@param ace_timer AceTimer
---@param winner_tracker WinnerTracker
---@param roll_controller RollController
---@param config Config
---@param softres GroupedSoftRes
---@return RollingStrategyFactory
function M.new(
    group_roster,
    loot_list,
    master_loot_candidates,
    announce,
    ace_timer,
    winner_tracker,
    roll_controller,
    config,
    softres
)
  ---@param item Item
  ---@param item_count number
  ---@param message string?
  ---@param seconds number
  ---@param on_rolling_finished RollingFinishedCallback
  local function normal_roll( item, item_count, message, seconds, on_rolling_finished )
    local players = group_roster.get_all_players_in_my_group()
    local rollers = m.map( players, function( player )
      return make_rolling_player( player.name, player.class, player.online, 1 )
    end )

    return m.NonSoftResRollingLogic.new(
      announce,
      ace_timer,
      rollers,
      item,
      item_count or 1,
      message,
      seconds,
      on_rolling_finished,
      config,
      roll_controller
    )
  end

  ---@param item Item
  ---@param item_count number
  ---@param message string?
  ---@param seconds number
  ---@param on_rolling_finished RollingFinishedCallback
  ---@param on_softres_rolls_available SoftresRollsAvailableCallback
  local function softres_roll( item, item_count, message, seconds, on_rolling_finished, on_softres_rolls_available )
    ---@type RollingPlayer[]
    local softressing_players = softres.get( item.id )

    if getn( softressing_players ) == 0 then
      return normal_roll( item, item_count or 1, message, seconds, on_rolling_finished )
    end

    return m.SoftResRollingLogic.new(
      announce,
      ace_timer,
      softressing_players,
      item,
      item_count or 1,
      seconds,
      on_rolling_finished,
      on_softres_rolls_available,
      roll_controller,
      config,
      winner_tracker,
      master_loot_candidates
    )
  end

  local function raid_roll( f )
    ---@param item Item
    ---@param item_count number
    return function( item, item_count )
      local dropped_item = loot_list.find_item( item.id )
      local candidates = dropped_item and master_loot_candidates.get() or group_roster.get_all_players_in_my_group()
      ---@type ItemCandidate[]|Player[]
      local online_candidates = m.filter( candidates, function( c ) return c.online == true end )

      if dropped_item and getn( online_candidates ) == 0 then
        m.pretty_print( "Game API didn't return any loot candidates.", m.colors.red )
        return
      end

      return f( announce, ace_timer, item, item_count or 1, winner_tracker, roll_controller, online_candidates )
    end
  end

  local function tie_roll( players, item, item_count, on_rolling_finished, roll_type )
    local rollers = m.map( players,
      ---@param player RollingPlayer
      function( player )
        return make_rolling_player( player.name, player.class, player.online, 1 )
      end
    )

    return m.TieRollingLogic.new(
      announce,
      rollers, -- Trackback: changed player_names to players
      item,
      item_count,
      on_rolling_finished,
      roll_type,
      config,
      roll_controller
    )
  end

  return {
    normal_roll = normal_roll,
    softres_roll = softres_roll,
    raid_roll = raid_roll( m.RaidRollRollingLogic.new ),
    insta_raid_roll = raid_roll( m.InstaRaidRollRollingLogic.new ),
    tie_roll = tie_roll
  }
end

m.RollingStrategyFactory = M
return M