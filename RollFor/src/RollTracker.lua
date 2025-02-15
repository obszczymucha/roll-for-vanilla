RollFor = RollFor or {}
local m = RollFor

if m.RollTracker then return end

-- I hold the entire journey of rolls.
-- The first iteration starts with either a normal or soft-res rolling.
-- Then there's either a winner or a tie.
-- For each tie we have a new iteration, because a tie can result in another tie.
local M = m.Module.new( "RollTracker" )
local getn = m.getn

local clear_table = m.clear_table
local RS = m.Types.RollingStrategy
local RT = m.Types.RollType
local S = m.Types.RollingStatus

---@class RollData
---@field player_name string
---@field player_class string
---@field roll_type RollType
---@field roll number?

---@class RollIteration
---@field rolling_strategy RollingStrategyType
---@field message string
---@field rolls RollData[]
---@field ignored_rolls RollData[]?
---@field tied_roll number?

-- The status data is different for each type. TODO: split this.
---@class RollStatus
---@field type RollingStatus
---@field seconds_left number?
---@field winners RollingPlayer[]?
---@field ml_candidates ItemCandidate[]?

---@alias RollTrackerData {
---  item: Item|MasterLootDistributableItem,
---  item_count: number,
---  status: RollStatus,
---  iterations: RollIteration[],
---  winners: Winner[],
---  ml_candidates: ItemCandidate[] }

---@class RollTracker
---@field preview fun( count: number, ml_candidates: ItemCandidate[], soft_ressers: RollingPlayer[], hard_ressed: boolean )
---@field start fun( rolling_strategy: RollingStrategyType, count: number, seconds: number?, message: string?, required_rolling_players: RollingPlayer[]? )
---@field waiting_for_rolls fun()
---@field add_winners fun( winners: Winner[] )
---@field finish fun( ml_candidates: ItemCandidate[] )
---@field rolling_canceled fun()
---@field tie fun( required_rolling_players: RollingPlayer[], roll_type: RollType, roll: number )
---@field tie_start fun()
---@field add fun( player_name: string, player_class: string, roll_type: RollType, roll: number )
---@field add_ignored fun( player_name: string, roll_type: RollType, roll: number, reason: string )
---@field get fun(): RollTrackerData, RollIteration
---@field tick fun( seconds_left: number )
---@field clear fun()
---@field loot_awarded fun( player_name: string, item_id: number )
---@field create_roll_data fun( players: RollingPlayer[] ): RollData[]

