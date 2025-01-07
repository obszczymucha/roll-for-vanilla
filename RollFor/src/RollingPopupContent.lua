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

local top_padding = 11

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
  return { type = "text", value = string.format( "%s wins the %s.", player, blue( "raid-roll" ) ), padding = 8 }
end

function M.insta_raid_roll_winner_content( winner )
  local player = c( winner.name, winner.class )
  return { type = "text", value = string.format( "%s wins the %s.", player, blue( "insta raid-roll" ) ), padding = 8 }
end

function M.roll_winner_content( winner, rolling_strategy )
  local player = c( winner.name, winner.class )
  local roll_type = winner.roll_type and r( winner.roll_type )
  local roll = winner.roll and blue( winner.roll )

  if roll then
    return { type = "text", value = string.format( "%s wins the %s roll with %s %s.", player, roll_type, article( winner.roll ), roll ), padding = top_padding }
  elseif rolling_strategy == RS.SoftResRoll then
    local soft_ressing = r( RT.SoftRes, "soft-ressing" )
    return { type = "text", value = string.format( "%s is the only one %s.", player, soft_ressing ), padding = top_padding }
  else
    return { type = "text", value = string.format( "%s %s win the roll.", player, red( "did not" ) ), padding = top_padding }
  end
end

function M.the_only_sr_content( winner )
  local player = c( winner.name, winner.class )
  local soft_ressing = r( RT.SoftRes, "soft-ressing" )
  return { type = "text", value = string.format( "%s is the only one %s.", player, soft_ressing ), padding = top_padding }
end

