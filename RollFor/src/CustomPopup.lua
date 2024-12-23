RollFor = RollFor or {}
local m = RollFor

if m.CustomPopup then return end

local blue = m.colors.blue
---@diagnostic disable-next-line: deprecated
local getn = table.getn

local M = {}

function M.builder()
  local options = {}
  local frame_cache = {}
  local lines = {}
  local is_dragging

  local function create_popup()
    local title_edge_size = 10
    local edge_size = 20
    local button_padding = 10
    local top_padding = 14
    local bottom_margin = 33
    local title_visible = false

    local function create_anchor()
      local anchor = m.api.CreateFrame( "Frame", nil, m.api.UIParent )
      anchor:SetWidth( 1 )
      anchor:SetHeight( 1 )
      anchor:SetPoint( "CENTER", 0, 0 )
      anchor:EnableMouse( true )
      anchor:SetMovable( true )

      return anchor
    end

    local function create_title_frame( parent )
      local title_frame = m.api.CreateFrame( "Frame", nil, parent )
      title_frame:SetWidth( 1 )
      title_frame:SetHeight( 1 )
      title_frame:SetPoint( "TOP", parent, "TOP", 50, 4.5 )

      local title = title_frame:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
      title:SetPoint( "TOP", title_frame, "TOP", 0, -1.5 )
      title:SetText( blue( "RollFor" ) )

      local title_bg = m.api.CreateFrame( "Frame", nil, parent )
      title_bg:SetBackdrop( {
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        edgeSize = title_edge_size,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
      } )
      title_bg:SetBackdropColor( 0, 0, 0, 0 )
      title_bg:SetWidth( title:GetStringWidth() + 30 )
      title_bg:SetHeight( 20 )
      title_bg:SetPoint( "CENTER", title, "CENTER" )

      local title_bg_bg = m.api.CreateFrame( "Frame", nil, title_bg )
      title_bg_bg:SetBackdrop( {
        bgFile = "Interface/Buttons/WHITE8x8",
        tile = true,
        tileSize = 8
      } )
      title_bg_bg:SetBackdropColor( 0, 0, 0, 1 )
      title_bg_bg:SetPoint( "TOPLEFT", title_bg, "TOPLEFT", 4, -4 )
      title_bg_bg:SetPoint( "BOTTOMRIGHT", title_bg, "BOTTOMRIGHT", -4, 4 )
      title_bg_bg:SetFrameLevel( title_bg:GetFrameLevel() )
      title_frame:SetFrameLevel( title_bg:GetFrameLevel() + 1 )
    end

    local function create_main_frame( anchor )
      local frame = m.api.CreateFrame( "Frame", options.name, anchor )
      frame:Hide()
      frame:SetWidth( options.width or 280 )
      frame:SetHeight( options.height or 100 )
      frame:SetPoint( "CENTER", anchor, "CENTER", 0, 0 )

      if options.point then
        local p = options.point
        anchor:SetPoint( p.point, m.api.UIParent, p.relative_point, p.x, p.y )
      else
        anchor:SetPoint( "CENTER", 0, 0 )
      end

      if options.frame_level then
        frame:SetFrameLevel( options.frame_level )
      else
        frame:SetFrameStrata( "DIALOG" )
      end

      if options.frame_style then
        frame:SetBackdrop( {
          bgFile = options.bg_file or "Interface/Tooltips/UI-Tooltip-Background",
          edgeFile = "Interface\\Buttons\\WHITE8X8",
          tile = false,
          tileSize = 0,
          edgeSize = 1,
          insets = { left = 0, right = 0, top = 0, bottom = 0 }
        } )
      else
        frame:SetBackdrop( {
          bgFile = options.bg_file or "Interface/Tooltips/UI-Tooltip-Background",
          edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
          tile = true,
          tileSize = 22,
          edgeSize = options.border_size or edge_size,
          insets = { left = 3, right = 3, top = 3, bottom = 3 }
        } )
      end

      if options.backdrop_color then
        local c = options.backdrop_color
        frame:SetBackdropColor( c.r, c.g, c.b, c.a or 1 )
      else
        frame:SetBackdropColor( 0, 0, 0, 0.7 )
      end

      if options.border_color then
        local c = options.border_color
        frame:SetBackdropBorderColor( c.r, c.g, c.b, c.a )
      end

      return frame
    end

    local function align_buttons( parent )
      if not parent.buttons_frame then
        local frame = m.api.CreateFrame( "Frame", nil, parent )
        frame:SetPoint( "BOTTOM", 0, 11 )
        parent.buttons_frame = frame
      end

      local total_width = 0
      local max_height = 0
      local last_anchor = nil

      local buttons = m.filter( lines, function( line ) return line.line_type == "button" end )

      for _, button in ipairs( buttons ) do
        local frame = button.frame
        local height = frame:GetHeight()
        local width = frame:GetWidth()
        local scale = frame:GetScale()

        if height > max_height then max_height = height end

        if not last_anchor then
          frame:SetPoint( "LEFT", parent.buttons_frame, "LEFT", 0, 0 )
        else
          frame:SetPoint( "LEFT", last_anchor, "RIGHT", button_padding, 0 )
          total_width = total_width + button_padding
        end

        total_width = total_width + (width * scale)
        last_anchor = frame
      end

      parent.buttons_frame:SetWidth( total_width )
      parent.buttons_frame:SetHeight( max_height )
    end

    local function configure_main_frame( frame, anchor )
      if options.with_sound then
        frame:SetScript( "OnShow", function()
          m.api.PlaySound( "igMainMenuOpen" )
          if options.on_show then options.on_show() end
        end )

        frame:SetScript( "OnHide", function()
          if is_dragging then
            anchor:StopMovingOrSizing()
          end

          m.api.PlaySound( "igMainMenuClose" )
          if options.on_hide then options.on_hide() end
        end )
      end

      if options.movable then
        frame:SetMovable( true )
      else
        frame:SetMovable( false )
      end

      frame:EnableMouse( true )

      if options.on_drag_stop then
        frame:RegisterForDrag( "LeftButton" )
        frame:SetScript( "OnDragStart", function()
          if not frame:IsMovable() then return end
          is_dragging = true
          ---@diagnostic disable-next-line: undefined-global
          anchor:StartMoving()
        end )
        frame:SetScript( "OnDragStop", function()
          is_dragging = false
          ---@diagnostic disable-next-line: undefined-global
          anchor:StopMovingOrSizing(); options.on_drag_stop()
        end )
      end

      if options.esc then
        m.api.tinsert( m.api.UISpecialFrames, frame:GetName() )
      end
    end

    local function get_from_cache( line_type )
      frame_cache[ line_type ] = frame_cache[ line_type ] or {}

      for i = getn( frame_cache[ line_type ] ), 1, -1 do
        if not frame_cache[ line_type ][ i ].is_used then
          return frame_cache[ line_type ][ i ]
        end
      end
    end

    local function get_total_width( buttons )
      local result = 0

      for _, button in ipairs( buttons ) do
        local frame = button.frame
        result = result + frame:GetWidth() * frame:GetScale()
      end

      return result
    end

    local function resize( parent )
      local max_width = 0
      local height = 0

      for _, line in ipairs( lines ) do
        if line.line_type ~= "button" and line.line_type ~= "info" then
          local frame = line.frame
          local scale = frame.GetScale and frame:GetScale() or 1
          local width = frame:GetWidth() * scale

          height = height + frame:GetHeight() * scale
          height = height + line.padding
          if width > max_width then max_width = width end
        end
      end


      local buttons = m.filter( lines, function( line ) return line.line_type == "button" end )
      local button_count = getn( buttons )
      local button_width = get_total_width( buttons ) + (button_count - 1) * button_padding

      if button_width > max_width then max_width = button_width end

      if getn( buttons ) > 0 then
        height = height + 23
      end

      parent:SetWidth( max_width + 50 )
      parent:SetHeight( height + bottom_margin )

      align_buttons( parent )
    end

    local function add_api_to( popup, anchor )
      popup.add_line = function( line_type, modify_fn, padding )
        local frame = get_from_cache( line_type )

        if not frame then
          local creator_fn = options.gui_elements and options.gui_elements[ line_type ] or nil
          if not creator_fn then return end

          frame = creator_fn( popup )
          frame.is_used = true
          table.insert( frame_cache[ line_type ], frame )
        else
          frame.is_used = true
          frame:Show()
        end

        local count = getn( lines )

        if line_type ~= "button" then
          if count == 0 then
            local y = -top_padding - (padding or 0)
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", popup, "TOP", 0, y )
          else
            local line_anchor = lines[ count ].frame
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", line_anchor, "BOTTOM", 0, padding and -padding or 0 )
          end
        end

        modify_fn( line_type, frame )
        local line = { line_type = line_type, padding = padding or 0, frame = frame }
        table.insert( lines, line )
        resize( popup )

        return line
      end

      popup.clear = function()
        for _, line in ipairs( lines ) do
          line.frame:Hide()
          line.frame.is_used = false
        end

        m.clear_table( lines )
        lines.n = 0
      end

      popup.border_color = function( _, r, g, b, a )
        popup:SetBackdropBorderColor( r, g, b, a )
      end

      popup.lock = function()
        popup:SetMovable( false )
      end

      popup.unlock = function()
        popup:SetMovable( true )
      end

      popup.position = function( _, point )
        anchor:ClearAllPoints()
        anchor:SetPoint( point.point, m.api.UIParent, point.relative_point, point.x, point.y )
      end

      popup.get_anchor_center = function()
        return anchor:GetCenter()
      end

      popup.get_anchor_point = function()
        return anchor:GetPoint()
      end

      popup.anchor = function( _, frame, point, relative_point, x, y )
        frame:ClearAllPoints()
        frame:SetPoint( point, anchor, relative_point, x, y )
      end
    end

    local anchor = create_anchor()
    local frame = create_main_frame( anchor )
    if title_visible then create_title_frame( frame ) end
    configure_main_frame( frame, anchor )
    add_api_to( frame, anchor )

    return frame, anchor
  end

  local function with_name( self, name )
    options.name = name
    return self
  end

  local function with_height( self, height )
    options.height = height
    return self
  end

  local function with_width( self, width )
    options.width = width
    return self
  end

  local function with_point( self, p )
    options.point = { point = p.point, relative_point = p.relative_point, x = p.x, y = p.y }
    return self
  end

  local function with_sound( self )
    options.with_sound = true
    return self
  end

  local function with_frame_level( self, frame_level )
    options.frame_level = frame_level
    return self
  end

  local function with_esc( self )
    options.esc = true
    return self
  end

  local function build()
    return create_popup()
  end

  local function with_backdrop_color( self, r, g, b, a )
    options.backdrop_color = { r = r, g = g, b = b, a = a }
    return self
  end

  local function with_bg_file( self, bg_file )
    options.bg_file = bg_file
    return self
  end

  local function with_gui_elements( self, gui_elements )
    options.gui_elements = gui_elements
    return self
  end

  local function with_frame_style( self, frame_style )
    options.frame_style = frame_style
    return self
  end

  local function with_on_drag_stop( self, callback )
    options.on_drag_stop = callback
    return self
  end

  local function with_movable( self )
    options.movable = true
    return self
  end

  local function with_border_size( self, border_size )
    options.border_size = border_size
    return self
  end

  local function with_on_show( self, on_show )
    options.on_show = on_show
    return self
  end

  local function with_on_hide( self, on_hide )
    options.on_hide = on_hide
    return self
  end

  local function with_border_color( self, r, g, b, a )
    options.border_color = { r = r, g = g, b = b, a = a }
    return self
  end

  return {
    with_name = with_name,
    with_height = with_height,
    with_width = with_width,
    with_point = with_point,
    with_sound = with_sound,
    with_frame_level = with_frame_level,
    with_backdrop_color = with_backdrop_color,
    with_bg_file = with_bg_file,
    with_esc = with_esc,
    with_gui_elements = with_gui_elements,
    with_frame_style = with_frame_style,
    with_on_drag_stop = with_on_drag_stop,
    with_movable = with_movable,
    with_border_size = with_border_size,
    with_on_show = with_on_show,
    with_on_hide = with_on_hide,
    with_border_color = with_border_color,
    build = build
  }
end

m.CustomPopup = M
return M
