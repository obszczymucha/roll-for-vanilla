package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
u.mock_wow_api()
local FrameBuilder = require( "src/FrameBuilder" )

local m = RollFor

-- A frame with a scroll viewport over "row" lines, plus the title/button kinds that stay put.
---@param max_lines number
---@param on_scroll function?
local function scrollable_frame( max_lines, on_scroll )
  local builder = FrameBuilder.new()
      :gui_elements( {
        row = function( parent ) return m.api.CreateFrame( "Frame", nil, parent ) end,
        title = function( parent ) return m.api.CreateFrame( "Frame", nil, parent ) end
      } )
      :scrollable( { line_types = "row", max_lines = max_lines } )

  if on_scroll then builder:on_scroll( on_scroll ) end

  return builder:build()
end

-- One render pass, the way a caller does it: clear, declare how many scrollable lines are coming,
-- then offer every one of them. Returns the labels that actually made it onto the frame.
---@param frame Frame
---@param row_count number
---@param with_title boolean?
local function render( frame, row_count, with_title )
  local rendered = {}

  frame.clear()
  frame:set_scroll_total( row_count )

  if with_title then
    frame.add_line( "title", function() table.insert( rendered, "title" ) end, 0 )
  end

  for i = 1, row_count do
    frame.add_line( "row", function() table.insert( rendered, i ) end, 2 )
  end

  return rendered
end

FrameBuilderScrollSpec = {}

function FrameBuilderScrollSpec:should_render_every_line_when_the_list_fits_the_window()
  local frame = scrollable_frame( 10 )

  eq( render( frame, 4 ), { 1, 2, 3, 4 } )
end

function FrameBuilderScrollSpec:should_render_only_the_first_window_of_a_longer_list()
  local frame = scrollable_frame( 3 )

  eq( render( frame, 10 ), { 1, 2, 3 } )
end

function FrameBuilderScrollSpec:should_keep_rendering_lines_of_other_types()
  local frame = scrollable_frame( 2 )

  eq( render( frame, 10, true ), { "title", 1, 2 } )
end

function FrameBuilderScrollSpec:should_move_the_window_when_scrolled()
  local frame = scrollable_frame( 3 )
  render( frame, 10 )

  frame:scroll_by( 2 )

  eq( render( frame, 10 ), { 3, 4, 5 } )
end

function FrameBuilderScrollSpec:should_not_scroll_past_the_end_of_the_list()
  local frame = scrollable_frame( 3 )
  render( frame, 10 )

  frame:scroll_by( 100 )

  eq( render( frame, 10 ), { 8, 9, 10 } )
end

function FrameBuilderScrollSpec:should_not_scroll_above_the_start_of_the_list()
  local frame = scrollable_frame( 3 )
  render( frame, 10 )

  frame:scroll_by( -100 )

  eq( render( frame, 10 ), { 1, 2, 3 } )
end

function FrameBuilderScrollSpec:should_redraw_through_on_scroll_when_the_window_moves()
  local scrolls = 0
  local frame = scrollable_frame( 3, function() scrolls = scrolls + 1 end )
  render( frame, 10 )

  frame:scroll_by( 1 )
  eq( scrolls, 1 )
end

function FrameBuilderScrollSpec:should_not_redraw_when_the_window_is_already_at_the_end()
  local scrolls = 0
  local frame = scrollable_frame( 3, function() scrolls = scrolls + 1 end )
  render( frame, 3 )

  frame:scroll_by( 1 )
  eq( scrolls, 0 )
end

-- Collapsing a node leaves fewer rows than the offset was scrolled to. Without the clamp the
-- window would sit past the end of the list and the popup would come up empty.
function FrameBuilderScrollSpec:should_pull_the_window_back_when_the_list_gets_shorter()
  local frame = scrollable_frame( 3 )
  render( frame, 30 )
  frame:scroll_by( 20 )

  eq( render( frame, 5 ), { 3, 4, 5 } )
