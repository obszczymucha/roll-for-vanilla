RollFor = RollFor or {}
local m = RollFor

if m.FrameBuilder then return end

local M = {}

local getn = m.getn

-- M.new declares a builder method called `type`, which shadows the global from its declaration
-- on, so anything below it that needs the real one goes through this.
local type_of = type

local scroll_bar_width = 4
local scroll_thumb_min_height = 12
local scroll_default_step = 3

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
---@field SetVertexColor fun( self: Texture, r: number, g: number, b: number, a: number? )
---@field ClearAllPoints fun( self: Texture )
---@field Show fun( self: Texture )
---@field Hide fun( self: Texture )
---@field SetWidth fun( self: Texture, width: number )
---@field SetHeight fun( self: Texture, height: number )
---@field SetPoint fun( self: Texture, point: string, relative_frame: Frame|Texture, relative_point: string, x: number, y: number )
---@field SetAllPoints fun( self: Texture, frame: Frame )
---@field SetTexCoord fun( self: Texture, x1: number, x2: number, y1: number, y2: number )
---@field SetBlendMode fun( self: Texture, blend_mode: string )

---@class Frame
---@field add_line fun( line_type: string, modify_fn: function, padding: number ): table? -- nil when the line falls outside the scroll window (see `scrollable`)
---@field clear fun()
---@field set_scroll_total fun( self: Frame, total: number )
---@field get_scroll fun(): table
---@field scroll_by fun( self: Frame, delta: number )
---@field update_scrollbar fun( lines: table )
---@field EnableMouseWheel fun( self: Frame, enabled: boolean )
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
---@field anchor_point fun( self: FrameBuilder, point: string ): FrameBuilder
---@field scale fun( self: FrameBuilder, scale: number ): FrameBuilder
---@field strata fun( self: FrameBuilder, strata: FrameStrata ): FrameBuilder
---@field hidden fun( self: FrameBuilder ): FrameBuilder
---@field scrollable fun( self: FrameBuilder, opts: table ): FrameBuilder
---@field on_scroll fun( self: FrameBuilder, callback: function ): FrameBuilder
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

  -- Scroll viewport state (see the `scrollable` builder method below). `offset` is how many
  -- scrollable lines are hidden above the window, `total` how many the caller last said there
  -- are, and `index` counts them off again during the current render pass.
  local scroll = { offset = 0, total = 0, index = 0 }

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
        local pin_point = options.anchor_point or "CENTER"
        frame:SetPoint( pin_point, anchor, pin_point, 0, 0 )
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
          m.api.PlaySound( m.api.SOUNDKIT.IG_MAINMENU_OPEN )

          if old_on_show then old_on_show() end
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
            local pin_point = options.anchor_point or "CENTER"
            frame:ClearAllPoints()
            frame:SetPoint( pin_point, anchor, pin_point, 0, 0 )
          end
        end )
      else
        frame:SetMovable( false )
      end

      frame:EnableMouse( true )

      if options.scroll then
        frame:EnableMouseWheel( true )
        frame:SetScript( "OnMouseWheel", function( _, delta )
          -- Wheel up (delta 1) shows earlier lines, i.e. a smaller offset.
          frame.scroll_by( frame, -(delta or 0) * options.scroll.step )
        end )
      end

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
      -- Lines outside the scroll window are never created, so a 900-row tree costs the same
      -- handful of frames a 20-row one does. Skipped lines don't enter `lines` either, which is
      -- what keeps the caller's chain anchoring (each line anchored under lines[ #lines ]) right
      -- without it knowing scrolling exists at all.
      local function is_scrolled_out( line_type )
        if not options.scroll or not options.scroll.line_types[ line_type ] then return false end

        scroll.index = scroll.index + 1

        return scroll.index <= scroll.offset or scroll.index > scroll.offset + options.scroll.max_lines
      end

      frame.add_line = function( line_type, modify_fn, padding )
        if is_scrolled_out( line_type ) then return end

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
        if options.scroll then frame.update_scrollbar( lines ) end

        return line
      end

      frame.clear = function()
        for _, line in ipairs( lines ) do
          line.frame:Hide()

          line.frame.is_used = false
        end

        m.clear_table( lines )
        scroll.index = 0
      end

      -- How many scrollable lines the caller is about to add, in full -- not just the ones that
      -- will fit. Told rather than counted because the window has to be picked before the first
      -- line is added, and because a total that shrank (a collapsed node) has to clamp the offset
      -- right then: counting during the pass would only notice after rendering an empty window.
      ---@param total number
      frame.set_scroll_total = function( _, total )
        scroll.total = total or 0
        local max_offset = scroll.total - (options.scroll and options.scroll.max_lines or 0)
        if max_offset < 0 then max_offset = 0 end
        if scroll.offset > max_offset then scroll.offset = max_offset end
      end

      ---@return table -- { offset, total, max_lines }, read-only as far as callers are concerned
      frame.get_scroll = function()
        return { offset = scroll.offset, total = scroll.total, max_lines = options.scroll and options.scroll.max_lines or 0 }
      end

      -- Moves the window by `delta` lines and lets the caller redraw. Nothing is re-anchored here:
      -- on_scroll runs the caller's own refresh, which clears and re-adds lines against the new
      -- offset, so scrolling and any other content change take exactly the same path.
      ---@param delta number
      frame.scroll_by = function( _, delta )
        if not options.scroll then return end

        local max_offset = scroll.total - options.scroll.max_lines
        if max_offset < 0 then max_offset = 0 end

        local offset = scroll.offset + delta
        if offset < 0 then offset = 0 end
        if offset > max_offset then offset = max_offset end
        if offset == scroll.offset then return end

        scroll.offset = offset
        if options.on_scroll then options.on_scroll() end
      end

      local scroll_bar, scroll_thumb

      local function create_scroll_bar()
        if scroll_bar then return end

        scroll_bar = frame:CreateTexture( nil, "ARTWORK" )
        scroll_bar:SetTexture( "Interface\\Buttons\\WHITE8x8" )
        scroll_bar:SetVertexColor( 1, 1, 1, 0.08 )
        scroll_bar:SetWidth( scroll_bar_width )

        scroll_thumb = frame:CreateTexture( nil, "OVERLAY" )
        scroll_thumb:SetTexture( "Interface\\Buttons\\WHITE8x8" )
        scroll_thumb:SetVertexColor( 0.351, 0.553, 1.0, 0.55 )
        scroll_thumb:SetWidth( scroll_bar_width )
      end

      local function hide_scroll_bar()
        if not scroll_bar then return end

        scroll_bar:Hide()
        scroll_thumb:Hide()
      end

      -- A slim track down the popup's right edge, spanning exactly the scrollable lines currently
      -- on screen, with a thumb sized and placed by the window. Indicator only -- the wheel does
      -- the scrolling. The track's own top/height are measured off the lines rather than anchored
      -- to them: line frames are sized to their content, so anchoring to one would make the bar
      -- shift sideways row by row.
      ---@param current_lines table
      frame.update_scrollbar = function( current_lines )
        local config = options.scroll

        if not config or scroll.total <= config.max_lines then
          hide_scroll_bar()
          return
        end

        local y = config.top_padding
        local height = 0
        local started = false

        for _, line in ipairs( current_lines ) do
          local line_frame = line.frame
          local scale = line_frame.GetScale and line_frame:GetScale() or 1
          local line_height = line_frame:GetHeight() * scale

          if config.line_types[ line.line_type ] then
            if started then
              height = height + line.padding
            else
              started = true
              y = y + line.padding
            end

            height = height + line_height
          elseif not started then
            y = y + line_height + line.padding
          end
        end

        if not started or height <= 0 then
          hide_scroll_bar()
          return
        end

        create_scroll_bar()

        scroll_bar:ClearAllPoints()
        scroll_bar:SetPoint( "TOPRIGHT", frame, "TOPRIGHT", -config.right_inset, -y )
        scroll_bar:SetHeight( height )
        scroll_bar:Show()

        local thumb_height = height * config.max_lines / scroll.total
        if thumb_height < scroll_thumb_min_height then thumb_height = scroll_thumb_min_height end

        local travel = height - thumb_height
        local progress = scroll.offset / (scroll.total - config.max_lines)

        scroll_thumb:ClearAllPoints()
        scroll_thumb:SetPoint( "TOP", scroll_bar, "TOP", 0, -(travel * progress) )
        scroll_thumb:SetHeight( thumb_height )
        scroll_thumb:Show()
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

  -- Which point of the frame stays pinned to the (self-centered) anchor when the frame resizes.
  -- Defaults to "CENTER" (grows/shrinks symmetrically); "TOP" keeps the top edge fixed and only
  -- moves the bottom, "BOTTOM" the reverse, etc.
  local function anchor_point( self, p )
    options.anchor_point = p
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

  -- Turns the frame into a viewport: at most `max_lines` lines of the given type(s) are rendered
  -- at once and the mouse wheel moves the window, so the frame's height stops growing with its
  -- content. Everything else (a title, buttons) stays put outside the window.
  --
  -- The caller keeps rendering its full list exactly as before -- add_line simply drops the lines
  -- that fall outside the window -- but it owes two things: :on_scroll( fn ) to redraw after the
  -- wheel moves, and popup:set_scroll_total( n ) before each pass so the window and the scrollbar
  -- know how long the list really is.
  --
  -- `top_padding` is the same offset the caller uses to place its first line under the frame's
  -- top edge; the scrollbar needs it to line up with the rows.
  ---@param opts table -- { line_types = string|string[], max_lines = number, top_padding = number?, right_inset = number?, step = number? }
  local function scrollable( self, opts )
    local line_types = {}

    if type_of( opts.line_types ) == "table" then
      for _, line_type in ipairs( opts.line_types ) do line_types[ line_type ] = true end
    else
      line_types[ opts.line_types ] = true
    end

    options.scroll = {
      line_types = line_types,
      max_lines = opts.max_lines,
      top_padding = opts.top_padding or 0,
      right_inset = opts.right_inset or 6,
      step = opts.step or scroll_default_step
    }

    return self
  end

  local function on_scroll( self, f )
    options.on_scroll = f
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
    anchor_point = anchor_point,
    scale = scale,
    enable_mouse = enable_mouse,
    strata = strata,
    hidden = hidden,
    scrollable = scrollable,
    on_scroll = on_scroll,
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
