RollFor = RollFor or {}
local m = RollFor

if m.InstaRaidRollRollingLogic then return end

local M = {}
local pp = m.pretty_print
local hl = m.colors.hl
local RollingStrategy = m.Types.RollingStrategy
local roll_type = m.Types.RollType.MainSpec
local clear_table = m.clear_table

---@type MakeWinnerFn
local make_winner = m.Types.make_winner

---@diagnostic disable-next-line: deprecated
local getn = table.getn

-- TODO: Lots of similarity with RaidRollRollingLogic. Perhaps refactor.

---@param announce AnnounceFn
---@param item Item
---@param item_count number
---@param winner_tracker WinnerTracker
---@param roll_controller RollController
---@param candidates ItemCandidate[]|Player[]
function M.new( announce, _, item, item_count, winner_tracker, roll_controller, candidates )
  local m_winners = {}

  local function clear_winners()
    clear_table( m_winners )
    m_winners.n = 0
  end

  local function start_rolling()
    clear_winners()

    roll_controller.start( RollingStrategy.InstaRaidRoll, item, item_count )

    for _ = 1, item_count do
      local roll = m.lua.math.random( 1, getn( candidates ) )
      table.insert( m_winners, candidates[ roll ] )
    end

    m.map( m_winners,
      ---@param player ItemCandidate|Player
      function( player )
        if type( player ) == "table" then -- Fucking lua50 and its n.
          local winner = make_winner( player.name, player.class, item, player.type == "ItemCandidate" or false, roll_type, nil )

          announce( string.format( "%s wins %s via insta raid-roll.", winner.name, item.link ) )
          roll_controller.winner_found( winner )
          winner_tracker.track( winner.name, item.link, roll_type, nil, m.Types.RollingStrategy.InstaRaidRoll )
        end
      end )

    roll_controller.finish()
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