function M.new(
    popup,
    roll_controller,
    roll_tracker,
    loot_list,
    config,
    finish_early,
    cancel_roll,
    raid_roll,
    roll_item,
    insta_raid_roll,
    select_player
)
  local function rolls_content( result, rolls )
    for i = 1, getn( rolls ) do
      local roll = rolls[ i ]

      table.insert( result, {
        type = "roll",
        roll_type = roll.roll_type,
        player_name = roll.player_name,
        player_class = roll.player_class,
        roll = roll.roll,
        padding = i == 1 and top_padding or nil
      } )
    end
  end

  local function make_roll_content( result, iterations )
    for _, iteration in ipairs( iterations ) do
      if iteration.rolling_strategy == RS.SoftResRoll or iteration.rolling_strategy == RS.NormalRoll then
        rolls_content( result, iteration.rolls )
      elseif iteration.rolling_strategy == RS.TieRoll then
        table.insert( result, { type = "text", value = string.format( "There was a tie (%s):", blue( iteration.tied_roll ) ), padding = top_padding } )
        rolls_content( result, iteration.rolls )
      end
    end
  end

  local function make_item( item )
    return { type = "item_link_with_icon", link = item and item.link, texture = item and item.texture }
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
    return data.status.type == S.Finished and data.status.winner and not data.status.winner.roll and softres_roll( current_iteration ) or
        data.status.type == S.Preview and data.item.sr_players and getn( data.item.sr_players ) == 1
  end

  local function award_winner_button( data )
    return { type = "button", label = "Award winner", width = 120, on_click = function() roll_controller.award_loot( data.status.winner, data.item ) end }
  end

  local function select_player_button( data )
    return { type = "button", label = "Award...", width = 90, on_click = function() select_player( data.item ) end }
  end

  -- local function free_roll_button( data )
  --   return { type = "button", label = "Free roll", width = 90, on_click = function() free_roll_item( data.item.link ) end }
  -- end
  --
  -- local function loot_yourself( data )
  --   return { type = "button", label = "Loot", width = 55, on_click = function() loot_to_yourself( data.item.slot ) end }
  -- end

  local function roll_button( data )
    return { type = "button", label = "Roll", width = 70, on_click = function() roll_item( data.item ) end }
  end

  local function generate_content( data, current_iteration, show_award_button )
    local result = {}
    local roll_count = current_iteration and current_iteration.rolls and getn( current_iteration.rolls ) or 0

    table.insert( result, make_item( data.item ) )

    if the_only_softres_winner( data, current_iteration ) then
      table.insert( result, M.the_only_sr_content( data.status.winner ) )

      if show_award_button then
        table.insert( result, award_winner_button( data ) )
        -- table.insert( result, free_roll_button( data ) )
        -- table.insert( result, select_player_button( data ) )
      else
        table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )
      end

      return result
    end

    make_roll_content( result, data.iterations )

    if data.status.type == S.TieFound then return result end

    if data.status.type == S.InProgress and current_iteration.rolling_strategy == RS.RaidRoll then
      table.insert( result, { type = "text", value = "Raid rolling...", padding = 8 } )
      return result
    end

    if raid_roll_winner( data, current_iteration ) then
      table.insert( result, M.raid_roll_winner_content( data.status.winner ) )

      if not config.auto_raid_roll() then
        table.insert( result,
          { type = "info", value = string.format( "Use %s to enable auto raid-roll.", blue( "/rf config auto-rr" ) ), anchor = "RollForRollingFrame" } )
      end

      if show_award_button then table.insert( result, award_winner_button( data ) ) end

      if config.raid_roll_again() then
        table.insert( result, { type = "button", label = "Raid roll again", width = 130, on_click = function() raid_roll( data.item ) end } )
      end

      table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )

      return result
    end

    if insta_raid_roll_winner( data, current_iteration ) then
      table.insert( result, M.insta_raid_roll_winner_content( data.status.winner ) )

      if show_award_button then table.insert( result, award_winner_button( data ) ) end

      table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )

      return result
    end

    if data.status.type == S.Canceled then
      table.insert( result, { type = "text", value = "Rolling has been canceled.", padding = top_padding } )
      table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )

      return result
    end

    if data.status.type == S.InProgress and data.status.seconds_left then
      local seconds = data.status.seconds_left
      table.insert( result,
        { type = "text", value = string.format( "Rolling ends in %s second%s.", seconds, seconds == 1 and "" or "s" ), padding = top_padding } )

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

      if show_award_button then table.insert( result, award_winner_button( data ) ) end

      if not softres_roll( current_iteration ) then
        table.insert( result, { type = "button", label = "Raid roll", width = 90, on_click = function() raid_roll( data.item ) end } )
      end

      table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )

      return result
    end

    if data.status.type == S.Finished and not data.status.winner then
      table.insert( result, { type = "text", value = "Rolling has finished. No one rolled.", padding = top_padding } )
      table.insert( result, { type = "button", label = "Raid roll", width = 90, on_click = function() raid_roll( data.item ) end } )
      table.insert( result, { type = "button", label = "Close", width = 90, on_click = function() popup:hide() end } )
      return result
    end

    if data.status.type == S.Waiting then
      table.insert( result, { type = "text", value = "Waiting for remaining rolls...", padding = top_padding } )
      table.insert( result,
        { type = "button", label = "Finish early", width = 100, on_click = finish_early } )
      table.insert( result,
        { type = "button", label = "Cancel", width = 100, on_click = cancel_roll } )
      return result
    end

    if data.item.hr then
      table.insert( result, { type = "text", value = string.format( "This item is %s.", red( "hard-ressed" ) ), padding = top_padding } )
      table.insert( result, select_player_button( data ) )
      -- table.insert( result, free_roll_button( data ) )
      return result
    end

    if data.status.type == S.Preview and roll_count == 0 then
      table.insert( result, roll_button( data ) )
      table.insert( result, { type = "button", label = "Insta RR", width = 80, on_click = function() insta_raid_roll( data.item ) end } )
      table.insert( result, select_player_button( data ) )

      return result
    end

    if data.status.type == S.Preview then
      table.insert( result, roll_button( data ) )
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

    local loot_item = loot_list.find_item( data.item.id )

    if loot_item and data.status.type == S.Finished and current_iteration and (current_iteration.rolling_strategy == RS.RaidRoll or current_iteration.rolling_strategy == RS.InstaRaidRoll) then
      popup:hide()
      roll_controller.award_loot( data.status.winner, data.item, current_iteration.rolling_strategy )
      return
    end

    popup:show()
    popup:refresh( generate_content( data, current_iteration, loot_item ) )
  end

  local function border_color( data )
    if not data then return end

    local color = data.color
    popup:border_color( color.r, color.g, color.b, color.a )
    -- popup:border_color( 0, 0, 0, 1 )
  end

  local function award_aborted()
    local data, current_iteration = roll_tracker.get()

    if not data or not data.status or not data.item or not current_iteration then
      return
    end

    local loot_item = loot_list.find_item( data.item.id )

    popup:show()
    popup:refresh( generate_content( data, current_iteration, loot_item ) )
  end

  local function loot_opened()
    local data = roll_tracker.get()
    if not data or not data.status or not data.item then return end

    local loot_item = loot_list.find_item( data.item.id )

    if not loot_item then return end

    show_and_refresh()
  end

  local function loot_closed()
    local data = roll_tracker.get()
    if not data or not data.status then return end

    refresh()
  end

  roll_controller.subscribe( "preview", show_and_refresh )
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
  roll_controller.subscribe( "loot_opened", loot_opened )
  roll_controller.subscribe( "loot_closed", loot_closed )
end

m.RollingPopupContent = M
return M