end

function FrameBuilderScrollSpec:should_report_the_window_it_is_showing()
  local frame = scrollable_frame( 3 )
  render( frame, 10 )
  frame:scroll_by( 4 )

  eq( frame.get_scroll(), { offset = 4, total = 10, max_lines = 3 } )
end

FrameBuilderScrollDragSpec = {}

-- A 100px track whose thumb is 20px tall, so 80px of travel, over 10 lines in a 3-line window:
-- offsets 0..7. Track top at y = 500; y grows upwards.
local function drag_to( cursor_y, grab_offset )
  return FrameBuilder.scroll_drag_offset( cursor_y, 500, 80, grab_offset or 0, 10, 3 )
end

function FrameBuilderScrollDragSpec:should_put_the_window_at_the_top_when_the_thumb_is_at_the_top()
  eq( drag_to( 500 ), 0 )
end

function FrameBuilderScrollDragSpec:should_put_the_window_at_the_end_when_the_thumb_is_at_the_bottom()
  eq( drag_to( 420 ), 7 )
end

function FrameBuilderScrollDragSpec:should_move_in_proportion_to_the_thumb()
  eq( drag_to( 460 ), 4 ) -- halfway: 3.5 lines, rounded
end

function FrameBuilderScrollDragSpec:should_round_to_the_nearest_line()
  eq( drag_to( 500 - 80 / 7 * 2 - 5 ), 2 )
  eq( drag_to( 500 - 80 / 7 * 2 - 6 ), 3 )
end

function FrameBuilderScrollDragSpec:should_not_go_above_the_start_when_dragged_past_the_top()
  eq( drag_to( 900 ), 0 )
end

function FrameBuilderScrollDragSpec:should_not_go_past_the_end_when_dragged_below_the_track()
  eq( drag_to( 0 ), 7 )
end

-- Taking hold of the thumb 10px below its top must not move anything until the cursor does.
function FrameBuilderScrollDragSpec:should_keep_the_grabbed_spot_under_the_cursor()
  eq( drag_to( 490, 10 ), 0 )
  eq( drag_to( 410, 10 ), 7 )
end

function FrameBuilderScrollDragSpec:should_not_drag_a_thumb_as_tall_as_its_track()
  eq( FrameBuilder.scroll_drag_offset( 450, 500, 0, 0, 10, 3 ), nil )
end

function FrameBuilderScrollDragSpec:should_not_drag_a_list_that_fits()
  eq( FrameBuilder.scroll_drag_offset( 450, 500, 80, 0, 3, 3 ), nil )
end

function FrameBuilderScrollDragSpec:should_page_up_when_the_track_is_clicked_above_the_thumb()
  eq( FrameBuilder.scroll_page_delta( 300, 250, 15 ), -15 )
end

function FrameBuilderScrollDragSpec:should_page_down_when_the_track_is_clicked_below_the_thumb()
  eq( FrameBuilder.scroll_page_delta( 200, 250, 15 ), 15 )
end

-- The bar's mouse frames are built the first time the list is too long for the window, through the
-- same mocked API every other frame uses.
function FrameBuilderScrollDragSpec:should_build_the_scrollbar_when_the_list_overflows()
  local frame = scrollable_frame( 3 )

  eq( render( frame, 10, true ), { "title", 1, 2, 3 } )
end

FrameBuilderNoScrollSpec = {}

function FrameBuilderNoScrollSpec:should_render_everything_when_no_viewport_was_asked_for()
  local frame = FrameBuilder.new()
      :gui_elements( { row = function( parent ) return m.api.CreateFrame( "Frame", nil, parent ) end } )
      :build()

  local rendered = {}
  for i = 1, 30 do
    frame.add_line( "row", function() table.insert( rendered, i ) end, 2 )
  end

  eq( m.getn( rendered ), 30 )
end

os.exit( lu.LuaUnit.run() )
