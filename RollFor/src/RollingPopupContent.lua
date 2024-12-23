RollFor = RollFor or {}
local m = RollFor

if m.RollingPopupContent then return end

---@diagnostic disable-next-line: deprecated
local getn = table.getn
local RT = m.Types.RollType
local RS = m.Types.RollingStrategy
local S = m.Types.RollingStatus
local c = m.colorize_player_by_class
local blue = m.colors.blue
local red = m.colors.red
local r = m.roll_type_color

local M = {}

local function article( number )
  local str = tostring( number )

  local first_digit = tonumber( string.sub( str, 1, 1 ) )
  local first_two = tonumber( string.sub( str, 1, 2 ) )

  if first_digit == 8 or first_two == 11 or first_two == 18 then
    return "an"
  end

  return "a"
end

function M.raid_roll_winner_content( winner )
  local player = c( winner.name, winner.class )
  return { type = "text", value = string.format( "%s wins the %s.", player, blue( "raid-roll" ) ), padding = 7 }
end

function M.insta_raid_roll_winner_content( winner )
  local player = c( winner.name, winner.class )
  return { type = "text", value = string.format( "%s wins the %s.", player, blue( "insta raid-roll" ) ), padding = 7 }
end

function M.roll_winner_content( winner, rolling_strategy )
  local player = c( winner.name, winner.class )
  local roll_type = winner.roll_type and r( winner.roll_type )
  local roll = winner.roll and blue( winner.roll )

  if roll then
    return { type = "text", value = string.format( "%s wins the %s roll with %s %s.", player, roll_type, article( winner.roll ), roll ), padding = 10 }
  elseif rolling_strategy == RS.SoftResRoll then
    local soft_ressing = r( RT.SoftRes, "soft-ressing" )
    return { type = "text", value = string.format( "%s is the only one %s.", player, soft_ressing ), padding = 10 }
  else
    return { type = "text", value = string.format( "%s %s win the roll.", player, red( "did not" ) ), padding = 10 }
  end
end

function M.the_only_sr_content( winner )
  local player = c( winner.name, winner.class )
  local soft_ressing = r( RT.SoftRes, "soft-ressing" )
  return { type = "text", value = string.format( "%s is the only one %s.", player, soft_ressing ), padding = 10 }
end

