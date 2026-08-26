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
---@field normal_roll fun( item: Item, item_count: number, item_quantity: number, message: string?, seconds: number, on_rolling_finished: RollingFinishedCallback, roll_controller_facade: RollControllerFacade, already_won_players: RollingPlayer[]? ): RollingStrategy
---@field softres_roll fun( item: Item, item_count: number, item_quantity: number, message: string?, seconds: number, on_rolling_finished: RollingFinishedCallback, on_softres_rolls_available: SoftresRollsAvailableCallback, roll_controller_facade: RollControllerFacade ): RollingStrategy, RollingPlayer[]?, RollingPlayer[]?
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
---@param bonus_roll_registry ResistanceBonusRollRegistry
function M.new(
    group_roster,
    loot_list,
    master_loot_candidates,
    chat,
    ace_timer,
    winner_tracker,
    config,
    softres,
    player_info,
    bonus_roll_registry
)
  ---@param item Item
  ---@param item_count number
  ---@param item_quantity number
  ---@param message string?
  ---@param seconds number
  ---@param on_rolling_finished RollingFinishedCallback
  ---@param roll_controller_facade RollControllerFacade
  ---@param already_won_players RollingPlayer[]? -- players who already won a copy; excluded from rolling, their rolls ignored
  local function normal_roll( item, item_count, item_quantity, message, seconds, on_rolling_finished, roll_controller_facade, already_won_players )
    local excluded = {}

    for _, player in ipairs( already_won_players or {} ) do
      excluded[ player.name ] = true
    end

    local players = group_roster.get_all_players_in_my_group()
    local rollers = {}

    for _, player in ipairs( players ) do
      if not excluded[ player.name ] then
        table.insert( rollers, make_rolling_player( player.name, player.class, player.online, 1 ) )
      end
    end

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
      roll_controller_facade,
      already_won_players
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
    -- Already annotated with each player's bonus allowance by SoftResBonusRollDecorator,
    -- so nothing here has to ask about bonus rolls. The registry below is the write path.
    local sr_item = sid( item.id, item_quantity )
    ---@type RollingPlayer[]
    local softressing_players = softres.get( sr_item )

    if getn( softressing_players ) == 0 then
      return normal_roll( item, item_count or 1, item_quantity, message, seconds, on_rolling_finished, roll_controller_facade )
    end

    local sr_count = getn( softressing_players )
    local needs_rolling = sr_count > item_count

    -- When fewer players soft-ressed than copies dropped, each soft-resser wins
    -- one copy and the rest go to a normal roll -- but only if there are
    -- non-soft-resser players left to roll. If everyone soft-ressed, there's
    -- no one to roll, so fall back to the plain soft-res behaviour.
    local sr_names = {}

    for _, player in ipairs( softressing_players ) do
      sr_names[ player.name ] = true
    end

    local non_sr_rollers = 0

    for _, player in ipairs( group_roster.get_all_players_in_my_group() ) do
      if not sr_names[ player.name ] then non_sr_rollers = non_sr_rollers + 1 end
    end

    local leftover_softressers = sr_count < item_count and non_sr_rollers > 0 and softressing_players or nil

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
      roll_controller_facade,
      bonus_roll_registry
    ), needs_rolling and softressing_players or nil, leftover_softressers
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
    -- A tie roll is a roll like any other, so the allowance rule is the same one: one roll
    -- each, plus whatever bonus rolls the player still holds. Spending them in the round
    -- that produced the tie is not what earns the tie -- a player who reached it on his
    -- first roll would otherwise be down every roll he never needed, and the player who
    -- spent his to get there would have had the more rolls at the item.
    local rollers = m.map( players,
      ---@param player RollingPlayer
      function( player )
        return make_rolling_player( player.name, player.class, player.online, 1, player.bonus_rolls )
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
      roll_controller_facade,
      bonus_roll_registry
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
