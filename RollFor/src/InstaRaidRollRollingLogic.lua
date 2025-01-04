RollFor = RollFor or {}
local m = RollFor

if m.InstaRaidRollRollingLogic then return end

local M = {}
local pp = m.pretty_print
local hl = m.colors.hl
local RollingStrategy = m.Types.RollingStrategy

---@diagnostic disable-next-line: deprecated
local getn = table.getn

function M.new( announce, item, winner_tracker, roll_controller, candidates )
  local m_winner

  local function start_rolling()
    m_winner = nil

    roll_controller.start( RollingStrategy.InstaRaidRoll, item )
    local roll = m.lua.math.random( 1, getn( candidates ) )
    m_winner = candidates[ roll ]
    roll_controller.finish( { name = m_winner.name, class = m_winner.class } )
    announce( string.format( "%s wins %s via insta raid-roll.", m_winner.name, item.link ) )
    winner_tracker.track( m_winner.name, item.link, nil, nil, m.Types.RollingStrategy.InstaRaidRoll )
  end

  local function show_sorted_rolls()
    if not m_winner then
      pp( "There is no winner yet.", nil, "RaidRoll" )
      return
    end

    pp( string.format( "%s won %s.", hl( m_winner.name ), item.link ), nil, "InstaRaidRoll" )
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
