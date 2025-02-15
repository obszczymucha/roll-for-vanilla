package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local lu = require( "luaunit" )
local utils = require( "test/utils" )
utils.mock_wow_api()
local LootQuality = utils.LootQuality
local modules = require( "src/modules" )
local ItemUtils = require( "src/ItemUtils" )
local LT = ItemUtils.LootType
local make_item = ItemUtils.make_item
require( "src/Types" )
require( "src/SoftResDataTransformer" )
require( "src/SoftRes" )
local mod = require( "src/DroppedLootAnnounce" )
local map = utils.map

local item = function( name, id, quality ) return make_item( id, name, string.format( "[%s]", name ), quality or 4 ) end

local hr = function( ... )
  local result = {}

  for _, v in pairs( { ... } ) do
    table.insert( result, { id = v } )
  end

  return result
end

DroppedLootAnnounceSpec = {}

function DroppedLootAnnounceSpec:should_create_item_details()
  -- When
  local result = make_item( 123, "Hearthstone", "fake link", 4 )

  -- Expect
  lu.assertEquals( result.id, 123 )
  lu.assertEquals( result.name, "Hearthstone" )
  lu.assertEquals( result.link, "fake link" )
  lu.assertEquals( result.quality, LootQuality.Epic )
end

local function softres( softresses, hardresses )
  local result = modules.SoftRes.new()
  result.import( { softreserves = softresses, hardreserves = hardresses } )

  return result
end

local function sr( player_name, ... )
  local item_ids = { ... }
  local items = {}

  for _, v in pairs( item_ids ) do
    table.insert( items, { id = v } )
  end

  return { name = player_name, items = items }
end

ItemSummarySpec = {}

