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

local colors = RollFor.colors
local title = { type = "text", value = "Auto Round Robin Queue", padding = 6 }
local empty_notice = { type = "text", value = "Nobody in the group yet.", padding = 10 }

local header = {
  type = "round_robin_row",
  header = true,
  player = "Player",
  status = "Status",
  eligible = "Eligible",
  padding = 0
}

local reset_button = { type = "button", label = "Reset", width = 70 }
local close_button = { type = "button", label = "Close", width = 70 }

---@param name string
---@param status string
---@param eligible string?
local function line( name, status, eligible )
  return {
    type = "round_robin_row",
    player = RollFor.colorize_player_by_class( name, "Warrior" ),
    status = status,
    eligible = eligible or "Yes"
  }
end

-- The whole popup in the order the transformer emits it: title, then either the empty notice or
-- the column titles and one line per player, then the buttons. The first player line sits a
-- little further from the column titles than the rest do.
---@param rows table[]?
local function popup( rows )
  local content = { title }

  if not rows or #rows == 0 then
    table.insert( content, empty_notice )
  else
    table.insert( content, header )

    for i, row in ipairs( rows ) do
      row.padding = i == 1 and 4 or 2
      table.insert( content, row )
    end
  end

  table.insert( content, reset_button )
  table.insert( content, close_button )

  return unpack( content )
end

---@param names string[]
local function mock_roster( names )
  local players = {}
  for _, name in ipairs( names ) do table.insert( players, { name = name, class = "Warrior" } ) end

  return { get_all_players_in_my_group = function() return players end }
end

-- Being in the group and being able to receive are different things. Unless a spec says who the
-- master loot candidates are, nothing is looting, GetMasterLootCandidate has no slot to speak
-- about, and the column has nothing to say -- so every row shows as eligible rather than the
-- window filling up with dimmed rows outside of a loot session.
---@param candidate_names string[]?
local function mock_loot_list( candidate_names )
  local looting = candidate_names and true or false

  return {
    is_looting = function() return looting end,
    get_items_by_slot = function() return looting and { [ 1 ] = { id = 32227 } } or {} end
  }
end

---@param candidate_names string[]?
local function mock_candidates( candidate_names )
  local candidates = {}
  for _, name in ipairs( candidate_names or {} ) do table.insert( candidates, { name = name, class = "Warrior" } ) end

  return { get = function() return candidates end, get_index = function() end }
end

---@param names string[]
---@param pool table<string, number>?
---@param cycle number?
---@param candidate_names string[]? -- who is a master loot candidate right now
local function new_frame( names, pool, cycle, candidate_names )
  local db = Db.new( {} )
  local round_robin_db = db( "autorobin" )
  round_robin_db.cycle = cycle or 1
  round_robin_db.pool = pool or {}

  local resets = 0

  local round_robin = AutoRoundRobin.new(
    mock_loot_list( candidate_names ),
    function() return RollFor.api end,
    round_robin_db,
    { auto_round_robin = function() return true end },
    { is_master_looter = function() return true end },
    { announce = function() end },
    mock_roster( names ),
    mock_candidates( candidate_names ),
    { is_auto_looted = function() return false end },
    { on_loot_awarded = function() end }
  )

  local frame = frame_mock.new( popup_builder.new(), round_robin,
    function() resets = resets + 1; round_robin.reset() end, db( "frame" ) )

  frame.round_robin = round_robin
  frame.db = round_robin_db
  frame.reset_count = function() return resets end

  return frame
end

RoundRobinQueueFrameSpec = {}

function RoundRobinQueueFrameSpec:should_be_hidden_by_default()
  new_frame( {} ).should_be_hidden()
end

function RoundRobinQueueFrameSpec:should_toggle_visibility()
  -- Given
  local frame = new_frame( {} )

  -- When
  frame.toggle()

  -- Then
  frame.should_be_visible()

  -- When
  frame.toggle()

  -- Then
  frame.should_be_hidden()
end

