---@diagnostic disable-next-line: undefined-global
local modules = LibStub( "RollFor-Modules" )
if modules.RollingPopup then return end

local m = modules
local c = m.colorize_player_by_class
local r = modules.roll_type_color
local blue = m.colors.blue
---@diagnostic disable-next-line: deprecated
local getn = table.getn
local RollingStrategy = m.Types.RollingStrategy
local RollType = m.Types.RollType

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

local M = {}

function M.new( custom_popup_builder, roll_tracker, finish_early, cancel_roll, raid_roll, config )
  local popup
  local selected_frame
  local item_link
  local seconds
  local rolling_strategy

  local function create_item( parent )
    local result = modules.api.CreateFrame( "Button", nil, parent )

    result.text = result:CreateFontString( nil, "ARTWORK", "GameFontNormal" )
    result.text:SetPoint( "TOP", 0, 0 )
    result.text:SetText( "PrincessKenny" )
    result:SetHeight( result.text:GetHeight() )

    result:SetScript( "OnEnter", function()
      ---@diagnostic disable-next-line: undefined-global
      local self = this
      modules.api.GameTooltip:SetOwner( self, "ANCHOR_CURSOR" )
      modules.api.GameTooltip:SetHyperlink( result.tooltip_link )
      modules.api.GameTooltip:Show()
    end )

    result:SetScript( "OnLeave", function()
      modules.api.GameTooltip:Hide()
    end )

    return result
  end

  local function create_text( parent, text )
    local result = parent:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )

    result:SetTextColor( 1, 1, 1 )
    if text then result:SetText( text ) end

    return result
  end

  local function create_roll( parent )
    local frame = m.api.CreateFrame( "Button", nil, parent )
    frame:SetWidth( 170 )
    frame:SetHeight( 14 )
    frame:SetFrameStrata( "DIALOG" )
    frame:SetFrameLevel( parent:GetFrameLevel() + 1 )
    frame:SetBackdrop( {
      bgFile = "Interface/Buttons/WHITE8x8",
      tile = true,
      tileSize = 22,
    } )

    local function blue_hover( a )
      frame:SetBackdropColor( 0.125, 0.624, 0.976, a )
    end

    local function hover()
      if frame.is_selected then
        return
      end

      blue_hover( 0.2 )
    end

    frame.select = function()
      blue_hover( 0.3 )
      frame.is_selected = true
    end

    local function no_hover()
      if frame.is_selected then
        frame.select()
      else
        blue_hover( 0 )
      end
    end

    frame.deselect = function()
      blue_hover( 0 )
      frame.is_selected = false
    end

    frame:deselect()
    frame:SetScript( "OnEnter", function()
      hover()
    end )

    frame:SetScript( "OnLeave", function()
      no_hover()
    end )

    frame:EnableMouse( true )

    local roll_type = create_text( frame )
    roll_type:SetPoint( "LEFT", frame, "LEFT", 10, 0 )
    frame.roll_type = roll_type

    local player_name = create_text( frame )
    player_name:SetPoint( "CENTER", frame, "CENTER", 0, 0 )
    frame.player_name = player_name

    local roll = create_text( frame )
    roll:SetPoint( "RIGHT", frame, "RIGHT", -10, 0 )
    frame.roll = roll

    return frame
  end

  local function create_button( parent )
    local button = modules.api.CreateFrame( "Button", nil, parent, "StaticPopupButtonTemplate" )
    button:SetWidth( 100 )
    button:SetHeight( 20 )
    button:SetText( "" )
    button:GetFontString():SetPoint( "CENTER", 0, -1 )

    return button
  end

  local frame_creators = {
    [ "item" ] = create_item,
    [ "text" ] = create_text,
    [ "roll" ] = create_roll,
    [ "button" ] = create_button
  }

  local function sort( rolls )
    table.sort( rolls, function( a, b )
      return a.roll_type < b.roll_type or (a.roll_type == b.roll_type and a.roll > b.roll)
    end )

    return rolls
  end

  local function make_roll_content( result, rolls )
    for i = 1, getn( rolls ) do
      local roll = rolls[ i ]

      table.insert( result, {
        type = "roll",
        roll_type = roll.roll_type,
        player_name = roll.player_name,
        player_class = roll.player_class,
        roll = roll.roll,
        padding = i == 1 and 10
      } )
    end
  end

  local function item_and_rolls()
    local result = {}
    table.insert( result, { type = "item", link = item_link } )

    local rolls = sort( roll_tracker.get() )
    make_roll_content( result, rolls )

    return result, getn( rolls ), rolls
  end

  local function tick_content()
    local content, roll_count = item_and_rolls()
    table.insert( content, { type = "text", value = string.format( "Rolling ends in %s second%s.", seconds, seconds == 1 and "" or "s" ), padding = 10 } )

    if roll_count == 0 and config.auto_raid_roll then
      table.insert( content,
        { type = "text", value = string.format( "Auto %s is %s.", blue( "raid-roll" ), modules.msg.enabled ), padding = 3 } )
    end

    table.insert( content,
      { type = "button", label = "Finish early", width = 100, on_click = finish_early } )
    table.insert( content,
      { type = "button", label = "Cancel", width = 100, on_click = cancel_roll } )

    return content
  end

  local function refresh( content )
    if not popup then return end
    popup:clear()

    for _, v in ipairs( content ) do
      popup.add_line( v.type, function( type, frame )
        if type == "item" then
          frame.text:SetText( v.link )
          frame:SetWidth( frame.text:GetWidth() )
          frame.tooltip_link = item_link and m.ItemUtils.get_tooltip_link( item_link )
        elseif type == "text" then
          frame:SetText( v.value )
        elseif type == "roll" then
          frame.roll_type:SetText( m.roll_type_color( v.roll_type, m.roll_type_abbrev( v.roll_type ) ) )
          frame.player_name:SetText( c( v.player_name, v.player_class ) )
          frame.roll:SetText( blue( v.roll ) )
          local player_name = v.player_name

          frame:SetScript( "OnClick", function()
            if selected_frame then selected_frame:deselect() end
            frame:select()
            selected_frame = frame
            print( player_name )
          end )
        elseif type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )
        end
      end, v.padding )
    end
  end

  local function start_content( strategy )
    if strategy == RollingStrategy.RaidRoll then
      return {
        { type = "item", link = item_link },
        { type = "text", value = "Raid rolling...", padding = 10 },
      }
    else
      return tick_content()
    end
  end

  local function create_popup()
    popup = custom_popup_builder()
        :with_name( "RollForRollingFrame" )
        :with_width( 180 )
        :with_height( 100 )
        :with_bg_file( "Interface/Buttons/WHITE8x8" )
        :with_sound()
        :with_esc()
        :with_backdrop_color( 0, 0, 0, 0.6 )
        :with_creators( frame_creators )
        :build()
  end

  local function on_start( data )
    if not popup then
      create_popup()
    else
      popup:clear()
    end

    item_link = data.item.link
    seconds = data.seconds
    rolling_strategy = data.rolling_strategy

    refresh( start_content( rolling_strategy ) )

    popup:Show()
  end

  local function on_tick( data )
    seconds = data.seconds
    refresh( tick_content() )
  end

  local function on_roll()
    refresh( tick_content() )
  end

  local function on_stop( data )
    seconds = 0

    if data.rolling_strategy == RollingStrategy.SoftResRoll and data.item_link then
      item_link = data.item_link
    end

    local content, roll_count, rolls = item_and_rolls()

    if data.rolling_strategy == RollingStrategy.RaidRoll then
      table.insert( content,
        { type = "text", value = string.format( "%s wins the %s.", c( data.player_name, data.player_class ), blue( "raid-roll" ) ), padding = 7 } )
      table.insert( content, { type = "button", label = "Raid roll again", width = 130, on_click = function() raid_roll( item_link ) end } )
      table.insert( content, { type = "button", label = "Close", width = 90, on_click = function() popup:Hide() end } )
      refresh( content )
      return
    end

    if data.rolling_strategy == RollingStrategy.SoftResRoll and data.player_name and data.player_class then
      if not popup then
        create_popup()
        popup:Show()
      else
        popup:clear()
      end

      local player = c( data.player_name, data.player_class )
      table.insert( content, { type = "text", value = string.format( "%s is the only one %s.", player, r( RollType.SoftRes, "soft-ressing" ) ), padding = 7 } )
      table.insert( content, { type = "button", label = "Close", width = 90, on_click = function() popup:Hide() end } )
      refresh( content )

      return
    end

    if roll_count == 0 then
      table.insert( content, { type = "text", value = "Rolling has finished. No one rolled.", padding = 10 } )
    else
      local winning_roll = rolls[ 1 ]
      local player = c( winning_roll.player_name, winning_roll.player_class )
      local roll_type = r( winning_roll.roll_type )
      local roll = blue( winning_roll.roll )

      table.insert( content, { type = "text", value = string.format( "%s wins the %s roll with a %s.", player, roll_type, roll ), padding = 10 } )
    end

    table.insert( content, { type = "button", label = "Raid roll", width = 90, on_click = function() raid_roll( item_link ) end } )
    table.insert( content, { type = "button", label = "Close", width = 90, on_click = function() popup:Hide() end } )
    refresh( content )
  end

  local function on_cancel()
    seconds = 0

    local contents = item_and_rolls()
    table.insert( contents, { type = "text", value = "Rolling has been canceled.", padding = 10 } )
    table.insert( contents, { type = "button", label = "Close", width = 90, on_click = function() popup:Hide() end } )
    refresh( contents )
  end

  local function show()
    if popup then popup:Show() end
  end

  roll_tracker.subscribe( "start", on_start )
  roll_tracker.subscribe( "tick", on_tick )
  roll_tracker.subscribe( "roll", on_roll )
  roll_tracker.subscribe( "stop", on_stop )
  roll_tracker.subscribe( "cancel", on_cancel )

  return {
    show = show
  }
end

modules.RollingPopup = M
return M
