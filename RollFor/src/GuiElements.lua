RollFor = RollFor or {}
local m = RollFor

if m.GuiElements then return end

local hl = m.colors.hl
local blue = m.colors.blue
local gold = m.colors.gold
local getn = m.getn

-- Grouped (soft-res) row metrics. The cell width is fixed at three digits: a ragged grid
-- across 25 rows is unscannable, and the wasted pixels on single-digit rolls are the
-- better trade. Cells sit flush against each other, so the cell width *is* the gap
-- between two rolls - which is why it is configurable (sr_roll_spacing); this is only
-- the fallback for callers that pass nothing.
local roll_cell_width = 24
-- The pip textures are 32x32 sheets with the die drawn at x 2-24, y 5-26 and transparent
-- padding around it - and the padding is lopsided (2 left, 7 right). Cropping to the die
-- makes the texture's own edges the ones we anchor, so a pip lands in the same column as
-- the right-aligned digits instead of ~4px to their left.
local pip_size = 12
local pip_left, pip_right, pip_top, pip_bottom = 2 / 32, 25 / 32, 5 / 32, 27 / 32
-- The cropped die is still a hair right of where the digits' ink centre lands, so the pip
-- is nudged a pixel left to sit in the same column as the numbers it stands in for.
local pip_x_offset = -1
-- Matches the breathing room the ungrouped rows have. Theirs varies with name length,
-- since the name is centred in a fixed 170px row while the label is pinned 37px from the
-- right; for their widest name it works out at ~22.6 units, which is what a grouped row's
-- widest name gets here. Applied to both sides, or the name comes off centre.
local grouped_name_gap = 22
-- The roll-type label mirrors the cell zone on the far side of the name. Reserving the
-- same width on both sides is what puts the name on the row's centre line - and so on
-- the popup's, since lines are anchored by their TOP centre.
local roll_type_zone = 37
-- The label is centred in a box just big enough for it, for the same reason the roll
-- cells are: left-aligning "MS" (16 units of ink) and "OS" (14) lines up their left edges
-- and dumps the whole difference on the right. The box is narrower than the zone it sits
-- in, so ungrouped rows offset its anchor by the difference to keep the label where it
-- has always been. Fontstrings are not clipped by their container, so a wider label than
-- this still renders in full - it just centres on the same point.
local roll_type_label_width = 16
local spent_cell_alpha = 0.5
local single_roll_width = 170

-- Colour encodes the roll *type*, so emphasis lives on the alpha axis instead.
---@param roll_type RollType
---@param roll number
local function cell_text( roll_type, roll )
  if roll_type == m.Types.RollType.SoftRes then return blue( roll ) end
  if roll_type == m.Types.RollType.BonusRoll then return gold( roll ) end
  return m.roll_type_color( roll_type, roll )
end

-- The two sheets are drawn with their opaque die at identical bounds, so the pip crop and
-- offset above apply to both unchanged.
---@param roll_type RollType
local function cell_icon_texture( roll_type )
  if roll_type == m.Types.RollType.BonusRoll then
    return "Interface\\AddOns\\RollFor\\assets\\icon-gold.tga"
  end

  return "Interface\\AddOns\\RollFor\\assets\\icon-white2.tga"
end

-- What the row's roll-type label says. A player holding only pending cells can have a
-- bonus cell first, and labelling the whole row "BR" would misreport it: the row is a
-- soft-res row that happens to carry a bonus roll. Under the soft-ressers-only scope
-- every bonus row also holds SR cells, so the fallback is only ever defensive.
---@param cells table[]
---@return RollType
local function row_roll_type( cells )
  for i = 1, getn( cells ) do
    if cells[ i ].roll_type ~= m.Types.RollType.BonusRoll then return cells[ i ].roll_type end
  end

  return cells[ 1 ].roll_type
