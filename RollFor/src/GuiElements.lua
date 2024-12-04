---@diagnostic disable-next-line: undefined-global
local modules = LibStub( "RollFor-Modules" )
if modules.GuiElements then return end

local m = modules

local M = {}

function M.item( parent )
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

function M.text( parent, text )
  local result = parent:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )

  result:SetTextColor( 1, 1, 1 )
  if text then result:SetText( text ) end

  return result
end

function M.icon( parent, show )
  local icon = parent:CreateTexture( nil, "BACKGROUND" )
  if not show then icon:Hide() end
  icon:SetWidth( 16 )
  icon:SetHeight( 16 )
  icon:SetTexture( "Interface\\AddOns\\RollFor\\assets\\icon-white2.tga" )

  return icon
end

function M.icon_text( parent, text )
  local container = create_text_in_container( parent, 20, nil, nil, "text" )

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

  local icon = M.icon( frame )
  icon:SetPoint( "LEFT", 22, 0 )
  frame.icon = icon

  roll_container:SetPoint( "LEFT", 0, 0 )
  frame.roll = roll_container.inner

  local player_name = M.text( frame )
  player_name:SetPoint( "CENTER", frame, "CENTER", 0, 0 )
  frame.player_name = player_name

  local roll_type_container = create_text_in_container( frame, 37, "LEFT" )
  roll_type_container:SetPoint( "RIGHT", 0, 0 )
  frame.roll_type = roll_type_container.inner

  return frame
end

function M.button( parent )
  local button = m.api.CreateFrame( "Button", nil, parent, "StaticPopupButtonTemplate" )
  button:SetWidth( 100 )
  button:SetHeight( 20 )
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

  frame:SetScript( "OnEnter", function()
    ---@diagnostic disable-next-line: undefined-global
    local self = this
    self.tooltip_scale = m.api.GameTooltip:GetScale()
    m.api.GameTooltip:SetOwner( self, "ANCHOR_CURSOR" )
    m.api.GameTooltip:AddLine( frame.tooltip_info, 1, 1, 1 )
    m.api.GameTooltip:SetScale( 0.75 )
    -- m.api.GameTooltip:ClearAllPoints()
    -- m.api.GameTooltip:SetPoint( "BOTTOMLEFT", frame, "TOPRIGHT", -90, 0 )
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

modules.GuiElements = M
return M
