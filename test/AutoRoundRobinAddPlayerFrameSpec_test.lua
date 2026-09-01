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
local frame_mock = require( "mocks/AutoRoundRobinAddPlayerFrame" )
require( "src/ItemCatalogue" )
require( "src/AutoRoundRobinDb" )
local AutoRoundRobin = require( "src/AutoRoundRobin" )

u.mock_wow_api()

-- The title is three coloured pieces, not one: |r resets to the default colour rather than to the
-- enclosing one, so a highlighted category nested inside a blue line would leave everything after
-- it white.
---@param category string
local function title( category )
  return string.format( "%s%s%s",
    RollFor.colors.blue( "Add a player to the " ),
    RollFor.colors.hl( category ),
    RollFor.colors.blue( " queue" ) )
end

---@param group table[]? -- who the roster knows about, for the class guess
local function new_frame( group )
  local db = Db.new( {} )
  local round_robin_db = db( "autorobin" )
  RollFor.AutoRoundRobinDb.ensure_seeded( round_robin_db )

  local players = group or {}

  local group_roster = {
    get_all_players_in_my_group = function() return players end,
    find_player = function( name )
      for _, player in ipairs( players ) do
        if string.lower( player.name ) == string.lower( name ) then return player end
      end
    end
  }

  local round_robin = AutoRoundRobin.new(
    { is_looting = function() return false end, get_items_by_slot = function() return {} end },
    function() return RollFor.api end,
    round_robin_db,
    { auto_round_robin = function() return true end },
    { is_master_looter = function() return true end },
    { announce = function() end },
    group_roster,
    { get = function() return {} end, get_index = function() end },
    { is_auto_looted = function() return false end },
    { on_loot_awarded = function() end }
  )

  local added = 0
  local frame = frame_mock.new( popup_builder, round_robin, group_roster, function() added = added + 1 end )

  frame.round_robin = round_robin
  frame.added_count = function() return added end

  ---@param category string?
  frame.queue = function( category )
    local result = {}

    for _, player in ipairs( round_robin.get_queue( category or "Gems" ) ) do
      table.insert( result, { player.name, player.class } )
    end

    return result
  end

  return frame
end

AddPlayerFrameSpec = {}

function AddPlayerFrameSpec:should_be_hidden_by_default()
  new_frame().should_be_hidden()
end

function AddPlayerFrameSpec:should_name_the_queue_it_will_add_to()
  local frame = new_frame()

  frame.show( "Hearts" )

  frame.should_be_visible()
  lu.assertEquals( frame.labels()[ 1 ], title( "Hearts" ) )
end

function AddPlayerFrameSpec:should_offer_every_class_alphabetically()
  local frame = new_frame()

  frame.show( "Gems" )

  eq( frame.class_options(), {
    "Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior"
  } )
end

function AddPlayerFrameSpec:should_add_the_typed_player_to_the_named_queue()
  local frame = new_frame()
  frame.show( "Marks" )

  frame.type_name( "Ohhaimark" )
  frame.pick_class( "Rogue" )
  frame.click( "Add" )

  eq( frame.queue( "Marks" ), { { "Ohhaimark", "Rogue" } } )
  eq( frame.queue( "Gems" ), {} )
  eq( frame.added_count(), 1 )
  frame.should_be_hidden()
end

-- Two fields where the second has a sensible default, so reaching for the mouse to confirm a name
-- you just typed is the odd path.
function AddPlayerFrameSpec:should_submit_on_enter()
  local frame = new_frame()
  frame.show( "Gems" )

  frame.type_name( "Ohhaimark" )
  frame.press_enter()

  eq( frame.queue(), { { "Ohhaimark", "Warrior" } } )
end

-- The roster already knows the class of anybody standing next to you, and making somebody pick it
-- again from a dropdown is asking them to retype a fact.
function AddPlayerFrameSpec:should_fill_the_class_in_for_somebody_in_the_group()
  local frame = new_frame( { { name = "Obszczymucha", class = "Druid" } } )
  frame.show( "Gems" )

  frame.type_name( "Obszczymucha" )
  frame.click( "Add" )

  eq( frame.queue(), { { "Obszczymucha", "Druid" } } )
end

function AddPlayerFrameSpec:should_leave_the_chosen_class_alone_for_a_name_nobody_knows()
  local frame = new_frame( { { name = "Obszczymucha", class = "Druid" } } )
  frame.show( "Gems" )

  frame.pick_class( "Mage" )
  frame.type_name( "Astranger" )
  frame.click( "Add" )

  eq( frame.queue(), { { "Astranger", "Mage" } } )
end

function AddPlayerFrameSpec:should_stay_open_and_explain_a_duplicate()
  local frame = new_frame()
  frame.show( "Gems" )
  frame.type_name( "Ohhaimark" )
  frame.click( "Add" )

  frame.show( "Gems" )
  frame.type_name( "ohhaimark" )
  frame.click( "Add" )

  frame.should_be_visible()
  lu.assertEquals( frame.field( RollFor.colors.red( "Ohhaimark is already in the Gems queue." ) ) ~= nil, true )
  eq( frame.queue(), { { "Ohhaimark", "Warrior" } } )
end

function AddPlayerFrameSpec:should_refuse_a_blank_name()
  local frame = new_frame()
  frame.show( "Gems" )

  frame.click( "Add" )

  frame.should_be_visible()
  eq( frame.queue(), {} )
end

-- A fresh form every time: the last name added is never the next one, and a stale error about it
-- would be about nothing.
function AddPlayerFrameSpec:should_clear_the_name_and_the_error_when_reopened()
  local frame = new_frame()
  frame.show( "Gems" )
  frame.click( "Add" ) -- blank, so it errors

  frame.show( "Gems" )

  eq( frame.field( "Name" ).value, "" )
  eq( frame.labels(), { title( "Gems" ), "Name", "Class", "Add", "Cancel" } )
end

function AddPlayerFrameSpec:should_close_on_cancel_without_adding()
  local frame = new_frame()
  frame.show( "Gems" )
  frame.type_name( "Ohhaimark" )

  frame.click( "Cancel" )

  frame.should_be_hidden()
  eq( frame.queue(), {} )
  eq( frame.added_count(), 0 )
end

os.exit( lu.LuaUnit.run() )
