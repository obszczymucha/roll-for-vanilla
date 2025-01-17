RollFor = RollFor or {}
local m = RollFor

if m.RollingPopupContent then return end

---@diagnostic disable-next-line: deprecated
local getn = table.getn

---@type RT
local RT = m.Types.RollType
local RS = m.Types.RollingStrategy
local S = m.Types.RollingStatus
---@type LT
local LT = m.ItemUtils.LootType

local c = m.colorize_player_by_class
local blue = m.colors.blue
local red = m.colors.red
local grey = m.colors.grey
local r = m.roll_type_color
local hl = m.colors.hl

local M = {}

local top_padding = 11

---@param number number
local function article( number )
  local str = tostring( number )

  local first_digit = tonumber( string.sub( str, 1, 1 ) )
  local first_two = tonumber( string.sub( str, 1, 2 ) )

  if first_digit == 8 or first_two == 11 or first_two == 18 then
    return "an"
  end

  return "a"
end

---@param winner Winner
---@param item Item
---@param strategy RollingStrategyType
---@param on_click fun( player: ItemCandidate|Winner, item: Item, strategy: RollingStrategyType )
local function award_winner_button( winner, item, strategy, on_click )
  -- TODO: Think how to deal with multiple winners in terms of awarding.
  return {
    type = "award_button",
    label = "Award",
    width = 90,
    on_click = function()
      if on_click then
        on_click( winner, item, strategy )
      end
    end,
    padding = 6
  }
end

---@param winners Winner[]
---@param item Item
---@param strategy RollingStrategyType
---@param on_award_click function
function M.raid_roll_winners_content( winners, item, strategy, on_award_click )
  local result = {}
  local last_award_button_visible = false
  local winner_count = getn( winners )

  for i, winner in ipairs( winners ) do
    local padding = last_award_button_visible and 8 or i > 1 and 2 or 8
    local player = c( winner.name, winner.class )
    table.insert( result, { type = "text", value = string.format( "%s wins the %s.", player, blue( "raid-roll" ) ), padding = padding } )

    if on_award_click and winner_count > 1 and winner.is_on_master_loot_candidate_list then
      table.insert( result, award_winner_button( winner, item, strategy, on_award_click ) )
      last_award_button_visible = true
    end
  end

  return result
end

---@param winners Winner[]
---@param item Item
---@param strategy RollingStrategyType
---@param on_award_click function
function M.insta_raid_roll_winners_content( winners, item, strategy, on_award_click )
  local result = {}
  local last_award_button_visible = false
  local winner_count = getn( winners )

  for i, winner in ipairs( winners ) do
    local padding = last_award_button_visible and 8 or i > 1 and 2 or 8
    local player = c( winner.name, winner.class )
    table.insert( result, { type = "text", value = string.format( "%s wins the %s.", player, blue( "insta raid-roll" ) ), padding = padding } )

    if on_award_click and winner_count > 1 and winner.is_on_master_loot_candidate_list then
      table.insert( result, award_winner_button( winner, item, strategy, on_award_click ) )
      last_award_button_visible = true
    end
  end

  return result
end

---@param winner Winner
function M.sr_content( winner, padding )
  local player = c( winner.name, winner.class )
  local soft_ressed = r( RT.MainSpec, "soft-ressed" )
  return { type = "text", value = string.format( "%s %s this item.", player, soft_ressed ), padding = padding or top_padding }
end

---@param winners Winner[]
---@param item Item
---@param strategy RollingStrategyType
---@param on_award_click fun( player: ItemCandidate, item: Item, strategy: RollingStrategyType )
function M.roll_winner_content( winners, item, strategy, on_award_click )
  local result = {}
  local last_award_button_visible = false
  local winner_count = getn( winners )

  for i, winner in ipairs( winners ) do
    local player = c( winner.name, winner.class )
    local roll_type = winner.roll_type and r( winner.roll_type )
    local roll = winner.winning_roll and blue( winner.winning_roll )
    local padding = last_award_button_visible and 8 or i == 1 and top_padding or (top_padding - 6)

    if roll then
      table.insert( result,
        { type = "text", value = string.format( "%s wins the %s roll with %s %s.", player, roll_type, article( winner.winning_roll ), roll ), padding = padding } )
    elseif strategy == RS.SoftResRoll then
      table.insert( result, M.sr_content( winner, padding ) )
    else
      table.insert( result, { type = "text", value = string.format( "%s %s win the roll.", player, red( "did not" ) ), padding = padding } )
    end

    if winner_count > 1 and winner.is_on_master_loot_candidate_list then
      table.insert( result, award_winner_button( winner, item, strategy, on_award_click ) )
      last_award_button_visible = true
    end
  end

  return result