---@param item_on_roll Item
function M.new( item_on_roll )
  local status
  local item_on_roll_count = 0
  local iterations = {}
  local current_iteration = 0
  local master_loot_candidates = {}

  ---@type Winner[]
  local winners = {}

  local function lua50_clear_table( t )
    clear_table( t )
    if m.vanilla then t.n = 0 end
  end

  local function update_roll( rolls, data )
    M.debug.add( "update_roll" )

    for _, line in ipairs( rolls ) do
      if line.player_name == data.player_name and not line.roll then
        line.roll = data.roll
        return
      end
    end
  end

  local function sort( rolls )
    table.sort( rolls, function( a, b )
      if a.roll_type ~= b.roll_type then return a.roll_type < b.roll_type end

      if a.roll and b.roll then
        if a.roll == b.roll then
          return a.player_name < b.player_name
        end

        return a.roll > b.roll
      end

      if a.roll then
        return true
      end

      if b.roll then
        return false
      end

      return a.player_name < b.player_name
    end )
  end

  local function add( player_name, player_class, roll_type, roll )
    if current_iteration == 0 then return end
    M.debug.add( "add" )

    ---@type RollData
    local data = { player_name = player_name, player_class = player_class, roll_type = roll_type, roll = roll }
    local iteration = iterations[ current_iteration ]

    if roll and (iteration.rolling_strategy == RS.SoftResRoll or iteration.rolling_strategy == RS.TieRoll) then
      update_roll( iteration.rolls, data )
    else
      table.insert( iteration.rolls, data )
    end

    sort( iteration.rolls )
  end

  ---@param players RollingPlayer[]
  local function create_roll_data( players )
    local result = {}

    for _, player in ipairs( players ) do
      for _ = 1, player.rolls do
        ---@type RollData
        local data = { player_name = player.name, player_class = player.class, roll_type = RT.SoftRes }
        table.insert( result, data )
      end
    end

    return result
  end

  ---@param count number
  ---@param ml_candidates ItemCandidate[]
  ---@param soft_ressers RollingPlayer[]
  ---@param hard_ressed boolean
  local function preview( count, ml_candidates, soft_ressers, hard_ressed )
    M.debug.add( "preview" )
    current_iteration = 1
    status = { type = S.Preview }
    item_on_roll_count = count

    local soft_ressed = getn( soft_ressers ) > 0
    local ressed_item = soft_ressed or hard_ressed

    table.insert( iterations, {
      rolling_strategy = ressed_item and RS.SoftResRoll or RS.NormalRoll,
      rolls = {}
    } )

    if soft_ressed then
      status.winners = soft_ressers

      for _, player in ipairs( soft_ressers or {} ) do
        for _ = 1, player.rolls or 1 do
          add( player.name, player.class, RT.SoftRes )
        end
      end
    end

    if ressed_item then
      status.ml_candidates = ml_candidates
    end
  end


  ---@param rolling_strategy RollingStrategyType
  ---@param count number
  ---@param seconds number
  ---@param message string
  ---@param required_rolling_players RollingPlayer[]?
  local function start( rolling_strategy, count, seconds, message, required_rolling_players )
    M.debug.add( "start" )
    lua50_clear_table( iterations )
    lua50_clear_table( winners )
    lua50_clear_table( master_loot_candidates )
    current_iteration = 1
    status = { type = S.InProgress, seconds_left = seconds }

    item_on_roll_count = count

    table.insert( iterations, {
      rolling_strategy = rolling_strategy,
      message = message,
      rolls = {}
    } )

    for _, player in ipairs( required_rolling_players or {} ) do
      for _ = 1, player.rolls or 1 do
        add( player.name, player.class, rolling_strategy == RS.SoftResRoll and RT.SoftRes or RS.TieRoll )
      end
    end
  end

  ---@param new_winners Winner[]
  local function add_winners( new_winners )
    M.debug.add( "add_winners" )

    for _, winner in ipairs( new_winners ) do
      table.insert( winners, winner )
    end
  end

  ---@param ml_candidates ItemCandidate[]
  local function update_ml_candidates( ml_candidates )
    lua50_clear_table( master_loot_candidates )

    for _, ml_candidate in ipairs( ml_candidates ) do
      table.insert( master_loot_candidates, ml_candidate )
    end
  end

  ---@param ml_candidates ItemCandidate[]
  local function finish( ml_candidates )
    M.debug.add( "finish" )
    status = { type = S.Finished }
    update_ml_candidates( ml_candidates )
  end

  --- @param players RollingPlayer[]
  --- @param roll_type RollType
  --- @param roll number
  local function tie( players, roll_type, roll )
    M.debug.add( "tie" )
    current_iteration = current_iteration + 1
    status = { type = S.TieFound }

    table.insert( iterations, {
      rolling_strategy = RS.TieRoll,
      tied_roll = roll,
      rolls = {}
    } )

    for _, player in ipairs( players or {} ) do
      add( player.name, player.class, roll_type )
    end
  end

  local function tie_start()
    M.debug.add( "tie_start" )
    status = { type = S.Waiting }
  end

  local function add_ignored( player_name, roll_type, roll, reason )
    M.debug.add( "add_ignored" )
    if current_iteration == 0 then return end
    iterations[ current_iteration ].ignored_rolls = iterations[ current_iteration ].ignored_rolls or {}
    local rolls = iterations[ current_iteration ].ignored_rolls
    local data = { player_name = player_name, roll_type = roll_type, roll = roll, reason = reason }
    table.insert( rolls, data )
  end

  local function get()
    M.debug.add( "get" )

    return {
      item = item_on_roll,
      item_count = item_on_roll_count,
      status = status,
      iterations = iterations,
      winners = winners,
      ml_candidates = master_loot_candidates
    }, current_iteration > 0 and iterations[ current_iteration ] or nil
  end

  local function tick( seconds_left )
    M.debug.add( "tick" )

    if status.type == S.InProgress then
      status.seconds_left = seconds_left
    end
  end

  local function waiting_for_rolls()
    M.debug.add( "waiting_for_rolls" )
    status.type = S.Waiting
  end

  local function rolling_canceled()
    M.debug.add( "rolling_canceled" )
    if not status then return end
    status.type = S.Canceled
  end

  local function clear()
    error( "Nothing should be clearing this.", 2 )
    -- M.debug.add( "clear" )
    -- lua50_clear_table( iterations )
    -- lua50_clear_table( winners )
    -- lua50_clear_table( master_loot_candidates )
    -- current_iteration = 0
    -- status = nil
    -- item_on_roll = nil
    -- item_on_roll_count = 0
    -- M.debug.add( "cleared" )
  end

  local function mark_as_awarded_if_no_more_items()
    if item_on_roll_count == 0 then
      status.type = S.Awarded
    end
  end

  ---@param player_name string
  ---@param item_id number
  local function loot_awarded( player_name, item_id )
    if item_on_roll.id ~= item_id then return end -- TODO: this makes no sense now

    item_on_roll_count = item_on_roll_count - 1
    local w = status.type == S.Preview and status.winners or winners

    for i, winner in ipairs( w ) do
      if winner.name == player_name then
        table.remove( w, i )
        mark_as_awarded_if_no_more_items()

        return
      end
    end

    mark_as_awarded_if_no_more_items()
  end

  ---@type RollTracker
  return {
    preview = preview,
    start = start,
    waiting_for_rolls = waiting_for_rolls,
    add_winners = add_winners,
    finish = finish,
    rolling_canceled = rolling_canceled,
    tie = tie,
    tie_start = tie_start,
    add = add,
    add_ignored = add_ignored,
    get = get,
    tick = tick,
    clear = clear,
    loot_awarded = loot_awarded,
    create_roll_data = create_roll_data
  }
end

m.RollTracker = M
return M
