RollFor = RollFor or {}
local m = RollFor

if m.RollResultAnnouncer then return end

local M = {}

local RT = m.Types.RollType
local RS = m.Types.RollingStrategy
local hl = m.colors.hl
local grey = m.colors.grey
local getn = table.getn

---@param chat Chat
---@param roll_controller RollController
---@param softres GroupAwareSoftRes
---@param config Config
function M.new( chat, roll_controller, softres, config )
  ---@param winners Winner[]
  ---@param top_roll boolean
  local announce_winner = function( winners, top_roll )
    local roll_value = winners[ 1 ].winning_roll

    if not roll_value then
      return
    end

    local roll_type = winners[ 1 ].roll_type
    local roll_type_str = roll_type == RT.MainSpec and "" or string.format( " (%s)", m.roll_type_abbrev_chat( roll_type ) )
    local rerolling = winners[ 1 ].rerolling
    local item = winners[ 1 ].item

    local function sr_plus( value )
      local sr_players = softres.get( item.id )
      local sr_player = m.find( winners[ 1 ].name, sr_players, 'name' )

      if sr_player and sr_player.sr_plus then
        local plus_value = sr_player.sr_plus
        value = value - plus_value
        return string.format( "%s+%s=%s", value, plus_value, value + plus_value )
      end

      return value
    end

    local function message( rollers, f )
      return string.format(
        "%s %srolled the %shighest (%s) for %s%s.",
        rollers,
        rerolling and "re-" or "",
        top_roll and "" or "next ",
        f and f( sr_plus( roll_value ) ) or sr_plus( roll_value ),
        -- item_count and item_count > 1 and string.format( "%sx", item_count ) or "",
        item.link,
        roll_type_str
      )
    end

    local rollers = m.prettify_table( winners, function( p ) return p.name end )
    chat.info( message( rollers, hl ) )
    chat.announce( message( rollers ) )
  end

  ---@param winners Winner[]
  ---@return table<number, Winner[]>
  local function split_winners_by_roll( winners )
    if getn( winners ) == 0 then return {} end
    local result = {}

    local i = 0
    local last_roll

    for _, winner in ipairs( winners ) do
      if not last_roll or last_roll ~= winner.winning_roll then
        table.insert( result, { winner } )
        i = i + 1
        last_roll = winner.winning_roll
      else
        table.insert( result[ i ], winner )
      end
    end

    return result
  end

  ---@param data WinnersFoundData
  local function on_winners_found( data )
    if not data then return end

    local item, item_count, winners, strategy = data.item, data.item_count, data.winners, data.rolling_strategy
    local winner_count = getn( winners )

    if winner_count == 0 then
      return
    end

    if strategy == RS.RaidRoll or strategy == RS.InstaRaidRoll then
      for _, winner in ipairs( winners ) do
        chat.announce( string.format( "%s wins %s (raid-roll).", winner.name, item.link ) )
      end

      return
    end

    if strategy == RS.SoftResRoll and winner_count == item_count and not winners[ 1 ].winning_roll then
      local ressed_by = m.prettify_table( m.map( winners, function( winner ) return winner.name end ) )
      chat.announce( string.format( "%s soft-ressed %s.", ressed_by, item.link ), true )

      return
    end

    for i, winners_by_roll in ipairs( split_winners_by_roll( winners ) ) do
      announce_winner( winners_by_roll, i == 1 )
    end
  end

  ---@param data { players: RollingPlayer[], item: Item, item_count: number, roll_type: RollType, roll: number, rerolling: boolean?, top_roll: boolean? }
  local function on_tie( data )
    local players = data.players
    local roll_type = data.roll_type
    local roll_value = data.roll
    local rerolling = data.rerolling
    local top_roll = data.top_roll
    local item = data.item

    local player_names = m.map( players,
      function( p )
        if type( p ) == "table" then -- Fucking lua50 and its n.
          return p.name
        end
      end )

    local top_rollers_str = m.prettify_table( player_names )
    local top_rollers_str_colored = m.prettify_table( player_names, hl )
    local roll_type_str = roll_type == RT.MainSpec and "" or string.format( " (%s)", m.roll_type_abbrev_chat( roll_type ) )

    local function message( rollers, f )
      return string.format(
        "%s %srolled the %shighest (%s) for %s%s.",
        rollers,
        rerolling and "re-" or "",
        top_roll and "" or "next ",
        f and f( roll_value ) or roll_value,
        -- item_count and item_count > 1 and string.format( "%sx", item_count ) or "",
        item.link,
        roll_type_str
      )
    end

    chat.info( message( top_rollers_str_colored ) )
    chat.announce( message( top_rollers_str ) )
  end

  ---@param event_data TieStartData
  local function on_tie_start( event_data )
    local data, iteration = event_data.tracker_data, event_data.iteration
    if not data or not iteration then return end

    local player_count = getn( iteration.rolls )
    if player_count == 0 then return end

    local roll_type = iteration.rolls[ 1 ].roll_type
    local item, item_count, winners = data.item, data.item_count, data.winners
    local winner_count = getn( winners )
    local count = item_count - winner_count
    local prefix = count > 1 and string.format( "%sx", count ) or ""
    local suffix = count > 1 and string.format( " %s top rolls win.", count ) or ""

    local player_names = m.map( iteration.rolls,
      ---@param roll_data RollData
      function( roll_data )
        return roll_data.player_name
      end )

    local top_rollers_str = m.prettify_table( player_names )
    local roll_threshold_str = config.roll_threshold( roll_type ).str

    chat.announce( string.format( "%s %s for %s%s now.%s", top_rollers_str, roll_threshold_str, prefix, item.link, suffix ) )
  end

  local function on_tick( data )
    if not data or not data.seconds_left then return end

    local seconds_left = data.seconds_left

    if seconds_left == 3 then
      chat.announce( "Stopping rolls in 3" )
    elseif seconds_left < 3 then
      chat.announce( tostring( seconds_left ) )
    end
  end

  ---@param event_data RollingFinishedData
  local function on_finish( event_data )
    local data = event_data.roll_tracker_data
    if not data or not data.item then return end

    local winner_count = getn( data.winners )

    if winner_count == 0 then
      local message = string.format( "No one rolled for %s.", data.item.link )
      chat.info( message )
      chat.announce( message )
    end
  end

  ---@param data LootAwardedData
  local function on_loot_awarded( data )
    local player_name = data.player_class and m.colorize_player_by_class( data.player_name, data.player_class ) or grey( data.player_name )
    chat.info( string.format( "%s received %s.", player_name, data.item_link ) )
  end

  roll_controller.subscribe( "finish", on_finish )
  roll_controller.subscribe( "winners_found", on_winners_found )
  roll_controller.subscribe( "there_was_a_tie", on_tie )
  roll_controller.subscribe( "tie_start", on_tie_start )
  roll_controller.subscribe( "tick", on_tick )
  roll_controller.subscribe( "loot_awarded", on_loot_awarded )
end

m.RollResultAnnouncer = M
return M
