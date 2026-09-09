---@diagnostic disable: inject-field, missing-fields
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

-- What counts as loot that dropped.
--
-- The record this builds is what everything downstream trusts: trading an item to its winner
-- only counts as awarding it if the item is in here, and a boss is credited with a kill because
-- one of its items turned up. So what must not get in is anything that did not come off a
-- creature or out of a chest. A disenchant and a lockbox are looted through the very same window,
-- with the very same events and slots, and neither dropped for anybody.

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
require( "src/Types" )
require( "src/ItemUtils" )
local Db = require( "src/Db" )
local DroppedLoot = require( "src/DroppedLoot" )

utils.mock_wow_api()

local ItemQuality = RollFor.Types.ItemQuality

-- The prefix is the whole of what a source GUID says here: a corpse is a Creature, a chest is a
-- GameObject, and an item you opened -- a lockbox, or the disenchant window -- is an Item.
local CREATURE = "Creature-0-4321-1234-0-19044-000012C1B7"
local GAME_OBJECT = "GameObject-0-4321-1234-0-185168-000012C1B7"
local AN_ITEM = "Item-6412-0-400000027180C59C"

local GRUULS_HORNS = 32837
local VOID_CRYSTAL = 22450

---@param id number
---@param name string
---@param quality number?
local function item( id, name, quality )
  return { id = id, name = name, quality = quality or ItemQuality.Epic }
end

-- The loot window, with what it holds and what it came out of.
--
-- The source is asked of the loot list rather than of the client: the same seam the rest of the
-- window comes through, so a simulated loot window (see RfTestLootFacade) can answer for its own
-- slots instead of the real client shrugging at them.
---@param items table[]
---@param source string
local function loot_window( items, source )
  local by_slot = {}

  for slot, looted in ipairs( items ) do by_slot[ slot ] = looted end

  -- Deliberately answering nothing: were DroppedLoot still reading the global, every one of these
  -- specs would pass on the harness's default corpse and prove nothing.
  utils.mock( "GetLootSourceInfo", function() return nil end )

  return {
    get_items = function() return items end,
    get_items_by_slot = function() return by_slot end,
    get_slot_source = function( slot ) return by_slot[ slot ] and source or nil end
  }
end

---@param loot_list table
---@param is_master_looter boolean?
local function dropped_loot( loot_list, is_master_looter )
  local saved = {}
  local killed = {}

  local sut = DroppedLoot.new( Db.new( saved )( "dropped_loot" ), loot_list,
    { is_master_looter = function() return is_master_looter ~= false end },
    { on_item_dropped = function( item_id ) table.insert( killed, item_id ) end } )

  sut.registered = function()
    local result = {}

    for _, entry in ipairs( saved.dropped_loot.dropped_items ) do table.insert( result, entry.id ) end

    return result
  end

  sut.credited_bosses = function() return killed end

  return sut
end

utils.loot_threshold( ItemQuality.Rare )

DroppedLootSpec = {}

function DroppedLootSpec:should_register_what_came_off_a_creature()
  local sut = dropped_loot( loot_window( { item( GRUULS_HORNS, "Gruul's Horns" ) }, CREATURE ) )

  sut.on_loot_opened()

  eq( sut.registered(), { GRUULS_HORNS } )
  eq( sut.get_dropped_item_name( GRUULS_HORNS ), "Gruul's Horns" )
end

-- Disenchanting opens a loot window like any other. The shards did not drop, nobody is owed
-- them, and trading one to a guildmate is not awarding them anything.
function DroppedLootSpec:should_not_register_what_came_out_of_a_disenchant()
  local sut = dropped_loot( loot_window( { item( VOID_CRYSTAL, "Void Crystal" ) }, AN_ITEM ) )

  sut.on_loot_opened()

  eq( sut.registered(), {} )
  eq( sut.get_dropped_item_name( VOID_CRYSTAL ), nil )
end

-- Nothing died, so nothing is a boss kill either.
function DroppedLootSpec:should_not_credit_a_boss_for_a_disenchant()
  local sut = dropped_loot( loot_window( { item( GRUULS_HORNS, "Gruul's Horns" ) }, AN_ITEM ) )

  sut.on_loot_opened()

  eq( sut.credited_bosses(), {} )
end

-- A chest is loot the raid found and has to hand out -- Zul'Aman's timed chests are exactly
-- that -- so it counts, the same as a corpse. What does not is an item a player opened.
function DroppedLootSpec:should_register_what_came_out_of_a_chest()
  local sut = dropped_loot( loot_window( { item( GRUULS_HORNS, "Gruul's Horns" ) }, GAME_OBJECT ) )

  sut.on_loot_opened()

  eq( sut.registered(), { GRUULS_HORNS } )
end

function DroppedLootSpec:should_credit_a_boss_for_what_came_off_a_creature()
  local sut = dropped_loot( loot_window( { item( GRUULS_HORNS, "Gruul's Horns" ) }, CREATURE ) )

  sut.on_loot_opened()

  eq( sut.credited_bosses(), { GRUULS_HORNS } )
end

-- Unchanged: the record is the master looter's, because it is what their awards are reconciled
-- against.
function DroppedLootSpec:should_register_nothing_when_you_are_not_the_master_looter()
  local sut = dropped_loot( loot_window( { item( GRUULS_HORNS, "Gruul's Horns" ) }, CREATURE ), false )

  sut.on_loot_opened()

  eq( sut.registered(), {} )
end

os.exit( lu.LuaUnit.run() )
