RollFor = RollFor or {}
local m = RollFor

if m.GuiElements then return end

local hl = m.colors.hl

---@class GuiElements
---@field item_link fun( parent: Frame ): Frame
---@field item_link_with_icon fun( parent: Frame, text: string ): Frame
---@field text fun( parent: Frame, text: string ): Frame
---@field icon fun( parent: Frame, show: boolean, width: number, height: number ): Frame
---@field icon_text fun( parent: Frame, text: string ): Frame
---@field roll fun( parent: Frame ): Frame
---@field button fun( parent: Frame ): Frame
---@field info fun( parent: Frame ): Frame
---@field dropped_item fun( parent: Frame, text: string ): Frame
---@field tiny_button fun( parent: Frame, text: string?, tooltip: string?, color: table?, font-size: number?):Frame
---@field titlebar fun( parent: Frame, title: string, on_close: function )

local M = {}

function M.create_text_in_container( type, parent, container_width, alignment, text, inner_field, font_type )
  local container = m.create_backdrop_frame( m.api, type, nil, parent )
  container:SetWidth( container_width )
  local label = container:CreateFontString( nil, "ARTWORK", font_type or "GameFontNormalSmall" )

  label:SetTextColor( 1, 1, 1 )
  if text then label:SetText( text ) end

  if alignment then label:SetPoint( alignment, 0, 0 ) end
  container:SetHeight( label:GetHeight() )

  if inner_field then
    container[ inner_field ] = label
  else
    container.inner = label
  end

  return container
end

function M.empty_line( parent )
  local result = m.api.CreateFrame( "Frame", nil, parent )
  result:SetWidth( 2 )

  return result
end

function M.item_link_with_icon( parent, text )
  local container = M.create_text_in_container( "Button", parent, 20, nil, nil, "text" )

  local w = 14
  local h = 14
  local spacing = 10
  local count = 0
  local texture
  local tooltip_link

  container:SetPoint( "TOP", 0, 0 )
  container.icon = M.icon( container, true, w, h )
  container.icon:SetPoint( "LEFT", 0, 0 )
  container.icon:SetTexCoord( 1 / w, (w - 1) / w, 1 / h, (h - 1) / h )
  container.count = M.text( container )
  container.text:SetTextColor( 1, 1, 1 )

  if text then
    container.text:SetText( text )
  else
    container.text:SetText( "PrincessKenny" )
  end

  container:SetHeight( container.text:GetHeight() )

  local function resize()
    if texture then
      container.icon:Show()

      local anchor = container.icon
      local padding = spacing
      local count_width = 0

      if count > 1 then
        container.count:Show()
        container.count:ClearAllPoints()
        container.count:SetPoint( "LEFT", container.icon, "RIGHT", spacing, 0 )
        anchor = container.count
        padding = 0
        count_width = container.count:GetWidth()
      end

      container.text:ClearAllPoints()
      container.text:SetPoint( "LEFT", anchor, "RIGHT", padding, 0 )
      container:SetWidth( container.text:GetWidth() + w + count_width + spacing )
    else
      local anchor = container
      local count_width = 0

      if count > 1 then
        container.count:Show()
        container.count:ClearAllPoints()
        container.count:SetPoint( "LEFT", container.icon, "RIGHT", spacing, 0 )
        anchor = container.count
        count_width = container.count:GetWidth()
      end

      container.icon:Hide()
      container.text:ClearAllPoints()
      container.text:SetPoint( "LEFT", anchor, 0, 0 )
      container:SetWidth( count_width + container.text:GetWidth() )
    end
  end

  container.SetItem = function( _, i, tt_link )
    texture = i.texture
    count = i.count or 0
    tooltip_link = tt_link

    container.text:SetText( i.link )
    container.icon:SetTexture( texture )
    container.count:SetText( count > 1 and hl( string.format( "%sx", count ) ) or nil )

    resize()
  end

  local function on_enter( self )
    if not tooltip_link then return end
    if m.vanilla then self = this end ---@diagnostic disable-line: undefined-global

    m.api.GameTooltip:SetOwner( self, "ANCHOR_CURSOR" )
    m.api.GameTooltip:SetHyperlink( tooltip_link )
    m.api.GameTooltip:Show()
  end

  local function on_leave()
    m.api.GameTooltip:Hide()
  end

  container:SetScript( "OnEnter", on_enter )
  container:SetScript( "OnLeave", on_leave )
  container:SetScript( "OnClick", function()
    if not tooltip_link then return end

    if m.is_ctrl_key_down() then
      m.api.DressUpItemLink( container.text:GetText() )
      return
    end

    if m.is_shift_key_down() then
      m.link_item_in_chat( container.text:GetText() )
    end
  end )

  return container
