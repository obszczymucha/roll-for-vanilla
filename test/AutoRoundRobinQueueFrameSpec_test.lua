-- The round-robin module is built here from stubs that implement exactly the methods it calls,
-- which is itself a statement of what it depends on -- filling them out to whole interfaces would
-- bury that. The specs also hang their own helpers off the frame the mock returns.
---@diagnostic disable: missing-fields, inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )

-- Before the catalogues are required: they read the client's quality colours at load time,
-- which in the real client are set during UIParent load, well before any addon file runs.
u.mock_wow_api()
local Db = require( "src/Db" )
local popup_builder = require( "mocks/PopupBuilder" )
local frame_mock = require( "mocks/AutoRoundRobinQueueFrame" )
require( "src/AutoRoundRobinDb" )
local AutoRoundRobin = require( "src/AutoRoundRobin" )


local title = { type = "text", value = "Auto Round Robin Queues", padding = 1 }
local empty_notice = { type = "text", value = "Nobody in this queue yet.", padding = 10 }

-- No Close: that is the corner X, which is part of the window rather than a line in it. No Reset
-- either -- it throws away every queue at once, so it lives on /rf autorobin reset instead of one
-- click away from the up arrow.
local buttons = {
  { type = "button", label = "Add", width = 60 },
  { type = "button", label = "Up", width = 60 },
  { type = "button", label = "Down", width = 60 }
}

---@param category string
---@param categories string[]?
local function picker( category, categories )
  local options = {}

  -- Trash last, because it is the fallback category and sorts after every real one. It owns a
  -- queue like any other category -- that is what being a category means here -- so it is offered
  -- in this dropdown even though it names qualities rather than item ids.
  -- The label carries the category's colour; the value is the plain name, because that is what
  -- selecting one means.
  for _, name in ipairs( categories or { "Marks", "Hearts", "Gems", "Trash" } ) do
    table.insert( options, { value = name, label = RollFor.AutoRoundRobinDb.colorize( name ) } )
  end

  -- No label: it sits under a title that already says what these are.
  return { type = "dropdown", label = "", width = 60, value = category, options = options, padding = 8 }
end

-- Transient unless the spec says otherwise: these frames are seeded from the group, and the
-- roster only ever brings people in transient.
---@param name string
---@param opts table? -- { first = boolean, last = boolean, core = boolean }
local function line( name, opts )
  local o = opts or {}

  return {
    type = "round_robin_row",
    player = RollFor.colorize_player_by_class( name, "Warrior" ),
    core = o.core or false,
    can_move_up = not o.first,
    can_move_down = not o.last
  }
end

-- How many are in the queue, aligned with the list's right edge. Its own line type rather than a
-- header row, so the viewport does not scroll it away with the first player.
---@param count number
local function total( count )
  return { type = "round_robin_count", count = tostring( count ), padding = 2 }
end

