RollFor = RollFor or {}
local m = RollFor

if m.RollingPopupContentTransformer then return end

local M = m.Module.new( "RollingPopupContentTransformer" )

local RT = m.Types.RollType ---@type RT
local RS = m.Types.RollingStrategy ---@type RS

local getn = m.getn
local c = m.colorize_player_by_class
local blue = m.colors.blue
local red = m.colors.red
local r = m.roll_type_color
local article = m.article

---@param label string
---@param width number
local function button_definition( label, width )
  return { type = "button", label = label, width = width }
end

M.button_definitions = {
  [ "AwardOther" ] = button_definition( "...", 40 ),
  [ "AwardWinner" ] = button_definition( "Award", 75 ),
  [ "Cancel" ] = button_definition( "Cancel", 80 ),
  [ "Close" ] = button_definition( "Close", 70 ),
  [ "FinishEarly" ] = button_definition( "Finish early", 110 ),
  [ "InstaRaidRoll" ] = button_definition( "Raid roll", 90 ),
  [ "RaidRoll" ] = button_definition( "Raid roll", 90 ),
  [ "RaidRollAgain" ] = button_definition( "Raid roll again", 130 ),
  [ "Roll" ] = button_definition( "Roll", 60 )
}

local top_padding = 11

---@alias RollingPopupButtonType
---| "Roll"
---| "AwardWinner"
---| "AwardOther"
---| "RaidRoll"
---| "InstaRaidRoll"
---| "RaidRollAgain"
---| "Close"
---| "FinishEarly"
---| "Cancel"

---@class RollingPopupContentTransformer
---@field transform fun( data: RollingPopupData ): table

