RollFor = RollFor or {}
local m = RollFor

if m.TieRollingLogic then return end

local M = {}

local getn = m.getn
local take = m.take
local RollType = m.Types.RollType
local hl = m.colors.hl

---@type MakeRollFn
local make_roll = m.Types.make_roll

---@param chat Chat
---@param players RollingPlayer[]
---@param item Item
---@param item_count number
---@param on_rolling_finished RollingFinishedCallback
---@param roll_type RollType
---@param config Config
---@param controller RollControllerFacade
function M.new( chat, players, item, item_count, on_rolling_finished, roll_type, config, controller )
  local rolls = {}
  local rolling = false
  local player_count = getn( players )

  ---@param player_name string
  local function find_player( player_name )
    for _, player in ipairs( players ) do
      if player.name == player_name then return player end
    end
  end

  local function sort_rolls()
    table.sort( rolls, function( a, b )
      if a.roll == b.roll then
        return a.player.name < b.player.name
      else
        return a.roll > b.roll
      end
    end )
  end

  local function stop_listening()
    rolling = false
  end

  local function have_all_rolls_been_exhausted()
    local roll_count = getn( rolls )

    if player_count == item_count and player_count == roll_count then
      return true
    end

    for _, v in ipairs( players ) do
      if v.rolls > 0 then return false end
    end

    return true
  end

  local function find_winner()
    stop_listening()
    sort_rolls()

    local roll_count = getn( rolls )

    if roll_count == 0 then
      controller.finish()
      return
    end

    local function count_top_roll_winners()
      if roll_count == 0 then return 0 end

      local function split_by_roll()
        local result = {}
        local last_roll

        for _, roll in ipairs( rolls ) do
          if not last_roll or last_roll ~= roll.roll then
            table.insert( result, { roll } )
            last_roll = roll.roll
          else
            table.insert( result[ getn( result ) ], roll )
          end
        end

        return result
      end

      local result = 0

      for _, r in ipairs( split_by_roll() ) do
        result = result + getn( r )
        if result >= item_count then return result end
      end

      return result
    end

    local top_roll_winner_count = count_top_roll_winners()
    local winner_rolls = take( rolls, top_roll_winner_count > item_count and top_roll_winner_count or item_count )

    on_rolling_finished( item, item_count, winner_rolls, true )
  end

  ---@param roller Player
  ---@param roll number
  ---@param min number
  ---@param max number
  local function on_roll( roller, roll, min, max )
    local ms_threshold = config.ms_roll_threshold()
    local os_threshold = config.os_roll_threshold()
    local tmog_threshold = config.tmog_roll_threshold()

    if not rolling or min ~= 1 or (max ~= tmog_threshold and max ~= os_threshold and max ~= ms_threshold) then return end

    local ms_roll = max == ms_threshold
    local os_roll = max == os_threshold
    local actual_roll_type = ms_roll and RollType.MainSpec or os_roll and RollType.OffSpec or RollType.Transmog

    local player = find_player( roller.name )

    if not player then
      chat.info( m.msg.did_not_tie( roller.name, roller.class, item.link, roll ) )
      controller.roll_was_ignored( roller.name, nil, roll_type, roll, "Not in GroupRoster." )
      return
    end

    if actual_roll_type ~= roll_type and not (actual_roll_type == RollType.MainSpec and roll_type == RollType.SoftRes) then
      local roll_threshold_str = config.roll_threshold( roll_type ).str
      chat.info( m.msg.invalid_roll( player.name, player.class, roll_threshold_str, roll ) )
      return
    end

    if player.rolls == 0 then
      chat.info( m.msg.rolls_exhausted( player.name, player.class, roll ) )
      return
    end

    player.rolls = player.rolls - 1
    table.insert( rolls, make_roll( player, roll_type, roll ) )
    controller.roll_was_accepted( roller.name, player.class, roll_type, roll )

    if have_all_rolls_been_exhausted() then find_winner() end
  end

  local function show_sorted_rolls( limit )
    sort_rolls()
    chat.info( "Tie rolls:" )

    for i, v in ipairs( rolls ) do
      if limit and limit > 0 and i > limit then return end
      chat.info( string.format( "[%s]: %s", hl( v.roll ), m.colorize_player_by_class( v.player.name, v.player.class ) ) )
    end
  end

  local function print_rolling_complete( canceled )
    chat.info( string.format( "Rolling for %s has %s.", item.link, canceled and "been canceled" or "finished" ) )
  end

  local function stop_accepting_rolls()
    stop_listening()
    find_winner()
  end

  local function cancel_rolling()
    stop_listening()
    print_rolling_complete( true )
    chat.announce( string.format( "Rolling for %s was canceled.", item.link ) )
  end

  local function is_rolling()
    return rolling
  end

  local function start_rolling()
    rolling = true
  end

  return {
    start_rolling = start_rolling,
    on_roll = on_roll,
    show_sorted_rolls = show_sorted_rolls,
    stop_accepting_rolls = stop_accepting_rolls,
    cancel_rolling = cancel_rolling,
    is_rolling = is_rolling,
    get_type = function() return m.Types.RollingStrategy.TieRoll end
  }
end

m.TieRollingLogic = M
return M
