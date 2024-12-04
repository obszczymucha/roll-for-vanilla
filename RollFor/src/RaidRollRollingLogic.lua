---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.RaidRollRollingLogic then return end

local M = {}
local pretty_print = modules.pretty_print
local hl = modules.colors.hl
local RollingStrategy = modules.Types.RollingStrategy

---@diagnostic disable-next-line: deprecated
local getn = table.getn

function M.new( announce, ace_timer, group_roster, item, winner_tracker, roll_controller )
  local m_rolling = false
  local m_players
  local m_winner

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
    m_winner = nil
    modules.api.RandomRoll( 1, getn( m_players ) )
  end

  local function announce_rolling()
    m_rolling = true
    m_winner = nil

    roll_controller.start( RollingStrategy.RaidRoll, item )
    roll_controller.show()
    announce( string.format( "Raid rolling %s...", item.link ) )

    m_players = group_roster.get_all_players_in_my_group( function( p )
      return p.online == true
    end )

    print_players( m_players )
    ace_timer.ScheduleTimer( M, raid_roll, 1 )
  end

  local function on_roll( player, roll, min, max )
    if player ~= modules.my_name() then return end
    if min ~= 1 or max ~= getn( m_players ) then return end

    m_winner = m_players[ roll ]
    roll_controller.finish( { name = m_winner.name, class = m_winner.class } )
    announce( string.format( "%s wins %s.", m_winner.name, item.link ) )
    winner_tracker.track( m_winner.name, item.link, modules.Types.RollType.RaidRoll )

    m_rolling = false
  end

  local function is_rolling()
    return m_rolling
  end

  local function show_sorted_rolls()
    if not m_winner then
      pretty_print( "There is no winner yet.", nil, "RaidRoll" )
      return
    end

    pretty_print( string.format( "%s won %s.", hl( m_winner.name ), item.link ), nil, "RaidRoll" )
  end

  return {
    announce_rolling = announce_rolling, -- This probably doesn't belong here either.
    on_roll = on_roll,
    is_rolling = is_rolling,
    show_sorted_rolls = show_sorted_rolls,
    get_rolling_strategy = function() return modules.Types.RollingStrategy.RaidRoll end
  }
end

modules.RaidRollRollingLogic = M
return M
