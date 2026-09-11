RollFor = RollFor or {}
local m = RollFor

if m.ListPopup then return end

local M = {}
local getn = m.getn

-- The shell the list windows are all built out of: a draggable popup
-- that remembers where it was left, a refresh that rebuilds itself from a content
-- transformer, and show/hide/toggle on a slash command.
--
-- What actually differs between those windows is small -- the frame's name, the slash
-- command, which row widget it lists, and where its rows and buttons come from -- so
-- that is all the caller supplies. Everything below this line was previously copied
-- once per window, which is how three of them ended up with three chances to fix the
-- same layout bug.
--
-- Rows are laid out by chaining each line under the one before it. Centred by default, which
-- is right when every row widget reports the same fixed width for the reason GuiElements
-- documents: the popup sizes itself from the widest line, so self-measuring rows would let the
-- columns drift between windows.
--
-- A window whose rows measure themselves -- nothing anchored to their right edge, so their width
-- is whatever their content came to -- wants `align = "LEFT"` instead: centring rows of differing
-- widths fans them out around the middle of the window rather than starting them in a column.

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

-- Clearance above the first line. A window with a border needs enough of it that the rows are not
-- crowded by the frame; one built without a border (see no_border) is asking for the opposite,
-- and says so by passing its own.
local default_top_padding = 16

-- UIPanelCloseButtonNoScripts is 32x32, which is most of a title bar, so it is scaled rather than
-- resized -- SetWidth on a textured button stretches the artwork. The offsets are in screen
-- pixels and divided back out by the scale at the anchor, the same way the queue row's buttons
-- are. They are two numbers rather than one inset because the artwork is not centred in its own
-- frame, so the corner it wants is not the same distance in on both axes.
local close_button_scale = 0.7
local close_button_x = -6
local close_button_y = -8

-- How far in from the popup's right edge the scrollbar sits. FrameBuilder's own default is 6,
-- which sits tight against this window's border.
local scroll_bar_right_inset = 11

-- What a list popup has always looked like. Windows that want something else say so in their own
-- config rather than changing it here, because this is every list window's border, not one.
local default_border_color = { 0.65, 0.22, 0.22, 0.22 }

---@class ListPopup
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field refresh_if_visible fun()
---@field get_frame fun(): Popup?

---@class ListPopupConfig
---@field name string -- the global frame name
---@field slash_command string? -- without the leading slash; omitted by a window that registers its
--- own, which is what a window with rules about when it may open at all has to do -- the toggle
--- below opens it unconditionally
---@field db table -- where the window position is remembered
---@field popup_builder PopupBuilder
---@field content_transformer table -- anything with transform( data ): table
---@field content fun(): table -- the model handed to the transformer, read fresh per refresh
---@field row_type string -- the name of the GuiElements line type its rows use
---@field row_callback string? -- the field a row carries that its widget calls back on
---@field close_button boolean? -- an X in the top right corner instead of a Close in the button row
---@field right_click_hides boolean? -- right-clicking the window closes it, for windows with no
--- close button of any kind. A row widget that takes the mouse has to hand the right-click on to
--- the window itself, or only the bare parts of it would answer
---@field border_color number[]? -- { r, g, b, a }; defaults to the red every list popup shipped with
---@field no_border boolean? -- no frame edge at all, leaving the backdrop on its own. Not the
--- same as a transparent border_color, which the classic frame style overrides
---@field top_padding number? -- clearance above the first line; defaults to 16
---@field backdrop_color number[]? -- { r, g, b, a }; defaults to the frame style's own fill
---@field esc boolean? -- whether Escape closes it
---@field header_type string? -- a widget drawn like a row but outside the scroll viewport
---@field max_rows (fun(): number)? -- rows shown before the list scrolls; nil for no limit. A
--- function, not a number, because it is a user setting that can change while the window is open.
---@field align ListPopupAlignment? -- how lines sit across the window; defaults to centred

---Where a line is pinned across the window. "LEFT" lines every line up on the left margin, which
---is where centring would have put the widest of them, so the window looks the same until the
---rows stop being equally wide.
---@alias ListPopupAlignment
---| "CENTER"
---| "LEFT"

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 0 }

