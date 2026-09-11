package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

-- The seam that lets an extension keep a dropped item out of the raid announcement.
--
-- Core cannot answer "is this item somebody else's to hand out?" -- only whoever is
-- handing it out can, and that may be another addon entirely. So core asks, and this
-- suite covers the asking. What an extension's predicate *answers* is the extension's own
-- test.

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_wow_api()
require( "src/modules" )
require( "src/Types" )
require( "src/ItemUtils" )
require( "src/SoftRes" )
local mod = require( "src/DroppedLootAnnounce" )

local HEARTHSTONE = u.item( "Hearthstone", 6948, 4 )
local ROBE = u.item( "Robe of Hateful Echoes", 32586, 4 )

u.loot_threshold( 2 )

local function loot_list( ... )
  local items = { ... }

  return {
    get_source_guid = function() return "boss-guid" end,
    get_items = function() return items end
  }
end

local softres = {
  get = function() return {} end,
  is_item_hardressed = function() return false end
}

---@return string[] -- the names of the items that survived the filter
local function announced( withhold )
  local _, items = mod.process_dropped_items( loot_list( HEARTHSTONE, ROBE ), softres, withhold )

  local names = {}
  for _, item in ipairs( items ) do table.insert( names, item.name ) end

  return names
end

DroppedItemWithholdSpec = {}

function DroppedItemWithholdSpec:should_announce_everything_when_nobody_registered_a_predicate()
  eq( announced(), { "Hearthstone", "Robe of Hateful Echoes" } )
end

function DroppedItemWithholdSpec:should_announce_everything_when_no_predicate_objects()
  eq( announced( { function() return true end } ), { "Hearthstone", "Robe of Hateful Echoes" } )
end

-- nil is what a predicate with no opinion about this item returns, and it must read as
-- "leave it alone" rather than as a withholding.
function DroppedItemWithholdSpec:should_treat_a_predicate_that_answers_nothing_as_no_opinion()
  eq( announced( { function() return nil end } ), { "Hearthstone", "Robe of Hateful Echoes" } )
end

function DroppedItemWithholdSpec:should_withhold_the_item_a_predicate_answers_false_for()
  eq( announced( { function( item ) return item.id ~= 32586 end } ), { "Hearthstone" } )
end

function DroppedItemWithholdSpec:should_withhold_when_any_predicate_objects()
  eq( announced( {
    function() return true end,
    function( item ) return item.id ~= 6948 end
  } ), { "Robe of Hateful Echoes" } )
end

-- Every predicate is asked about every item rather than stopping at the first false, so
-- one is never quietly skipped because of the order it registered in.
function DroppedItemWithholdSpec:should_ask_every_predicate_about_every_item()
  local asked = {}

  announced( {
    function( item ) table.insert( asked, string.format( "first:%s", item.id ) ) return false end,
    function( item ) table.insert( asked, string.format( "second:%s", item.id ) ) return true end
  } )

  eq( asked, { "first:6948", "second:6948", "first:32586", "second:32586" } )
end

os.exit( lu.LuaUnit.run() )
