package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua;../RollFor/libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
utils.mock_wow_api()
utils.load_libstub()
local LootQuality = utils.LootQuality
local loot_threshold = utils.loot_threshold
local modules = require( "src/modules" )
local ItemUtils = require( "src/ItemUtils" )
local make_item = ItemUtils.make_item
require( "src/SoftResDataTransformer" )
require( "src/SoftRes" )
require( "src/MasterLootTracker" )
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
    item = { id = 123, link = "[Hearthstone]", name = "Hearthstone", quality = LootQuality.Epic },
    how_many_dropped = 2,
    softressers = {
      { name = "Obszczymucha", rolls = 1 },
      { name = "Psikutas",     rolls = 1 }
    },
    is_hardressed = false
  } )

  lu.assertEquals( result[ 2 ], {
    item = { id = 111, link = "[Big mace]", name = "Big mace", quality = LootQuality.Epic },
    how_many_dropped = 1,
    softressers = {},
    is_hardressed = true
  } )

  lu.assertEquals( result[ 3 ], {
    item = { id = 112, link = "[Small mace]", name = "Small mace", quality = LootQuality.Epic },
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
    item = { id = 123, link = "[Hearthstone]", name = "Hearthstone", quality = LootQuality.Epic },
    how_many_dropped = 2,
    softressers = {
      { name = "Obszczymucha", rolls = 1 },
      { name = "Psikutas",     rolls = 1 }
    },
    is_hardressed = false
  } )

  lu.assertEquals( result[ 2 ], {
    item = { id = 123, link = "[Hearthstone]", name = "Hearthstone", quality = LootQuality.Epic },
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

ProcessDroppedItemsIntegrationSpec = {}

local function make_link( _item )
  return utils.item_link( _item.name, _item.id )
end

local function make_quality( _item )
  return function() return _, _, _, _item.quality end
end

local function process_dropped_items()
  return mod.process_dropped_items( modules.MasterLootTracker.new(), modules.SoftRes.new() )
end

function ProcessDroppedItemsIntegrationSpec:should_return_source_guid()
  -- Given
  local items = { item( "Legendary item", 123, LootQuality.Legendary ), item( "Epic item", 124, LootQuality.Epic ) }
  utils.mock( "GetNumLootItems", #items )
  -- utils.mock( "UnitGUID", "PrincessKenny_123" ) -- 2.4.3
  utils.mock( "UnitName", "Nightbane" )
  utils.targetting_enemy( "Nightbane" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )

  -- When
  local result, _, _ = process_dropped_items()

  -- Then
  lu.assertEquals( result, "Nightbane" )
end

function ProcessDroppedItemsIntegrationSpec:should_return_dropped_items()
  -- Given
  local items = { item( "Legendary item", 123, LootQuality.Legendary ), item( "Epic item", 124, LootQuality.Epic ) }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "UnitGUID", "PrincessKenny_123" )
  utils.targetting_enemy( "Nightbane" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )

  -- When
  local _, result, _ = process_dropped_items()

  -- Then
  lu.assertEquals( result, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = LootQuality.Legendary },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r",      name = "Epic item",      quality = LootQuality.Epic }
  } )
end

function ProcessDroppedItemsIntegrationSpec:should_filter_items_below_epic_quality_threshold()
  -- Given
  local items = {
    item( "Legendary item", 123, LootQuality.Legendary ),
    item( "Epic item", 124, LootQuality.Epic ),
    item( "Rare item", 125, LootQuality.Rare ),
    item( "Uncommon item", 126, LootQuality.Uncommon ),
    item( "Common item", 127, LootQuality.Common ),
    item( "Poor item", 128, LootQuality.Poor )
  }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "UnitGUID", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )
  loot_threshold( LootQuality.Epic )

  -- When
  local _, items_dropped, announcements = process_dropped_items()
  local result = map( get_text( announcements ), utils.parse_item_link )

  -- Then
  lu.assertEquals( items_dropped, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = LootQuality.Legendary },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r",      name = "Epic item",      quality = LootQuality.Epic }
  } )

  lu.assertEquals( result, {
    "1. [Legendary item]",
    "2. [Epic item]"
  } )
end

function ProcessDroppedItemsIntegrationSpec:should_filter_items_below_rare_quality_threshold()
  -- Given
  local items = {
    item( "Legendary item", 123, LootQuality.Legendary ),
    item( "Epic item", 124, LootQuality.Epic ),
    item( "Rare item", 125, LootQuality.Rare ),
    item( "Uncommon item", 126, LootQuality.Uncommon ),
    item( "Common item", 127, LootQuality.Common ),
    item( "Poor item", 128, LootQuality.Poor )
  }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "UnitGUID", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )
  utils.mock( "UnitName", "Onyxia" )
  loot_threshold( LootQuality.Rare )

  -- When
  local _, items_dropped, announcements = process_dropped_items()
  local result = map( get_text( announcements ), utils.parse_item_link )

  -- Then
  lu.assertEquals( items_dropped, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = LootQuality.Legendary },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r",      name = "Epic item",      quality = LootQuality.Epic },
    { id = 125, link = "|cff9d9d9d|Hitem:125::::::::20:257::::::|h[Rare item]|h|r",      name = "Rare item",      quality = LootQuality.Rare }
  } )

  lu.assertEquals( result, {
    "1. [Legendary item]",
    "2. [Epic item]",
    "3. [Rare item]"
  } )
