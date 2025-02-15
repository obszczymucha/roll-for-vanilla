RollFor = RollFor or {}
local m = RollFor

if m.FrameBuilder then return end

local M = {}

M.interface = {

}
---@class Frame
---@field add_line fun( line_type: string, modify_fn: function, padding: number ): table
---@field clear fun()
---@field border_color fun( _, r: number, g: number, b: number, a: number )
---@field backdrop_color fun( _, r: number, g: number, b: number, a: number )
---@field lock fun()
---@field unlock fun()
---@field position fun( self: Frame, point: table )
---@field get_anchor_center fun(): table
---@field get_anchor_point fun(): table
---@field anchor fun( frame: Frame, point: string, relative_point: string, x: number, y: number )
---@field Show fun( self )
---@field Hide fun( self )
---@field SetWidth fun( frame: Frame, width: number )
---@field SetHeight fun( frame: Frame, height: number )
---@field SetPoint fun( frame: Frame, point: string, relative_frame: Frame, relative_point: string, x: number, y: number )
---@field GetScale fun(): number
---@field GetWidth fun(): number
---@field GetHeight fun(): number
---@field ClearAllPoints fun()
---@field IsVisible fun( self ): boolean
---@field GetName fun(): string?

---@alias Anchor table

---@class FrameBuilder
---@field name fun( self: FrameBuilder, name: string ): FrameBuilder
---@field height fun( self: FrameBuilder, height: number ): FrameBuilder
---@field width fun( self: FrameBuilder, width: number ): FrameBuilder
---@field point fun( self: FrameBuilder, p: table ): FrameBuilder
---@field sound fun( self: FrameBuilder ): FrameBuilder
---@field frame_level fun( self: FrameBuilder, frame_level: number ): FrameBuilder
---@field backdrop_color fun( self: FrameBuilder, r: number, g: number, b: number, a: number ): FrameBuilder
---@field bg_file fun( self: FrameBuilder, bg_file: string ): FrameBuilder
---@field esc fun( self: FrameBuilder ): FrameBuilder
---@field gui_elements fun( self: FrameBuilder, gui_elements: table ): FrameBuilder
---@field frame_style fun( self: FrameBuilder, frame_style: string ): FrameBuilder
---@field on_drag_stop fun( self: FrameBuilder, callback: function ): FrameBuilder
---@field movable fun( self: FrameBuilder ): FrameBuilder
---@field border_size fun( self: FrameBuilder, border_size: number ): FrameBuilder
---@field on_show fun( self: FrameBuilder, on_show: function ): FrameBuilder
---@field on_hide fun( self: FrameBuilder, on_hide: function ): FrameBuilder
---@field border_color fun( self: FrameBuilder, r: number, g: number, b: number, a: number ): FrameBuilder
---@field self_centered_anchor fun( self: FrameBuilder ): FrameBuilder
---@field scale fun( self: FrameBuilder, scale: number ): FrameBuilder
---@field build fun( self: FrameBuilder ): Frame

---@class FrameBuilderFactory
---@field new fun(): FrameBuilder

