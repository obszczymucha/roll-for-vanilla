RollFor = RollFor or {}
local m = RollFor

if m.InstaRaidRollRollingLogic then return end

local M = {}
local hl = m.colors.hl
local strategy = m.Types.RollingStrategy.InstaRaidRoll
local roll_type = m.Types.RollType.MainSpec
local clear_table = m.clear_table

---@type MakeWinnerFn
local make_winner = m.Types.make_winner

-- TODO: Lots of similarity with RaidRollRollingLogic. Perhaps refactor.

---@param chat Chat
---@param item Item|MasterLootDistributableItem
---@param item_count number
---@param winner_tracker WinnerTracker
---@param controller RollControllerFacade
---@param candidates ItemCandidate[]|Player[]
function M.new(
    chat,
    _,
    item,
    item_count,
    winner_tracker,
    controller,
    candidates
)
  local m_winners = {}

  local function clear_winners()
    clear_table( m_winners )
    m_winners.n = 0
  end

  local function start_rolling()
    clear_winners()

    for _ = 1, item_count do
      local roll = m.lua.math.random( 1, #candidates )
      table.insert( m_winners, candidates[ roll ] )
    end

    local winners = m.map( m_winners,
      ---@param player ItemCandidate|Player
      function( player )
        if type( player ) == "table" then -- Fucking lua50 and its n.
          local winner = make_winner( player.name, player.class, item, player.type == "ItemCandidate" or false, roll_type, nil )
          winner_tracker.track( winner.name, item.link, roll_type, nil, m.Types.RollingStrategy.InstaRaidRoll )
          return winner
        end
      end )

    controller.winners_found( item, item_count, winners, strategy )
    controller.finish()
  end

  local function show_sorted_rolls()
    if #m_winners == 0 then
      chat.info( "There is no winner yet.", nil, "RaidRoll" )
      return
    end

    for _, winner in ipairs( m_winners ) do
      chat.info( string.format( "%s won %s.", hl( winner.name ), item.link ), nil, "InstaRaidRoll" )
    end
  end

  ---@type RollingStrategy
  return {
    start_rolling = start_rolling, -- This probably doesn't belong here either.
    on_roll = function() end,
    is_rolling = function() return false end,
    show_sorted_rolls = show_sorted_rolls,
    get_type = function() return m.Types.RollingStrategy.InstaRaidRoll end,
    stop_accepting_rolls = m.noop(),
    cancel_rolling = m.noop()
  }
end

m.InstaRaidRollRollingLogic = M
return M
