RollFor = RollFor or {}
local m = RollFor

if m.RollResultAnnouncer then return end

local M = {}

local RT = m.Types.RollType
local info = m.pretty_print
local hl = m.colors.hl
local getn = table.getn

---@param announce AnnounceFn
---@param roll_controller RollController
---@param roll_tracker RollTracker
function M.new( announce, roll_controller, roll_tracker, config )
  ---@param winner Winner
  ---@param top_roll boolean
  local announce_winner = function( winner, top_roll )
    local roll_value = winner.winning_roll

    if not roll_value then
      return
    end

    local roll_type = winner.roll_type
    local roll_type_str = roll_type == RT.MainSpec and "" or string.format( " (%s)", m.roll_type_abbrev_chat( roll_type ) )
    local rerolling = winner.rerolling
    local item = winner.item

    info( string.format( "%s %srolled the %shighest (%s) for %s%s.", hl( winner.name ),
      rerolling and "re-" or "", top_roll and "" or "next ", hl( roll_value ), item.link, roll_type_str ) )
    announce(
      string.format( "%s %srolled the %shighest (%d) for %s%s.", winner.name,
        rerolling and "re-" or "", top_roll and "" or "next ", roll_value, item.link, roll_type_str ) )
  end

  local function on_finish()
    local data = roll_tracker.get()
    if not data then return end

    local item, winners = data.item, data.winners
    local winner_count = getn( winners )

    if winner_count == 0 then
      info( string.format( "No one rolled for %s.", item.link ) )
      announce( string.format( "No one rolled for %s.", item.link ) )
    end

    for i, winner in ipairs( winners ) do
      announce_winner( winner, i == 1 )
    end
  end

  ---@param data { players: RollingPlayer[], roll_type: RollType, roll: number, rerolling: boolean?, top_roll: boolean? }
  local function on_tie( data )
    local players = data.players
    local roll_type = data.roll_type
    local roll = data.roll
    local rerolling = data.rerolling
    local top_roll = data.top_roll

    local player_names = m.map( players,
      function( p )
        if type( p ) == "table" then -- Fucking lua50 and its n.
          return p.name
        end
      end )

    local top_rollers_str = m.prettify_table( player_names )
    local top_rollers_str_colored = m.prettify_table( player_names, hl )
    local roll_type_str = roll_type == RT.MainSpec and "" or string.format( " (%s)", m.roll_type_abbrev_chat( roll_type ) )

    local message = function( rollers )
      return string.format( "The %shighest %sroll was %d by %s%s.", not rerolling and top_roll and "" or "next ",
        rerolling and "re-" or "", roll or 1337, rollers, roll_type_str )
    end

    info( message( top_rollers_str_colored ) )
    announce( message( top_rollers_str ) )
  end

  local function on_tie_start()
    local data, iteration = roll_tracker.get()
    if not data or not iteration then return end

    local player_count = getn( iteration.rolls )
    if player_count == 0 then return end

    local roll_type = iteration.rolls[ 1 ].roll_type
    local item, item_count = data.item, data.count
    local prefix = item_count > 1 and string.format( "%sx", item_count ) or ""
    local suffix = item_count > 1 and string.format( " %s top rolls win.", item_count ) or ""

    local player_names = m.map( iteration.rolls,
      ---@param roll_data RollData
      function( roll_data )
        return roll_data.player_name
      end )

    local top_rollers_str = m.prettify_table( player_names )
    local roll_threshold_str = config.roll_threshold( roll_type ).str

    announce( string.format( "%s %s for %s%s now.%s", top_rollers_str, roll_threshold_str, prefix, item.link, suffix ) )
  end

  local function on_tick( data )
    if not data or not data.seconds_left then return end

    local seconds_left = data.seconds_left

    if seconds_left == 3 then
      announce( "Stopping rolls in 3" )
    elseif seconds_left < 3 then
      announce( tostring( seconds_left ) )
    end
  end

  roll_controller.subscribe( "finish", on_finish )
  roll_controller.subscribe( "tie", on_tie )
  roll_controller.subscribe( "tie_start", on_tie_start )
  roll_controller.subscribe( "tick", on_tick )
end

m.RollResultAnnouncer = M
return M