---@return FrameBuilder
function M.new()
  local options = {}
  local frame_cache = {}
  local lines = {}
  local is_dragging

  local function create_frame()
    local function create_anchor()
      local anchor = m.api.CreateFrame( "Frame", nil, m.api.UIParent )
      anchor:SetWidth( 1 )
      anchor:SetHeight( 1 )
      anchor:SetPoint( "CENTER", 0, 0 )
      anchor:EnableMouse( true )
      anchor:SetMovable( true )

      return anchor
    end

    local function create_main_frame( anchor )
      local frame = m.api.CreateFrame( "Frame", options.name, m.api.UIParent, "BackdropTemplate" )

      frame:Hide()
      frame:SetWidth( options.width or 280 )
      frame:SetHeight( options.height or 100 )

      if anchor then
        frame:SetPoint( "CENTER", anchor, "CENTER", 0, 0 )
      end

      if options.point then
        local p = options.point
        local f = anchor or frame

        f:SetPoint( p.point, m.api.UIParent, p.relative_point, p.x, p.y )
      else
        frame:SetPoint( "CENTER", anchor or m.api.UIParent, "CENTER", 0, 0 )
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
          edgeSize = 0.8,
          insets = { left = 0, right = 0, top = 0, bottom = 0 }
        } )
      else
        frame:SetBackdrop( {
          bgFile = options.bg_file or "Interface/Tooltips/UI-Tooltip-Background",
          edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
          tile = true,
          tileSize = 22,
          edgeSize = options.border_size or 0,
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

    local function configure_main_frame( frame, anchor )
      if options.sound then
        frame:SetScript( "OnShow", function()
          m.api.PlaySound( m.api.SOUNDKIT.IG_MAINMENU_OPEN )
          if options.on_show then options.on_show() end
        end )

        frame:SetScript( "OnHide", function()
          if is_dragging then
            local f = anchor or frame
            f:StopMovingOrSizing()
          end

          m.api.PlaySound( m.api.SOUNDKIT.IG_MAINMENU_CLOSE )
          if options.on_hide then options.on_hide() end
        end )
      end

      if options.movable then
        frame:SetMovable( true )
        frame:RegisterForDrag( "LeftButton" )
        frame:SetScript( "OnDragStart", function()
          if not frame:IsMovable() then return end
          is_dragging = true

          local f = anchor or frame
          f:StartMoving()
        end )

        frame:SetScript( "OnDragStop", function()
          is_dragging = false

          local f = anchor or frame
          f:StopMovingOrSizing()

          if options.on_drag_stop then
            options.on_drag_stop( frame )
          end

          if anchor then
            frame:ClearAllPoints()
            frame:SetPoint( "CENTER", anchor, "CENTER", 0, 0 )
          end
        end )
      else
        frame:SetMovable( false )
      end

      frame:EnableMouse( true )

      if options.esc then
        m.api.tinsert( m.api.UISpecialFrames, frame:GetName() )
      end

      if options.scale then
        frame:SetScale( options.scale )
      end
    end

    local function get_from_cache( line_type )
      frame_cache[ line_type ] = frame_cache[ line_type ] or {}

      for i = #frame_cache[ line_type ], 1, -1 do
        if not frame_cache[ line_type ][ i ].is_used then
          return frame_cache[ line_type ][ i ]
        end
      end
    end

    local function add_api_to( frame, anchor )
      frame.add_line = function( line_type, modify_fn, padding )
        local line_frame = get_from_cache( line_type )

        if not line_frame then
          local creator_fn = options.gui_elements and options.gui_elements[ line_type ] or nil
          if not creator_fn then return end

          line_frame = creator_fn( frame )
          line_frame.is_used = true
          table.insert( frame_cache[ line_type ], line_frame )
        else
          line_frame.is_used = true
          line_frame:Show()
        end

        modify_fn( line_type, line_frame, lines )
        local line = { line_type = line_type, padding = padding or 0, frame = line_frame }
        table.insert( lines, line )

        if frame.resize then frame:resize( lines ) end

        return line
      end

      frame.clear = function()
        for _, line in ipairs( lines ) do
          line.frame:Hide()

          line.frame.is_used = false
        end

        m.clear_table( lines )
        lines.n = 0
      end

      frame.backdrop_color = function( _, r, g, b, a )
        frame:SetBackdropColor( r, g, b, a )
      end

      frame.border_color = function( _, r, g, b, a )
        frame:SetBackdropBorderColor( r, g, b, a )
      end

      frame.lock = function()
        frame:SetMovable( false )
      end

      frame.unlock = function()
        frame:SetMovable( true )
      end

      frame.position = function( _, point )
        local f = anchor or frame

        f:ClearAllPoints()
        f:SetPoint( point.point, m.api.UIParent, point.relative_point, point.x, point.y )
      end

      frame.get_anchor_center = function()
        local f = anchor or frame

        return f:GetCenter()
      end

      frame.get_anchor_point = function()
        local f = anchor or frame

        return f:GetPoint()
      end

      frame.anchor = function( _, source_frame, point, relative_point, x, y )
        if anchor then
          source_frame:ClearAllPoints()
          source_frame:SetPoint( point, anchor, relative_point, x, y )
        else
          source_frame:ClearAllPoints()
          source_frame:SetPoint( point, m.api.UIParent, relative_point, x, y )
        end
      end
    end

    local self_centered_anchor = options.self_centered_anchor and create_anchor()
    local frame = create_main_frame( self_centered_anchor )
    configure_main_frame( frame, self_centered_anchor )
    add_api_to( frame, self_centered_anchor )

    return frame, self_centered_anchor
  end

  local function name( self, v )
    options.name = v
    return self
  end

  local function height( self, v )
    options.height = v
    return self
  end

  local function width( self, v )
    options.width = v
    return self
  end

  local function point( self, p )
    options.point = { point = p.point, relative_point = p.relative_point, x = p.x, y = p.y }
    return self
  end

  local function sound( self )
    options.sound = true
    return self
  end

  local function frame_level( self, v )
    options.frame_level = v
    return self
  end

  local function esc( self )
    options.esc = true
    return self
  end

  ---@return Frame
  ---@return Anchor
  local function build()
    return create_frame()
  end

  local function backdrop_color( self, r, g, b, a )
    options.backdrop_color = { r = r, g = g, b = b, a = a }
    return self
  end

  local function bg_file( self, v )
    options.bg_file = v
    return self
  end

  local function gui_elements( self, t )
    options.gui_elements = t
    return self
  end

  local function frame_style( self, v )
    options.frame_style = v
    return self
  end

  local function on_drag_stop( self, callback )
    options.on_drag_stop = callback
    return self
  end

  local function movable( self )
    options.movable = true
    return self
  end

  local function border_size( self, v )
    options.border_size = v
    return self
  end

  local function on_show( self, f )
    options.on_show = f
    return self
  end

  local function on_hide( self, f )
    options.on_hide = f
    return self
  end

  local function border_color( self, r, g, b, a )
    options.border_color = { r = r, g = g, b = b, a = a }
    return self
  end

  local function self_centered_anchor( self )
    options.self_centered_anchor = true
    return self
  end

  local function scale( self, v )
    options.scale = v
    return self
  end

  return {
    name = name,
    height = height,
    width = width,
    point = point,
    sound = sound,
    frame_level = frame_level,
    backdrop_color = backdrop_color,
    bg_file = bg_file,
    esc = esc,
    gui_elements = gui_elements,
    frame_style = frame_style,
    on_drag_stop = on_drag_stop,
    movable = movable,
    border_size = border_size,
    on_show = on_show,
    on_hide = on_hide,
    border_color = border_color,
    self_centered_anchor = self_centered_anchor,
    scale = scale,
    build = build
  }
end

m.FrameBuilder = M
return M
