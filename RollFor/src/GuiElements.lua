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
    if m.vanilla then self = this end

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
---@param color table?
---@param font_size number?
function M.tiny_button( parent, text, tooltip, color, font_size )
  local button = m.api.CreateFrame( "Button", nil, parent )
  if not text then text = 'x' end

  if m.classic then
    if not color then color = { r = .9, g = .8, b = .25 } end
    button:SetWidth( 18 )
    button:SetHeight( 18 )

    local highlight_texture = button:CreateTexture( nil, "HIGHLIGHT" )
    highlight_texture:SetTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight" )
    highlight_texture:SetTexCoord( .1875, .78125, .21875, .78125 )
    highlight_texture:SetBlendMode( "ADD" )
    highlight_texture:SetAllPoints( button )

    if text == 'x' then
      button:SetNormalTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Up" )
      button:SetPushedTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Down" )
    else
      button:SetNormalTexture( "Interface\\AddOns\\RollFor\\assets\\tiny-button-up.tga" )
      button:SetPushedTexture( "Interface\\AddOns\\RollFor\\assets\\tiny-button-down.tga" )
    end
    button:GetNormalTexture():SetTexCoord( .1875, .78125, .21875, .78125 )
    button:GetPushedTexture():SetTexCoord( .1875, .78125, .21875, .78125 )

    if text ~= 'x' then
      button:SetText( text )
      button:SetPushedTextOffset( -1.5, -1.5 )

      if string.upper( text ) == text then
        button:GetFontString():SetPoint( "CENTER", 0, 0 )
        font_size = font_size or 13
      else
        button:GetFontString():SetPoint( "CENTER", -1, 2 )
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
    button:SetHeight( 10 )
    button:SetWidth( 10 )
    button:SetText( text )
    button:SetPushedTextOffset( 0, 0 )
    if string.upper( text ) == text then
      button:GetFontString():SetPoint( "CENTER", 0, 0 )
      font_size = font_size or 10
    else
      button:GetFontString():SetPoint( "CENTER", 0, 1.5 )
      font_size = font_size or 14
    end
  end

  if not m.classic or text ~= "x" then
    button:GetFontString():SetFont( "FONTS\\FRIZQT__.TTF", font_size )
    button:GetFontString():SetTextColor( color.r, color.g, color.b, color.a or 1 )
  end

  button:SetScript( "OnEnter", function()
    this:SetBackdropBorderColor( color.r, color.g, color.b, color.a or 1 )
    if tooltip then
      m.api.GameTooltip:SetOwner( this, "ANCHOR_RIGHT" )
      m.api.GameTooltip:SetText( tooltip )
      m.api.GameTooltip:SetScale( 0.8 )
      m.api.GameTooltip:Show()
    end
  end )
  button:SetScript( "OnLeave", function()
    this:SetBackdropBorderColor( .2, .2, .2, 1 )
    if tooltip then
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
  button.texture = button:CreateTexture()
  button.texture:SetTexture( "Interface\\AddOns\\RollFor\\assets\\resize-grip.tga", "ARTWORK" )
  button.texture:ClearAllPoints()
  button.texture:SetAllPoints( button )

  button:SetScript( "OnEnter", function()
    this.texture:SetBlendMode( "ADD" )
  end )
  button:SetScript( "OnLeave", function()
    this.texture:SetBlendMode( "BLEND" )
  end )
  button:SetScript( "OnMouseDown", function()
    this:GetParent():StartSizing( "BOTTOMRIGHT" )
    if on_start then on_start() end
  end )
  button:SetScript( "OnMouseUp", function()
    this:GetParent():StopMovingOrSizing()
    if on_end then on_end() end
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
  cb:SetNormalTexture( "" )
  cb:SetPushedTexture( "" )
  cb:SetHighlightTexture( "" )
  cb:SetBackdrop( {
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Buttons/WHITE8x8",
    tile = false,
    tileSize = 0,
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
  label:SetTextColor( 1, 1, 1 )
  label:SetText( title )

  local btn_close = M.tiny_button( parent, "x", "Close Window" )
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

function M.winners_header( parent, on_click )
  local frame = m.api.CreateFrame( "Frame", nil, parent )
  frame:SetWidth( 250 )
  frame:SetHeight( 14 )
  frame:SetFrameStrata( "DIALOG" )
  frame:SetFrameLevel( parent:GetFrameLevel() + 1 )
  frame:EnableMouse( true )

  ---@diagnostic disable-next-line: undefined-global
  local font_file = pfUI and pfUI.version and pfUI.font_default or "FONTS\\ARIALN.TTF"
  local font_size =  11

  local headers = {
    { text = "Player", name = "player_name",  width = 74 },
    { text = "Item",   name = "item_id",      width = 150 },
    { text = "Roll",   name = "winning_roll", width = 25 },
    { text = "Type",   name = "roll_type",    width = 25 }
  }

  for _, v in pairs( headers ) do
    local header = M.create_text_in_container( "Button", frame, v.width, nil, v.text )
    header.inner:SetFont( font_file, font_size )
    header.sort = v.name
    header:SetHeight( 14 )
    header.inner:SetPoint( v.name == "winning_roll" and "RIGHT" or "LEFT", v.name == "winning_roll" and -5 or 2, 0 )
    header:SetBackdrop( {
      bgFile = "Interface/Buttons/WHITE8x8",
      tile = true,
      tileSize = 22,
    } )
    header:SetBackdropColor( 0.125, 0.624, 0.976, 0.4 )
    header:SetScript( "OnClick", on_click )
    frame[ v.name .. "_header" ] = header
  end

  frame.player_name_header:SetPoint( "LEFT", 0, 0 )
  frame.roll_type_header:SetPoint( "RIGHT", 0, 0 )
  frame.winning_roll_header:SetPoint( "RIGHT", frame.roll_type_header, "LEFT", -1, 0 )
  frame.item_id_header:SetPoint( "LEFT", frame.player_name_header, "RIGHT", 1, 0 )
  frame.item_id_header:SetPoint( "RIGHT", frame.winning_roll_header, "LEFT", -1, 0 )

  return frame
end

function M.winner( parent )
  local frame = m.api.CreateFrame( "Button", nil, parent )
  frame:SetWidth( 250 )
  frame:SetHeight( 14 )
  frame:SetPoint( "LEFT", parent:GetParent(), "LEFT", 0, 0 )
  frame:SetPoint( "RIGHT", parent:GetParent(), "RIGHT", -13, 0 )
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

  blue_hover( 0 )
  frame:SetScript( "OnEnter", function()
    blue_hover( 0.2 )
  end )

  frame:SetScript( "OnLeave", function()
    blue_hover( 0 )
  end )

  ---@diagnostic disable-next-line: undefined-global
  local font_file = pfUI and pfUI.version and pfUI.font_default or "FONTS\\ARIALN.TTF"
  local font_size = 11

  local player_name = M.create_text_in_container( "Frame", frame, 74, "LEFT", "dummy" )
  player_name.inner:SetFont( font_file, font_size )
  player_name.inner:SetJustifyH( "LEFT" )
  player_name:SetPoint( "LEFT", frame, "LEFT", 2, 0 )
  player_name:SetHeight( 14 )
  frame.player_name = player_name.inner

  local roll_type = M.create_text_in_container( "Frame", frame, 25, nil, "dummy" )
  roll_type.inner:SetFont( font_file, font_size )
  roll_type.inner:SetJustifyH( "LEFT" )
  roll_type.inner:SetPoint( "LEFT", 5, 0 )
  roll_type:SetPoint( "RIGHT", 0, 0 )
  roll_type:SetHeight( 14 )
  frame.roll_type = roll_type.inner

  local winning_roll = M.create_text_in_container( "Frame", frame, 25, nil, "dummy" )
  winning_roll.inner:SetFont( font_file, font_size )
  winning_roll.inner:SetJustifyH( "RIGHT" )
  winning_roll.inner:SetPoint( "RIGHT", -5, 0 )
  winning_roll:SetPoint( "RIGHT", roll_type, "LEFT", -1, 0 )
  winning_roll:SetHeight( 14 )
  frame.winning_roll = winning_roll.inner

  local tooltip_link
  local item_link = M.create_text_in_container( "Button", frame, 1, "LEFT", "dummy" )
  item_link.inner:SetFont( font_file, font_size )
  item_link.inner:SetJustifyH( "LEFT" )
  item_link:SetPoint( "LEFT", player_name, "RIGHT", 1, 0 )
  item_link:SetPoint( "RIGHT", winning_roll, "LEFT", -1, 0 )
  item_link:SetHeight( item_link.inner:GetHeight() )
  frame.item_link = item_link

  frame.SetItem = function( _, itemLink )
    local function truncate_text( font_string, max )
      local item = font_string:GetText()
      local originalText = string.gsub( m.ItemUtils.get_item_name( font_string:GetText() ), "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1" )
      local truncatedText = originalText

      while font_string:GetStringWidth() > max do
        truncatedText = string.sub( truncatedText, 1, -2 )
        font_string:SetText( "[" .. truncatedText .. "...]" )
        if string.len( truncatedText ) < 4 then break end
      end

      if originalText == truncatedText then
        font_string:SetText( string.gsub( item, originalText, truncatedText ) )
      else
        font_string:SetText( string.gsub( item, originalText, truncatedText .. "..." ) )
      end
    end

    item_link.inner:SetText( itemLink )
    truncate_text( item_link.inner, frame:GetParent():GetParent():GetParent():GetWidth() - 145 - winning_roll:GetWidth() )

    tooltip_link = m.ItemUtils.get_tooltip_link( itemLink )

    item_link:SetScript( "OnEnter", function()
      blue_hover( 0.2 )
    end )

    item_link:SetScript( "OnLeave", function()
      blue_hover( 0 )
    end )

    item_link:SetScript( "OnClick", function()
      if not tooltip_link then return end

      if m.is_ctrl_key_down() then
        m.api.DressUpItemLink( itemLink )
        return
      end

      if m.is_shift_key_down() then
        m.link_item_in_chat( itemLink )
        return
      end

      m.api.SetItemRef( tooltip_link, tooltip_link, "LeftButton" )
    end )
  end

  return frame
end

function M.create_scroll_frame( parent, name )
  local f = m.api.CreateFrame( "ScrollFrame", name, parent )

  f.slider = m.api.CreateFrame( "Slider", nil, f )
  f.slider:SetOrientation( 'VERTICAL' )
  f.slider:SetPoint( "TOPLEFT", f, "TOPRIGHT", m.classic and -13 or -7, 0 )
  f.slider:SetPoint( "BOTTOMRIGHT", 0, 0 )
  f.slider:SetThumbTexture( "Interface\\AddOns\\RollFor\\assets\\col.tga" )
  f.slider.thumb = f.slider:GetThumbTexture()
  f.slider.thumb:SetHeight( 50 )
  f.slider.thumb:SetTexture( .125, .624, .976, .5 )

  f.slider:SetScript( "OnValueChanged", function()
    f:SetVerticalScroll( this:GetValue() )
    f.update_scroll_state()
  end )

  f.update_scroll_state = function()
    f.slider:SetMinMaxValues( 0, f:GetVerticalScrollRange() )
    f.slider:SetValue( f:GetVerticalScroll() )

    local r = f:GetHeight() + f:GetVerticalScrollRange()
    local v = f:GetHeight()
    local ratio = v / r

    if ratio < 1 then
      local size = math.floor( v * ratio )
      f.slider.thumb:SetHeight( size )
      f.slider:Show()
    else
      f.slider:Hide()
    end
  end

  f.scroll = function( self, step )
    step = step or 0

    local current = f:GetVerticalScroll()
    local max = f:GetVerticalScrollRange()
    local new = current - step

    if new >= max then
      f:SetVerticalScroll( max )
    elseif new <= 0 then
      f:SetVerticalScroll( 0 )
    else
      f:SetVerticalScroll( new )
    end

    f:update_scroll_state()
  end

  f:EnableMouseWheel( 1 )
  f:SetScript( "OnMouseWheel", function()
    this:scroll( arg1 * 10 )
  end )

  return f
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
    if m.vanilla then self = this end

    self.tooltip_scale = m.api.GameTooltip:GetScale()
    m.api.GameTooltip:SetOwner( self, "ANCHOR_CURSOR" )
    m.api.GameTooltip:AddLine( frame.tooltip_info, 1, 1, 1 )
    m.api.GameTooltip:SetScale( 0.75 )
    m.api.GameTooltip:Show()
  end )

  frame:SetScript( "OnLeave", function( self )
    if m.vanilla then self = this end

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
