package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
u.mock_wow_api()
local PopupBuilder = require( "src/PopupBuilder" )

-- A popup with no buttons still reserves 23px under its last line (see the tail of resize), so
-- every expected height below is the lines' own total plus this.
local NO_BUTTON_MARGIN = 23

-- resize() sizes the popup from the lines currently on it. With a scroll viewport only the lines
-- inside the window exist, so both dimensions have to be held steady across the wheel -- otherwise
-- the window grows and shrinks as you scroll. These specs drive resize() directly with handmade
-- lines, which is the only way to say "this row is 40 wide and that one is 90" without a client.

---@param width number
---@param height number
---@param padding number
---@param line_type string?
local function line( width, height, padding, line_type )
  return {
    line_type = line_type or "row",
    padding = padding,
    frame = {
      GetWidth = function() return width end,
      GetHeight = function() return height end,
      GetScale = function() return 1 end
    }
  }
end

-- A button line. Buttons are positioned by align_buttons rather than chained like the rest, so
-- they carry the widget calls that needs.
---@param width number
---@param height number
local function button( width, height )
  local frame = line( width, height, 0, "button" ).frame
  frame.SetPoint = function() end
  frame.ClearAllPoints = function() end

  return { line_type = "button", padding = 0, frame = frame }
end

-- A popup that reports whatever scroll window the spec sets, and records what it was sized to.
---@param bottom_margin number?
---@param side_margin number?
local function popup( bottom_margin, side_margin )
  local sized = { width = 0, height = 0 }
  local scroll = { offset = 0, total = 0, max_lines = 0 }

  local frame_builder = {
    new = function()
      local builder = {}

      for _, name in ipairs( {
        "name", "parent", "height", "width", "point", "position", "texture", "border_color",
        "border_size", "esc", "sound", "gui_elements", "frame_style", "self_centered_anchor",
        "anchor_point", "bg_file", "backdrop_color", "movable", "on_drag_stop", "on_hide", "lock",
        "unlock", "frame_level", "on_show", "scale", "strata", "hidden", "scrollable", "on_scroll",
        "type", "edge_file", "enable_mouse"
      } ) do
        builder[ name ] = function( self ) return self end
      end

      builder.build = function()
        return {
          SetWidth = function( _, value ) sized.width = value end,
          SetHeight = function( _, value ) sized.height = value end,
          GetWidth = function() return sized.width end,
          GetHeight = function() return sized.height end,
          get_scroll = function() return scroll end,
          add_line = function() return {} end,
          clear = function() end
        }
      end

      return builder
    end
  }

  local result = PopupBuilder.modern( frame_builder, 0, 0, 0 ):build()

  result.sized = function() return sized end
  result.set_scroll = function( total, max_lines )
    scroll = { offset = 0, total = total, max_lines = max_lines }
  end

  return result
end

PopupResizeSpec = {}

function PopupResizeSpec:should_size_itself_to_its_lines()
  local p = popup()

  p:resize( { line( 50, 10, 2 ), line( 90, 10, 2 ) } )

  eq( p.sized().width, 90 )
  eq( p.sized().height, 24 + NO_BUTTON_MARGIN ) -- two 10s plus two paddings
end

-- A button's own size is never counted into the lines' total -- buttons are laid out by the
-- popup's own button row, which is what the 23 accounts for.
function PopupResizeSpec:should_ignore_buttons_when_measuring_the_lines()
  local p = popup()

  p:resize( { line( 50, 10, 0 ), button( 500, 500 ) } )

  eq( p.sized().height, 10 + 23 )
end

PopupScrollResizeSpec = {}

-- The widest row is not the same row at every offset, so the popup would breathe sideways as the
-- wheel moved.
function PopupScrollResizeSpec:should_not_shrink_in_width_when_a_wide_row_scrolls_out_of_view()
  local p = popup()
  p.set_scroll( 10, 2 )

  p:resize( { line( 90, 10, 2 ), line( 50, 10, 2 ) } )
  eq( p.sized().width, 90 )

  -- Scrolled: the 90-wide row is gone and only narrow ones are on screen.
  p:resize( { line( 50, 10, 2 ), line( 50, 10, 2 ) } )

  eq( p.sized().width, 90 )
