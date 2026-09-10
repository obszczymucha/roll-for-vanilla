RollFor = RollFor or {}
local m = RollFor

if m.TieRollingLogic then return end

local M = {}

local getn = m.getn
local take = m.take
local RollType = m.Types.RollType
local hl = m.colors.hl
local available_rolls = m.RollingLogicUtils.available_rolls
local consume_roll = m.RollingLogicUtils.consume_roll
local apply_modifiers = m.RollingLogicUtils.apply_modifiers
local best_roll_per_player = m.RollingLogicUtils.best_roll_per_player
local count_top_roll_winners = m.RollingLogicUtils.count_top_roll_winners
local winner_found = m.RollingLogicUtils.winner_found

---@type MakeRollFn
local make_roll = m.Types.make_roll

---@param chat Chat
---@param players RollingPlayer[]
---@param item Item
---@param item_count number
---@param item_quantity number
---@param on_rolling_finished RollingFinishedCallback
---@param roll_type RollType
---@param config Config
---@param controller RollControllerFacade
function M.new( chat, players, item, item_count, item_quantity, on_rolling_finished, roll_type, config, controller )
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

    -- Sorted first, because the check reads each player's best roll and rolls arrive in
    -- cast order.
    sort_rolls()

    -- A player still holding a roll owes one -- unless nothing he could roll would change
    -- the result, which is the same rule the soft-res round stops on. Without it a player
    -- whose tie roll already won would still have to burn every roll he brought.
    for _, v in ipairs( players ) do
      if available_rolls( v ) > 0 then
        return winner_found( players, rolls, item_count, config.roll_threshold( roll_type ).value )
      end
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

    -- One prize per player, so a player who brought several rolls into the tie is judged
    -- on his best one and cannot fill two winning slots with them.
    local candidates = best_roll_per_player( rolls )
    local top_roll_winner_count = count_top_roll_winners( candidates, item_count )
    local winner_rolls = take( candidates, top_roll_winner_count > item_count and top_roll_winner_count or item_count )

    on_rolling_finished( item, item_count, item_quantity, winner_rolls, true )
  end

  ---@param roller Player
  ---@param roll number
  ---@param min number
  ---@param max number
  local function on_roll( roller, roll, min, max )
    local ms_threshold = config.ms_roll_threshold()
    local os_threshold = config.os_roll_threshold()

    if not rolling or min ~= 1 or (max ~= os_threshold and max ~= ms_threshold) then return end

    local ms_roll = max == ms_threshold
    local actual_roll_type = ms_roll and RollType.MainSpec or RollType.OffSpec

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

    local roll_type_used = consume_roll( player )

    if not roll_type_used then
      chat.info( m.msg.rolls_exhausted( player.name, player.class, roll ) )
      return
    end

    -- This round is its own round as far as modifiers are concerned: one that declares
    -- only the soft-res round contributes nothing here, and one that declares the tie round
    -- contributes and says so, which is what makes the announcement right either way.
    local total, adjustments = apply_modifiers( player, item, roll, m.Types.RollingStrategy.TieRoll )

    table.insert( rolls, make_roll( player, roll_type, total, adjustments ) )
    controller.roll_was_accepted( roller.name, player.class, roll_type, total )

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
