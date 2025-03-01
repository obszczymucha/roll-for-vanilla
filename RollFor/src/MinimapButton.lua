RollFor = RollFor or {}
local m = RollFor

if m.MinimapButton then return end

local M = {}
local hl = m.colors.hl
local blue = m.colors.blue
local grey = m.colors.grey
local white = m.colors.white
local green = m.colors.green
local red = m.colors.red
local pretty_print = m.pretty_print
local class_color = m.colorize_player_by_class

local ColorType = {
  White = "White",
  Green = "Green",
  Orange = "Orange",
  Red = "Red"
}

function M.new( api, db, manage_softres_fn, winners_popup_fn, softres_check, config )
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

  local function print_players_who_did_not_softres( tooltip )
    local result, players = softres_check.check_softres( true )

    if result == softres_check.ResultType.SomeoneIsNotSoftRessing then
      tooltip:AddLine( white( "Missing softres:" ) )

      for _, player in pairs( players ) do
        tooltip:AddLine( class_color( player.name, player.class ) )
      end
    end
  end

  local function create()
    local frame = api().CreateFrame( "Button", "RollForMinimapButton", api().Minimap )
    local was_dragging = false

    function frame.OnClick( self )
      if m.vanilla then self = this end

      if m.is_shift_key_down() then
        winners_popup_fn()
      else
        manage_softres_fn()
      end
      self:OnEnter()
      api().GameTooltip:Hide()
    end

    function frame.OnMouseDown( self )
      if m.vanilla then self = this end

      self.icon:SetTexCoord( 0, 1, 0, 1 )
      was_dragging = false
    end

    function frame.OnMouseUp( self )
      if m.vanilla then self = this end

      self.icon:SetTexCoord( 0.05, 0.95, 0.05, 0.95 )
      if m.vanilla and not was_dragging then self:OnClick() end
    end

    function frame.OnEnter( self )
      if m.vanilla then self = this end

      if not self.dragging then
        api().GameTooltip:SetOwner( self, "ANCHOR_LEFT" )
        api().GameTooltip:SetText( blue( "RollFor" ) )

        api().GameTooltip:AddLine( " " )
        api().GameTooltip:AddLine( string.format( "%s - %s", hl( "/htr" ), white( "show how to roll" ) ) )
        api().GameTooltip:AddLine( string.format( "%s %s - %s", hl( "/rf" ), grey( "<item>" ), white( "roll for" ) ) )
        api().GameTooltip:AddLine( string.format( "%s %s - %s", hl( "/rr" ), grey( "<item>" ), white( "raid-roll" ) ) )
        api().GameTooltip:AddLine( string.format( "%s %s - %s", hl( "/irr" ), grey( "<item>" ), white( "insta raid-roll" ) ) )
        api().GameTooltip:AddLine( string.format( "%s %s - %s", hl( "/arf" ), grey( "<item>" ), white( "roll for (ignore SR)" ) ) )
        api().GameTooltip:AddLine( string.format( "%s %s %s - %s", hl( "/rf" ), grey( "<item>" ), grey( "<seconds>" ), white( "roll with custom time" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - %s", hl( "/sr" ), white( "manage softres" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - %s", hl( "/sro" ), white( "fix player softres name" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - %s", hl( "/src" ), white( "check softres status" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - %s", hl( "/srs" ), white( "show softres items" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - %s", hl( "/rfr" ), white( "reset loot announce" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - %s", hl( "/cr" ), white( "cancel rolling in progress" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - %s", hl( "/fr" ), white( "finish rolling early" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - %s", hl( "/rf config" ), white( "show configuration" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - %s", hl( "/rf config help" ), white( "show configuration help" ) ) )
        api().GameTooltip:AddLine( " " )
        api().GameTooltip:AddLine( "Click to manage softres." )

        if icon_color == ColorType.Green then
          api().GameTooltip:AddLine( " " )
          api().GameTooltip:AddLine( string.format( "%s %s", white( "Softres status:" ), green( "OK" ) ) )
        elseif icon_color == ColorType.Orange then
          api().GameTooltip:AddLine( " " )
          print_players_who_did_not_softres( api().GameTooltip )
        elseif icon_color == ColorType.Red then
          api().GameTooltip:AddLine( " " )
          api().GameTooltip:AddLine( white( "Softres status:" ) )
          api().GameTooltip:AddLine( red( "Found outdated softres data!" ) )
        end

        api().GameTooltip:Show()
      end
    end

    function frame.OnLeave()
      api().GameTooltip:Hide()
    end

    function frame.OnDragStart( self )
      if m.vanilla then self = this end

      self.dragging = true
      self:LockHighlight()
      self.icon:SetTexCoord( 0, 1, 0, 1 )
      self:SetScript( "OnUpdate", self.OnUpdate )
      api().GameTooltip:Hide()
      was_dragging = true
    end

    function frame.OnDragStop( self )
      if m.vanilla then self = this end

      self.dragging = nil
      self:SetScript( "OnUpdate", nil )
      self.icon:SetTexCoord( 0.05, 0.95, 0.05, 0.95 )
      self:UnlockHighlight()
    end

    function frame.OnUpdate( self )
      if m.vanilla then self = this end

      local mx, my = api().Minimap:GetCenter()
      local px, py = api().GetCursorPosition()
      local scale = api().Minimap:GetEffectiveScale()

      px, py = px / scale, py / scale

      persist_angle( m.mod( math.deg( math.atan2( py - my, px - mx ) ), 360 ) )
      self:UpdatePosition()
    end

    -- Copy pasted from Bongos.
    --magic fubar code for updating the minimap button"s position
    --I suck at trig, so I"m not going to bother figuring it out
    ---@diagnostic disable-next-line: redefined-local
    function frame.UpdatePosition( self )
      if m.vanilla then self = this end

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
  set_icon( ColorType.Red )

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
    ColorType = ColorType
  }
end

m.MinimapButton = M
return M