end

function M.text( parent, text )
  local label = parent:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )

  label:SetTextColor( 1, 1, 1 )
  label:SetNonSpaceWrap( false )

  if text then label:SetText( text ) end

  return label
end

function M.icon( parent, show, width, height )
  local icon = parent:CreateTexture( nil, "ARTWORK" )
  if not show then icon:Hide() end
  icon:SetWidth( width or 16 )
  icon:SetHeight( height or 16 )
  icon:SetTexture( "Interface\\AddOns\\RollFor\\assets\\icon-white2.tga" )

  return icon
end

function M.icon_text( parent, text )
  local container = M.create_text_in_container( "Button", parent, 20, nil, nil, "text" )

  container:SetPoint( "CENTER", 0, 0 )
  container.icon = M.icon( container, true )
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

function M.roll( parent )
  local frame = m.create_backdrop_frame( m.api, "Button", nil, parent )
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

  local roll_container = M.create_text_in_container( "Button", frame, 35, "RIGHT" )
  roll_container:SetPoint( "LEFT", 0, 0 )
  frame.roll = roll_container.inner

  local icon = M.icon( frame )
  icon:SetPoint( "LEFT", 22, 0 )
  frame.icon = icon

  roll_container:SetPoint( "LEFT", 0, 0 )
  frame.roll = roll_container.inner

  local player_name = M.text( frame )
  player_name:SetPoint( "CENTER", frame, "CENTER", 0, 0 )
  frame.player_name = player_name

  local roll_type_container = M.create_text_in_container( "Button", frame, 37, "LEFT" )
  roll_type_container:SetPoint( "RIGHT", 0, 0 )
  frame.roll_type = roll_type_container.inner

  return frame
end

function M.button( parent )
  local template = m.vanilla and "StaticPopupButtonTemplate" or "UIPanelButtonTemplate"
  local height = m.vanilla and 20 or 21

  local button = m.api.CreateFrame( "Button", nil, parent, template )
  button:SetWidth( 100 )
  button:SetHeight( height )
  button:SetText( "" )
  button:GetFontString():SetPoint( "CENTER", 0, -1 )

  return button
end

function M.award_button( parent )
  local template = m.vanilla and "StaticPopupButtonTemplate" or "UIPanelButtonTemplate"
  local height = m.vanilla and 20 or 21

  local button = m.api.CreateFrame( "Button", nil, parent, template )
  button:SetWidth( 100 )
  button:SetHeight( height )
  button:SetText( "" )
  button:GetFontString():SetPoint( "CENTER", 0, -1 )

  return button
end

