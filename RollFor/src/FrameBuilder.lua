RollFor = RollFor or {}
local m = RollFor

if m.FrameBuilder then return end

local M = {}

local getn = m.getn

M.interface = {
}

---@alias FrameStyle
---| "Modern"
---| "Classic"

---@class Vector2
---@field x number
---@field y number

---@class FontString
---@field SetFont fun( self: FontString, font: string, size: number, flags: string )
---@field SetText fun( self: FontString, text: string )
---@field SetTextColor fun( self: FontString, r: number, g: number, b: number, a: number )
---@field SetJustifyH fun( self: FontString, justify_h: string )
---@field SetWidth fun( self: FontString, width: number )
---@field SetHeight fun( self: FontString, height: number )
---@field SetPoint fun( self: FontString, point: string, relative_frame: Frame|Texture, relative_point: string, x: number, y: number )

---@class Texture
---@field SetTexture fun( self: Texture, texture: string )
---@field SetWidth fun( self: Texture, width: number )
---@field SetHeight fun( self: Texture, height: number )
---@field SetPoint fun( self: Texture, point: string, relative_frame: Frame|Texture, relative_point: string, x: number, y: number )
---@field SetAllPoints fun( self: Texture, frame: Frame )
---@field SetTexCoord fun( self: Texture, x1: number, x2: number, y1: number, y2: number )
---@field SetBlendMode fun( self: Texture, blend_mode: string )

---@class Frame
---@field add_line fun( line_type: string, modify_fn: function, padding: number ): table
---@field clear fun()
---@field border_color fun( _, r: number, g: number, b: number, a: number )
---@field backdrop_color fun( _, r: number, g: number, b: number, a: number )
---@field lock fun()
---@field unlock fun()
---@field position fun( self: Frame, point: table )
---@field get_anchor_center fun(): Vector2
---@field get_anchor_point fun(): Point
---@field get_point fun(): Point
---@field anchor fun( frame: Frame, point: string, relative_point: string, x: number, y: number )
---@field Show fun( self )
---@field Hide fun( self )
---@field SetWidth fun( frame: Frame, width: number )
---@field SetHeight fun( frame: Frame, height: number )
---@field SetPoint fun( frame: Frame, point: string, relative_frame: Frame|string, relative_point: string, x: number, y: number )
---@field GetScale fun(): number
---@field GetWidth fun(): number
---@field GetHeight fun(): number
---@field ClearAllPoints fun()
---@field IsVisible fun( self ): boolean
---@field GetName fun(): string?
---@field SetFrameStrata fun( self: Frame, strata: string )
---@field CreateTexture fun( self: Frame, name: string?, layer: string ): Texture
---@field SetNormalTexture fun( self: Frame, texture: string )
---@field SetPushedTexture fun( self: Frame, texture: string )
---@field CreateFontString fun( self: Frame, name: string?, layer: string, font: string ): FontString
---@field SetScript fun( self: Frame, event: string, callback: function )
---@field GetTop fun(): number
---@field GetBottom fun(): number
---@field GetLeft fun(): number
---@field GetRight fun(): number
---@field SetPushedTexture fun( self: Frame, texture: string )
---@field SetHighlightTexture fun( self: Frame, texture: string )

---@alias Anchor table

---@alias AnchorPoint
---| "TOPLEFT"
---| "TOPRIGHT"
---| "BOTTOMLEFT"
---| "BOTTOMRIGHT"
---| "CENTER"
---| "TOP"
---| "BOTTOM"
---| "LEFT"
---| "RIGHT"

---@class Point
---@field point AnchorPoint
---@field relative_frame (Frame|string)?
---@field relative_point AnchorPoint
---@field x number?
---@field y number?

---@alias FrameStrata
---| "BACKGROUND"
---| "LOW"
---| "MEDIUM"
---| "HIGH"
---| "DIALOG"
---| "FULLSCREEN"
---| "FULLSCREEN_DIALOG"
---| "TOOLTIP"