function ItemSummarySpec:should_create_the_summary()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs, item( "Big mace", 111 ), item( "Small mace", 112 ) }
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }

  -- When
  local result = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- Then
  lu.assertEquals( #items, 4 )
  lu.assertEquals( #result, 3 )
  lu.assertEquals( result[ 1 ], {
    item = { id = 123, link = "[Hearthstone]", name = "Hearthstone", quality = LootQuality.Epic, type = LT.Item },
    how_many_dropped = 2,
    softressers = {
      { name = "Obszczymucha", rolls = 1, type = "Roller" },
      { name = "Psikutas",     rolls = 1, type = "Roller" }
    },
    is_hardressed = false
  } )

  lu.assertEquals( result[ 2 ], {
    item = { id = 111, link = "[Big mace]", name = "Big mace", quality = LootQuality.Epic, type = LT.Item },
    how_many_dropped = 1,
    softressers = {},
    is_hardressed = true
  } )

  lu.assertEquals( result[ 3 ], {
    item = { id = 112, link = "[Small mace]", name = "Small mace", quality = LootQuality.Epic, type = LT.Item },
    how_many_dropped = 1,
    softressers = {},
    is_hardressed = false
  } )
end

function ItemSummarySpec:should_split_softresses_from_non_softresses_for_each_item()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs, hs, hs }
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }

  -- When
  local result = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- Then
  lu.assertEquals( #items, 4 )
  lu.assertEquals( #result, 2 )
  lu.assertEquals( result[ 1 ], {
    item = { id = 123, link = "[Hearthstone]", name = "Hearthstone", quality = LootQuality.Epic, type = LT.Item },
    how_many_dropped = 2,
    softressers = {
      { name = "Obszczymucha", rolls = 1, type = "Roller" },
      { name = "Psikutas",     rolls = 1, type = "Roller" }
    },
    is_hardressed = false
  } )

  lu.assertEquals( result[ 2 ], {
    item = { id = 123, link = "[Hearthstone]", name = "Hearthstone", quality = LootQuality.Epic, type = LT.Item },
    how_many_dropped = 2,
    softressers = {},
    is_hardressed = false
  } )
end

ItemAnnouncementSpec = {}

local function get_text( announcements )
  return map( announcements, function( v ) return v.text end )
end

function ItemAnnouncementSpec:should_create_announcements_if_there_is_one_sr_hr_and_normal()
  -- Given
  local items = { item( "Hearthstone", 123 ), item( "Big mace", 111 ), item( "Small mace", 112 ) }
  local softresses = { sr( "Psikutas", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- When
  local result = get_text( mod.create_item_announcements( summary ) )

  -- Then
  lu.assertEquals( result, {
    "1. [Big mace] (HR)",
    "2. [Hearthstone] (SR by Psikutas)",
    "3. [Small mace]"
  } )
end

function ItemAnnouncementSpec:should_create_announcements_if_there_is_one_sr_and_more_items_dropped()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs }
  local softresses = { sr( "Psikutas", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- When
  local result = get_text( mod.create_item_announcements( summary ) )

  -- Then
  lu.assertEquals( result, {
    "1. [Hearthstone] (SR by Psikutas)",
    "2. [Hearthstone]"
  } )
end

function ItemAnnouncementSpec:should_create_announcements_if_the_number_of_items_is_equal_to_softressers()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs, item( "Big mace", 111 ), item( "Small mace", 112 ) }
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- When
  local result = get_text( mod.create_item_announcements( summary ) )

  -- Then
  lu.assertEquals( result, {
    "1. [Big mace] (HR)",
    "2. [Hearthstone] (SR by Obszczymucha)",
    "3. [Hearthstone] (SR by Psikutas)",
    "4. [Small mace]"
  } )
end

function ItemAnnouncementSpec:should_create_announcements_if_the_number_of_items_is_greater_than_softressers_by_one()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs, hs, item( "Big mace", 111 ), item( "Small mace", 112 ) }
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- When
  local result = get_text( mod.create_item_announcements( summary ) )

  -- Then
  lu.assertEquals( result, {
    "1. [Big mace] (HR)",
    "2. [Hearthstone] (SR by Obszczymucha)",
    "3. [Hearthstone] (SR by Psikutas)",
    "4. [Hearthstone]",
    "5. [Small mace]"
  } )
end

function ItemAnnouncementSpec:should_create_announcements_if_the_number_of_items_is_greater_than_softressers_by_more()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs, hs, hs, item( "Big mace", 111 ), item( "Small mace", 112 ) }
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- When
  local result = get_text( mod.create_item_announcements( summary ) )

  -- Then
  lu.assertEquals( result, {
    "1. [Big mace] (HR)",
    "2. [Hearthstone] (SR by Obszczymucha)",
    "3. [Hearthstone] (SR by Psikutas)",
    "4. 2x[Hearthstone]",
    "5. [Small mace]"
  } )
end

function ItemAnnouncementSpec:should_group_items_that_are_not_soft_ressed()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local sm = item( "Small mace", 112 )
  local items = { hs, hs, hs, hs, item( "Big mace", 111 ), sm, sm }
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- When
  local result = get_text( mod.create_item_announcements( summary ) )

  -- Then
  lu.assertEquals( result, {
    "1. [Big mace] (HR)",
    "2. [Hearthstone] (SR by Obszczymucha)",
    "3. [Hearthstone] (SR by Psikutas)",
    "4. 2x[Hearthstone]",
    "5. 2x[Small mace]"
  } )
end

function ItemAnnouncementSpec:should_group_soft_ressers_if_only_one_sr_item_dropped()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local sm = item( "Small mace", 112 )
  local items = { hs, item( "Big mace", 111 ), sm, sm }
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- When
  local result = get_text( mod.create_item_announcements( summary ) )

  -- Then
  lu.assertEquals( result, {
    "1. [Big mace] (HR)",
    "2. [Hearthstone] (SR by Obszczymucha and Psikutas)",
    "3. 2x[Small mace]"
  } )
end

function ItemAnnouncementSpec:should_group_soft_ressers_if_only_one_sr_item_dropped_and_there_is_more_than_two_softressers()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local sm = item( "Small mace", 112 )
  local items = { hs, item( "Big mace", 111 ), sm, sm }
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Ponpon", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- When
  local result = get_text( mod.create_item_announcements( summary ) )

  -- Then
  lu.assertEquals( result, {
    "1. [Big mace] (HR)",
    "2. [Hearthstone] (SR by Obszczymucha, Ponpon and Psikutas)",
    "3. 2x[Small mace]"
  } )
end

function ItemAnnouncementSpec:should_group_soft_ressers_if_two_sr_items_dropped_and_there_is_more_than_two_softressers()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local sm = item( "Small mace", 112 )
  local items = { hs, hs, item( "Big mace", 111 ), sm, sm }
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Ponpon", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- When
  local result = get_text( mod.create_item_announcements( summary ) )

  -- Then
  lu.assertEquals( result, {
    "1. [Big mace] (HR)",
    "2. 2x[Hearthstone] (SR by Obszczymucha, Ponpon and Psikutas)",
    "3. 2x[Small mace]"
  } )
end

function ItemAnnouncementSpec:should_sort_soft_ressed_items_by_quality()
  -- Given
  local items = { item( "Big mace", 111, 3 ), item( "Hearthstone", 123, 4 ), item( "Small mace", 222 ) }
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 111 ) }
  local summary = mod.create_item_summary( items, softres( softresses ) )

  -- When
  local result = get_text( mod.create_item_announcements( summary ) )

  -- Then
  lu.assertEquals( result, {
    "1. [Hearthstone] (SR by Psikutas)",
    "2. [Big mace] (SR by Obszczymucha)",
    "3. [Small mace]"
  } )
end

os.exit( lu.LuaUnit.run() )