function M.new( popup, roll_controller, roll_tracker, config, finish_early, cancel_roll, raid_roll, master_loot_correlation_data )
  local function rolls_content( result, rolls )
    for i = 1, getn( rolls ) do
      local roll = rolls[ i ]

      table.insert( result, {
        type = "roll",
        roll_type = roll.roll_type,
        player_name = roll.player_name,
        player_class = roll.player_class,
        roll = roll.roll,
        padding = i == 1 and 10 or nil
      } )
    end
  end

  local function make_roll_content( result, iterations )
    for _, iteration in ipairs( iterations ) do
      if iteration.rolling_strategy == RS.SoftResRoll or iteration.rolling_strategy == RS.NormalRoll then
        rolls_content( result, iteration.rolls )
      elseif iteration.rolling_strategy == RS.TieRoll then
        table.insert( result, { type = "text", value = string.format( "There was a tie (%s):", blue( iteration.tied_roll ) ), padding = 10 } )
        rolls_content( result, iteration.rolls )
      end
    end
  end

  local function make_item( item )
    return { type = "item", link = item and item.link }
  end

  local function raid_roll_winner( data, current_iteration )
    return data.status.type == S.Finished and current_iteration and current_iteration.rolling_strategy == RS.RaidRoll
  end

  local function insta_raid_roll_winner( data, current_iteration )
    return data.status.type == S.Finished and current_iteration and current_iteration.rolling_strategy == RS.InstaRaidRoll
  end

  local function roll_winner( data )
    return data.status.type == S.Finished and data.status.winner and data.status.winner.roll
  end

  local function softres_roll( current_iteration )
    return current_iteration and current_iteration.rolling_strategy == RS.SoftResRoll
  end

  local function the_only_softres_winner( data, current_iteration )
    return data.status.type == S.Finished and data.status.winner and not data.status.winner.roll and softres_roll( current_iteration )
  end

  local function generate_content( data, current_iteration, award_button )
    local result = {}
    local roll_count = current_iteration and current_iteration.rolls and getn( current_iteration.rolls ) or 0

    table.insert( result, make_item( data.item ) )

    if the_only_softres_winner( data, current_iteration ) then
      table.insert( result, M.the_only_sr_content( data.status.winner ) )

      if award_button then
        table.insert( result,
          { type = "button", label = "Award", width = 90, on_click = function() roll_controller.award_loot( data.status.winner, data.item.link ) end } )
      end

      table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )
      return result
    end

    make_roll_content( result, data.iterations )

    if data.status.type == S.TieFound then return result end

    if data.status.type == S.InProgress and current_iteration.rolling_strategy == RS.RaidRoll then
      table.insert( result, { type = "icon_text", value = "Raid rolling...", padding = 10 } )
      return result
    end

    if raid_roll_winner( data, current_iteration ) then
      table.insert( result, M.raid_roll_winner_content( data.status.winner ) )

      if not config.auto_raid_roll() then
        table.insert( result,
          { type = "info", value = string.format( "Use %s to enable auto raid-roll.", blue( "/rf config auto-rr" ) ), anchor = "RollForRollingFrame" } )
      end

      if award_button then
        table.insert( result,
          { type = "button", label = "Award", width = 90, on_click = function() roll_controller.award_loot( data.status.winner, data.item.link ) end } )
      end

      if config.raid_roll_again() then
        table.insert( result, { type = "button", label = "Raid roll again", width = 130, on_click = function() raid_roll( data.item.link ) end } )
      end

      table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )

      return result
    end

    if insta_raid_roll_winner( data, current_iteration ) then
      table.insert( result, M.insta_raid_roll_winner_content( data.status.winner ) )

      if award_button then
        table.insert( result,
          { type = "button", label = "Award", width = 90, on_click = function() roll_controller.award_loot( data.status.winner, data.item.link ) end } )
      end

      table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )

      return result
    end

    if data.status.type == S.Canceled then
      table.insert( result, { type = "text", value = "Rolling has been canceled.", padding = 10 } )
      table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )

      return result
    end

    if data.status.type == S.InProgress and data.status.seconds_left then
      local seconds = data.status.seconds_left
      table.insert( result, { type = "text", value = string.format( "Rolling ends in %s second%s.", seconds, seconds == 1 and "" or "s" ), padding = 10 } )

      if roll_count == 0 and config.auto_raid_roll() then
        table.insert( result, { type = "text", value = string.format( "Auto %s is %s.", blue( "raid-roll" ), m.msg.enabled ) } )
      end

      table.insert( result,
        { type = "button", label = "Finish early", width = 100, on_click = finish_early } )
      table.insert( result,
        { type = "button", label = "Cancel", width = 100, on_click = cancel_roll } )
      return result
    end

    if roll_winner( data ) then
      table.insert( result, M.roll_winner_content( data.status.winner, current_iteration and current_iteration.rolling_strategy ) )

      if award_button then
        table.insert( result,
          { type = "button", label = "Award", width = 90, on_click = function() roll_controller.award_loot( data.status.winner, data.item.link ) end } )
      end

      if not softres_roll( current_iteration ) then
        table.insert( result, { type = "button", label = "Raid roll", width = 90, on_click = function() raid_roll( data.item.link ) end } )
      end

      table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )

      return result
    end

    if data.status.type == S.Finished and not data.status.winner then
      table.insert( result, { type = "text", value = "Rolling has finished. No one rolled.", padding = 10 } )
      table.insert( result, { type = "button", label = "Raid roll", width = 90, on_click = function() raid_roll( data.item.link ) end } )
      table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )
      return result
    end

    if data.status.type == S.Waiting then
      table.insert( result, { type = "text", value = "Waiting for remaining rolls...", padding = 10 } )
      table.insert( result,
        { type = "button", label = "Finish early", width = 100, on_click = finish_early } )
      table.insert( result,
        { type = "button", label = "Cancel", width = 100, on_click = cancel_roll } )
      return result
    end

    return result
  end

  local function refresh()
    local data, current_iteration = roll_tracker.get()
    popup:refresh( generate_content( data, current_iteration ) )
  end

  local function show_and_refresh()
    local data, current_iteration = roll_tracker.get()

    if not data or not data.status or not data.item then return end

    if data.status.type == S.Finished and current_iteration and (current_iteration.rolling_strategy == RS.RaidRoll or current_iteration.rolling_strategy == RS.InstaRaidRoll) then
      local slot = master_loot_correlation_data.get( data.item.link )

      -- This confirms that we can safely distribute the item.
      if slot then
        popup:hide()
        roll_controller.award_loot( data.status.winner, data.item.link, current_iteration.rolling_strategy )
        return
      end
    end

    local slot = master_loot_correlation_data.get( data.item.link )

    popup:show()
    popup:refresh( generate_content( data, current_iteration, slot ) )
  end

  local function border_color( data )
    if not data then return end

    local color = data.color
    popup:border_color( color.r, color.g, color.b, color.a )
  end

  local function award_aborted()
    local data, current_iteration = roll_tracker.get()
    if not data or not data.status or not data.item or not current_iteration then return end

    local slot = master_loot_correlation_data.get( data.item.link )

    popup:show()
    popup:refresh( generate_content( data, current_iteration, slot ) )
  end

  local function loot_closed()
    local data = roll_tracker.get()
    if not data or not data.status then return end

    refresh()
  end

  roll_controller.subscribe( "start", refresh )
  roll_controller.subscribe( "tick", refresh )
  roll_controller.subscribe( "finish", show_and_refresh )
  roll_controller.subscribe( "roll", refresh )
  roll_controller.subscribe( "cancel", refresh )
  roll_controller.subscribe( "waiting_for_rolls", refresh )
  roll_controller.subscribe( "tie", show_and_refresh )
  roll_controller.subscribe( "tie_start", refresh )
  roll_controller.subscribe( "show", show_and_refresh )
  roll_controller.subscribe( "border_color", border_color )
  roll_controller.subscribe( "award_aborted", award_aborted )
  roll_controller.subscribe( "loot_closed", loot_closed )
end

m.RollingPopupContent = M
return M
