RollFor = RollFor or {}
local m = RollFor

if m.RollingStrategyFactory then return end

local M = {}

local getn = m.getn
---@type MakeRollingPlayerFn
local make_rolling_player = m.Types.make_rolling_player
local sid = m.SoftRes.softres_item_data

---@class RollingStrategy
---@field start_rolling fun()
---@field on_roll fun( player_name: Player, roll: number, min: number, max: number )
---@field show_sorted_rolls fun( limit: number? )
---@field stop_accepting_rolls fun( manual_stop: boolean )
---@field cancel_rolling fun()
---@field is_rolling fun(): boolean
---@field get_type fun(): RollingStrategyType -- TODO: rename to get_type()

---@class RollingStrategyFactory
---@field normal_roll fun( item: Item, item_count: number, item_quantity: number, message: string?, seconds: number, on_rolling_finished: RollingFinishedCallback, roll_controller_facade: RollControllerFacade ): RollingStrategy
---@field softres_roll fun( item: Item, item_count: number, item_quantity: number, message: string?, seconds: number, on_rolling_finished: RollingFinishedCallback, on_softres_rolls_available: SoftresRollsAvailableCallback, roll_controller_facade: RollControllerFacade ): RollingStrategy, RollingPlayer[]
---@field raid_roll fun( item: Item, item_count: number, roll_controller_facade: RollControllerFacade ): RollingStrategy
---@field insta_raid_roll fun( item: Item, item_count: number, roll_controller_facade: RollControllerFacade ): RollingStrategy
---@field tie_roll fun( players: RollingPlayer[], item: Item, item_count: number, item_quantity: number, on_rolling_finished: RollingFinishedCallback, roll_type: RollType, roll_controller_facade: RollControllerFacade ): RollingStrategy

---@param group_roster GroupRoster
---@param loot_list SoftResLootList
---@param master_loot_candidates MasterLootCandidates
---@param chat Chat
---@param ace_timer AceTimer
---@param winner_tracker WinnerTracker
---@param config Config
---@param softres GroupAwareSoftRes
---@param player_info PlayerInfo
function M.new(
    group_roster,
    loot_list,
    master_loot_candidates,
    chat,
    ace_timer,
    winner_tracker,
    config,
    softres,
    player_info
)
  ---@param item Item
  ---@param item_count number
  ---@param item_quantity number
  ---@param message string?
  ---@param seconds number
  ---@param on_rolling_finished RollingFinishedCallback
  ---@param roll_controller_facade RollControllerFacade
  local function normal_roll( item, item_count, item_quantity, message, seconds, on_rolling_finished, roll_controller_facade )
    local players = group_roster.get_all_players_in_my_group()
    local rollers = m.map( players, function( player )
      return make_rolling_player( player.name, player.class, player.online, 1 )
    end )

    return m.NonSoftResRollingLogic.new(
      chat,
      ace_timer,
      rollers,
      item,
      item_count,
      item_quantity,
      message,
      seconds,
      on_rolling_finished,
      config,
      roll_controller_facade
    )
  end

  ---@param item Item
  ---@param item_count number
  ---@param item_quantity number
  ---@param message string?
  ---@param seconds number
  ---@param on_rolling_finished RollingFinishedCallback
  ---@param on_softres_rolls_available SoftresRollsAvailableCallback
  ---@param roll_controller_facade RollControllerFacade
  local function softres_roll(
      item,
      item_count,
      item_quantity,
      message,
      seconds,
      on_rolling_finished,
      on_softres_rolls_available,
      roll_controller_facade
  )
    local sr_item = sid( item.id )
    ---@type RollingPlayer[]
    local softressing_players = softres.get( sr_item )

    if getn( softressing_players ) == 0 then
      return normal_roll( item, item_count or 1, item_quantity, message, seconds, on_rolling_finished, roll_controller_facade )
    end

    local needs_rolling = getn( softressing_players ) > item_count
    return m.SoftResRollingLogic.new(
      chat,
      ace_timer,
      softressing_players,
      item,
      item_count,
      item_quantity,
      seconds,
      on_rolling_finished,
      on_softres_rolls_available,
      config,
      winner_tracker,
      master_loot_candidates,
      roll_controller_facade
    ), needs_rolling and softressing_players or nil
  end

  local function raid_roll( f )
    ---@param item Item
    ---@param item_count number
    ---@param roll_controller_facade RollControllerFacade
    return function( item, item_count, roll_controller_facade )
      local slot = loot_list.get_slot( item.id )
      local candidates = slot and master_loot_candidates.get( slot ) or group_roster.get_all_players_in_my_group()
      ---@type ItemCandidate[]|Player[]
      local online_candidates = m.filter( candidates, function( c ) return c.online == true end )

      if slot and getn( online_candidates ) == 0 then
        m.pretty_print( "Game API didn't return any loot candidates.", m.colors.red )
        return
      end

      return f( chat, ace_timer, item, item_count or 1, winner_tracker, roll_controller_facade, online_candidates, player_info )
    end
  end

  local function tie_roll( players, item, item_count, item_quantity, on_rolling_finished, roll_type, roll_controller_facade )
    local rollers = m.map( players,
      ---@param player RollingPlayer
      function( player )
        return make_rolling_player( player.name, player.class, player.online, 1 )
      end
    )

    return m.TieRollingLogic.new(
      chat,
      rollers, -- Trackback: changed player_names to players
      item,
      item_count,
      item_quantity,
      on_rolling_finished,
      roll_type,
      config,
      roll_controller_facade
    )
  end

  ---@type RollingStrategyFactory
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