end

---@param popup table
---@param roll_controller RollController
---@param roll_tracker RollTracker
---@param loot_list SoftResLootList
---@param config Config
---@param raid_roll function
---@param roll_item function
---@param insta_raid_roll function
---@param select_player function
function M.new(
    popup,
    roll_controller,
    roll_tracker,
    loot_list,
    config,
    raid_roll,
    roll_item,
    insta_raid_roll,
    select_player
)
  ---@param result table
  ---@param rolls RollData[]
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

  ---@param result table
  ---@param iterations RollIteration[]
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

  ---@param item Item
  ---@param count number
  local function make_item( item, count )
    return { type = "item_link_with_icon", link = item and item.link, texture = item and item.texture, count = count }
  end

  ---@param data RollTrackerData
  ---@param current_iteration RollIteration
  local function raid_roll_winners( data, current_iteration )
    return data.status.type == S.Finished and current_iteration and current_iteration.rolling_strategy == RS.RaidRoll
  end

  ---@param data RollTrackerData
  ---@param current_iteration RollIteration
  local function insta_raid_roll_winners( data, current_iteration )
    return data.status.type == S.Finished and current_iteration and current_iteration.rolling_strategy == RS.InstaRaidRoll
  end

  ---@param data RollTrackerData
  local function roll_winners( data )
    if data.status.type ~= S.Finished or not data.winners then return false end

    for _, winner in ipairs( data.winners ) do
      if winner.winning_roll then return true end
    end

    return false
  end

  ---@param current_iteration RollIteration
  local function softres_roll( current_iteration )
    return current_iteration and current_iteration.rolling_strategy == RS.SoftResRoll
  end

  ---@param winners Winner[]
  local function there_were_no_rolls( winners )
    for _, winner in ipairs( winners ) do
      if winner.winning_roll then return false end
    end

    return true
  end

  ---@param data RollTrackerData
  ---@param current_iteration RollIteration
  local function softres_winners_with_no_rolls( data, current_iteration )
    return data.status.type == S.Finished and
        data.winners and
        getn( data.winners ) == data.item_count and
        there_were_no_rolls( data.winners ) and
        softres_roll( current_iteration ) or
        data.status.type == S.Preview and
        data.item.sr_players and
        getn( data.item.sr_players ) == data.item_count
  end

  ---@param result table
  ---@param winners Winner[]
  ---@param item Item|DroppedItem|HardRessedDroppedItem|SoftRessedDroppedItem
  ---@param strategy RollingStrategyType
  local function add_bottom_award_winner_button( result, winners, item, strategy )
    if getn( winners ) ~= 1 then return end
    if item.type ~= LT.DroppedItem and item.type ~= LT.SoftRessedDroppedItem then return end

    local dropped_item = assert( item --[[@as DroppedItem|SoftRessedDroppedItem]] )
    local winner = winners[ 1 ]
    if not winner.is_on_master_loot_candidate_list then return end

    table.insert( result, {
      type = "button",
      label = "Award winner",
      width = 130,
      on_click = function()
        roll_controller.show_master_loot_confirmation( winner, dropped_item, strategy )
      end
    } )
  end

  local function select_player_button( item )
    return { type = "button", label = "Award...", width = 90, on_click = function() select_player( item ) end }
  end

  local function roll_button( data )
    return { type = "button", label = "Roll", width = 70, on_click = function() roll_item( data.item ) end }
  end

  local function close_button()
    return { type = "button", label = "Close", width = 70, on_click = function() popup:hide() end }
  end

  ---@param padding number?
  ---@param color function?
  ---@diagnostic disable-next-line: unused-local, unused-function
  local function separator( padding, color )
    local col = color or grey
    return { type = "text", value = col( "-" ), padding = padding or 3 }
  end

  ---@param result table
  ---@param winners Winner[]
  ---@param item Item|DroppedItem|HardRessedDroppedItem|SoftRessedDroppedItem
  ---@param strategy RollingStrategyType
  local function softres_winners_content( result, winners, item, strategy )
    local last_award_button_visible = false
    local winner_count = getn( winners )

    for i, winner in ipairs( winners ) do
      -- if i > 1 and last_award_button_visible then
      --   table.insert( result, separator() )
      -- end

      local padding = last_award_button_visible and 8 or i > 1 and 4 or nil
      table.insert( result, M.sr_content( winner, padding ) )

      if winner_count > 1 and winner.is_on_master_loot_candidate_list then
        table.insert( result, award_winner_button( winner, item, strategy, roll_controller.show_master_loot_confirmation ) )
        last_award_button_visible = true
      end
    end

    if winner_count == 1 then
      add_bottom_award_winner_button( result, winners, item, strategy )
    end

    table.insert( result, close_button() )
    table.insert( result, select_player_button( item ) )

    return result
  end

  ---@param result table
  ---@param data RollTrackerData
  ---@param strategy RollingStrategyType
  local function raid_roll_content( result, data, strategy )
    m.map( M.raid_roll_winners_content( data.winners, data.item, strategy, roll_controller.show_master_loot_confirmation ),
      function( winner ) table.insert( result, winner ) end )

    if not config.auto_raid_roll() then
      table.insert( result,
        { type = "info", value = string.format( "Use %s to enable auto raid-roll.", blue( "/rf config auto-rr" ) ), anchor = "RollForRollingFrame" } )
    end

    add_bottom_award_winner_button( result, data.winners, data.item, strategy )

    if config.raid_roll_again() then
      table.insert( result, { type = "button", label = "Raid roll again", width = 130, on_click = function() raid_roll( data.item, data.item_count ) end } )
    end

    table.insert( result, close_button() )

    return result
  end

  ---@param result table
  ---@param data RollTrackerData
  ---@param strategy RollingStrategyType
  local function insta_raid_roll_content( result, data, strategy )
    m.map( M.insta_raid_roll_winners_content( data.winners, data.item, strategy, roll_controller.show_master_loot_confirmation ),
      function( winner ) table.insert( result, winner ) end )

    add_bottom_award_winner_button( result, data.winners, data.item, strategy )

    if config.raid_roll_again() then
      table.insert( result, { type = "button", label = "Raid roll again", width = 130, on_click = function() insta_raid_roll( data.item, data.item_count ) end } )
    end

    table.insert( result, close_button() )

    return result
  end

  local function seconds_left_content( result, data, roll_count )
    local seconds = data.status.seconds_left
    table.insert( result,
      { type = "text", value = string.format( "Rolling ends in %s second%s.", seconds, seconds == 1 and "" or "s" ), padding = top_padding } )

    if roll_count == 0 and config.auto_raid_roll() then
      table.insert( result, { type = "text", value = string.format( "Auto %s is %s.", blue( "raid-roll" ), m.msg.enabled ) } )
    end

    table.insert( result,
      { type = "button", label = "Finish early", width = 100, on_click = roll_controller.finish_rolling_early } )
    table.insert( result,
      { type = "button", label = "Cancel", width = 100, on_click = roll_controller.cancel_rolling } )
    return result
  end

  ---@param data RollTrackerData
  ---@param current_iteration RollIteration
  local function generate_content( data, current_iteration )
    local result     = {}
    local roll_count = current_iteration and current_iteration.rolls and getn( current_iteration.rolls ) or 0
    local strategy   = current_iteration and current_iteration.rolling_strategy

    table.insert( result, make_item( data.item, data.item_count ) )

    local preview = data.status.type == S.Preview

    if softres_winners_with_no_rolls( data, current_iteration ) then
      return softres_winners_content( result, preview and data.status.winners or data.winners, data.item, strategy )
    end

    make_roll_content( result, data.iterations )

    if preview and roll_count == 0 then
      if data.item_count and data.item_count > 1 then
        table.insert( result, { type = "text", value = string.format( "%s top rolls win.", hl( data.item_count ) ), padding = top_padding } )
      end

      table.insert( result, roll_button( data ) )
      table.insert( result, { type = "button", label = "Insta RR", width = 80, on_click = function() insta_raid_roll( data.item, data.item_count ) end } )
      table.insert( result, select_player_button( data.item ) )

      return result
    end

    if preview then
      table.insert( result, roll_button( data ) )
      table.insert( result, select_player_button( data.item ) )
      return result
    end

    if data.status.type == S.TieFound then return result end

    if data.status.type == S.InProgress and current_iteration.rolling_strategy == RS.RaidRoll then
      table.insert( result, { type = "text", value = "Raid rolling...", padding = 8 } )
      table.insert( result, { type = "empty_line", height = 5 } )
      return result
    end

    if data.status.type == S.InProgress and current_iteration.rolling_strategy == RS.InstaRaidRoll then
      table.insert( result, { type = "text", value = "Insta raid rolling...", padding = 8 } )
      return result
    end

    if raid_roll_winners( data, current_iteration ) then
      return raid_roll_content( result, data, strategy )
    end

    if insta_raid_roll_winners( data, current_iteration ) then
      insta_raid_roll_content( result, data, strategy )
    end

    if data.status.type == S.Canceled then
      table.insert( result, { type = "text", value = "Rolling has been canceled.", padding = top_padding } )
      table.insert( result, close_button() )

      return result
    end

    if data.status.type == S.InProgress and data.status.seconds_left then
      return seconds_left_content( result, data, roll_count )
    end

    if roll_winners( data ) then
      m.map(
        M.roll_winner_content( data.winners, data.item, current_iteration and current_iteration.rolling_strategy, roll_controller.show_master_loot_confirmation ),
        function( winner ) table.insert( result, winner ) end )

      add_bottom_award_winner_button( result, data.winners, data.item, strategy )

      if not softres_roll( current_iteration ) then
        table.insert( result, { type = "button", label = "Raid roll", width = 90, on_click = function() raid_roll( data.item ) end } )
      end

      table.insert( result, close_button() )

      return result
    end

    if data.status.type == S.Finished and (not data.winners or getn( data.winners ) == 0) then
      table.insert( result, { type = "text", value = "Rolling has finished. No one rolled.", padding = top_padding } )
      table.insert( result, { type = "button", label = "Raid roll", width = 90, on_click = function() raid_roll( data.item ) end } )
      table.insert( result, close_button() )
      return result
    end

    if data.status.type == S.Waiting then
      table.insert( result, { type = "text", value = "Waiting for remaining rolls...", padding = top_padding } )
      table.insert( result,
        { type = "button", label = "Finish early", width = 100, on_click = roll_controller.finish_rolling_early } )
      table.insert( result,
        { type = "button", label = "Cancel", width = 100, on_click = roll_controller.cancel_rolling } )
      return result
    end

    if data.item.type == LT.HardRessedItem or data.item.type == LT.HardRessedDroppedItem then
      table.insert( result, { type = "text", value = string.format( "This item is %s.", red( "hard-ressed" ) ), padding = top_padding } )
      table.insert( result, select_player_button( data.item ) )
      -- table.insert( result, free_roll_button( data ) )
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

    local slot = loot_list.get_slot( data.item.id )

    if slot and data.status.type == S.Finished and current_iteration and (current_iteration.rolling_strategy == RS.RaidRoll or current_iteration.rolling_strategy == RS.InstaRaidRoll) then
      local winners = data.winners
      local winner_count = getn( winners )

      -- TODO: Think how to award multiple players.
      if winner_count == 1 then
        local winner = winners[ 1 ]

        if winner.is_on_master_loot_candidate_list then
          popup:hide()

          if data.item.type == LT.DroppedItem or data.item.type == LT.SoftRessedDroppedItem then
            local item = assert( data.item --[[@as DroppedItem|SoftRessedDroppedItem]] )
            roll_controller.show_master_loot_confirmation( winner, item, current_iteration.rolling_strategy )
          else
            m.pdump( data.item )
            m.trace( string.format( "Item was of %s type.", data and data.item and data.item.type or "nil" ) )
          end

          return
        end
      end
    end

    popup:show()
    popup:refresh( generate_content( data, current_iteration ) )
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

    popup:show()
    popup:refresh( generate_content( data, current_iteration ) )
  end

  local function loot_opened()
    local data = roll_tracker.get()
    if not data or not data.status or not data.item then return end

    local slot = loot_list.get_slot( data.item.id )
    if not slot then return end

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
  roll_controller.subscribe( "winners_found", show_and_refresh )
  roll_controller.subscribe( "finish", show_and_refresh )
  roll_controller.subscribe( "roll", refresh )
  roll_controller.subscribe( "rolling_canceled", refresh )
  roll_controller.subscribe( "waiting_for_rolls", refresh )
  roll_controller.subscribe( "tie", show_and_refresh )
  roll_controller.subscribe( "tie_start", refresh )
  roll_controller.subscribe( "show", show_and_refresh )
  roll_controller.subscribe( "border_color", border_color )
  roll_controller.subscribe( "award_aborted", award_aborted )
  roll_controller.subscribe( "not_all_items_awarded", award_aborted )
  roll_controller.subscribe( "loot_opened", loot_opened )
  roll_controller.subscribe( "loot_closed", loot_closed )
end

m.RollingPopupContent = M
return M