-- The whole popup in the order the transformer emits it: title, the category picker, then either
-- the empty notice or the count and one line per player, then the buttons. No column title above
-- the names -- the queue is ordered, so a header reading "Player" would say nothing the list did
-- not.
---@param category string
---@param rows table[]?
local function popup( category, rows )
  local content = { title, picker( category ) }

  if not rows or #rows == 0 then
    table.insert( content, empty_notice )
  else
    table.insert( content, total( #rows ) )

    -- Every row padded the same, so that scrolling the first one away does not take a wider gap
    -- with it and shift the rest of the list up.
    for _, row in ipairs( rows ) do
      row.padding = 2
      table.insert( content, row )
    end
  end

  for _, button in ipairs( buttons ) do table.insert( content, button ) end

  return unpack( content )
end

---@param names string[]
---@param opts table? -- { rows = number }
local function new_frame( names, opts )
  local o = opts or {}
  local max_rows = o.rows or 6

  -- Only the two things this window asks Config for. The row limit is read on every redraw, so a
  -- spec can move it and redraw rather than rebuilding the window.
  local config = {
    round_robin_queue_rows = function() return max_rows end,
    subscribe = function() end,
    set_rows = function( value ) max_rows = value end
  }
  local db = Db.new( {} )
  local round_robin_db = db( "autorobin" )
  RollFor.AutoRoundRobinDb.ensure_seeded( round_robin_db )

  local players = {}
  for _, name in ipairs( names or {} ) do table.insert( players, { name = name, class = "Warrior" } ) end

  local in_group = true

  -- This window never asks the client anything: the queue is the queue whether or not a corpse
  -- is open. Both stubs are here only because AutoRoundRobin's award pass takes them.
  local loot_list = {
    is_looting = function() return false end,
    get_items_by_slot = function() return {} end
  }

  local candidates = {
    get = function() return players end,
    get_index = function() return 1 end
  }

  local round_robin = AutoRoundRobin.new(
    loot_list,
    function() return RollFor.api end,
    round_robin_db,
    { auto_round_robin = function() return true end },
    { is_master_looter = function() return true end },
    { announce = function() end },
    -- In a group by default, so the queue hides anybody who isn't in it (see
    -- AutoRoundRobin.get_rows). Both are mutable so a spec can have somebody join or leave.
    { get_all_players_in_my_group = function() return players end, am_i_in_group = function() return in_group end },
    candidates,
    { is_auto_looted = function() return false end },
    { on_loot_awarded = function() end }
  )

  round_robin.on_group_changed()

  local added_for

  local add_player_frame = { show = function( category ) added_for = category end }

  local frame = frame_mock.new( popup_builder.new(), round_robin, add_player_frame, config, db( "frame" ) )

  frame.round_robin = round_robin
  frame.set_rows = config.set_rows
  frame.add_shown_for = function() return added_for end

  -- Somebody walks in. Not a roster sync -- that is on_group_changed -- just the group they are
  -- now part of, which is what decides whether the queue draws them.
  frame.join = function( name )
    table.insert( players, { name = name, class = "Warrior" } )
  end

  frame.leave_group = function()
    in_group = false
  end

  ---@param category string?
  frame.queue_names = function( category )
    local result = {}

    for _, player in ipairs( round_robin.get_queue( category or "Marks" ) ) do
      table.insert( result, player.name )
    end

    return result
  end

  return frame
end

RoundRobinQueueFrameSpec = {}

function RoundRobinQueueFrameSpec:should_be_hidden_by_default()
  new_frame( {} ).should_be_hidden()
end

function RoundRobinQueueFrameSpec:should_toggle_visibility()
  local frame = new_frame( {} )

  frame.toggle()
  frame.should_be_visible()

  frame.toggle()
  frame.should_be_hidden()
end

function RoundRobinQueueFrameSpec:should_show_the_empty_notice_when_nobody_is_queued()
  local frame = new_frame( {} )

  frame.show()

  frame.should_display( popup( "Marks" ) )
end

function RoundRobinQueueFrameSpec:should_count_the_queue_above_the_list()
  local frame = new_frame( { "Ann", "Bob", "Cid" } )

  frame.show()

  -- The count is the whole queue, not the part of it the viewport is showing.
  frame.set_rows( 2 )
  frame.round_robin.cycle( "Marks", 1 )

  local content = frame.content()
  eq( content[ 3 ], { type = "round_robin_count", count = "3", padding = 2 } )
end

function RoundRobinQueueFrameSpec:should_list_the_queue_in_order()
  local frame = new_frame( { "Ann", "Bob", "Cid" } )

  frame.show()

  frame.should_display( popup( "Marks", {
    line( "Ann", { first = true } ),
    line( "Bob" ),
    line( "Cid", { last = true } )
  } ) )
end

RoundRobinQueueFrameCategorySpec = {}

function RoundRobinQueueFrameCategorySpec:should_start_on_the_first_category()
  local frame = new_frame( { "Ann" } )

  frame.show()

  frame.should_display( popup( "Marks", { line( "Ann", { first = true, last = true } ) } ) )
end

function RoundRobinQueueFrameCategorySpec:should_switch_to_another_categorys_queue()
  local frame = new_frame( { "Ann", "Bob" } )
  frame.show()

  frame.select_category( "Gems" )

  frame.should_display( popup( "Gems", {
    line( "Ann", { first = true } ),
    line( "Bob", { last = true } )
  } ) )
end

-- Editing one queue must not touch another: that is what makes them independent.
function RoundRobinQueueFrameCategorySpec:should_edit_only_the_category_on_screen()
  local frame = new_frame( { "Ann", "Bob" } )
  frame.show()
  frame.select_category( "Gems" )

  frame.click( "CycleUp" )

  eq( frame.queue_names( "Gems" ), { "Bob", "Ann" } )
  eq( frame.queue_names( "Marks" ), { "Ann", "Bob" } )
end

RoundRobinQueueFrameEditingSpec = {}

function RoundRobinQueueFrameEditingSpec:should_move_a_player_up()
  local frame = new_frame( { "Ann", "Bob", "Cid" } )
  frame.show()

  frame.click_row( 3, "up" )

  eq( frame.queue_names(), { "Ann", "Cid", "Bob" } )
  frame.should_display( popup( "Marks", {
    line( "Ann", { first = true } ),
    line( "Cid" ),
    line( "Bob", { last = true } )
  } ) )
end

function RoundRobinQueueFrameEditingSpec:should_move_a_player_down()
  local frame = new_frame( { "Ann", "Bob", "Cid" } )
  frame.show()

  frame.click_row( 1, "down" )

  eq( frame.queue_names(), { "Bob", "Ann", "Cid" } )
end

function RoundRobinQueueFrameEditingSpec:should_remove_a_player()
  local frame = new_frame( { "Ann", "Bob" } )
  frame.show()

  frame.click_row( 1, "remove" )

  eq( frame.queue_names(), { "Bob" } )
end

-- Up moves the list up: the head goes to the back and everybody else climbs a place.
function RoundRobinQueueFrameEditingSpec:should_cycle_the_whole_queue_up()
  local frame = new_frame( { "Ann", "Bob", "Cid" } )
  frame.show()

  frame.click( "CycleUp" )

  eq( frame.queue_names(), { "Bob", "Cid", "Ann" } )
end

function RoundRobinQueueFrameEditingSpec:should_cycle_the_whole_queue_down()
  local frame = new_frame( { "Ann", "Bob", "Cid" } )
  frame.show()

  frame.click( "CycleDown" )

  eq( frame.queue_names(), { "Cid", "Ann", "Bob" } )
end

function RoundRobinQueueFrameEditingSpec:should_open_the_add_popup_for_the_category_on_screen()
  local frame = new_frame( { "Ann" } )
  frame.show()
  frame.select_category( "Hearts" )

  frame.click( "Add" )

  eq( frame.add_shown_for(), "Hearts" )
end

function RoundRobinQueueFrameEditingSpec:should_close_from_the_corner_x()
  local frame = new_frame( { "Ann" } )
  frame.show()
  frame.should_be_visible()

  frame.click_close()

  frame.should_be_hidden()
end

function RoundRobinQueueFrameEditingSpec:should_redraw_when_the_queue_moves()
  local frame = new_frame( { "Ann", "Bob" } )
  frame.show()

  frame.round_robin.cycle( "Marks", 1 )

  frame.should_display( popup( "Marks", {
    line( "Bob", { first = true } ),
    line( "Ann", { last = true } )
  } ) )
end

RoundRobinQueueFrameCoreSpec = {}

function RoundRobinQueueFrameCoreSpec:should_draw_a_player_added_by_hand_as_core()
  local frame = new_frame( { "Ann" } )

  frame.round_robin.add_player( "Marks", "Bob", "Warrior" )
  frame.join( "Bob" )
  frame.show()

  frame.should_display( popup( "Marks", {
    line( "Ann", { first = true } ),
    line( "Bob", { last = true, core = true } )
  } ) )
end

function RoundRobinQueueFrameCoreSpec:should_promote_the_player_whose_box_is_ticked()
  local frame = new_frame( { "Ann", "Bob" } )

  frame.show()
  frame.toggle_core( 2 )

  frame.should_display( popup( "Marks", {
    line( "Ann", { first = true } ),
    line( "Bob", { last = true, core = true } )
  } ) )
end

function RoundRobinQueueFrameCoreSpec:should_demote_the_player_whose_box_is_unticked()
  local frame = new_frame( { "Ann" } )

  frame.round_robin.add_player( "Marks", "Bob", "Warrior" )
  frame.join( "Bob" )
  frame.show()
  frame.toggle_core( 2 )

  frame.should_display( popup( "Marks", {
    line( "Ann", { first = true } ),
    line( "Bob", { last = true } )
  } ) )
end

-- The box says who survives the next group, not where they stand in this one.
function RoundRobinQueueFrameCoreSpec:should_leave_the_order_alone_when_a_box_is_ticked()
  local frame = new_frame( { "Ann", "Bob", "Cid" } )

  frame.show()
  frame.toggle_core( 2 )

  eq( frame.queue_names(), { "Ann", "Bob", "Cid" } )
end

-- Each category owns its own queue, so a player is core in the one whose box was ticked and
-- nowhere else.
function RoundRobinQueueFrameCoreSpec:should_only_promote_in_the_category_on_screen()
  local frame = new_frame( { "Ann" } )

  frame.show()
  frame.toggle_core( 1 )
  frame.select_category( "Gems" )

  frame.should_display( popup( "Gems", { line( "Ann", { first = true, last = true } ) } ) )
end

RoundRobinQueueFrameAbsenceSpec = {}

-- Hidden, not dropped: they keep their place in the queue and take the next drop they are
-- around for.
function RoundRobinQueueFrameAbsenceSpec:should_hide_a_player_who_is_not_in_the_group()
  local frame = new_frame( { "Ann", "Cid" } )

  frame.round_robin.add_player( "Marks", "Bob", "Warrior" )
  frame.show()

  frame.should_display( popup( "Marks", {
    line( "Ann", { first = true } ),
    line( "Cid", { last = true } )
  } ) )
  eq( frame.queue_names(), { "Ann", "Cid", "Bob" } )
end

function RoundRobinQueueFrameAbsenceSpec:should_count_only_the_players_it_draws()
  local frame = new_frame( { "Ann" } )

  frame.round_robin.add_player( "Marks", "Bob", "Warrior" )
  frame.show()

  eq( frame.content()[ 3 ], { type = "round_robin_count", count = "1", padding = 2 } )
end

-- Out of a group there is nothing to be absent from, and it is the only time the core players
-- added between raids can all be seen at once.
function RoundRobinQueueFrameAbsenceSpec:should_show_everybody_when_not_in_a_group()
  local frame = new_frame( { "Ann" } )

  frame.round_robin.add_player( "Marks", "Bob", "Warrior" )
  frame.leave_group()
  frame.show()

  frame.should_display( popup( "Marks", {
    line( "Ann", { first = true } ),
    line( "Bob", { last = true, core = true } )
  } ) )
end

function RoundRobinQueueFrameAbsenceSpec:should_draw_a_hidden_player_again_once_they_join()
  local frame = new_frame( { "Ann" } )

  frame.round_robin.add_player( "Marks", "Bob", "Warrior" )
  frame.join( "Bob" )
  frame.show()

  frame.should_display( popup( "Marks", {
    line( "Ann", { first = true } ),
    line( "Bob", { last = true, core = true } )
  } ) )
end

-- The arrows move a player past the one above them on screen. Stepping one place in the queue
-- would swap them with the hidden player instead and redraw identically.
function RoundRobinQueueFrameAbsenceSpec:should_move_a_player_past_the_hidden_one_between_them()
  local frame = new_frame( { "Ann", "Cid" } )

  -- Ann, Bob (hidden), Cid
  frame.round_robin.add_player( "Marks", "Bob", "Warrior" )
  frame.round_robin.move_player( "Marks", 3, -1 )
  frame.show()

  -- Cid is drawn second, so up means past Ann.
  frame.click_row( 2, "up" )

  eq( frame.queue_names(), { "Cid", "Bob", "Ann" } )
  frame.should_display( popup( "Marks", {
    line( "Cid", { first = true } ),
    line( "Ann", { last = true } )
  } ) )
end

-- Up and Down rotate what is on screen, for the same reason the arrows move a player past their
-- neighbour on screen: rotating the whole queue would send an absent player to the back and
-- redraw identically, and a queue carried over from the last raid is normally full of them.
function RoundRobinQueueFrameAbsenceSpec:should_move_the_list_by_a_row_on_every_cycle_up()
  local frame = new_frame( { "Ann", "Cid" } )

  -- Ann, Bob (hidden), Cid
  frame.round_robin.add_player( "Marks", "Bob", "Warrior" )
  frame.round_robin.move_player( "Marks", 3, -1 )
  frame.show()

  frame.click( "CycleUp" )

  eq( frame.queue_names(), { "Bob", "Cid", "Ann" } )
  frame.should_display( popup( "Marks", {
    line( "Cid", { first = true } ),
    line( "Ann", { last = true } )
  } ) )

  frame.click( "CycleUp" )

  frame.should_display( popup( "Marks", {
    line( "Ann", { first = true } ),
    line( "Cid", { last = true } )
  } ) )
end

function RoundRobinQueueFrameAbsenceSpec:should_move_the_list_by_a_row_on_every_cycle_down()
  local frame = new_frame( { "Ann", "Cid" } )

  frame.round_robin.add_player( "Marks", "Bob", "Warrior" )
  frame.round_robin.move_player( "Marks", 3, -1 )
  frame.show()

  frame.click( "CycleDown" )

  eq( frame.queue_names(), { "Cid", "Ann", "Bob" } )
  frame.should_display( popup( "Marks", {
    line( "Cid", { first = true } ),
    line( "Ann", { last = true } )
  } ) )

  frame.click( "CycleDown" )

  frame.should_display( popup( "Marks", {
    line( "Ann", { first = true } ),
    line( "Cid", { last = true } )
  } ) )
end

-- The x takes out the player on that row, not whoever happens to sit at that index in the queue.
function RoundRobinQueueFrameAbsenceSpec:should_remove_the_player_on_the_row_not_the_queue_index()
  local frame = new_frame( { "Ann", "Cid" } )

  frame.round_robin.add_player( "Marks", "Bob", "Warrior" )
  frame.round_robin.move_player( "Marks", 3, -1 )
  frame.show()

  frame.click_row( 2, "remove" )

  eq( frame.queue_names(), { "Ann", "Bob" } )
end

os.exit( lu.LuaUnit.run() )