---@class FrameBuilder
---@field name fun( self: FrameBuilder, name: string ): FrameBuilder
---@field type fun( self: FrameBuilder, name: string ): FrameBuilder
---@field parent fun( self: FrameBuilder, parent: Frame ): FrameBuilder
---@field height fun( self: FrameBuilder, height: number ): FrameBuilder
---@field width fun( self: FrameBuilder, width: number ): FrameBuilder
---@field point fun( self: FrameBuilder, p: Point ): FrameBuilder
---@field sound fun( self: FrameBuilder ): FrameBuilder
---@field frame_level fun( self: FrameBuilder, frame_level: number ): FrameBuilder
---@field backdrop_color fun( self: FrameBuilder, r: number, g: number, b: number, a: number ): FrameBuilder
---@field bg_file fun( self: FrameBuilder, bg_file: string ): FrameBuilder
---@field edge_file fun( self: FrameBuilder, edge_file: string ): FrameBuilder
---@field esc fun( self: FrameBuilder ): FrameBuilder
---@field gui_elements fun( self: FrameBuilder, gui_elements: table ): FrameBuilder
---@field frame_style fun( self: FrameBuilder, frame_style: FrameStyle ): FrameBuilder
---@field on_drag_stop fun( self: FrameBuilder, callback: function ): FrameBuilder
---@field movable fun( self: FrameBuilder ): FrameBuilder
---@field enable_mouse fun( self: FrameBuilder ): FrameBuilder
---@field border_size fun( self: FrameBuilder, border_size: number ): FrameBuilder
---@field on_show fun( self: FrameBuilder, on_show: function ): FrameBuilder
---@field on_hide fun( self: FrameBuilder, on_hide: function ): FrameBuilder
---@field border_color fun( self: FrameBuilder, r: number, g: number, b: number, a: number ): FrameBuilder
---@field self_centered_anchor fun( self: FrameBuilder ): FrameBuilder
---@field scale fun( self: FrameBuilder, scale: number ): FrameBuilder
---@field strata fun( self: FrameBuilder, strata: FrameStrata ): FrameBuilder
---@field hidden fun( self: FrameBuilder ): FrameBuilder
---@field build fun( self: FrameBuilder ): Frame

