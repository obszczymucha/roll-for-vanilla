RollFor = RollFor or {}
local m = RollFor

if m.MinimapButton then return end

local M = {}
local hl = m.colors.hl
local blue = m.colors.blue
local grey = m.colors.grey
local white = m.colors.white
local pretty_print = m.pretty_print

local ColorType = {
  White = "White",
  Green = "Green",
  Orange = "Orange",
  Purple = "Purple",
  Red = "Red"
}

-- What an extension contributes to the minimap button, keyed by nothing -- registration
-- order is the only thing that matters. Read at render time (OnEnter, and whenever core
-- recomputes the icon colour), never snapshotted, because the button is built well before
-- extensions get a chance to register anything.
---@class MinimapContribution
---@field commands { cmd: string, args: string?, description: string }[]?
---@field hint string?
---@field status fun(): { color: string, lines: string[]? }?

---@param entry { cmd: string, args: string?, description: string }
---@return string
local function format_command( entry )
  if entry.args then
    return string.format( "%s %s - %s", hl( entry.cmd ), grey( entry.args ), white( entry.description ) )
  end

  return string.format( "%s - %s", hl( entry.cmd ), white( entry.description ) )
end

---@param api fun(): table
---@param db table
---@param config Config
---@param event_bus EventBus
---@param contributions MinimapContribution[]
function M.new( api, db, config, event_bus, contributions )
  local icon_color

  local function persist_angle( angle )
    db.angle = angle
  end

  local function get_angle()
    return db.angle
  end

  local function is_locked()
    return config.minimap_button_locked()
  end

  local function is_hidden()
    return config.minimap_button_hidden()
  end

  local function build_tooltip( tooltip )
    tooltip:SetText( blue( "RollFor" ) )
    tooltip:AddLine( " " )

    tooltip:AddLine( string.format( "%s - %s", hl( "/htr" ), white( "show how to roll" ) ) )
    tooltip:AddLine( string.format( "%s %s - %s", hl( "/rf" ), grey( "<item>" ), white( "roll for" ) ) )
    tooltip:AddLine( string.format( "%s %s - %s", hl( "/rr" ), grey( "<item>" ), white( "raid-roll" ) ) )
    tooltip:AddLine( string.format( "%s %s - %s", hl( "/irr" ), grey( "<item>" ), white( "insta raid-roll" ) ) )
    tooltip:AddLine( string.format( "%s %s - %s", hl( "/arf" ), grey( "<item>" ), white( "roll for (ignore SR)" ) ) )
    tooltip:AddLine( string.format( "%s %s %s - %s", hl( "/rf" ), grey( "<item>" ), grey( "<seconds>" ), white( "roll with custom time" ) ) )
    tooltip:AddLine( string.format( "%s %s - %s", hl( "/rfreset" ), grey( "announce" ), white( "reset loot announce" ) ) )
    tooltip:AddLine( string.format( "%s - %s", hl( "/cr" ), white( "cancel rolling in progress" ) ) )
    tooltip:AddLine( string.format( "%s - %s", hl( "/fr" ), white( "finish rolling early" ) ) )
    tooltip:AddLine( string.format( "%s - %s", hl( "/rf config" ), white( "show configuration" ) ) )
    tooltip:AddLine( string.format( "%s - %s", hl( "/rf config help" ), white( "show configuration help" ) ) )

    local hint

    for _, contribution in ipairs( contributions ) do
      for _, entry in ipairs( contribution.commands or {} ) do
        tooltip:AddLine( format_command( entry ) )
      end

      hint = hint or contribution.hint
    end

    tooltip:AddLine( " " )
    tooltip:AddLine( hint or "Click to open options." )

    for _, contribution in ipairs( contributions ) do
      local status = contribution.status and contribution.status()

      if status and status.lines then
        tooltip:AddLine( " " )

        for _, line in ipairs( status.lines ) do
          tooltip:AddLine( line )
        end
      end
    end
  end

  local function create()
    local frame = api().CreateFrame( "Button", "RollForMinimapButton", api().Minimap )

    function frame.OnClick( self )
      event_bus.notify( "minimap_icon_left_click" )
      self:OnEnter()
      api().GameTooltip:Hide()
    end

    function frame.OnMouseDown( self )
      self.icon:SetTexCoord( 0, 1, 0, 1 )
    end

    function frame.OnMouseUp( self )
      self.icon:SetTexCoord( 0.05, 0.95, 0.05, 0.95 )
    end

    function frame.OnEnter( self )
      if not self.dragging then
        api().GameTooltip:SetOwner( self, "ANCHOR_LEFT" )
        build_tooltip( api().GameTooltip )
        api().GameTooltip:Show()
      end
    end

    function frame.OnLeave()
      api().GameTooltip:Hide()
    end

    function frame.OnDragStart( self )
      self.dragging = true
      self:LockHighlight()
      self.icon:SetTexCoord( 0, 1, 0, 1 )
      self:SetScript( "OnUpdate", self.OnUpdate )
      api().GameTooltip:Hide()
    end

    function frame.OnDragStop( self )
      self.dragging = nil
      self:SetScript( "OnUpdate", nil )
      self.icon:SetTexCoord( 0.05, 0.95, 0.05, 0.95 )
      self:UnlockHighlight()
    end

    function frame.OnUpdate( self )
      local mx, my = api().Minimap:GetCenter()
      local px, py = api().GetCursorPosition()
      local scale = api().Minimap:GetEffectiveScale()

      px, py = px / scale, py / scale

      persist_angle( m.mod( math.deg( math.atan2( py - my, px - mx ) ), 360 ) ) ---@diagnostic disable-line: deprecated
      self:UpdatePosition()
    end

    -- Copy pasted from Bongos.
    --magic fubar code for updating the minimap button"s position
    --I suck at trig, so I"m not going to bother figuring it out
    ---@diagnostic disable-next-line: redefined-local
    function frame.UpdatePosition( self )
      local angle = math.rad( get_angle() or m.lua.random( 0, 360 ) )
      local cos = math.cos( angle )
      local sin = math.sin( angle )
      local minimapShape = api().GetMinimapShape and api().GetMinimapShape() or "ROUND"

      local round = false
      if minimapShape == "ROUND" then
        round = true
      elseif minimapShape == "SQUARE" then
        round = false
      elseif minimapShape == "CORNER-TOPRIGHT" then
        round = not (cos < 0 or sin < 0)
      elseif minimapShape == "CORNER-TOPLEFT" then
        round = not (cos > 0 or sin < 0)
      elseif minimapShape == "CORNER-BOTTOMRIGHT" then
        round = not (cos < 0 or sin > 0)
      elseif minimapShape == "CORNER-BOTTOMLEFT" then
        round = not (cos > 0 or sin > 0)
      elseif minimapShape == "SIDE-LEFT" then
        round = cos <= 0
      elseif minimapShape == "SIDE-RIGHT" then
        round = cos >= 0
      elseif minimapShape == "SIDE-TOP" then
        round = sin <= 0
      elseif minimapShape == "SIDE-BOTTOM" then
        round = sin >= 0
      elseif minimapShape == "TRICORNER-TOPRIGHT" then
        round = not (cos < 0 and sin > 0)
      elseif minimapShape == "TRICORNER-TOPLEFT" then
        round = not (cos > 0 and sin > 0)
      elseif minimapShape == "TRICORNER-BOTTOMRIGHT" then
        round = not (cos < 0 and sin < 0)
      elseif minimapShape == "TRICORNER-BOTTOMLEFT" then
        round = not (cos > 0 and sin < 0)
      end

      local x, y
      if round then
        x = cos * 80
        y = sin * 80
      else
        x = math.max( -82, math.min( 110 * cos, 84 ) )
        y = math.max( -86, math.min( 110 * sin, 82 ) )
      end

      self:ClearAllPoints()
      self:SetPoint( "CENTER", x, y )
    end

    frame:SetFrameStrata( "MEDIUM" )
    frame:SetWidth( 31 )
    frame:SetHeight( 31 )
    frame:SetFrameLevel( 8 )
    frame:RegisterForClicks( "anyUp" )
    frame:RegisterForDrag( "LeftButton" )
    frame:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )

    local overlay = frame:CreateTexture( nil, "OVERLAY" )
    overlay:SetWidth( 53 )
    overlay:SetHeight( 53 )
    overlay:SetTexture( "Interface\\Minimap\\MiniMap-TrackingBorder" )
    overlay:SetPoint( "TOPLEFT", 0, 0 )

    local icon = frame:CreateTexture( nil, "BACKGROUND" )
    icon:SetWidth( 20 )
    icon:SetHeight( 20 )
    icon:SetTexCoord( 0.05, 0.95, 0.05, 0.95 )
    icon:SetPoint( "TOPLEFT", 7, -5 )
    frame.icon = icon

    frame:SetScript( "OnEnter", frame.OnEnter )
    frame:SetScript( "OnLeave", frame.OnLeave )
    frame:SetScript( "OnClick", frame.OnClick )

    frame:SetScript( "OnMouseDown", frame.OnMouseDown )
    frame:SetScript( "OnMouseUp", frame.OnMouseUp )

    frame:UpdatePosition()

    frame:SetScript( "OnEvent", function() frame:UpdatePosition() end )
    frame:RegisterEvent( "PLAYER_ENTERING_WORLD" )

    return frame
  end

  local frame = create()

  local function show()
    if is_hidden() then
      frame:Hide()
      pretty_print( string.format( "Minimap button is hidden. Type %s to show.", hl( "/rf config minimap" ) ) )
    else
      frame:Show()
    end
  end

  local function lock()
    if is_locked() then
      frame:SetScript( "OnDragStart", nil )
      frame:SetScript( "OnDragStop", nil )
    else
      frame:SetScript( "OnDragStart", frame.OnDragStart )
      frame:SetScript( "OnDragStop", frame.OnDragStop )
    end
  end

  local function set_icon( color )
    frame.icon:SetTexture( string.format( "Interface\\AddOns\\RollFor\\assets\\icon-%s.tga", string.lower( color ) ) )
    icon_color = color
  end

  show()
  lock()
  -- No source is known to be loaded yet -- that used to be spelled "Red" (outdated data)
  -- and corrected a moment later at login, but with no soft-res source installed at all
  -- "Red" would be a lie that never gets corrected. White until the first refresh.
  set_icon( ColorType.White )

  local function toggle()
    if is_hidden() then
      config.show_minimap_button()
    else
      config.hide_minimap_button()
    end

    show()
  end

  local function toggle_lock()
    if is_locked() then
      config.unlock_minimap_button()
    else
      config.lock_minimap_button()
    end

    lock()
  end

  config.subscribe( "minimap_button_hidden", show )

  return {
    toggle = toggle,
    toggle_lock = toggle_lock,
    set_icon = set_icon,
    get_icon_color = function() return icon_color end,
    ColorType = ColorType
  }
end

M.ColorType = ColorType

m.MinimapButton = M
return M