end

function ProcessDroppedItemsIntegrationSpec:should_filter_items_below_uncommon_quality_threshold()
  -- Given
  local items = {
    item( "Legendary item", 123, LootQuality.Legendary ),
    item( "Epic item", 124, LootQuality.Epic ),
    item( "Rare item", 125, LootQuality.Rare ),
    item( "Uncommon item", 126, LootQuality.Uncommon ),
    item( "Common item", 127, LootQuality.Common ),
    item( "Poor item", 128, LootQuality.Poor )
  }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "UnitGUID", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )
  loot_threshold( LootQuality.Uncommon )

  -- When
  local _, items_dropped, announcements = process_dropped_items()
  local result = map( get_text( announcements ), utils.parse_item_link )

  -- Then
  lu.assertEquals( items_dropped, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = LootQuality.Legendary },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r",      name = "Epic item",      quality = LootQuality.Epic },
    { id = 125, link = "|cff9d9d9d|Hitem:125::::::::20:257::::::|h[Rare item]|h|r",      name = "Rare item",      quality = LootQuality.Rare },
    { id = 126, link = "|cff9d9d9d|Hitem:126::::::::20:257::::::|h[Uncommon item]|h|r",  name = "Uncommon item",  quality = LootQuality.Uncommon }
  } )

  lu.assertEquals( result, {
    "1. [Legendary item]",
    "2. [Epic item]",
    "3. [Rare item]",
    "4. [Uncommon item]"
  } )
end

function ProcessDroppedItemsIntegrationSpec:should_filter_items_below_common_quality_threshold()
  -- Given
  local items = {
    item( "Legendary item", 123, LootQuality.Legendary ),
    item( "Epic item", 124, LootQuality.Epic ),
    item( "Rare item", 125, LootQuality.Rare ),
    item( "Uncommon item", 126, LootQuality.Uncommon ),
    item( "Common item", 127, LootQuality.Common ),
    item( "Poor item", 128, LootQuality.Poor )
  }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "UnitGUID", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )
  utils.mock( "UnitName", "Onyxia" )
  loot_threshold( LootQuality.Common )

  -- When
  local _, items_dropped, announcements = process_dropped_items()
  local result = map( get_text( announcements ), utils.parse_item_link )

  -- Then
  lu.assertEquals( items_dropped, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = LootQuality.Legendary },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r",      name = "Epic item",      quality = LootQuality.Epic },
    { id = 125, link = "|cff9d9d9d|Hitem:125::::::::20:257::::::|h[Rare item]|h|r",      name = "Rare item",      quality = LootQuality.Rare },
    { id = 126, link = "|cff9d9d9d|Hitem:126::::::::20:257::::::|h[Uncommon item]|h|r",  name = "Uncommon item",  quality = LootQuality.Uncommon },
    { id = 127, link = "|cff9d9d9d|Hitem:127::::::::20:257::::::|h[Common item]|h|r",    name = "Common item",    quality = LootQuality.Common }
  } )

  lu.assertEquals( result, {
    "1. [Legendary item]",
    "2. [Epic item]",
    "3. [Rare item]",
    "4. [Uncommon item]",
    "5. [Common item]"
  } )
end

function ProcessDroppedItemsIntegrationSpec:should_not_filter_any_items_if_threshold_is_set_to_poor_quality()
  -- Given
  local items = {
    item( "Legendary item", 123, LootQuality.Legendary ),
    item( "Epic item", 124, LootQuality.Epic ),
    item( "Rare item", 125, LootQuality.Rare ),
    item( "Uncommon item", 126, LootQuality.Uncommon ),
    item( "Common item", 127, LootQuality.Common ),
    item( "Poor item", 128, LootQuality.Poor )
  }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "UnitGUID", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )
  loot_threshold( LootQuality.Poor )

  -- When
  local _, items_dropped, announcements = process_dropped_items()
  local result = map( get_text( announcements ), utils.parse_item_link )

  -- Then
  lu.assertEquals( items_dropped, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = LootQuality.Legendary },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r",      name = "Epic item",      quality = LootQuality.Epic },
    { id = 125, link = "|cff9d9d9d|Hitem:125::::::::20:257::::::|h[Rare item]|h|r",      name = "Rare item",      quality = LootQuality.Rare },
    { id = 126, link = "|cff9d9d9d|Hitem:126::::::::20:257::::::|h[Uncommon item]|h|r",  name = "Uncommon item",  quality = LootQuality.Uncommon },
    { id = 127, link = "|cff9d9d9d|Hitem:127::::::::20:257::::::|h[Common item]|h|r",    name = "Common item",    quality = LootQuality.Common },
    { id = 128, link = "|cff9d9d9d|Hitem:128::::::::20:257::::::|h[Poor item]|h|r",      name = "Poor item",      quality = LootQuality.Poor }
  } )

  lu.assertEquals( result, {
    "1. [Legendary item]",
    "2. [Epic item]",
    "3. [Rare item]",
    "4. [Uncommon item]",
    "5. [Common item]",
    "6. [Poor item]"
  } )
end

os.exit( lu.LuaUnit.run() )
