RollFor = RollFor or {}
local m = RollFor

if m.RollTracker then return end

-- I hold the entire journey of rolls.
-- The first iteration starts with either a normal or soft-res rolling.
-- Then there's either a winner or a tie.
-- For each tie we have a new iteration, because a tie can result in another tie.
local M = m.Module.new( "RollTracker" )

local clear_table = m.clear_table
local RS = m.Types.RollingStrategy
local RT = m.Types.RollType
local S = m.Types.RollingStatus

---@type LT
local LT = m.ItemUtils.LootType

---@diagnostic disable-next-line: deprecated
local getn = table.getn

---@class RollData
---@field player_name string
---@field player_class string
---@field roll_type RollType
---@field roll number?

---@class RollIteration
---@field rolling_strategy RollingStrategyType
---@field info string
---@field rolls RollData[]
---@field ignored_rolls RollData[]?
---@field tied_roll number?

---@class RollStatus
---@field type RollingStatus
---@field seconds_left number?
---@field winners RollingPlayer[]?

---@alias RollTrackerData {
---  item: Item|DroppedItem|SoftRessedDroppedItem|HardRessedDroppedItem,
---  item_count: number,
---  status: RollStatus,
---  iterations: RollIteration[],
---  winners: Winner[] }

---@class RollTracker
---@field preview fun( item: DroppedItem|HardRessedDroppedItem|SoftRessedDroppedItem, count: number )
---@field start fun( rolling_strategy: RollingStrategyType, item: Item|DroppedItem|SoftRessedDroppedItem, count: number, info: string?, seconds: number?, required_rolling_players: RollingPlayer[]? )
---@field waiting_for_rolls fun()
---@field add_winners fun( winners: Winner[] )
---@field finish fun()
---@field rolling_canceled fun()
---@field tie fun( required_rolling_players: RollingPlayer[], roll_type: RollType, roll: number )
---@field tie_start fun()
---@field add fun( player_name: string, player_class: string, roll_type: RollType, roll: number )
---@field add_ignored fun( player_name: string, roll_type: RollType, roll: number, reason: string )
---@field get fun(): RollTrackerData, RollIteration
---@field tick fun( seconds_left: number )
---@field clear fun()
---@field loot_awarded fun( player_name: string, item_id: number )

function M.new()
  local status
  local item_on_roll
  local item_on_roll_count = 0
  local iterations = {}
  local current_iteration = 0

  ---@type Winner[]
  local winners = {}

  local function clear_iterations()
    clear_table( iterations )
    iterations.n = 0
  end

  local function clear_winners()
    clear_table( winners )
    ---@diagnostic disable-next-line: inject-field
    winners.n = 0
  end

  local function update_roll( rolls, data )
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
    M.debug.add( "add" )

    if current_iteration == 0 then return end

    local data = { player_name = player_name, player_class = player_class, roll_type = roll_type, roll = roll }
    local iteration = iterations[ current_iteration ]

    if roll and (iteration.rolling_strategy == RS.SoftResRoll or iteration.rolling_strategy == RS.TieRoll) then
      update_roll( iteration.rolls, data )
    else
      table.insert( iteration.rolls, data )
    end

    sort( iteration.rolls )
  end

  ---@param item DroppedItem|HardRessedDroppedItem|SoftRessedDroppedItem
  ---@param count number
  local function preview( item, count )
    M.debug.add( "preview" )
    clear_iterations()
    clear_winners()
    current_iteration = 1
    status = { type = S.Preview }
    item_on_roll = item
    item_on_roll_count = count

    table.insert( iterations, {
      rolling_strategy = item.type == LT.SoftRessedDroppedItem and RS.SoftResRoll or RS.NormalRoll,
      rolls = {}
    } )

    if item.type == LT.SoftRessedDroppedItem then
      ---@type RollingPlayer[]
      local candidates = item.sr_players
      status.winners = candidates

      for _, player in ipairs( candidates or {} ) do
        for _ = 1, player.rolls or 1 do
          add( player.name, player.class, RT.SoftRes )
        end
      end
    end
  end


  ---@param rolling_strategy RollingStrategyType
  ---@param item Item|DroppedItem|SoftRessedDroppedItem
  ---@param count number
  ---@param info string
  ---@param seconds number
  ---@param required_rolling_players RollingPlayer[]?
  local function start( rolling_strategy, item, count, info, seconds, required_rolling_players )
    M.debug.add( "start" )
    clear_iterations()
    clear_winners()
    current_iteration = 1
    status = { type = S.InProgress, seconds_left = seconds }

    item_on_roll = item
    item_on_roll_count = count

    table.insert( iterations, {
      rolling_strategy = rolling_strategy,
      info = info,
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

  local function finish()
    M.debug.add( "finish" )
    status = { type = S.Finished }
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
      winners = winners
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
    status.type = S.Canceled
  end

  local function clear()
    clear_iterations()
    clear_winners()
    current_iteration = 0
    status = nil
    item_on_roll = nil
    item_on_roll_count = 0
    M.debug.add( "cleared" )
  end

  local function clear_if_no_winners()
    if getn( winners ) == 0 then
      clear()
    end
  end

  ---@param player_name string
  ---@param item_id number
  local function loot_awarded( player_name, item_id )
    if not item_on_roll or item_on_roll.id ~= item_id then return end

    for i, winner in ipairs( winners ) do
      if winner.name == player_name then
        table.remove( winners, i )
        item_on_roll_count = item_on_roll_count - 1
        clear_if_no_winners()

        return
      end
    end

    clear_if_no_winners()
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
    loot_awarded = loot_awarded
  }
end

m.RollTracker = M
return M