---@param parent Frame
---@param text string?
---@param tooltip string?
---@param color string|table?
---@param font_size number?
function M.tiny_button( parent, text, tooltip, color, font_size )
  local font_x, font_y
  local button = m.api.CreateFrame( "Button", nil, parent )
  if not text then text = 'X' end

  if type( color ) == "string" and color ~= "" then
    local str_color = color
    color = {}
    color.r, color.g, color.b, color.a = m.hex_to_rgba( str_color )
  end

  if m.classic then
    if not color then color = { r = .9, g = .8, b = .25 } end
    button:SetWidth( 18 )
    button:SetHeight( 18 )

    local highlight_texture = button:CreateTexture( nil, "HIGHLIGHT" )
    highlight_texture:SetTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight" )
    highlight_texture:SetTexCoord( .1875, .78125, .21875, .78125 )
    highlight_texture:SetBlendMode( "ADD" )
    highlight_texture:SetAllPoints( button )

    if text == 'X' then
      button:SetNormalTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Up" )
      button:SetPushedTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Down" )
    else
      button:SetNormalTexture( "Interface\\AddOns\\RollFor\\assets\\tiny-button-up.tga" )
      button:SetPushedTexture( "Interface\\AddOns\\RollFor\\assets\\tiny-button-down.tga" )
    end
    button:GetNormalTexture():SetTexCoord( .1875, .78125, .21875, .78125 )
    button:GetPushedTexture():SetTexCoord( .1875, .78125, .21875, .78125 )

    if text ~= 'X' then
      button:SetText( text )
      button:SetPushedTextOffset( -1.5, -1.5 )

      if string.upper( text ) == text then
        font_x, font_y = 0, 0
        font_size = font_size or 13
      else
        font_x, font_y = -1, 2
        font_size = font_size or 15
      end
    end
  else
    if not color then color = { r = 1, g = .25, b = .25 } end
    button:SetBackdrop( {
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      tile = false,
      tileSize = 0,
      edgeSize = 0.5,
      insets = { left = 0, right = 0, top = 0, bottom = 0 }
    } )
    button:SetBackdropColor( 0, 0, 0, 1 )
    button:SetBackdropBorderColor( .2, .2, .2, 1 )
    button:SetHeight( 13 )
    button:SetWidth( 13 )
    button:SetText( text )
    button:SetPushedTextOffset( 0, 0 )

    if string.upper( text ) == text then
      font_x = text == "?" and -.5 or 0
      font_y = 0.5
      font_size = font_size or 10
    else
      font_x, font_y = -.5, 1.5
      font_size = font_size or 14
    end
  end

  if not m.classic or text ~= "X" then
    button:GetFontString():SetFont( "FONTS\\FRIZQT__.TTF", font_size )
    button:GetFontString():SetTextColor( color.r, color.g, color.b, color.a or 1 )
    button:GetFontString():SetPoint( "CENTER", font_x, font_y )
  end

  button:SetScript( "OnEnter", function()
    local self = button
    self:SetBackdropBorderColor( color.r, color.g, color.b, color.a or 1 )
    if tooltip then
      m.api.GameTooltip:SetOwner( button, "ANCHOR_RIGHT" )
      m.api.GameTooltip:SetText( tooltip )
      m.api.GameTooltip:SetScale( 0.8 )
      m.api.GameTooltip:Show()
    end
  end )
  button:SetScript( "OnLeave", function()
    local self = button
    if not self.active then
      self:SetBackdropBorderColor( .2, .2, .2, 1 )
    end
    if tooltip and m.api.GameTooltip:IsVisible() then
      m.api.GameTooltip:SetScale( 1 )
      m.api.GameTooltip:Hide()
    end
  end )

  return button
end

---@param parent Frame
---@param on_start function
---@param on_end function
function M.resize_grip( parent, on_start, on_end )
  local button = m.api.CreateFrame( "Button", nil, parent )
  button:SetWidth( 16 )
  button:SetHeight( 16 )
  button:SetNormalTexture( "Interface\\AddOns\\RollFor\\assets\\resize-grip.tga", "ARTWORK" )
  button:GetNormalTexture():SetAllPoints( button )

  button:SetScript( "OnEnter", function()
    button:GetNormalTexture():SetBlendMode( "ADD" )
  end )
  button:SetScript( "OnLeave", function()
    button:GetNormalTexture():SetBlendMode( "BLEND" )
  end )
  button:SetScript( "OnMouseDown", function()
    parent:StartSizing( "BOTTOMRIGHT" )
    if on_start then on_start( parent ) end
  end )
  button:SetScript( "OnMouseUp", function()
    parent:StopMovingOrSizing()
    if on_end then on_end( parent ) end
  end )

  return button
end

function M.checkbox( parent, text, on_change )
  local frame = m.api.CreateFrame( "Frame", nil, parent )
  frame:SetPoint( "LEFT", 5, 0 )
  frame:SetHeight( 14 )

  local cb = m.api.CreateFrame( "CheckButton", nil, frame, "UICheckButtonTemplate" )
  cb:SetWidth( 14 )
  cb:SetHeight( 14 )
  cb:SetPoint( "LEFT", 2, 0 )
  cb:SetNormalTexture( nil )
  cb:SetPushedTexture( nil )
  cb:SetHighlightTexture( nil )
  cb:SetBackdrop( {
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Buttons/WHITE8x8",
    edgeSize = 0.5,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
  } )
  cb:SetBackdropColor( 0, 0, 0, 1 )
  cb:SetBackdropBorderColor( .2, .2, .2, 1 )
  cb:SetScript( "OnClick", function()
    if on_change then on_change( cb:GetChecked() ) end
  end )
  frame.checkbox = cb

  local label = M.create_text_in_container( "Button", frame, 1, "LEFT", text )
  label.inner:SetJustifyH( "LEFT" )
  label:SetWidth( label.inner:GetWidth() )
  label:SetPoint( "LEFT", cb, "RIGHT", 5, 0 )
  label:SetScript( "OnClick", function()
    cb:SetChecked( not cb:GetChecked() )
    if on_change then on_change( cb:GetChecked() ) end
  end )

  frame:SetWidth( cb:GetWidth() + label:GetWidth() + 5 )

  return frame