-- The window opens out of raid so the rotation can be looked at; there's just nobody to list.
function RoundRobinQueueFrameSpec:should_show_the_empty_notice_when_the_group_is_empty()
  -- Given
  local frame = new_frame( {} )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup() )
end

function RoundRobinQueueFrameSpec:should_list_everybody_served_this_cycle_as_received()
  -- Given
  local frame = new_frame( { "Psikutas", "Obszczymucha" }, { Psikutas = 2, Obszczymucha = 2 }, 2 )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( {
    line( "Obszczymucha", colors.grey( "Received" ) ),
    line( "Psikutas", colors.grey( "Received" ) )
  } ) )
end

-- Who is owed the most comes first, and only somebody more than one cycle behind is called out --
-- being one behind is just where you stand after somebody else was served.
function RoundRobinQueueFrameSpec:should_order_by_who_is_owed_the_most_and_name_the_cycles_owed()
  -- Given
  local frame = new_frame(
    { "Psikutas", "Obszczymucha", "Jogobobek" },
    { Psikutas = 3, Obszczymucha = 2, Jogobobek = 1 }, 3 )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( {
    line( "Jogobobek", colors.hl( "Owed (2 cycles)" ) ),
    line( "Obszczymucha", "Waiting" ),
    line( "Psikutas", colors.grey( "Received" ) )
  } ) )
end

-- Somebody the roster has but the pool doesn't hasn't been seeded yet, which is where a joiner
-- is: served for the current cycle, waiting for the next one.
function RoundRobinQueueFrameSpec:should_show_a_player_missing_from_the_pool_as_received()
  -- Given
  local frame = new_frame( { "Jogobobek" }, {}, 4 )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( { line( "Jogobobek", colors.grey( "Received" ) ) } ) )
end

function RoundRobinQueueFrameSpec:should_redraw_when_the_rotation_moves()
  -- Given
  local frame = new_frame( { "Psikutas" }, { Psikutas = 1 }, 2 )
  frame.show()
  frame.should_display( popup( { line( "Psikutas", "Waiting" ) } ) )

  -- When -- anything that changes the rotation notifies the window
  frame.db.pool.Psikutas = 2
  frame.round_robin.on_group_changed()

  -- Then
  frame.should_display( popup( { line( "Psikutas", colors.grey( "Received" ) ) } ) )
end

function RoundRobinQueueFrameSpec:should_reset_the_rotation_from_the_reset_button()
  -- Given
  local frame = new_frame( { "Psikutas", "Obszczymucha" }, { Psikutas = 3, Obszczymucha = 1 }, 3 )
  frame.show()

  -- When
  frame.click( "Reset" )

  -- Then -- everybody present starts over at cycle 1
  eq( frame.reset_count(), 1 )
  eq( frame.round_robin.get_cycle(), 1 )
  frame.should_display( popup( {
    line( "Obszczymucha", colors.grey( "Received" ) ),
    line( "Psikutas", colors.grey( "Received" ) )
  } ) )
end

-- Somebody outside the instance or out of range is still in the rotation -- they just can't be
-- paid right now, and the column says so rather than dropping them off the list.
function RoundRobinQueueFrameSpec:should_dim_a_player_who_is_in_the_group_but_not_a_candidate()
  -- Given
  local frame = new_frame(
    { "Psikutas", "Obszczymucha" },
    { Psikutas = 2, Obszczymucha = 2 }, 2,
    { "Psikutas" } )

  -- When
  frame.show()

  -- Then
  frame.should_display( popup( {
    line( "Obszczymucha", colors.grey( "Received" ), colors.grey( "No" ) ),
    line( "Psikutas", colors.grey( "Received" ) )
  } ) )
end

function RoundRobinQueueFrameSpec:should_close_from_the_close_button()
  -- Given
  local frame = new_frame( { "Psikutas" } )
  frame.show()
  frame.should_be_visible()

  -- When
  frame.click( "Close" )

  -- Then
  frame.should_be_hidden()
end

os.exit( lu.LuaUnit.run() )
