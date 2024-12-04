---@diagnostic disable-next-line: undefined-global
local modules = LibStub( "RollFor-Modules" )
if modules.RollingPopup then return end

local m = modules
local c = m.colorize_player_by_class
local blue = m.colors.blue

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

local M = {}

function M.new( custom_popup_builder, db, config )
  local popup

  local function create_item( parent )
    local result = m.api.CreateFrame( "Button", nil, parent )

    result.text = result:CreateFontString( nil, "ARTWORK", "GameFontNormal" )
    result.text:SetPoint( "TOP", 0, 0 )
    result.text:SetText( "PrincessKenny" )
    result:SetHeight( result.text:GetHeight() )

    result:SetScript( "OnEnter", function()
      ---@diagnostic disable-next-line: undefined-global
      local self = this
      m.api.GameTooltip:SetOwner( self, "ANCHOR_CURSOR" )
      m.api.GameTooltip:SetHyperlink( result.tooltip_link )
      m.api.GameTooltip:Show()
    end )

    result:SetScript( "OnLeave", function()
      m.api.GameTooltip:Hide()
    end )

    return result
  end

  local function create_text_in_container( parent, container_width, alignment, text, inner_field )
    local container = m.api.CreateFrame( "Frame", nil, parent )
    container:SetWidth( container_width )
    local frame = container:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )

    frame:SetTextColor( 1, 1, 1 )
    if text then frame:SetText( text ) end

    if alignment then frame:SetPoint( alignment, 0, 0 ) end
    container:SetHeight( frame:GetHeight() )

    if inner_field then
      container[ inner_field ] = frame
    else
      container.inner = frame
    end

    return container
  end

  local function create_text( parent, text )
    local result = parent:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )

    result:SetTextColor( 1, 1, 1 )
    if text then result:SetText( text ) end

    return result
  end

  local function create_icon( parent, show )
    local icon = parent:CreateTexture( nil, "BACKGROUND" )
    if not show then icon:Hide() end
    icon:SetWidth( 16 )
    icon:SetHeight( 16 )
    icon:SetTexture( "Interface\\AddOns\\RollFor\\assets\\icon-white2.tga" )

    return icon
  end

  local function create_icon_text( parent, text )
    local container = create_text_in_container( parent, 20, nil, nil, "text" )

    container:SetPoint( "CENTER", 0, 0 )
    container.icon = create_icon( container, true )
    container.icon:SetPoint( "LEFT", 0, 0 )
    container.text:SetPoint( "LEFT", container.icon, "RIGHT", 3, 0 )
    container.text:SetTextColor( 1, 1, 1 )

    if text then container.text:SetText( text ) end

    container.SetText = function( _, v )
      container.text:SetText( v )
      container:SetWidth( container.text:GetWidth() + 19 )
    end

    return container
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

    local roll_container = create_text_in_container( frame, 35, "RIGHT" )
    roll_container:SetPoint( "LEFT", 0, 0 )
    frame.roll = roll_container.inner

    local icon = create_icon( frame )
    icon:SetPoint( "LEFT", 22, 0 )
    frame.icon = icon

    roll_container:SetPoint( "LEFT", 0, 0 )
    frame.roll = roll_container.inner

    local player_name = create_text( frame )
    player_name:SetPoint( "CENTER", frame, "CENTER", 0, 0 )
    frame.player_name = player_name

    local roll_type_container = create_text_in_container( frame, 37, "LEFT" )
    roll_type_container:SetPoint( "RIGHT", 0, 0 )
    frame.roll_type = roll_type_container.inner

    return frame
  end

  local function create_button( parent )
    local button = m.api.CreateFrame( "Button", nil, parent, "StaticPopupButtonTemplate" )
    button:SetWidth( 100 )
    button:SetHeight( 20 )
    button:SetText( "" )
    button:GetFontString():SetPoint( "CENTER", 0, -1 )

    return button
  end

  local function create_info( parent )
    local frame = m.api.CreateFrame( "Frame", nil, parent )
    frame:SetWidth( 11 )
    frame:SetHeight( 11 )
    frame:SetFrameStrata( "DIALOG" )
    frame:SetFrameLevel( parent:GetFrameLevel() + 1 )
    frame:EnableMouse( true )

    local icon = frame:CreateTexture( nil, "BACKGROUND" )
    icon:SetWidth( 11 )
    icon:SetHeight( 11 )
    icon:SetTexture( "Interface\\AddOns\\RollFor\\assets\\info.tga" )
    icon:SetPoint( "CENTER", 0, 0 )

    frame:SetScript( "OnEnter", function()
      ---@diagnostic disable-next-line: undefined-global
      local self = this
      self.tooltip_scale = m.api.GameTooltip:GetScale()
      m.api.GameTooltip:SetOwner( self, "ANCHOR_NONE" )
      m.api.GameTooltip:AddLine( frame.tooltip_info, 1, 1, 1 )
      m.api.GameTooltip:SetScale( 0.75 )
      m.api.GameTooltip:ClearAllPoints()
      m.api.GameTooltip:SetPoint( "BOTTOMLEFT", frame, "TOPRIGHT", -90, 0 )
      m.api.GameTooltip:Show()
    end )

    frame:SetScript( "OnLeave", function()
      ---@diagnostic disable-next-line: undefined-global
      local self = this
      m.api.GameTooltip:Hide()
      m.api.GameTooltip:SetScale( self.tooltip_scale or 1 )
    end )

    return frame
  end

  local frame_creators = {
    [ "item" ] = create_item,
    [ "text" ] = create_text,
    [ "icon_text" ] = create_icon_text,
    [ "roll" ] = create_roll,
    [ "button" ] = create_button,
    [ "info" ] = create_info
  }

  local function create_popup()
    local center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 150 }
    local function is_out_of_bounds( point, x, y, frame_width, frame_height, screen_width, screen_height )
      local left, right, top, bottom
      local width = frame_width / 2
      local height = frame_height / 2

      if point == "TOPLEFT" then
        left = x - width
        right = x + width
        top = y + height
        bottom = y - height
      elseif point == "TOPRIGHT" then
        left = x - width
        right = x + width
        top = y + height
        bottom = y - height
      elseif point == "BOTTOMLEFT" then
        left = x - width
        right = x + width
        top = y + height
        bottom = y - height
      elseif point == "BOTTOMRIGHT" then
        left = x - width
        right = x + width
        top = y + height
        bottom = y - height
      else
        return false
      end

      return left < 0 or
          right > screen_width or
          top > 0 or
          bottom < -screen_height
    end

    local function on_drag_stop()
      local width, height = popup:GetWidth(), popup:GetHeight()
      local screen_width, screen_height = m.api.GetScreenWidth(), m.api.GetScreenHeight()
      local point, _, _, x, y = popup:get_anchor_point()

      if is_out_of_bounds( point, x, y, width, height, screen_width, screen_height ) then
        db.point = center_point
        popup:position( center_point )

        return
      end

      local anchor_point, _, anchor_relative_point, anchor_x, anchor_y = popup:get_anchor_point()
      db.point = { point = anchor_point, relative_point = anchor_relative_point, x = anchor_x, y = anchor_y }
    end

    local function get_point()
      if popup then
        local width, height = popup:GetWidth(), popup:GetHeight()
        local screen_width, screen_height = m.api.GetScreenWidth(), m.api.GetScreenHeight()
        local x, y = popup:get_anchor_center()

        if is_out_of_bounds( x, y, width, height, screen_width, screen_height ) then
          return center_point
        end
      elseif db.point then
        return db.point
      else
        return center_point
      end
    end

    local builder = custom_popup_builder()
        :with_name( "RollForRollingFrame" )
        :with_width( 180 )
        :with_height( 100 )
        :with_point( get_point() )
        :with_bg_file( "Interface/Buttons/WHITE8x8" )
        :with_sound()
        :with_esc()
        :with_backdrop_color( 0, 0, 0, 0.6 )
        :with_creators( frame_creators )
        :with_frame_style( "PrincessKenny" )
        :with_on_drag_stop( on_drag_stop )

    popup = builder:build()

    if config.rolling_popup_locked() then
      popup:lock()
    else
      popup:unlock()
    end

    config.subscribe( "rolling_popup_lock", function( enabled )
      if enabled then
        popup:lock()
      else
        popup:unlock()
      end
    end )

    config.subscribe( "reset_rolling_popup", function()
      db.point = nil
      popup:position( center_point )
    end )
  end

  local function refresh( _, content )
    if not popup then return end
    popup:clear()

    for _, v in ipairs( content ) do
      popup.add_line( v.type, function( type, frame )
        if type == "item" then
          frame.text:SetText( v.link )
          frame:SetWidth( frame.text:GetWidth() )
          frame.tooltip_link = v.link and m.ItemUtils.get_tooltip_link( v.link )
        elseif type == "text" then
          frame:SetText( v.value )
        elseif type == "icon_text" then
          frame:SetText( v.value )
        elseif type == "roll" then
          frame.roll_type:SetText( m.roll_type_color( v.roll_type, m.roll_type_abbrev( v.roll_type ) ) )
          frame.player_name:SetText( c( v.player_name, v.player_class ) )

          if v.roll then
            frame.roll:SetText( blue( v.roll ) )
            frame.icon:Hide()
          else
            frame.roll:SetText( "" )
            frame.icon:Show()
          end

          -- local player_name = v.player_name

          frame:SetScript( "OnClick", function()
            -- if selected_frame then selected_frame:deselect() end
            -- frame:select()
            -- selected_frame = frame
            -- print( player_name )
          end )
        elseif type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )
        elseif type == "info" then
          print( frame:IsVisible() and "yes" or "no" )
          frame.tooltip_info = v.tip
          frame:ClearAllPoints()
          frame:SetPoint( "TOPRIGHT", v.anchor, "TOPRIGHT", -10, -10 )
        end
      end, v.padding )
    end
  end

  local function show()
    if not popup then
      create_popup()
    else
      popup:clear()
    end

    popup:Show()
  end

  local function hide()
    popup:Hide()
  end

  local function border_color( _, r, g, b, a )
    if not popup then
      create_popup()
    end

    popup:border_color( r, g, b, a )
  end

  return {
    show = show,
    refresh = refresh,
    hide = hide,
    border_color = border_color
  }
end

m.RollingPopup = M
return M
