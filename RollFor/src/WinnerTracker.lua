RollFor = RollFor or {}
local m = RollFor

if m.WinnerTracker then return end

local M = {}

---@class WinnerTracker
---@field start_rolling fun( item_link: string )
---@field track fun( winner_name: string, item_link: string, roll_type: RollType, winning_roll: number?, rolling_strategy: RollingStrategyType )
---@field untrack fun( winner_name: string, item_link: string )
---@field find_winners fun( item_link: string ): table[]
---@field clear fun()

---@param db table
function M.new( db )
  db.winners = db.winners or {}

  local function track( winner_name, item_link, roll_type, winning_roll, rolling_strategy )
    db.winners[ item_link ] = db.winners[ item_link ] or {}
    db.winners[ item_link ][ winner_name ] = {
      winning_roll = winning_roll,
      roll_type = roll_type,
      rolling_strategy = rolling_strategy
    }
  end

  local function untrack( winner_name, item_link )
    db.winners[ item_link ] = db.winners[ item_link ] or {}
    db.winners[ item_link ][ winner_name ] = nil

    if m.count_elements( db.winners[ item_link ] ) == 0 then
      db.winners[ item_link ] = nil
    end
  end

  local function find_winners( item_link )
    local result = {}

    for winner_name, details in pairs( db.winners[ item_link ] or {} ) do
      table.insert( result, {
        winner_name = winner_name,
        roll_type = details.roll_type,
        winning_roll = details.winning_roll,
        rolling_strategy = details.rolling_strategy
      } )
    end

    return result
  end

  local function start_rolling( item_link )
    db.winners[ item_link ] = {}
  end

  local function clear()
    m.clear_table( db.winners )
  end

  ---@type WinnerTracker
  return {
    start_rolling = start_rolling,
    track = track,
    untrack = untrack,
    find_winners = find_winners,
    clear = clear
  }
end

m.WinnerTracker = M
return M