end

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
---@field resistance_row fun( parent: Frame ): Frame
---@field eligibility_row fun( parent: Frame ): Frame
---@field bonus_roll_row fun( parent: Frame ): Frame

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
  frame:SetWidth( single_roll_width )
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

  local roll_type_container = M.create_text_in_container( "Button", frame, roll_type_label_width, "CENTER" )
  roll_type_container:SetPoint( "RIGHT", -(roll_type_zone - roll_type_label_width), 0 )
  frame.roll_type = roll_type_container.inner

  frame.cells = {}

  -- The gap between two of a player's rolls is the cell width, since the cells are flush
  -- and their contents centred. set_cells refreshes it from the config on every render.
  local cell_width = roll_cell_width

  -- Each cell is its own frame and its contents are centred in it, so a column of rolls
  -- lines up on the numbers' centres. Right-aligning them instead lines up the advance
  -- edges, which puts the font's uneven side bearings on show: "75" is a 14px ink block
  -- where "50" is 17px, so right-aligned they start 3px apart.
  ---@param index number
  local function create_cell( index )
    local cell = M.create_text_in_container( "Button", frame, cell_width, "CENTER" )
    cell.icon = M.icon( cell, false, pip_size, pip_size )
    cell.icon:SetTexCoord( pip_left, pip_right, pip_top, pip_bottom )
    cell.icon:SetPoint( "CENTER", pip_x_offset, 0 )
    table.insert( frame.cells, index, cell )

    return cell
  end

  -- Grouped mode: one row per player, one cell per roll, the name centred between the
  -- cell zone and the roll-type label.
  local side_zone = roll_type_zone

  -- Lines are anchored by their TOP centre to the line above, so grouped rows must all
  -- come out the same width or their cell columns drift apart. The name column is sized
  -- to the widest name in the popup, which is only known once every row has its text -
  -- hence a separate step the popup re-runs afterwards.
  ---@param name_zone number
  local function layout_name( name_zone )
    player_name:ClearAllPoints()
    player_name:SetPoint( "CENTER", frame, "LEFT", side_zone + grouped_name_gap + name_zone / 2, 0 )

    roll_type_container:ClearAllPoints()
    roll_type_container:SetPoint( "LEFT", frame, "LEFT", side_zone + grouped_name_gap + name_zone + grouped_name_gap, 0 )

    -- Symmetric by construction, so the name's centre is the row's centre.
    frame:SetWidth( side_zone * 2 + grouped_name_gap * 2 + name_zone )
  end

  frame.set_name_zone = layout_name

  ---@param cells table[] -- { roll_type = RollType, roll = number? }
  ---@param cell_count number -- uniform across the popup, so the name column lines up
  ---@param best_index number? -- the player's own best cast roll, rendered at full alpha
  ---@param width number? -- gap between adjacent rolls; defaults to the built-in metric
  frame.set_cells = function( cells, cell_count, best_index, width )
    local count = getn( cells )
    cell_width = width or roll_cell_width

    -- Whichever side needs more room sets the width of both, or the name comes off centre.
    side_zone = (cell_count or count) * cell_width
    if roll_type_zone > side_zone then side_zone = roll_type_zone end

    roll_container:Hide()
    icon:Hide()

    roll_type_container:Show()
    local label_roll_type = row_roll_type( cells )
    frame.roll_type:SetText( m.roll_type_color( label_roll_type, m.roll_type_abbrev( label_roll_type ) ) )


    -- Cells arrive in cast order with the pending ones trailing. On screen the cast rolls
    -- sit against the name and the pending pips fill in to their left, so the numbers form
    -- one block that right-aligns on the name. Cast cells keep their chronological order.
    local ordered, best_slot = {}, nil

    for i = 1, count do
      if not cells[ i ].roll then table.insert( ordered, cells[ i ] ) end
    end

    for i = 1, count do
      if cells[ i ].roll then
        table.insert( ordered, cells[ i ] )
        if i == best_index then best_slot = getn( ordered ) end
      end
    end

    for i = 1, count do
      local cell = frame.cells[ i ] or create_cell( i )
      local data = ordered[ i ]

      -- Cells fill from the right of the zone, so a player with fewer rolls than the
      -- widest gets his blanks on the left and his cells still abut the name.
      -- Pooled cells were sized by whatever spacing was in force when they were created.
      cell:SetWidth( cell_width )
      cell:ClearAllPoints()
      cell:SetPoint( "LEFT", side_zone - (count - i + 1) * cell_width, 0 )

      if data.roll then
        cell.inner:SetText( cell_text( data.roll_type, data.roll ) )
        cell.icon:Hide()
        cell:SetAlpha( i == best_slot and 1 or spent_cell_alpha )
      else
        cell.inner:SetText( "" )
        cell.icon:SetTexture( cell_icon_texture( data.roll_type ) )
        cell.icon:Show()
        cell:SetAlpha( 1 )
      end

      cell:Show()
    end

    -- Line frames are pooled and reused across refreshes, so surplus cells left over from
    -- a previous, longer row have to be hidden explicitly or their numbers bleed into
    -- this one. frame.clear only hides the line frame, not its children.
    for i = count + 1, getn( frame.cells ) do
      frame.cells[ i ]:Hide()
    end

    layout_name( player_name:GetStringWidth() )
  end

  -- The same pooled frame may come back as an ungrouped row, so grouped mode has to be
  -- undoable.
  frame.set_single_cell = function()
    for i = 1, getn( frame.cells ) do
      frame.cells[ i ]:Hide()
    end

    roll_container:Show()
    roll_type_container:Show()
    roll_type_container:ClearAllPoints()
    roll_type_container:SetPoint( "RIGHT", -(roll_type_zone - roll_type_label_width), 0 )

    player_name:ClearAllPoints()
    player_name:SetPoint( "CENTER", frame, "CENTER", 0, 0 )

    frame:SetWidth( single_roll_width )
  end

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
  -- Decimal places the knob snaps to and the readout shows. 0 means whole numbers, which is
  -- what the SetValueStep above already enforces until SetPrecision says otherwise.
  local m_precision = 0

  local function format_value( value )
    if not value then return "" end
    if m_precision > 0 then return string.format( "%." .. m_precision .. "f", value ) end

    return string.format( "%d", math.floor( value + 0.5 ) )
  end

  local function round( value )
    return tonumber( format_value( value ) )
  end

  container.SetText = function( _, text )
    label:SetText( text )
    container:SetWidth( label:GetWidth() + value_gap + slider_width )
  end

  container.SetMinMaxValues = function( _, min, max )
    slider:SetMinMaxValues( min or 0, max or 100 )
  end

  -- Must be called before SetValue: it decides the step the knob snaps to and how the readout
  -- is formatted.
  container.SetPrecision = function( _, precision )
    m_precision = precision or 0
    slider:SetValueStep( m_precision > 0 and 1 / (10 ^ m_precision) or 1 )
  end

  container.SetValue = function( _, value )
    updating = true
    slider:SetValue( value )
    if slider_text then slider_text:SetText( format_value( value ) ) end
    pending_value = value
    committed_value = value
    updating = false
  end

  slider:SetScript( "OnValueChanged", function( _, value )
    if m.vanilla then value = arg1 end ---@diagnostic disable-line: undefined-global

    value = round( value )
    if slider_text then slider_text:SetText( format_value( value ) ) end
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
  -- Decimal places this box accepts and displays. 0 means whole numbers only, which is also what
  -- the SetNumeric above enforces until SetPrecision says otherwise.
  local m_precision = 0

  local function format_value( value )
    if not value then return "" end
    if m_precision > 0 then return string.format( "%." .. m_precision .. "f", value ) end

    return string.format( "%d", math.floor( value + 0.5 ) )
  end

  local function revert()
    edit:SetText( format_value( last_valid_value ) )
  end

  -- Range/legality is Config's call, not ours: on_change (a Config setter) returns whether it
  -- accepted the value. We only rule out text that isn't even a number (e.g. an emptied box).
  local function commit()
    -- Round to our precision first, so the setter never sees more decimals than we display.
    local value = tonumber( format_value( tonumber( edit:GetText() ) ) )

    -- Enter runs commit and then drops focus, which runs commit again. Bail out when nothing
    -- actually changed, so the setter (and its notification) only fires once per edit. The text
    -- still needs normalizing: typing 1.52 at precision 1 rounds to the value we already hold,
    -- but the box is showing what was typed.
    if format_value( value ) == format_value( last_valid_value ) then
      revert()
      edit:ClearFocus()
      return
    end

    local accepted = value ~= nil and container.on_change and container.on_change( value )

    if accepted then
      last_valid_value = value
      edit:SetText( format_value( value ) )
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

  -- Must be called before SetValue: it decides how the value is rendered and whether the box
  -- will even accept a decimal point.
  container.SetPrecision = function( _, precision )
    m_precision = precision or 0
    edit:SetNumeric( m_precision == 0 )
  end

  container.SetValue = function( _, value )
    last_valid_value = value
    edit:SetText( format_value( value ) )
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

-- A row in a tree/list view (e.g. AutoLootFrame): an expand/collapse icon button (only shown for
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

-- Fixed column geometry. The popup sizes itself from the widest line, so a row
-- that measured itself from its own text would be a different width per player
-- and the columns would drift; every row reports the same width instead.
local resistance_row_height = 14
local resistance_row_clear_size = 12
local resistance_row_width = 310

local resistance_row_columns = {
  { field = "player", x = 18, width = 108, justify = "LEFT" },
  { field = "resistance", x = 130, width = 66, justify = "CENTER" },
  { field = "personal", x = 196, width = 54, justify = "RIGHT" },
  { field = "total", x = 252, width = 54, justify = "RIGHT" }
}

-- Cool grey: the column titles are a legend, not data, so they sit back.
local resistance_row_header_color = { 0.6, 0.65, 0.76 }
local resistance_row_text_color = { 1, 1, 1 }
-- Enough to tell which row the cursor is on across four columns, not enough to
-- compete with the values themselves.
local resistance_row_hover_color = { 0.351, 0.553, 1.0, 0.18 }
-- How far the highlight reaches past the row on each side. The popup is the
-- widest row plus its side margin, so this stays inside the frame.
local resistance_row_hover_overhang = 10

-- A row in the resistance list: a small clear button, then Player / Resistance /
-- Personal / Total at fixed offsets. The column-title row is the same widget
-- (SetHeader) so the titles line up with the values underneath them.
function M.resistance_row( parent )
  local container = m.api.CreateFrame( "Frame", nil, parent )
  container:SetHeight( resistance_row_height )
  container:SetWidth( resistance_row_width )

  local clear_button = m.api.CreateFrame( "Button", nil, container )
  clear_button:SetWidth( resistance_row_clear_size )
  clear_button:SetHeight( resistance_row_clear_size )
  clear_button:SetPoint( "LEFT", container, "LEFT", 0, 0 )
  clear_button:SetNormalTexture( "Interface\\Buttons\\UI-GroupLoot-Pass-Up" )
  clear_button:SetPushedTexture( "Interface\\Buttons\\UI-GroupLoot-Pass-Down" )
  clear_button:SetHighlightTexture( "Interface\\Buttons\\UI-Common-MouseHilight" )

  -- Reaches a little past the row on both sides so it reads as a band rather
  -- than a box around the text. Both corners are anchored to the row itself, so
  -- the rectangle is fully defined by these two points; the row frame's own
  -- width is untouched, which keeps the popup's width-to-content math intact.
  local hover_highlight = container:CreateTexture( nil, "BACKGROUND" )
  hover_highlight:SetTexture( "Interface\\Buttons\\WHITE8x8" )
  hover_highlight:SetVertexColor( unpack( resistance_row_hover_color ) )
  hover_highlight:SetPoint( "TOPLEFT", container, "TOPLEFT", -resistance_row_hover_overhang, 1 )
  hover_highlight:SetPoint( "BOTTOMRIGHT", container, "BOTTOMRIGHT", resistance_row_hover_overhang, -1 )
  hover_highlight:Hide()

  local is_header = false

  local columns = {}

  for _, column in ipairs( resistance_row_columns ) do
    local label = container:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
    label:SetWidth( column.width )
    label:SetHeight( resistance_row_height )
    label:SetJustifyH( column.justify )
    label:SetTextColor( unpack( resistance_row_text_color ) )
    label:SetPoint( "LEFT", container, "LEFT", column.x, 0 )
    columns[ column.field ] = label
  end

  -- FrameBuilder caches line frames per line type and reuses them across
  -- refreshes, so every column is written on every call -- a field left alone
  -- would keep showing whichever player occupied this frame last time.
  container.SetRow = function( _, row )
    for _, column in ipairs( resistance_row_columns ) do
      columns[ column.field ]:SetText( row[ column.field ] or "" )
    end

    -- The only thing that shows the button, so the column-title row (which has
    -- no clearable field) and rows with nothing cached both come out bare.
    if row.clearable then clear_button:Show() else clear_button:Hide() end

    -- Rows are recycled between refreshes and a hidden frame never gets its
    -- OnLeave, so a stale highlight would follow the frame to its next row.
    hover_highlight:Hide()
  end

  container.SetHeader = function( _, header )
    is_header = header and true or false
    local color = is_header and resistance_row_header_color or resistance_row_text_color

    if is_header then hover_highlight:Hide() end

    for _, column in ipairs( resistance_row_columns ) do
      columns[ column.field ]:SetTextColor( unpack( color ) )
    end
  end

  container:EnableMouse( true )

  container:SetScript( "OnEnter", function()
    if is_header then return end
    hover_highlight:Show()
  end )

  container:SetScript( "OnLeave", function()
    hover_highlight:Hide()
  end )

  -- A mouse-enabled row swallows the click the popup needs to start dragging,
  -- so the row hands it back rather than making most of the frame undraggable.
  container:RegisterForDrag( "LeftButton" )

  local function forward_to_popup( script )
    return function()
      local handler = parent:GetScript( script )
      if handler then handler( parent ) end
    end
  end

  container:SetScript( "OnDragStart", forward_to_popup( "OnDragStart" ) )
  container:SetScript( "OnDragStop", forward_to_popup( "OnDragStop" ) )

  clear_button:SetScript( "OnClick", function()
    if container.on_clear then container.on_clear() end
  end )

  return container
end

-- Same fixed-geometry reasoning as resistance_row above: the popup sizes itself
-- from the widest line, so a self-measuring row would be a different width per
-- player and the columns would drift.
local eligibility_row_height = 16
local eligibility_row_checkbox_size = 18
local eligibility_row_width = 240

local eligibility_row_columns = {
  { field = "player", x = 24, width = 108, justify = "LEFT" },
  -- Wide enough for "Shadow 180" and the slack a longer reason would want.
  { field = "reason", x = 136, width = 100, justify = "LEFT" }
}

-- A row in the bonus roll eligibility list: a checkbox, then Player / Reason at
-- fixed offsets. The column-title row is the same widget (SetHeader) so the
-- titles line up with the values underneath them.
function M.eligibility_row( parent )
  local container = m.api.CreateFrame( "Frame", nil, parent )
  container:SetHeight( eligibility_row_height )
  container:SetWidth( eligibility_row_width )

  local checkbox = m.api.CreateFrame( "CheckButton", nil, container, "UICheckButtonTemplate" )
  checkbox:SetWidth( eligibility_row_checkbox_size )
  checkbox:SetHeight( eligibility_row_checkbox_size )
  checkbox:SetPoint( "LEFT", container, "LEFT", 0, 0 )

  -- Reaches a little past the row on both sides so it reads as a band rather
  -- than a box around the text, exactly as the resistance list's rows do.
  local hover_highlight = container:CreateTexture( nil, "BACKGROUND" )
  hover_highlight:SetTexture( "Interface\\Buttons\\WHITE8x8" )
  hover_highlight:SetVertexColor( unpack( resistance_row_hover_color ) )
  hover_highlight:SetPoint( "TOPLEFT", container, "TOPLEFT", -resistance_row_hover_overhang, 1 )
  hover_highlight:SetPoint( "BOTTOMRIGHT", container, "BOTTOMRIGHT", resistance_row_hover_overhang, -1 )
  hover_highlight:Hide()

  local is_header = false

  local columns = {}

  for _, column in ipairs( eligibility_row_columns ) do
    local label = container:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
    label:SetWidth( column.width )
    label:SetHeight( eligibility_row_height )
    label:SetJustifyH( column.justify )
    label:SetTextColor( unpack( resistance_row_text_color ) )
    label:SetPoint( "LEFT", container, "LEFT", column.x, 0 )
    columns[ column.field ] = label
  end

  -- FrameBuilder caches line frames per line type and reuses them across
  -- refreshes, so every column is written on every call -- including the checked
  -- state, which would otherwise keep whichever player occupied this frame last.
  container.SetRow = function( _, row )
    for _, column in ipairs( eligibility_row_columns ) do
      columns[ column.field ]:SetText( row[ column.field ] or "" )
    end

    checkbox:SetChecked( row.checked and true or false )

    -- Rows are recycled between refreshes and a hidden frame never gets its
    -- OnLeave, so a stale highlight would follow the frame to its next row.
    hover_highlight:Hide()
  end

  container.SetHeader = function( _, header )
    is_header = header and true or false
    local color = is_header and resistance_row_header_color or resistance_row_text_color

    -- The column titles are a legend, so there is nothing there to tick.
    if is_header then
      checkbox:Hide()
      hover_highlight:Hide()
    else
      checkbox:Show()
    end

    for _, column in ipairs( eligibility_row_columns ) do
      columns[ column.field ]:SetTextColor( unpack( color ) )
    end
  end

  container:EnableMouse( true )

  container:SetScript( "OnEnter", function()
    if is_header then return end
    hover_highlight:Show()
  end )

  container:SetScript( "OnLeave", function()
    hover_highlight:Hide()
  end )

  -- A mouse-enabled row swallows the click the popup needs to start dragging,
  -- so the row hands it back rather than making most of the frame undraggable.
  container:RegisterForDrag( "LeftButton" )

  local function forward_to_popup( script )
    return function()
      local handler = parent:GetScript( script )
      if handler then handler( parent ) end
    end
  end

  container:SetScript( "OnDragStart", forward_to_popup( "OnDragStart" ) )
  container:SetScript( "OnDragStop", forward_to_popup( "OnDragStop" ) )

  checkbox:SetScript( "OnClick", function()
    if container.on_check then container.on_check( checkbox:GetChecked() and true or false ) end
  end )

  return container
end

-- Same fixed-geometry reasoning as the rows above. No checkbox and no clear button --
-- this is a read display of an earned, roster-independent fact, not something driven
-- by a click.
local bonus_roll_row_height = 14
local bonus_roll_row_width = 200

local bonus_roll_row_columns = {
  { field = "player", x = 8, width = 140, justify = "LEFT" },
  { field = "rolls", x = 148, width = 44, justify = "RIGHT" }
}

-- A row in the bonus roll list: Player / Rolls at fixed offsets, with a tooltip on
-- hover naming the bosses that paid for them. The column-title row is the same widget
-- (SetHeader) so the titles line up with the values underneath them.
function M.bonus_roll_row( parent )
  local container = m.api.CreateFrame( "Frame", nil, parent )
  container:SetHeight( bonus_roll_row_height )
  container:SetWidth( bonus_roll_row_width )

  -- Reaches a little past the row on both sides so it reads as a band rather than a
  -- box around the text, exactly as the resistance list's rows do.
  local hover_highlight = container:CreateTexture( nil, "BACKGROUND" )
  hover_highlight:SetTexture( "Interface\\Buttons\\WHITE8x8" )
  hover_highlight:SetVertexColor( unpack( resistance_row_hover_color ) )
  hover_highlight:SetPoint( "TOPLEFT", container, "TOPLEFT", -resistance_row_hover_overhang, 1 )
  hover_highlight:SetPoint( "BOTTOMRIGHT", container, "BOTTOMRIGHT", resistance_row_hover_overhang, -1 )
  hover_highlight:Hide()

  local is_header = false

  local columns = {}

  for _, column in ipairs( bonus_roll_row_columns ) do
    local label = container:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
    label:SetWidth( column.width )
    label:SetHeight( bonus_roll_row_height )
    label:SetJustifyH( column.justify )
    label:SetTextColor( unpack( resistance_row_text_color ) )
    label:SetPoint( "LEFT", container, "LEFT", column.x, 0 )
    columns[ column.field ] = label
  end

  -- FrameBuilder caches line frames per line type and reuses them across refreshes, so
  -- every column is written on every call -- and the tooltip lines with it, since a
  -- frame left holding a stale list would name the wrong player's bosses on hover.
  container.SetRow = function( _, row )
    for _, column in ipairs( bonus_roll_row_columns ) do
      columns[ column.field ]:SetText( row[ column.field ] or "" )
    end

    container.tooltip_lines = row.tooltip_lines

    -- Rows are recycled between refreshes and a hidden frame never gets its OnLeave, so
    -- a stale highlight would follow the frame to its next row.
    hover_highlight:Hide()
  end

  container.SetHeader = function( _, header )
    is_header = header and true or false
    local color = is_header and resistance_row_header_color or resistance_row_text_color

    if is_header then hover_highlight:Hide() end

    for _, column in ipairs( bonus_roll_row_columns ) do
      columns[ column.field ]:SetTextColor( unpack( color ) )
    end
  end

  container:EnableMouse( true )

  -- The tooltip's first line always uses the big header font, so swap it to the
  -- regular body font for the first boss name and put it back afterwards -- the
  -- tooltip is shared with the rest of the UI.
  local function set_title_font( font )
    local title = m.api.GameTooltip.TextLeft1
    if title then title:SetFontObject( font ) end
  end

  -- Whether this row is the one currently showing the tooltip. Only the owner puts the
  -- title font back and hides it: without this, a row that never opened a tooltip would
  -- close whichever frame's tooltip happens to be up when the mouse crosses it.
  local showing_tooltip = false

  local function hide_tooltip()
    if not showing_tooltip then return end

    showing_tooltip = false
    set_title_font( m.api.GameTooltipHeaderText )
    m.api.GameTooltip:Hide()
  end

  container:SetScript( "OnEnter", function()
    if is_header then return end
    hover_highlight:Show()

    local lines = container.tooltip_lines
    if not lines or getn( lines ) == 0 then return end

    m.api.GameTooltip:SetOwner( container, "ANCHOR_RIGHT" )

    for _, line in ipairs( lines ) do
      m.api.GameTooltip:AddLine( line, 1, 1, 1 )
    end

    set_title_font( m.api.GameTooltipText )
    showing_tooltip = true
    m.api.GameTooltip:Show()
  end )

  container:SetScript( "OnLeave", function()
    hover_highlight:Hide()
    hide_tooltip()
  end )

  -- A row hovered when the list redraws is hidden out from under the mouse and never
  -- gets its OnLeave, which would leave the swapped title font on the shared tooltip
  -- for the rest of the session -- every tooltip in the UI, not just this window's.
  container:SetScript( "OnHide", function()
    hover_highlight:Hide()
    hide_tooltip()
  end )

  -- A mouse-enabled row swallows the click the popup needs to start dragging, so the
  -- row hands it back rather than making most of the frame undraggable.
  container:RegisterForDrag( "LeftButton" )

  local function forward_to_popup( script )
    return function()
      local handler = parent:GetScript( script )
      if handler then handler( parent ) end
    end
  end

  container:SetScript( "OnDragStart", forward_to_popup( "OnDragStart" ) )
  container:SetScript( "OnDragStop", forward_to_popup( "OnDragStop" ) )

  return container
end

m.GuiElements = M
return M
