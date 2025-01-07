RollFor = RollFor or {}
local m = RollFor

if m.InstaRaidRollRollingLogic then return end

local M = {}
local pp = m.pretty_print
local hl = m.colors.hl
local RollingStrategy = m.Types.RollingStrategy
local clear_table = m.clear_table

---@diagnostic disable-next-line: deprecated
local getn = table.getn

function M.new( announce, item, count, winner_tracker, roll_controller, candidates )
  local m_winners = {}

  local function clear_winners()
    clear_table( m_winners )
    m_winners.n = 0
  end

  local function start_rolling()
    clear_winners()

    roll_controller.start( RollingStrategy.InstaRaidRoll, item, count )

    for _ = 1, count do
      local roll = m.lua.math.random( 1, getn( candidates ) )
      table.insert( m_winners, candidates[ roll ] )
    end

    roll_controller.finish( m_winners )

    for _, winner in ipairs( m_winners ) do
      announce( string.format( "%s wins %s via insta raid-roll.", winner.name, item.link ) )
      winner_tracker.track( winner.name, item.link, nil, nil, m.Types.RollingStrategy.InstaRaidRoll )
    end
  end

  local function show_sorted_rolls()
    if getn( m_winners ) == 0 then
      pp( "There is no winner yet.", nil, "RaidRoll" )
      return
    end

    for _, winner in ipairs( m_winners ) do
      pp( string.format( "%s won %s.", hl( winner.name ), item.link ), nil, "InstaRaidRoll" )
    end
  end

  return {
    announce_rolling = start_rolling, -- This probably doesn't belong here either.
    on_roll = function() end,
    is_rolling = function() return false end,
    show_sorted_rolls = show_sorted_rolls,
    get_rolling_strategy = function() return m.Types.RollingStrategy.InstaRaidRoll end
  }
end

m.InstaRaidRollRollingLogic = M
return M
