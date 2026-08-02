RollFor = RollFor or {}
local m = RollFor

if m.GuiElements then return end

local hl = m.colors.hl

---@class GuiElements
---@field item_link fun( parent: Frame ): Frame
---@field item_link_with_icon fun( parent: Frame, text: string, spacing: number? ): Frame
---@field text fun( parent: Frame, text: string ): Frame
---@field icon fun( parent: Frame, show: boolean, width: number, height: number ): Frame
---@field icon_text fun( parent: Frame, text: string ): Frame
---@field roll fun( parent: Frame ): Frame
---@field button fun( parent: Frame ): Frame
---@field info fun( parent: Frame ): Frame
---@field dropped_item fun( parent: Frame, text: string ): Frame
---@field checkbox fun( parent: Frame ): Frame
---@field slider fun( parent: Frame ): Frame
---@field dropdown fun( parent: Frame ): Frame
---@field editbox fun( parent: Frame ): Frame
---@field tree_node fun( parent: Frame ): Frame

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

function M.item_link_with_icon( parent, text, spacing )
  local container = M.create_text_in_container( "Button", parent, 20, nil, nil, "text" )

  local w = 14
  local h = 14
  spacing = spacing or 10
  local count = 0
  local quantity = 1
  local texture
  local tooltip_link
  local tooltip_position

  container:SetPoint( "TOP", 0, 0 )
  container.icon = M.icon( container, true, w, h )
  container.icon:SetPoint( "LEFT", 0, 0 )
  container.icon:SetTexCoord( 1 / w, (w - 1) / w, 1 / h, (h - 1) / h )
  container.count = M.text( container )
  container.quantity = M.text( container )
  container.quantity:SetPoint( "BOTTOMRIGHT", container.icon, "BOTTOMRIGHT", 4, -2 )
  container.quantity:SetScale( 0.75 )
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
      container.icon:Hide()
      container.text:ClearAllPoints()

      if count > 1 then
        container.count:Show()
        container.count:ClearAllPoints()
        container.count:SetPoint( "LEFT", container, "LEFT", 0, 0 )
        container.text:SetPoint( "LEFT", container.count, "RIGHT", 0, 0 )
        container:SetWidth( container.count:GetWidth() + container.text:GetWidth() )
      else
        container.text:SetPoint( "LEFT", container, 0, 0 )
        container:SetWidth( container.text:GetWidth() )
      end
    end
  end

  container.SetItem = function( _, i, tt_link )
    texture = i.texture
    count = i.count or 0
    quantity = i.quantity or 1
    tooltip_link = tt_link
    tooltip_position = i.tooltip_position

    container.text:SetText( i.link )
    container.icon:SetTexture( texture )
    container.count:SetText( count > 1 and hl( string.format( "%sx", count ) ) or nil )
    container.quantity:SetText( quantity > 1 and quantity or "" )

    resize()
  end

  -- ANCHOR_CURSOR ignores SetOwner's offsetX/offsetY -- the client repositions the tooltip to the
  -- raw cursor position every frame regardless of what's passed there. Shifting it requires
  -- fighting that same per-frame repositioning with our own OnUpdate. tooltip_position (supplied
  -- per item, see SetItem) decides how far and in which direction; this only feeds it the cursor.
  local function reposition_at_cursor( tooltip )
    local x, y = m.api.GetCursorPosition()
    local scale = m.api.UIParent:GetEffectiveScale()
    local anchor, px, py = tooltip_position( x / scale, y / scale )

    -- px/py are absolute screen coordinates (GetCursorPosition's origin), so the relative-to point
    -- has to stay UIParent's BOTTOMLEFT -- the only UIParent anchor that actually sits at (0, 0).
    -- Only the tooltip's own corner/edge is meant to be configurable via `anchor`.
    tooltip:ClearAllPoints()
    tooltip:SetPoint( anchor, m.api.UIParent, "BOTTOMLEFT", px, py )
  end

  local function on_enter( self )
    if not tooltip_link then return end
    if m.vanilla then self = this end ---@diagnostic disable-line: undefined-global

    m.api.GameTooltip:SetOwner( self, "ANCHOR_CURSOR" )
    m.api.GameTooltip:SetHyperlink( tooltip_link )
    m.api.GameTooltip:Show()

    if tooltip_position then
      m.api.GameTooltip:SetScript( "OnUpdate", reposition_at_cursor )
    end
  end

  local function on_leave()
    if tooltip_position then m.api.GameTooltip:SetScript( "OnUpdate", nil ) end
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
      return
    end

    if container.on_click then container.on_click() end
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

function M.checkbox( parent )
  local container = m.api.CreateFrame( "Frame", nil, parent )
  local button = m.api.CreateFrame( "CheckButton", nil, container, "UICheckButtonTemplate" )
  button:SetWidth( 20 )
  button:SetHeight( 20 )
  button:SetPoint( "LEFT", container, "LEFT", 0, 0 )

  local label = container:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
  label:SetTextColor( 1, 1, 1 )
  label:SetPoint( "LEFT", button, "RIGHT", 0, 1 )

  container:SetHeight( button:GetHeight() )

  container.SetText = function( _, text )
    label:SetText( text )
    container:SetWidth( button:GetWidth() + label:GetWidth() )
  end

  container.SetChecked = function( _, checked )
    button:SetChecked( checked and true or false )
  end

  button:SetScript( "OnClick", function()
    if container.on_click then
      container.on_click( button:GetChecked() and true or false )
    end
  end )

  return container
end

local slider_count = 0

function M.slider( parent )
  slider_count = slider_count + 1
  local name = "RollForOptionsSlider" .. slider_count

  local slider_width = 80
  local value_gap = 34

  local container = m.api.CreateFrame( "Frame", nil, parent )
  local slider = m.api.CreateFrame( "Slider", name, container, "OptionsSliderTemplate" )
  slider:SetWidth( slider_width )
  slider:SetHeight( 16 )
  slider:SetOrientation( "HORIZONTAL" )
  slider:SetValueStep( 1 )

  -- OptionsSliderTemplate creates Low/High/Text FontStrings named after the slider and registers them globally.
  local slider_low = m.api[ name .. "Low" ]
  local slider_high = m.api[ name .. "High" ]
  local slider_text = m.api[ name .. "Text" ]

  if slider_low then slider_low:SetText( "" ) end
  if slider_high then slider_high:SetText( "" ) end
  if slider_text then slider_text:SetFontObject( m.api.GameFontHighlightSmall ) end

  local label = container:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
  label:SetTextColor( 1, 1, 1 )
  label:SetPoint( "LEFT", container, "LEFT", 0, 0 )

  slider:ClearAllPoints()
  slider:SetPoint( "LEFT", label, "RIGHT", value_gap, 0 )

  if slider_text then
    -- Move the built-in value readout from above the slider to its left, right up against it.
    slider_text:ClearAllPoints()
    slider_text:SetPoint( "RIGHT", slider, "LEFT", -6, 1 )
  end

  container:SetHeight( slider:GetHeight() )

  local updating = false
  -- Only commit on mouse release, not on every drag tick. pending_value tracks what's on
  -- screen while dragging; committed_value is what on_change was last called with.
  local pending_value
  local committed_value

  container.SetText = function( _, text )
    label:SetText( text )
    container:SetWidth( label:GetWidth() + value_gap + slider_width )
  end

  container.SetMinMaxValues = function( _, min, max )
    slider:SetMinMaxValues( min or 0, max or 100 )
  end

  container.SetValue = function( _, value )
    updating = true
    slider:SetValue( value )
    if slider_text then slider_text:SetText( tostring( value ) ) end
    pending_value = value
    committed_value = value
    updating = false
  end

  slider:SetScript( "OnValueChanged", function( _, value )
    if m.vanilla then value = arg1 end ---@diagnostic disable-line: undefined-global

    value = math.floor( value + 0.5 )
    if slider_text then slider_text:SetText( tostring( value ) ) end
    pending_value = value

    if updating then return end
  end )

  slider:SetScript( "OnMouseUp", function()
    if pending_value == nil or pending_value == committed_value then return end

    committed_value = pending_value
    if container.on_change then container.on_change( pending_value ) end
  end )

  return container
end

local dropdown_count = 0

function M.dropdown( parent )
  dropdown_count = dropdown_count + 1
  local name = "RollForOptionsDropdown" .. dropdown_count

  local dropdown_width = 90
  -- UIDropDownMenuTemplate bakes in ~16px of empty space to the left of its visible box.
  local value_gap = 4 - 16

  local container = m.api.CreateFrame( "Frame", nil, parent )
  local dropdown = m.api.CreateFrame( "Frame", name, container, "UIDropDownMenuTemplate" )
  m.api.UIDropDownMenu_SetWidth( dropdown, dropdown_width )

  local label = container:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
  label:SetTextColor( 1, 1, 1 )
  label:SetPoint( "LEFT", container, "LEFT", 0, 0 )

  dropdown:SetPoint( "LEFT", label, "RIGHT", value_gap, 0 )

  container:SetHeight( dropdown:GetHeight() )

  local options = {}

  local function option_label( value )
    for _, option in ipairs( options ) do
      if option.value == value then return option.label end
    end
  end

  local function initialize()
    for _, option in ipairs( options ) do
      local info = m.api.UIDropDownMenu_CreateInfo()
      info.text = option.label
      info.value = option.value
      info.checked = option.value == container.value

      info.func = function()
        container.value = option.value
        m.api.UIDropDownMenu_SetSelectedValue( dropdown, option.value )
        m.api.UIDropDownMenu_SetText( dropdown, option.label )
        if container.on_change then container.on_change( option.value ) end
      end

      m.api.UIDropDownMenu_AddButton( info )
    end
  end

  m.api.UIDropDownMenu_Initialize( dropdown, initialize )

  container.SetText = function( _, text )
    label:SetText( text )
    container:SetWidth( label:GetWidth() + value_gap + dropdown_width + 40 )
  end

  container.SetOptions = function( _, opts )
    options = opts or {}
  end

  container.SetValue = function( _, value )
    container.value = value
    m.api.UIDropDownMenu_SetSelectedValue( dropdown, value )
    m.api.UIDropDownMenu_SetText( dropdown, option_label( value ) or "" )
  end

  return container
end

function M.editbox( parent )
  local edit_width = 40
  local value_gap = 16

  local container = m.api.CreateFrame( "Frame", nil, parent )
  local edit = m.api.CreateFrame( "EditBox", nil, container, "InputBoxTemplate" )
  edit:SetWidth( edit_width )
  edit:SetHeight( 16 )
  edit:SetAutoFocus( false )
  edit:SetNumeric( true )
  edit:SetFontObject( m.api.GameFontHighlightSmall )

  local label = container:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
  label:SetTextColor( 1, 1, 1 )
  label:SetPoint( "LEFT", container, "LEFT", 0, 0 )

  edit:SetPoint( "LEFT", label, "RIGHT", value_gap, 1 )

  container:SetHeight( edit:GetHeight() )

  -- Last committed valid value. Restored whenever the typed text is rejected.
  local last_valid_value

  local function revert()
    edit:SetText( last_valid_value ~= nil and tostring( last_valid_value ) or "" )
  end

  -- Range/legality is Config's call, not ours: on_change (a Config setter) returns whether it
  -- accepted the value. We only rule out text that isn't even a number (e.g. an emptied box).
  local function commit()
    local value = tonumber( edit:GetText() )
    local accepted = value ~= nil and container.on_change and container.on_change( value )

    if accepted then
      last_valid_value = value
      edit:SetText( tostring( value ) )
    else
      revert()
    end

    edit:ClearFocus()
  end

  edit:SetScript( "OnEnterPressed", commit )
  edit:SetScript( "OnEditFocusLost", commit )
  edit:SetScript( "OnEscapePressed", function()
    revert()
    edit:ClearFocus()
  end )

  container.SetText = function( _, text )
    label:SetText( text )
    container:SetWidth( label:GetWidth() + value_gap + edit_width )
  end

  container.SetValue = function( _, value )
    last_valid_value = value
    edit:SetText( tostring( value ) )
  end

  return container
end

local tree_node_indent_step = 14
local tree_node_toggle_size = 14
local tree_node_label_gap = 4
local tree_node_checkbox_size = 14
local tree_node_checkbox_gap = 4
local tree_node_icon_spacing = 4
local tree_node_row_right_margin = 18

-- A row in a tree/list view (e.g. SandboxFrame): an expand/collapse icon button (only shown for
-- expandable nodes) followed by a label. Indentation is baked into the row's own internal layout
-- (rather than the row frame's outer position) so the popup's own width-to-content math, which
-- only looks at each line's width, keeps working unmodified.
function M.tree_node( parent )
  local container = m.api.CreateFrame( "Frame", nil, parent )
  container:SetHeight( tree_node_toggle_size )

  local checkbox = m.api.CreateFrame( "CheckButton", nil, container, "UICheckButtonTemplate" )
  checkbox:SetWidth( tree_node_checkbox_size )
  checkbox:SetHeight( tree_node_checkbox_size )

  local toggle = m.api.CreateFrame( "Button", nil, container )
  toggle:SetWidth( tree_node_toggle_size )
  toggle:SetHeight( tree_node_toggle_size )

  local label = container:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
  label:SetJustifyH( "LEFT" )

  -- L-shaped connector back to the parent row's icon column: a vertical tick from this row's top
  -- down to icon-center, then a horizontal tick over to this row's own icon. Only shown at depth > 0.
  local connector_right_margin = 3
  local connector_x_offset = 1

  local connector_v = container:CreateTexture( nil, "ARTWORK" )
  connector_v:SetTexture( "Interface\\Buttons\\WHITE8x8" )
  connector_v:SetVertexColor( 0.5, 0.5, 0.5, 0.7 )
  connector_v:SetWidth( 0.8 )

  local connector_h = container:CreateTexture( nil, "ARTWORK" )
  connector_h:SetTexture( "Interface\\Buttons\\WHITE8x8" )
  connector_h:SetVertexColor( 0.5, 0.5, 0.5, 0.7 )
  connector_h:SetHeight( 0.8 )

  -- Leaf rows that carry a real item use the existing item_link_with_icon widget (tooltip,
  -- shift-click chat link, ctrl-click dress up) instead of reinventing that behaviour here.
  local item_link_widget = M.item_link_with_icon( container, nil, tree_node_icon_spacing )
  item_link_widget:Hide()

  -- Native Button highlight layer: Blizzard shows/hides it automatically on hover, always above
  -- the button's own content, so there's no custom OnEnter/OnLeave or z-order to get wrong. Its
  -- color comes from item.hover_background_color (set via SetItem below).
  item_link_widget:SetHighlightTexture( "Interface\\Buttons\\WHITE8x8", "BLEND" )
  local item_highlight = item_link_widget:GetHighlightTexture()
  -- Re-anchored slightly taller than the button itself (1px above, 2px below) instead of the
  -- default exact fill.
  item_highlight:ClearAllPoints()
  item_highlight:SetPoint( "TOPLEFT", item_link_widget, "TOPLEFT", 0, 2 )
  item_highlight:SetPoint( "BOTTOMRIGHT", item_link_widget, "BOTTOMRIGHT", 0, -2 )

  -- Lets clicking the label itself (not just the +/- icon) expand/collapse a dungeon or boss row.
  -- Also drives the hover feedback (background + text color) for dungeon/boss rows.
  local label_button = m.api.CreateFrame( "Button", nil, container )
  label_button:Hide()

  -- Set per row via SetLabelStyle below. nil means exactly that -- no color override, no hover
  -- effect at all -- not "pick a default", this widget doesn't get to decide that. Hover text and
  -- hover background are independent -- a row can set either, both, or neither.
  local label_color
  local label_hover_text_color
  local label_hover_background_color

  local label_highlight = container:CreateTexture( nil, "BACKGROUND" )
  label_highlight:SetTexture( "Interface\\Buttons\\WHITE8x8" )
  label_highlight:Hide()

  local depth = 0
  local expandable = false
  local is_link = false

  local function layout()
    local indent = depth * tree_node_indent_step

    checkbox:ClearAllPoints()
    toggle:ClearAllPoints()
    label:ClearAllPoints()
    label_button:ClearAllPoints()
    label_highlight:ClearAllPoints()
    item_link_widget:ClearAllPoints()
    connector_v:ClearAllPoints()
    connector_h:ClearAllPoints()

    local after_toggle

    if expandable then
      toggle:SetPoint( "LEFT", container, "LEFT", indent, 0 )
      toggle:Show()
      after_toggle = indent + tree_node_toggle_size + tree_node_checkbox_gap
    else
      -- No icon to align with, so don't reserve room for one: checkbox sits right after the indent.
      toggle:Hide()
      after_toggle = indent
    end

    checkbox:SetPoint( "LEFT", container, "LEFT", after_toggle, 0 )

    local content_start = after_toggle + tree_node_checkbox_size + tree_node_label_gap

    local content_width

    if is_link then
      label:Hide()
      label_button:Hide()
      label_highlight:Hide()
      item_link_widget:SetPoint( "LEFT", container, "LEFT", content_start, 0 )
      item_link_widget:Show()
      -- Measure the natural (unstretched) width first -- this is what container reports for the
      -- popup's own auto-sizing below. Stretching to the popup's right edge is purely visual/click
      -- -area (the highlight fills whatever the frame's actual width ends up being).
      content_width = item_link_widget:GetWidth()
      item_link_widget:SetPoint( "RIGHT", parent, "RIGHT", -tree_node_row_right_margin, 0 )
    else
      item_link_widget:Hide()
      label:SetPoint( "LEFT", container, "LEFT", content_start, 0 )
      if label_color then label:SetTextColor( unpack( label_color ) ) end
      label:Show()
      content_width = label:GetWidth()

      -- Only expandable rows (dungeon/boss) reach this branch, so it's always safe to make the
      -- label clickable here. Stretched to the popup's right edge (like item rows), so hover/click
      -- covers the full row, not just the text -- content_width above stays the natural
      -- (unstretched) measurement used for the popup's own auto-sizing.
      label_button:SetPoint( "LEFT", container, "LEFT", content_start, 0 )
      label_button:SetPoint( "RIGHT", parent, "RIGHT", -tree_node_row_right_margin, 0 )
      label_button:SetHeight( tree_node_toggle_size )
      label_button:Show()

      label_highlight:SetPoint( "LEFT", container, "LEFT", content_start, 0 )
      label_highlight:SetPoint( "RIGHT", parent, "RIGHT", -tree_node_row_right_margin, 0 )
      label_highlight:SetHeight( tree_node_toggle_size )
    end

    if depth > 0 then
      local parent_column = (depth - 1) * tree_node_indent_step + tree_node_toggle_size / 2 - connector_x_offset
      local mid_height = tree_node_toggle_size / 2

      connector_v:SetPoint( "TOPLEFT", container, "TOPLEFT", parent_column, 0 )
      connector_v:SetHeight( mid_height )
      connector_v:Show()

      connector_h:SetPoint( "TOPLEFT", container, "TOPLEFT", parent_column, -mid_height )
      connector_h:SetWidth( indent - parent_column - connector_right_margin + 1 )
      connector_h:Show()
    else
      connector_v:Hide()
      connector_h:Hide()
    end

    container:SetWidth( content_start + content_width )
  end

  container.SetText = function( _, text )
    label:SetText( text )
    layout()
  end

  container.SetDepth = function( _, d )
    depth = d or 0
    layout()
  end

  container.SetChecked = function( _, checked )
    checkbox:SetChecked( checked and true or false )
  end

  -- Per-row label styling: base text color (required) and hover text/background color
  -- (optional -- nil means no hover effect), all { r, g, b }. Only meaningful for label rows
  -- (dungeon/boss), not item rows.
  container.SetLabelStyle = function( _, color, hover_text_color, hover_background_color )
    label_color = color
    label_hover_text_color = hover_text_color
    label_hover_background_color = hover_background_color

    label:SetTextColor( unpack( label_color ) )

    if label_hover_background_color then
      local c = label_hover_background_color
      label_highlight:SetVertexColor( c[ 1 ], c[ 2 ], c[ 3 ], c[ 4 ] )
    end
  end

  -- Greyed-out, slightly translucent checkmark: used to show a node is effectively off because an
  -- ancestor is unchecked, independent of this node's own checked state. Desaturation alone reads
  -- as barely-there at this size, so alpha is dropped too for a clearer visual cue.
  container.SetDesaturated = function( _, desaturated )
    local texture = checkbox:GetCheckedTexture()
    if not texture then return end

    if texture.SetDesaturated then texture:SetDesaturated( desaturated and true or false ) end
    texture:SetAlpha( desaturated and 0.55 or 1 )
  end

  -- item: { link, texture, count, quantity, hover_background_color } -- hover_background_color
  -- ({r,g,b}) comes from AutoLootTree, the rest is consumed by item_link_with_icon.SetItem.
  container.SetItem = function( _, item, tooltip_link )
    if item.hover_background_color then
      local c = item.hover_background_color
      item_highlight:SetVertexColor( c[ 1 ], c[ 2 ], c[ 3 ], c[ 4 ] )
    end
    item_link_widget:SetItem( item, tooltip_link )
    layout()
  end

  container.SetExpandable = function( _, is_expandable, is_expanded )
    expandable = is_expandable and true or false
    is_link = not expandable

    if expandable then
      toggle:SetNormalTexture( is_expanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up" )
      toggle:SetPushedTexture( is_expanded and "Interface\\Buttons\\UI-MinusButton-Down" or "Interface\\Buttons\\UI-PlusButton-Down" )
    end

    layout()
  end

  toggle:SetScript( "OnClick", function()
    if container.on_click then container.on_click() end
  end )

  label_button:SetScript( "OnClick", function()
    if container.on_click then container.on_click() end
  end )

  label_button:SetScript( "OnEnter", function()
    if label_hover_background_color then label_highlight:Show() end
    if label_hover_text_color then label:SetTextColor( unpack( label_hover_text_color ) ) end
  end )

  label_button:SetScript( "OnLeave", function()
    if label_hover_background_color then label_highlight:Hide() end
    if label_hover_text_color then label:SetTextColor( unpack( label_color ) ) end
  end )

  checkbox:SetScript( "OnClick", function()
    if container.on_check then container.on_check( checkbox:GetChecked() and true or false ) end
  end )

  -- Clicking the item link itself toggles the same checkbox shown to its left.
  item_link_widget.on_click = function()
    checkbox:Click()
  end

  return container
end

m.GuiElements = M
return M
