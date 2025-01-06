package.path = "./?.lua;" .. package.path .. ";../?.lua;./../RollFor/?.lua;../RollFor/libs/?.lua"

local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
local m = require( "src/modules" )
require( "src/Interface" )
require( "src/WowApi" )
---@diagnostic disable-next-line: different-requires
local LootFacade = require( "test/mocks/LootFacade" )
require("src/DebugBuffer")
require("src/Module")
require( "src/ItemUtils" )
require( "src/LootList" )
require( "src/SoftResLootListDecorator" )

local getn = table.getn
local LootQuality = utils.LootQuality
local item_link = utils.item_link
local mock_value, mock_values = utils.mock_value, utils.mock_values

LootListSpec = {}

local softres = {
  get = function() return {} end,
  is_item_hardressed = function() return false end
}

function LootListSpec.should_return_a_coin_entry_if_its_the_only_one_that_dropped()
  -- Given
  local loot_facade = LootFacade.new()
  loot_facade.get_item_count = mock_value( 1 )
  loot_facade.is_coin = mock_value( true )
  loot_facade.get_info = mock_value( { texture = "Interface\\Icons\\INV_Misc_Coin_06", name = "64 Copper", quantity = 0, quality = 0 } )
  local raw_loot_list = m.LootList.new( loot_facade, m.ItemUtils )
  local loot_list = m.SoftResLootListDecorator.new( raw_loot_list, softres )

  -- When
  LootFacade.notify( "LootOpened" )
  local result = loot_list.get_items()

  -- Then
  eq( getn( result ), 1 )
  eq( result[ 1 ].coin, true )
  eq( result[ 1 ].texture, "Interface\\Icons\\INV_Misc_Coin_06" )
  eq( result[ 1 ].amount_text, "64 Copper" )
end

function LootListSpec.should_return_an_item_entry_if_its_the_only_one_that_dropped()
  -- Given
  local loot_facade = LootFacade.new()
  loot_facade.get_item_count = mock_value( 1 )
  loot_facade.is_coin = mock_value( false )
  local link = item_link( "Big item", 123 )
  loot_facade.get_link = mock_value( link )
  loot_facade.get_info = mock_value( { texture = "tex", name = "item", quantity = 1, quality = LootQuality.Epic } )
  local raw_loot_list = m.LootList.new( loot_facade, m.ItemUtils )
  local loot_list = m.SoftResLootListDecorator.new( raw_loot_list, softres )

  -- When
  LootFacade.notify( "LootOpened" )
  local result = loot_list.get_items()

  -- Then
  eq( getn( result ), 1 )
  eq( result[ 1 ].coin, nil )
  eq( result[ 1 ].id, 123 )
  eq( result[ 1 ].name, "Big item" )
  eq( result[ 1 ].texture, "tex" )
  eq( result[ 1 ].slot, 1 )
  eq( result[ 1 ].link, link )
  eq( result[ 1 ].quality, LootQuality.Epic )
end

function LootListSpec.should_sort_the_coin_last()
  -- Given
  local loot_facade = LootFacade.new()
  loot_facade.get_item_count = mock_value( 2 )
  loot_facade.is_coin = mock_value( false, true )
  local link = item_link( "Big item", 123 )
  loot_facade.get_link = mock_value( link )
  loot_facade.get_info = mock_value(
    { texture = "tex", name = "item", quantity = 1, quality = LootQuality.Epic },
    { texture = "coin texture", name = "1337 Copper", quantity = 0, quality = 0 }
  )
  local raw_loot_list = m.LootList.new( loot_facade, m.ItemUtils )
  local loot_list = m.SoftResLootListDecorator.new( raw_loot_list, softres )

  -- When
  LootFacade.notify( "LootOpened" )
  local result = loot_list.get_items()

  -- Then
  eq( getn( result ), 2 )
  eq( result[ 1 ].coin, nil )
  eq( result[ 1 ].id, 123 )
  eq( result[ 1 ].name, "Big item" )
  eq( result[ 1 ].texture, "tex" )
  eq( result[ 1 ].slot, 1 )
  eq( result[ 1 ].link, link )
  eq( result[ 1 ].quality, LootQuality.Epic )
  eq( result[ 2 ].coin, true )
  eq( result[ 2 ].texture, "coin texture" )
  eq( result[ 2 ].amount_text, "1337 Copper" )
end

function LootListSpec.should_sort_the_items_by_quality_and_then_name()
  -- Given
  local loot_facade = LootFacade.new()
  loot_facade.get_item_count = mock_value( 3 )
  loot_facade.is_coin = mock_value( false, false )
  local links = { item_link( "Small item", 111 ), item_link( "Big item", 222 ), item_link( "Average item", 333 ) }
  loot_facade.get_link = mock_values( links )
  loot_facade.get_info = mock_value(
    { texture = "tex", name = "item", quantity = 1, quality = LootQuality.Rare },
    { texture = "tex", name = "item", quantity = 1, quality = LootQuality.Epic },
    { texture = "tex", name = "item", quantity = 1, quality = LootQuality.Rare }
  )
  local raw_loot_list = m.LootList.new( loot_facade, m.ItemUtils )
  local loot_list = m.SoftResLootListDecorator.new( raw_loot_list, softres )

  -- When
  LootFacade.notify( "LootOpened" )
  local result = loot_list.get_items()

  -- Then
  eq( getn( result ), 3 )
  eq( result[ 1 ].coin, nil )
  eq( result[ 1 ].id, 222 )
  eq( result[ 1 ].name, "Big item" )
  eq( result[ 1 ].texture, "tex" )
  eq( result[ 1 ].slot, 2 )
  eq( result[ 1 ].link, links[ 2 ] )
  eq( result[ 1 ].quality, LootQuality.Epic )
  eq( result[ 2 ].coin, nil )
  eq( result[ 2 ].id, 333 )
  eq( result[ 2 ].name, "Average item" )
  eq( result[ 2 ].texture, "tex" )
  eq( result[ 2 ].slot, 3 )
  eq( result[ 2 ].link, links[ 3 ] )
  eq( result[ 2 ].quality, LootQuality.Rare )
  eq( result[ 3 ].coin, nil )
  eq( result[ 3 ].id, 111 )
  eq( result[ 3 ].name, "Small item" )
  eq( result[ 3 ].texture, "tex" )
  eq( result[ 3 ].slot, 1 )
  eq( result[ 3 ].link, links[ 1 ] )
  eq( result[ 3 ].quality, LootQuality.Rare )
end

os.exit( lu.LuaUnit.run() )