---@param config ListPopupConfig
---@return ListPopup
function M.new( config )
  ---@type Popup?
  local popup

  local top_padding = config.top_padding or default_top_padding

  -- Forward declared: create_popup wires the scroll wheel to it.
  local refresh

  local function on_drag_stop()
    if not popup then return end

    if m.is_frame_out_of_bounds( popup ) then
      config.db.point = M.center_point
      popup:position( M.center_point )

      return
    end

    local anchor = popup:get_anchor_point()
    config.db.point = { point = anchor.point, relative_point = anchor.relative_point, x = anchor.x, y = anchor.y }
  end

  local function get_point()
    if popup and m.is_frame_out_of_bounds( popup ) then
      return M.center_point
    elseif config.db.point then
      return config.db.point
    else
      return M.center_point
    end
  end

  local function create_popup()
    local builder = config.popup_builder
        :name( config.name )
        :point( get_point() )
        :gui_elements( m.GuiElements )
        :movable()
        :on_drag_stop( on_drag_stop )
        :strata( "DIALOG" )
        :self_centered_anchor()
        :anchor_point( "TOPLEFT" )
        :hidden()

    -- Only the rows scroll; the title, the picker and the buttons stay where they are. Scrolling
    -- is just another reason to redraw, so it goes through the same refresh() everything else
    -- does -- the full list is rendered every time and add_line drops what falls outside.
    if config.max_rows then
      builder:scrollable( {
        line_types = config.row_type,
        max_lines = config.max_rows(),
        top_padding = top_padding,
        right_inset = scroll_bar_right_inset
      } ):on_scroll( function() refresh() end )
    end

    if config.esc then builder:esc() end
    if config.no_border then builder:no_border() end

    local result = builder:build()

    local backdrop = config.backdrop_color

    if backdrop then
      result:backdrop_color( backdrop[ 1 ], backdrop[ 2 ], backdrop[ 3 ], backdrop[ 4 ] )
    end

    -- A window without an edge has no border to colour, and border_color on one is a no-op the
    -- builder ignores anyway -- asked here rather than there so the default doesn't read as
    -- something that applies.
    if not config.no_border then
      local border = config.border_color or default_border_color
      result:border_color( border[ 1 ], border[ 2 ], border[ 3 ], border[ 4 ] )
    end

    -- The whole window is the close button. For a window with no X and no button row this is the
    -- only way to put it away with the mouse, so it is deliberately the frame itself rather than
    -- anything drawn: there is nothing to aim at.
    if config.right_click_hides then
      result:SetScript( "OnMouseUp", function( self, button )
        if button == "RightButton" then self:Hide() end
      end )
    end

    -- The client's own frame close button, in the corner every other WoW window puts it. Created
    -- once with the popup rather than added as a line, because it isn't content: clear() throws
    -- the lines away on every refresh and this has to outlive that.
    if config.close_button then
      local close = m.api.CreateFrame( "Button", nil, result, "UIPanelCloseButtonNoScripts" )
      close:SetScale( close_button_scale )
      close:SetPoint( "TOPRIGHT", result, "TOPRIGHT", close_button_x / close_button_scale,
        close_button_y / close_button_scale )
      close:SetFrameLevel( result:GetFrameLevel() + 1 )
      close:SetScript( "OnClick", function() result:Hide() end )

      -- Hung off the popup so callers (and specs) can reach it. It is the only control on this
      -- window that isn't a line, so there is otherwise no way to find it.
      result.close_button = close
    end

    return result
  end

  ---@param frame table
  ---@param v table
  local function draw_button( frame, v )
    frame:SetWidth( v.width or button_defaults.width )
    frame:SetHeight( v.height or button_defaults.height )
    frame:SetText( v.label or "" )
    frame:ClearAllPoints() -- This fixes a strange visual bug in BCC. Frame is either without label or misaligned without this.
    frame:SetScale( v.scale or button_defaults.scale )
    frame:SetScript( "OnClick", v.on_click or function() end )

    if v.disabled then frame:Disable() else frame:Enable() end
  end

  -- SetRow writes every column on every call because FrameBuilder recycles line frames
  -- across refreshes; the same reason is why the callback is reassigned unconditionally
  -- rather than only when the row carries one -- a frame left holding the previous
  -- occupant's closure would act on the wrong player.
  ---@param frame table
  ---@param v table
  local function draw_row( frame, v )
    frame:SetHeader( v.header and true or false )
    frame:SetRow( v )

    if config.row_callback then
      frame[ config.row_callback ] = v[ config.row_callback ] or function() end
    end
  end

  -- Left-aligned lines are pinned by their own top left corner, so each one chains off the left
  -- edge of the line above rather than off its centre. The first is inset by half the popup's
  -- side margin: the popup is the widest line plus that margin, so half of it is the gap centring
  -- would have left on the left of that line, and the rows keep the margin the window was built
  -- with.
  ---@return string -- the corner each line pins to
  ---@return number -- how far in from the window's left edge the first one sits
  local function alignment()
    if config.align ~= "LEFT" then return "TOP", 0 end

    return "TOPLEFT", (popup and popup.side_margin or 0) / 2
  end

  ---@param frame table
  ---@param v table
  ---@param lines table[]
  local function place( frame, v, lines )
    local count = getn( lines )
    local point, inset = alignment()

    frame:ClearAllPoints()

    if count == 0 then
      frame:SetPoint( point, popup, point, inset, -top_padding - (v.padding or 0) )
    else
      local anchor_to = point == "TOPLEFT" and "BOTTOMLEFT" or "BOTTOM"
      frame:SetPoint( point, lines[ count ].frame, anchor_to, 0, v.padding and -v.padding or 0 )
    end
  end

  ---@param transformed table
  ---@return number -- how many of them are scrollable rows
  local function count_rows( transformed )
    local result = 0

    for _, v in ipairs( transformed ) do
      if v.type == config.row_type then result = result + 1 end
    end

    return result
  end

  refresh = function()
    if not popup then popup = create_popup() end
    popup:clear()

    local transformed = config.content_transformer.transform( config.content() )

    if config.max_rows then
      -- Read every pass rather than at build time, so changing the setting takes effect on the
      -- next redraw instead of on the next reload.
      popup:set_max_scroll_lines( config.max_rows() )
      -- The whole row list, not just the part that fits: the popup needs the real length to size
      -- the scrollbar, and to pull the window back up when a shorter list leaves fewer rows than
      -- the offset it was scrolled to.
      popup:set_scroll_total( count_rows( transformed ) )
    end

    for _, v in ipairs( transformed ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "button" then
          draw_button( frame, v )
        elseif type == config.row_type then
          draw_row( frame, v )
        elseif type == config.header_type then
          frame:SetRow( v )
        elseif type == "checkbox_row" then
          frame:SetRow( v )
        elseif type == "dropdown" then
          frame:SetText( v.label or "" )
          frame:SetDropdownWidth( v.width )
          frame:SetOptions( v.options )
          frame:SetValue( v.value )
          frame.on_change = v.on_change or function() end
        elseif type == "text" then
          frame:SetText( v.value )
        end

        -- Buttons are laid out by the popup itself; everything else chains downwards.
        if type ~= "button" then place( frame, v, lines ) end
      end, v.padding )
    end
  end

  local function show()
    if not popup then popup = create_popup() end
    refresh()

    popup:Show()
  end

  local function hide()
    if popup then popup:Hide() end
  end

  local function toggle()
    if not popup then popup = create_popup() end

    if popup:IsVisible() then
      popup:Hide()
    else
      show()
    end
  end

  -- Nothing to redraw while it's hidden, and every caller that subscribes to a model
  -- wants exactly this, so it's the one they get rather than raw refresh.
  local function refresh_if_visible()
    if popup and popup:IsVisible() then refresh() end
  end

  if config.slash_command then m.slash_cmd( config.slash_command, toggle ) end

  ---@type ListPopup
  return {
    show = show,
    hide = hide,
    toggle = toggle,
    refresh_if_visible = refresh_if_visible,
    get_frame = function() return popup end
  }
end

m.ListPopup = M
return M
