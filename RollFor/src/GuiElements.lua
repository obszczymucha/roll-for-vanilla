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

local M = {}

local function create_text_in_container( type, parent, container_width, alignment, text, inner_field )
  local container = m.create_backdrop_frame( m.api, type, nil, parent )
  container:SetWidth( container_width )
  local label = container:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )

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
  local container = create_text_in_container( "Button", parent, 20, nil, nil, "text" )

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
  local container = create_text_in_container( "Button", parent, 20, nil, nil, "text" )

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

  local roll_container = create_text_in_container( "Button", frame, 35, "RIGHT" )
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

  local roll_type_container = create_text_in_container( "Button", frame, 37, "LEFT" )
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

local function create_icon_in_container( type, parent, w, h, icon_zoom )
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

---@param parent Frame
function M.dropped_item( parent )
  local container = m.create_loot_button( m.api, parent )

  local w = 22
  local h = 22
  local spacing = 6
  local bind_spacing = 3
  local mouse_down = false
  local icon_zoom = 2

  local item

  container:SetHeight( h )
  container.name = create_text_in_container( "Frame", container, 20, "LEFT", nil, "text" )
  container.name.text:SetJustifyH( "LEFT" )
  container.name.text:SetTextColor( 1, 1, 1 )
  container.index = create_text_in_container( "Frame", container, 20, "CENTER", nil, "text" )
  container.index:SetPoint( "LEFT", 1, 0 )
  container.index:SetWidth( 16 )
  container.index:SetHeight( h )
  container.icon = create_icon_in_container( "Button", container, w, h, icon_zoom )
  container.icon:SetPoint( "LEFT", container.index, "RIGHT", 2, 0 )
  container.quantity = create_text_in_container( "Frame", container.icon, 20, "CENTER", nil, "text" )
  container.quantity:SetPoint( "BOTTOMRIGHT", -2, -1 )
  container.quantity:SetHeight( 16 )
  container.bind = create_text_in_container( "Frame", container, 15, "LEFT", nil, "text" )
  container.bind:SetPoint( "LEFT", container.icon, "RIGHT", 5, 0 )
  container.comment = create_text_in_container( "Button", container, 20, "CENTER", nil, "text" )
  container.comment:SetPoint( "RIGHT", -4, 0 )
  container.comment:SetHeight( 16 )

  local function resize()
    container.icon:Show()

    local index_width = container.index:GetWidth() + 1
    local icon_width = container.icon:GetWidth() + spacing
    local bind_width = item.bind and (container.bind:GetWidth() + bind_spacing) or 0
    local text_width = container.name.text:GetStringWidth() + spacing + 1
    local comment_width = container.comment:IsVisible() and container.comment:GetWidth() + spacing or 0

    local total_width = index_width + icon_width + bind_width + text_width + comment_width

    container:SetWidth( total_width )
    container:SetPoint( "LEFT", 0, 0 )
    container:SetPoint( "RIGHT", 0, 0 )
  end

  local function get_color( multiplier )
    local mult = multiplier or 1
    local color = m.api.ITEM_QUALITY_COLORS[ item.quality or 0 ]
    return color.r * mult, color.g * mult, color.b * mult
  end

  local function hovered_color()
    if not item then return end
    if item.is_selected then return end
    local r, g, b = get_color()
    container:SetBackdropColor( r, g, b, 0.3 )
  end

  local function clicked_color()
    local r, g, b = get_color()
    container:SetBackdropColor( r, g, b, 0.4 )
  end

  local function selected_color()
    if not item then return end
    local r, g, b = get_color()
    container:SetBackdropColor( r, g, b, 0.3 )
  end

  local function not_hovered_color()
    if not item or item.is_selected then return end
    container:SetBackdropColor( 0, 0, 0, 0.1 )
  end

  local function update()
    if not item then return end

    if not item.is_enabled then
      container:SetAlpha( 0.6 )
      return
    end

    if item.is_selected then
      selected_color()
    else
      not_hovered_color()
    end

    container:SetAlpha( 1 )
  end

  ---@param v LootFrameItem
  container.SetItem = function( _, v )
    item = v
    container.index.text:SetText( v.index )
    container.icon.texture:SetTexture( v.texture )
    container.name.text:SetText( m.colorize_item_by_quality( v.name, v.quality ) )

    if v.bind then
      container.bind.text:SetText( v.bind )
      container.bind:SetWidth( container.bind.text:GetStringWidth() )
      container.bind:Show()
      container.name:SetPoint( "LEFT", container.bind, "RIGHT", bind_spacing, 0 )
    else
      container.bind:Hide()
      container.name:SetPoint( "LEFT", container.icon, "RIGHT", spacing, 0 )
    end

    if v.comment then
      container.comment.text:SetText( v.comment )
      container.comment:Show()
      container.name:SetPoint( "RIGHT", container.comment, "LEFT", 0, 0 )
    else
      container.comment:Hide()
      container.name:SetPoint( "RIGHT", container, "RIGHT", 0, 0 )
    end

    if v.quantity and v.quantity > 1 then
      container.quantity:Show()
      container.quantity.text:SetText( v.quantity )
      container.quantity:SetWidth( container.quantity.text:GetStringWidth() )
    else
      container.quantity:Hide()
    end

    local function modifier_fn()
      if m.is_ctrl_key_down() then
        m.api.DressUpItemLink( v.link )
        return
      end

      if m.is_shift_key_down() then
        m.link_item_in_chat( v.link )
        return
      end
    end

    container:SetScript( "OnClick", v.is_enabled and not v.is_selected and v.click_fn or modifier_fn )
    container.icon:SetScript( "OnClick", v.is_enabled and not v.is_selected and v.click_fn or modifier_fn )
    container.comment:SetScript( "OnClick", v.is_enabled and not v.is_selected and v.click_fn or modifier_fn )

    if m.vanilla then
      -- Fucking hell this took forever to figure out. Fuck you Blizzard.
      -- For looting to work in vanilla, the frame must be of a "LootButton" type and
      -- then it comes with the SetSlot function that we need to use to set the slot.
      -- This will probably be a pain in the ass when porting.
      container:SetSlot( v.slot or 0 )
    end

    update()
    resize()
  end

  local function on_enter( self )
    if m.vanilla then self = this end

    if not item then return end
    if item.tooltip_link then
      m.api.GameTooltip:SetOwner( self, "ANCHOR_RIGHT" )
      m.api.GameTooltip:SetHyperlink( item.tooltip_link )
      m.api.GameTooltip:Show()
    end

    if not item.is_enabled then return end
    hovered_color()
  end

  container:SetBackdrop( {
    bgFile = "Interface/Buttons/WHITE8x8",
    tile = false,
    tileSize = 0,
  } )

  not_hovered_color()

  local function on_leave()
    m.api.GameTooltip:Hide()
    mouse_down = false
    not_hovered_color()
  end

  container.comment:SetScript( "OnEnter", function( self )
    if not item then return end
    if item.comment_tooltip then
      if m.vanilla then self = this end

      self.tooltip_scale = m.api.GameTooltip:GetScale()
      m.api.GameTooltip:SetOwner( self, "ANCHOR_RIGHT" )

      local result = ""

      for _, line in ipairs( item.comment_tooltip ) do
        if result ~= "" then result = result .. "\n" end
        result = result .. line
      end

      m.api.GameTooltip:AddLine( result, 1, 1, 1 )
      m.api.GameTooltip:SetScale( 0.9 )
      m.api.GameTooltip:Show()
    end

    if not item.is_enabled then return end
    hovered_color()
  end )

  container.comment:SetScript( "OnLeave", function( self )
    if m.vanilla then self = this end

    m.api.GameTooltip:Hide()
    m.api.GameTooltip:SetScale( self.tooltip_scale or 1 )
    mouse_down = false

    not_hovered_color()
  end )

  container.icon:SetScript( "OnEnter", on_enter )
  container.icon:SetScript( "OnLeave", on_leave )

  container:SetScript( "OnEnter", on_enter )
  container:SetScript( "OnLeave", on_leave )

  local function on_mouse_down()
    if not item then return end
    if not item.is_enabled or item.is_selected then return end

    mouse_down = true
    clicked_color()
  end

  local function on_mouse_up()
    if not item then return end
    if not item.is_enabled or item.is_selected then return end

    if not mouse_down then return end
    hovered_color()
  end

  container:SetScript( "OnMouseUp", on_mouse_up )
  container:SetScript( "OnMouseDown", on_mouse_down )
  container.icon:SetScript( "OnMouseUp", on_mouse_up )
  container.icon:SetScript( "OnMouseDown", on_mouse_down )

  container:SetScript( "OnShow", function()
    mouse_down = false
  end )

  return container
end

m.GuiElements = M
return M
