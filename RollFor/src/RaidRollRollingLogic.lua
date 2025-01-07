RollFor = RollFor or {}
local m = RollFor

if m.RaidRollRollingLogic then return end

local M = {}
local pretty_print = m.pretty_print
local hl = m.colors.hl
local RollingStrategy = m.Types.RollingStrategy
local clear_table = m.clear_table

---@diagnostic disable-next-line: deprecated
local getn = table.getn

function M.new( announce, ace_timer, item, count, winner_tracker, roll_controller, candidates )
  local m_rolling = false
  local m_winners = {}

  local function clear_winners()
    clear_table( m_winners )
    m_winners.n = 0
  end

  local function print_players( players )
    local buffer = ""

    for i, player in ipairs( players ) do
      local separator = ""
      if buffer ~= "" then separator = separator .. ", " end
      local next_player = string.format( "[%d]:%s", i, player.name )

      if (string.len( buffer .. separator .. next_player ) > 255) then
        announce( buffer )
        buffer = next_player
      else
        buffer = buffer .. separator .. next_player
      end
    end

    if buffer ~= "" then announce( buffer ) end
  end

  local function raid_roll()
    m_rolling = true
    m.api.RandomRoll( 1, getn( candidates ) )
  end

  local function announce_rolling()
    m_rolling = true
    clear_winners()

    roll_controller.start( RollingStrategy.RaidRoll, item, count )
    roll_controller.show()
    announce( string.format( "Raid rolling %s...", item.link ) )

    print_players( candidates )
    ace_timer.ScheduleTimer( M, function()
      for _ = 1, count do
        raid_roll()
      end
    end, 1 )
  end

  local function on_roll( player, roll, min, max )
    if player ~= m.my_name() then return end
    if min ~= 1 or max ~= getn( candidates ) then return end

    table.insert( m_winners, candidates[ roll ] )

    if getn( m_winners ) < count then return end

    roll_controller.finish( m_winners )

    for _, winner in ipairs( m_winners ) do
      announce( string.format( "%s wins %s.", winner.name, item.link ) )
      winner_tracker.track( winner.name, item.link, nil, nil, RollingStrategy.RaidRoll )
    end

    m_rolling = false
  end

  local function is_rolling()
    return m_rolling
  end

  local function show_sorted_rolls()
    if getn( m_winners ) == 0 then
      pretty_print( "There is no winner yet.", nil, "RaidRoll" )
      return
    end

    for _, winner in ipairs( m_winners ) do
      pretty_print( string.format( "%s won %s.", hl( winner.name ), item.link ), nil, "RaidRoll" )
    end
  end

  return {
    announce_rolling = announce_rolling, -- This probably doesn't belong here either.
    on_roll = on_roll,
    is_rolling = is_rolling,
    show_sorted_rolls = show_sorted_rolls,
    get_rolling_strategy = function() return m.Types.RollingStrategy.RaidRoll end
  }
end

m.RaidRollRollingLogic = M
return M