end

-- A row's padding is decided by its position in the whole list, so the first row carries a wider
-- gap. Scrolling it out of view takes that gap with it and the popup would shrink by it.
function PopupScrollResizeSpec:should_not_shrink_in_height_when_the_first_rows_wider_gap_scrolls_away()
  local p = popup()
  p.set_scroll( 10, 3 )

  p:resize( { line( 50, 10, 4 ), line( 50, 10, 2 ), line( 50, 10, 2 ) } )
  eq( p.sized().height, 38 + NO_BUTTON_MARGIN )

  -- Scrolled by one: three rows again, but all of them at the narrower padding.
  p:resize( { line( 50, 10, 2 ), line( 50, 10, 2 ), line( 50, 10, 2 ) } )

  eq( p.sized().height, 38 + NO_BUTTON_MARGIN )
end

-- Held only for as long as the list is the same list. A shorter one is a different question, and
-- the window really should shrink to it.
function PopupScrollResizeSpec:should_resize_when_the_list_changes_length()
  local p = popup()
  p.set_scroll( 10, 3 )
  p:resize( { line( 90, 10, 4 ), line( 90, 10, 2 ), line( 90, 10, 2 ) } )

  p.set_scroll( 2, 3 )
  p:resize( { line( 50, 10, 4 ), line( 50, 10, 2 ) } )

  eq( p.sized().width, 50 )
  eq( p.sized().height, 26 + NO_BUTTON_MARGIN )
end

-- The window's own height is the other thing that decides how many rows get rendered, so a
-- change to it has to resize the popup even though the list is the same list.
function PopupScrollResizeSpec:should_shrink_when_the_window_is_made_shorter()
  local p = popup()
  p.set_scroll( 10, 3 )
  p:resize( { line( 50, 10, 4 ), line( 50, 10, 2 ), line( 50, 10, 2 ) } )
  eq( p.sized().height, 38 + NO_BUTTON_MARGIN )

  -- The user drops the row limit to 2. Same list, fewer rows on screen.
  p.set_scroll( 10, 2 )
  p:resize( { line( 50, 10, 4 ), line( 50, 10, 2 ) } )

  eq( p.sized().height, 26 + NO_BUTTON_MARGIN )
end

function PopupScrollResizeSpec:should_grow_when_the_window_is_made_taller()
  local p = popup()
  p.set_scroll( 10, 2 )
  p:resize( { line( 50, 10, 4 ), line( 50, 10, 2 ) } )

  p.set_scroll( 10, 4 )
  p:resize( { line( 50, 10, 4 ), line( 50, 10, 2 ), line( 50, 10, 2 ), line( 50, 10, 2 ) } )

  eq( p.sized().height, 50 + NO_BUTTON_MARGIN )
end

-- The wheel changes neither number, which is the case all of this exists for.
function PopupScrollResizeSpec:should_still_hold_its_size_across_the_wheel_at_a_new_window_height()
  local p = popup()
  p.set_scroll( 10, 2 )
  p:resize( { line( 90, 10, 4 ), line( 50, 10, 2 ) } )

  p:resize( { line( 50, 10, 2 ), line( 50, 10, 2 ) } )

  eq( p.sized().width, 90 )
  eq( p.sized().height, 26 + NO_BUTTON_MARGIN )
end

function PopupScrollResizeSpec:should_still_grow_for_a_bigger_line_at_the_same_length()
  local p = popup()
  p.set_scroll( 10, 2 )
  p:resize( { line( 50, 10, 2 ), line( 50, 10, 2 ) } )

  p:resize( { line( 120, 10, 2 ), line( 50, 10, 2 ) } )

  eq( p.sized().width, 120 )
end

-- Nothing is held for a popup with no viewport: every line exists on every pass, so its size is
-- simply what its lines are.
function PopupScrollResizeSpec:should_track_its_lines_exactly_when_it_does_not_scroll()
  local p = popup()

  p:resize( { line( 90, 10, 2 ), line( 90, 10, 2 ) } )
  p:resize( { line( 50, 10, 2 ) } )

  eq( p.sized().width, 50 )
  eq( p.sized().height, 12 + NO_BUTTON_MARGIN )
end

os.exit( lu.LuaUnit.run() )