---@class FrameBuilderFactory
---@field new fun(): FrameBuilder
---@field button fun(): FrameBuilder
---@field modern fun(): FrameBuilder
---@field classic fun(): FrameBuilder

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
      local type = options.type or "Frame"
      local frame = m.create_backdrop_frame( m.api, type, options.name, options.parent )

      if options.hidden then
        frame:Hide()
      end

      frame:SetWidth( options.width or 280 )
      frame:SetHeight( options.height or 100 )

      if anchor then
        frame:SetPoint( "CENTER", anchor, "CENTER", 0, 0 )
      end

      if options.point then
        local p = options.point
        local f = anchor or frame

        f:SetPoint( p.point, p.relative_frame or m.api.UIParent, p.relative_point, p.x, p.y )
      else
        frame:SetPoint( "CENTER", anchor or m.api.UIParent, "CENTER", 0, 0 )
      end

      if options.frame_level then
        frame:SetFrameLevel( options.frame_level )
      end

      if options.strata then
        frame:SetFrameStrata( options.strata )
      else
        frame:SetFrameStrata( "DIALOG" )
      end

      if options.frame_style == "Modern" then
        frame:SetBackdrop( {
          bgFile = options.bg_file or "Interface/Buttons/WHITE8x8",
          edgeFile = "Interface\\Buttons\\WHITE8X8",
          tile = false,
          tileSize = 0,
          edgeSize = 0.8,
          insets = { left = 0, right = 0, top = 0, bottom = 0 }
        } )
      elseif options.frame_style == "Classic" then
        frame:SetBackdrop( {
          bgFile = options.bg_file or "Interface/Buttons/WHITE8x8",
          edgeFile = options.edge_file or "Interface\\DialogFrame\\UI-DialogBox-Border",
          tile = true,
          tileSize = 22,
          edgeSize = options.border_size or 24,
          insets = { left = 5, right = 5, top = 5, bottom = 5 }
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
        frame:SetBackdropBorderColor( c.r, c.g, c.b, options.frame_style == "Classic" and 1 or c.a )
      end

      return frame
    end

    local function configure_main_frame( frame, anchor )
      if options.sound then
        local old_on_show = frame:GetScript( "OnShow" )

        frame:SetScript( "OnShow", function()
          if m.vanilla then
            m.api.PlaySound( "igMainMenuOpen" )
          else
            m.api.PlaySound( m.api.SOUNDKIT.IG_MAINMENU_OPEN )
          end

          if old_on_show then old_on_show() end
          if options.on_show then options.on_show() end
        end )

        frame:SetScript( "OnHide", function()
          if is_dragging then
            local f = anchor or frame
            f:StopMovingOrSizing()
          end

          if m.vanilla then
            m.api.PlaySound( "igMainMenuClose" )
          else
            m.api.PlaySound( m.api.SOUNDKIT.IG_MAINMENU_CLOSE )
          end

          if options.on_hide then options.on_hide() end
        end )
      end

      if options.enable_mouse then
        frame:EnableMouse( true )
      end

      if options.movable then
        frame:SetMovable( true )
        -- frame:EnableMouse( true )
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

      for i = getn( frame_cache[ line_type ] ), 1, -1 do
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
        if m.vanilla then lines.n = 0 end
      end

      frame.backdrop_color = function( _, r, g, b, a )
        frame:SetBackdropColor( r, g, b, a )
      end

      frame.border_color = function( _, r, g, b, a )
        frame:SetBackdropBorderColor( r, g, b, options.frame_style == "Classic" and 1 or a )
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
        f:SetPoint( point.point, point.anchor or m.api.UIParent, point.relative_point, point.x, point.y )
      end

      frame.get_anchor_center = function()
        local f = anchor or frame
        local x, y = f:GetCenter()

        return { x = x, y = y }
      end

      frame.get_anchor_point = function()
        local f = anchor or frame

        local point, relative_frame, relative_point, x, y = f:GetPoint()
        return point and { point = point, relative_frame = relative_frame, relative_point = relative_point, x = x, y = y }
      end

      frame.get_point = function()
        local f = frame

        local point, relative_frame, relative_point, x, y = f:GetPoint()
        return point and { point = point, relative_frame = relative_frame, relative_point = relative_point, x = x, y = y }
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

  local function type( self, v )
    options.type = v
    return self
  end

  local function parent( self, v )
    options.parent = v
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
    options.point = { point = p.point, relative_frame = p.relative_frame or m.api.UIParent, relative_point = p.relative_point, x = p.x or 0, y = p.y or 0 }
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

  local function edge_file( self, v )
    options.edge_file = v
    return self
  end

  local function gui_elements( self, t )
    options.gui_elements = t
    return self
  end

  ---@param self FrameBuilder
  ---@param v FrameStyle
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

  local function enable_mouse( self )
    options.enable_mouse = true
    return self
  end

  local function strata( self, v )
    options.strata = v
    return self
  end

  local function hidden( self )
    options.hidden = true
    return self
  end

  ---@type FrameBuilder
  return {
    name = name,
    type = type,
    parent = parent,
    height = height,
    width = width,
    point = point,
    sound = sound,
    frame_level = frame_level,
    backdrop_color = backdrop_color,
    bg_file = bg_file,
    edge_file = edge_file,
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
    enable_mouse = enable_mouse,
    strata = strata,
    hidden = hidden,
    build = build
  }
end

function M.button()
  return M.new():type( "Button" )
end

function M.modern()
  return M.new()
      :frame_style( "Modern" )
end

function M.classic()
  return M.new()
      :frame_style( "Classic" )
      :border_size( 25 )
end

m.FrameBuilder = M

return M