---@param config Config
---@diagnostic disable-next-line: unused-local
function M.new( config )
  ---@param on_click fun()
  local function award_winner_button( on_click )
    return { type = "award_button", label = "Award", width = 90, on_click = on_click, padding = 6 }
  end

  ---@param content table
  ---@param message string
  ---@param padding number?
  local function add_text( content, message, padding )
    table.insert( content, { type = "text", value = message, padding = padding } )
  end

  ---@param content table
  ---@param height number
  local function add_empty_line( content, height )
    table.insert( content, { type = "empty_line", height = height } )
  end

  ---@param content table
  ---@param item_link ItemLink
  ---@param item_tooltip_link TooltipItemLink
  ---@param item_texture ItemTexture
  ---@param item_count number
  local function add_item( content, item_link, item_tooltip_link, item_texture, item_count )
    table.insert( content, {
      type = "item_link_with_icon",
      link = item_link,
      tooltip_link = item_tooltip_link,
      texture = item_texture,
      count = item_count
    } )
  end

  ---@param content table
  local function add_hr_info( content )
    table.insert( content, { type = "text", value = string.format( "This item is %s.", red( "hard-ressed" ) ), padding = top_padding } )
  end

  ---@param result table
  ---@param rolls RollData[]
  local function add_rolls( result, rolls )
    M.debug.add( "rolls_content" )

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

  ---@param content table
  ---@param player string
  ---@param padding number
  local function add_raid_roll_winner_new( content, player, padding )
    M.debug.add( "add_insta_raid_roll_winner" )
    table.insert( content, { type = "text", value = string.format( "%s wins the %s.", player, blue( "raid-roll" ) ), padding = padding } )
  end

  ---@param content table
  ---@param player string
  ---@param roll_type RollType
  ---@param winning_roll number?
  ---@param padding number
  local function add_roll_winner_new( content, player, roll_type, winning_roll, strategy, padding )
    M.debug.add( "add_roll_winner" )
    local roll = winning_roll and blue( winning_roll )

    if roll then
      table.insert( content,
        { type = "text", value = string.format( "%s wins the %s roll with %s %s.", player, r( roll_type ), article( winning_roll ), roll ), padding = padding } )
    elseif strategy == RS.SoftResRoll then
      local soft_ressed = r( RT.SoftRes, "soft-ressed" )
      table.insert( content, { type = "text", value = string.format( "%s %s this item.", player, soft_ressed ), padding = padding or top_padding } )
    else
      table.insert( content, { type = "text", value = string.format( "%s %s win the roll.", player, red( "did not" ) ), padding = padding } )
    end
  end

  ---@param content table
  ---@param winners WinnerWithAwardCallback[]
  ---@param strategy_type RollingStrategyType
  local function add_winners( content, winners, strategy_type )
    local was_there_award_button = false

    for i, winner in ipairs( winners ) do
      local player = c( winner.name, winner.class )
      local padding = i == 1 and 11 or was_there_award_button and 8 or 2

      if strategy_type == RS.InstaRaidRoll or strategy_type == RS.RaidRoll then
        add_raid_roll_winner_new( content, player, padding )
      else
        add_roll_winner_new( content, player, winner.roll_type, winner.roll, strategy_type, padding )
      end

      if winner.award_callback then
        table.insert( content, award_winner_button( winner.award_callback ) )
        was_there_award_button = true
      else
        was_there_award_button = false
      end
    end
  end

  ---@param content table
  ---@param buttons RollingPopupButtonWithCallback[]
  local function add_buttons( content, buttons )
    for _, button in ipairs( buttons ) do
      local definition = M.button_definitions[ button.type ]
      if not definition then error( string.format( "Unsupported button type: %s", button.type or "nil" ) ) end

      if not button.should_display_callback or button.should_display_callback() then
        table.insert( content, {
          type = definition.type,
          label = definition.label,
          width = definition.width,
          on_click = button.callback
        } )
      end
    end
  end

  ---@class RollingPopupPreviewData
  ---@field item_link ItemLink
  ---@field item_tooltip_link TooltipItemLink
  ---@field item_texture ItemTexture
  ---@field item_count number
  ---@field hard_ressed boolean
  ---@field winners WinnerWithAwardCallback[]
  ---@field rolls RollData[]
  ---@field strategy_type RollingStrategyType
  ---@field buttons RollingPopupButtonWithCallback[]
  ---@field type "Preview"

  ---@param data RollingPopupPreviewData
  local function preview_content( data )
    local content = {}

    add_item( content, data.item_link, data.item_tooltip_link, data.item_texture, data.item_count )

    if data.hard_ressed then
      add_hr_info( content )
    else
      add_rolls( content, data.rolls )
      add_winners( content, data.winners, data.strategy_type )
    end

    add_buttons( content, data.buttons )

    return content
  end

  ---@class RollingPopupRaidRollData
  ---@field item_link ItemLink
  ---@field item_tooltip_link TooltipItemLink
  ---@field item_texture ItemTexture
  ---@field item_count number
  ---@field winners WinnerWithAwardCallback[]
  ---@field buttons RollingPopupButtonWithCallback[]
  ---@field type "RaidRoll"

  ---@param data RollingPopupRaidRollData
  local function insta_raid_roll_content( data )
    local content = {}

    add_item( content, data.item_link, data.item_tooltip_link, data.item_texture, data.item_count )
    add_winners( content, data.winners, "InstaRaidRoll" )
    add_buttons( content, data.buttons )

    return content
  end

  ---@param content table
  ---@param seconds_left number
  local function seconds_left_content( content, seconds_left )
    local color = m.interpolate_color( seconds_left )
    local seconds = m.colorize( color, seconds_left )
    add_text( content, string.format( "Rolling ends in %s second%s.", seconds, seconds_left == 1 and "" or "s" ), top_padding )
  end

  ---@class RollingPopupRollData
  ---@field item_link ItemLink
  ---@field item_tooltip_link TooltipItemLink
  ---@field item_texture ItemTexture
  ---@field item_count number
  ---@field seconds_left number?
  ---@field rolls RollData[]
  ---@field winners WinnerWithAwardCallback[]
  ---@field buttons RollingPopupButtonWithCallback[]
  ---@field strategy_type RollingStrategyType
  ---@field waiting_for_rolls boolean?
  ---@field type "Roll"

  ---@param data RollingPopupRollData
  local function roll_content( data )
    local content = {}

    add_item( content, data.item_link, data.item_tooltip_link, data.item_texture, data.item_count )

    if not data.seconds_left and getn( data.rolls ) == 0 then
      add_text( content, "Rolling finished. No one rolled.", top_padding )
    else
      add_rolls( content, data.rolls )
    end

    if data.seconds_left then seconds_left_content( content, data.seconds_left ) end

    add_winners( content, data.winners, data.strategy_type )

    if data.waiting_for_rolls then
      add_text( content, "Waiting for remaining rolls...", top_padding )
    end

    add_buttons( content, data.buttons )

    return content
  end

  ---@class RollingPopupRollingCanceledData
  ---@field item_link ItemLink
  ---@field item_tooltip_link TooltipItemLink
  ---@field item_texture ItemTexture
  ---@field item_count number
  ---@field buttons RollingPopupButtonWithCallback[]
  ---@field type "RollingCanceled"

  ---@param data RollingPopupRollingCanceledData
  local function rolling_canceled_content( data )
    local content = {}

    add_item( content, data.item_link, data.item_tooltip_link, data.item_texture, data.item_count )
    add_text( content, "Rolling was canceled.", top_padding )
    add_buttons( content, data.buttons )

    return content
  end

  ---@class RollingPopupRaidRollingData
  ---@field item_link ItemLink
  ---@field item_tooltip_link TooltipItemLink
  ---@field item_texture ItemTexture
  ---@field item_count number
  ---@field type "RaidRolling"

  ---@param data RollingPopupRaidRollingData
  local function raid_rolling_content( data )
    local content = {}

    add_item( content, data.item_link, data.item_tooltip_link, data.item_texture, data.item_count )
    add_text( content, "Raid rolling...", top_padding )
    add_empty_line( content, 5 )

    return content
  end

  ---@class TieIteration
  ---@field tied_roll number
  ---@field rolls RollData[]

  ---@class RollingPopupTieData
  ---@field roll_data RollingPopupRollData
  ---@field tie_iterations TieIteration[]
  ---@field type "Tie"

  ---@param data RollingPopupTieData
  local function tie_content( data )
    local content = {}

    add_item( content, data.roll_data.item_link, data.roll_data.item_tooltip_link, data.roll_data.item_texture, data.roll_data.item_count )
    add_rolls( content, data.roll_data.rolls )

    for _, iteration in ipairs( data.tie_iterations ) do
      add_text( content, string.format( "There was a tie (%s):", blue( iteration.tied_roll ) ), top_padding )
      add_rolls( content, iteration.rolls )
    end

    if data.roll_data.waiting_for_rolls then
      add_text( content, "Waiting for remaining rolls...", top_padding )
    elseif getn( data.roll_data.winners ) == 0 then
      add_empty_line( content, 5 )
    end

    add_buttons( content, data.roll_data.buttons )

    return content
  end

  ---@param data RollingPopupPreviewData|RollingPopupRaidRollData|RollingPopupRollData|RollingPopupRollingCanceledData|RollingPopupRaidRollingData|RollingPopupTieData
  local function transform( data )
    if data.type == "Preview" then
      return preview_content( data )
    end

    if data.type == "RaidRoll" then
      return insta_raid_roll_content( data )
    end

    if data.type == "Roll" then
      return roll_content( data )
    end

    if data.type == "RollingCanceled" then
      return rolling_canceled_content( data )
    end

    if data.type == "RaidRolling" then
      return raid_rolling_content( data )
    end

    if data.type == "Tie" then
      return tie_content( data )
    end

    error( string.format( "Unsupported type: %s", data.type or "nil" ) )
  end

  return {
    transform = transform
  }
end

m.RollingPopupContentTransformer = M
return M