end

---@param parent Frame
---@param title string
---@param on_close function
function M.titlebar( parent, title, on_close )
  local frame = m.api.CreateFrame( "Frame", nil, parent )
  frame:SetHeight( 32 )
  if not m.classic then
    frame:SetPoint( "TOPLEFT", 0, 5 )
    frame:SetPoint( "RIGHT", 0, 0 )
  else
    frame:SetPoint( "TOPLEFT", 3, 2 )
    frame:SetPoint( "RIGHT", -3, 2 )
    frame:SetBackdrop( {
      bgFile = "Interface\\AddOns\\RollFor\\assets\\titlebar-top.tga",
      tile = true,
      tileSize = 32,
      edgeSize = 0,
      insets = { left = 30, right = 30, top = 0, bottom = 0 }
    } )

    local topLeft = frame:CreateTexture( nil, "BORDER" )
    topLeft:SetTexture( "Interface\\AddOns\\RollFor\\assets\\titlebar-topleft.tga" )
    topLeft:SetPoint( "TOPLEFT", frame, "TOPLEFT", 0, 0 )
    topLeft:SetWidth( 64 )
    topLeft:SetHeight( 32 )

    local topRight = frame:CreateTexture( nil, "BORDER" )
    topRight:SetTexture( "Interface\\AddOns\\RollFor\\assets\\titlebar-topright.tga" )
    topRight:SetPoint( "TOPRIGHT", frame, "TOPRIGHT", 0, 0 )
    topRight:SetWidth( 64 )
    topRight:SetHeight( 32 )
  end

  local label = frame:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
  label:SetPoint( "TOPLEFT", 0, -12 )
  label:SetPoint( "RIGHT", m.classic and -19 or 0, 0 )
  label:SetJustifyH( "CENTER" )
  label:SetTextColor( 1, 1, 1 )
  label:SetText( title )

  local btn_close = M.tiny_button( parent, "X", "Close Window" )
  btn_close:SetPoint( "TOPRIGHT", m.classic and -7 or -5, m.classic and -5 or -5 )
  btn_close:SetScript( "OnClick", function()
    if on_close then
      on_close()
    else
      if parent then parent:Hide() end
    end
  end )

  return frame
end

function M.info( parent )
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

  frame:SetScript( "OnEnter", function( self )
    if m.vanilla then self = this end ---@diagnostic disable-line: undefined-global

    self.tooltip_scale = m.api.GameTooltip:GetScale()
    m.api.GameTooltip:SetOwner( self, "ANCHOR_CURSOR" )
    m.api.GameTooltip:AddLine( frame.tooltip_info, 1, 1, 1 )
    m.api.GameTooltip:SetScale( 0.75 )
    m.api.GameTooltip:Show()
  end )

  frame:SetScript( "OnLeave", function( self )
    if m.vanilla then self = this end ---@diagnostic disable-line: undefined-global

    m.api.GameTooltip:Hide()
    m.api.GameTooltip:SetScale( self.tooltip_scale or 1 )
  end )

  return frame
end

function M.create_icon_in_container( type, parent, w, h, icon_zoom )
  local result = m.create_backdrop_frame( m.api, type or "Button", nil, parent )
  result:SetWidth( w + 1 )
  result:SetHeight( h )

  result:SetBackdrop( {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    tileSize = 0,
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 }
  } )

  result:SetBackdropBorderColor( 0, 0, 0, 1 )
  result:SetBackdropColor( 0, 0, 0, 0 )

  result.texture = M.icon( result, true, w, h )
  result.texture:SetPoint( "CENTER", 0, 0 )
  result.texture:SetTexCoord( icon_zoom / w, (w - icon_zoom) / w, icon_zoom / h, (h - icon_zoom) / h )

  return result
end

m.GuiElements = M
return M
