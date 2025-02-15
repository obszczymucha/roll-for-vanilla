RollFor = RollFor or {}
local m = RollFor

if m.RaidRollRollingLogic then return end

local M = {}

local getn = m.getn
local hl = m.colors.hl
local strategy = m.Types.RollingStrategy.RaidRoll
local roll_type = m.Types.RollType.MainSpec
local clear_table = m.clear_table

---@type MakeWinnerFn
local make_winner = m.Types.make_winner

-- TODO: Lots of similarity with InstaRaidRollRollingLogic. Perhaps refactor.

---@param chat Chat
---@param ace_timer AceTimer
---@param item Item
---@param item_count number
---@param winner_tracker WinnerTracker
---@param controller RollControllerFacade
---@param candidates ItemCandidate[]|Player[]
---@param roller PlayerInfo
function M.new(
    chat,
    ace_timer,
    item,
    item_count,
    winner_tracker,
    controller,
    candidates,
    roller
)
  local m_rolling = false
  local m_winners = {}

  local function clear_winners()
    clear_table( m_winners )
    if m.vanilla then m_winners.n = 0 end
  end

  local function print_players( players )
    local buffer = ""

    for i, player in ipairs( players ) do
      local separator = ""
      if buffer ~= "" then separator = separator .. ", " end
      local next_player = string.format( "[%d]:%s", i, player.name )

      if (string.len( buffer .. separator .. next_player ) > 255) then
        chat.announce( buffer )
        buffer = next_player
      else
        buffer = buffer .. separator .. next_player
      end
    end

    if buffer ~= "" then chat.announce( buffer ) end
  end

  local function raid_roll()
    m_rolling = true
    m.api.RandomRoll( 1, getn( candidates ) )
  end

  local function start_rolling()
    m_rolling = true
    clear_winners()

    chat.announce( string.format( "Raid rolling %s%s...", item_count and item_count > 1 and string.format( "%sx", item_count ) or "", item.link ) )

    print_players( candidates )
    ace_timer.ScheduleTimer( M, function()
      for _ = 1, item_count do
        raid_roll()
      end
    end, 1 )
  end

  ---@param player Player
  ---@param roll number
  ---@param min number
  ---@param max number
  local function on_roll( player, roll, min, max )
    if player.name ~= roller.get_name() then return end
    if min ~= 1 or max ~= getn( candidates ) then return end

    table.insert( m_winners, candidates[ roll ] )
    if getn( m_winners ) < item_count then return end

    local winners = m.map( m_winners,
      ---@param p ItemCandidate|Player
      function( p )
        if type( p ) == "table" then                                                                       -- Fucking lua50 and its n.
          local winner = make_winner( p.name, p.class, item, p.type == "ItemCandidate" or false, roll_type, nil )
          winner_tracker.track( winner.name, item.link, roll_type, nil, m.Types.RollingStrategy.RaidRoll ) -- TODO: Get the fuck outta here.
          return winner
        end
      end )

    controller.winners_found( item, item_count, winners, strategy )
    controller.finish()
    m_rolling = false
  end

  local function is_rolling()
    return m_rolling
  end

  local function show_sorted_rolls()
    if getn( m_winners ) == 0 then
      chat.info( "There is no winner yet.", nil, "RaidRoll" )
      return
    end

    for _, winner in ipairs( m_winners ) do
      chat.info( string.format( "%s won %s.", hl( winner.name ), item.link ), nil, "RaidRoll" )
    end
  end

  ---@type RollingStrategy
  return {
    start_rolling = start_rolling, -- This probably doesn't belong here either.
    on_roll = on_roll,
    is_rolling = is_rolling,
    show_sorted_rolls = show_sorted_rolls,
    get_type = function() return m.Types.RollingStrategy.RaidRoll end,
    cancel_rolling = m.noop(),
    stop_accepting_rolls = m.noop()
  }
end

m.RaidRollRollingLogic = M
return M
