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
local Db = require( "src/Db" )
local popup_builder = require( "mocks/PopupBuilder" )
local frame_mock = require( "mocks/AutoRoundRobinQueueFrame" )
require( "src/ItemCatalogue" )
require( "src/AutoRoundRobinDb" )
local AutoRoundRobin = require( "src/AutoRoundRobin" )

u.mock_wow_api()

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
  for _, name in ipairs( categories or { "Gems", "Marks", "Hearts", "Trash" } ) do
    table.insert( options, { value = name, label = name } )
  end

  -- No label: it sits under a title that already says what these are.
  return { type = "dropdown", label = "", width = 60, value = category, options = options, padding = 8 }
end

---@param name string
---@param opts table? -- { first = boolean, last = boolean }
local function line( name, opts )
  local o = opts or {}

  return {
    type = "round_robin_row",
    player = RollFor.colorize_player_by_class( name, "Warrior" ),
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
    { get_all_players_in_my_group = function() return players end },
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

  ---@param category string?
  frame.queue_names = function( category )
    local result = {}

    for _, player in ipairs( round_robin.get_queue( category or "Gems" ) ) do
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

  frame.should_display( popup( "Gems" ) )
end

function RoundRobinQueueFrameSpec:should_count_the_queue_above_the_list()
  local frame = new_frame( { "Ann", "Bob", "Cid" } )

  frame.show()

  -- The count is the whole queue, not the part of it the viewport is showing.
  frame.set_rows( 2 )
  frame.round_robin.cycle( "Gems", 1 )

  local content = frame.content()
  eq( content[ 3 ], { type = "round_robin_count", count = "3", padding = 2 } )
end

function RoundRobinQueueFrameSpec:should_list_the_queue_in_order()
  local frame = new_frame( { "Ann", "Bob", "Cid" } )

  frame.show()

  frame.should_display( popup( "Gems", {
    line( "Ann", { first = true } ),
    line( "Bob" ),
    line( "Cid", { last = true } )
  } ) )
end

RoundRobinQueueFrameCategorySpec = {}

function RoundRobinQueueFrameCategorySpec:should_start_on_the_first_category()
  local frame = new_frame( { "Ann" } )

  frame.show()

  frame.should_display( popup( "Gems", { line( "Ann", { first = true, last = true } ) } ) )
end

function RoundRobinQueueFrameCategorySpec:should_switch_to_another_categorys_queue()
  local frame = new_frame( { "Ann", "Bob" } )
  frame.show()

  frame.select_category( "Marks" )

  frame.should_display( popup( "Marks", {
    line( "Ann", { first = true } ),
    line( "Bob", { last = true } )
  } ) )
end

-- Editing one queue must not touch another: that is what makes them independent.
function RoundRobinQueueFrameCategorySpec:should_edit_only_the_category_on_screen()
  local frame = new_frame( { "Ann", "Bob" } )
  frame.show()
  frame.select_category( "Marks" )

  frame.click( "CycleUp" )

  eq( frame.queue_names( "Marks" ), { "Bob", "Ann" } )
  eq( frame.queue_names( "Gems" ), { "Ann", "Bob" } )
end

RoundRobinQueueFrameEditingSpec = {}

function RoundRobinQueueFrameEditingSpec:should_move_a_player_up()
  local frame = new_frame( { "Ann", "Bob", "Cid" } )
  frame.show()

  frame.click_row( 3, "up" )

  eq( frame.queue_names(), { "Ann", "Cid", "Bob" } )
  frame.should_display( popup( "Gems", {
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

  frame.round_robin.cycle( "Gems", 1 )

  frame.should_display( popup( "Gems", {
    line( "Bob", { first = true } ),
    line( "Ann", { last = true } )
  } ) )
end

os.exit( lu.LuaUnit.run() )
