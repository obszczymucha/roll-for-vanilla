package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua;../RollFor/libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )

local player = utils.player
local leader = utils.raid_leader
local is_in_raid = utils.is_in_raid
local loot_threshold = utils.loot_threshold
local mock_blizzard_loot_buttons = utils.mock_blizzard_loot_buttons
local LootQuality = utils.LootQuality
local r = utils.raid_message
local loot = utils.loot
local master_looter = utils.master_looter
local assert_messages = utils.assert_messages
local item = utils.item
local targetting_enemy = utils.targetting_enemy
local soft_res = utils.soft_res
local hr = utils.hard_res_item
local sr = utils.soft_res_item
local mock = utils.mock

DroppedLootAnnounceIntegrationSpec = {}

function DroppedLootAnnounceIntegrationSpec:should_not_show_loot_that_dropped_if_not_a_master_looter()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  loot_threshold( LootQuality.Epic )

  -- When
  loot()

  -- Then
  assert_messages(
  )
end

function DroppedLootAnnounceIntegrationSpec:should_not_show_loot_if_there_are_no_epic_quality_items()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  loot_threshold( LootQuality.Epic )
  mock( "GiveMasterLoot" )

  -- When
  loot( item( "Hearthstone", 123, 3 ) )

  -- Then
  assert_messages(
  )
end

function DroppedLootAnnounceIntegrationSpec:should_only_show_loot_once()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  targetting_enemy( "Moroes" )

  -- When
  loot( item( "Hearthstone", 123 ), item( "Hearthstone", 123 ), item( "Some item", 400 ) )
  loot( item( "Hearthstone", 123 ), item( "Hearthstone", 123 ), item( "Some item", 400 ) )

  -- Then
  assert_messages(
    r( "Moroes dropped 3 items:" ),
    r( "1. 2x[Hearthstone]" ),
    r( "2. [Some item]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_loot_that_dropped_if_a_master_looter_and_targetting_an_enemy()
  -- Given
  master_looter( "Psikutas" )
  targetting_enemy( "Instructor Razuvious" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  loot( item( "Hearthstone", 123 ), item( "Some item", 400 ) )

  -- Then
  assert_messages(
    r( "Instructor Razuvious dropped 2 items:" ),
    r( "1. [Hearthstone]" ),
    r( "2. [Some item]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_not_announce_badges_of_justice()
  -- Given
  master_looter( "Psikutas" )
  targetting_enemy( "Netherspite" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  utils.mock( "UnitGUID", "PrincessKenny_123" )
  loot_threshold( LootQuality.Epic )
  mock_blizzard_loot_buttons()

  -- When
  loot( item( "Hearthstone", 123 ), item( "Badge of Justice", 29434 ), item( "Some item", 400 ) )

  -- Then
  assert_messages(
    r( "Netherspite dropped 2 items:" ),
    r( "1. [Hearthstone]" ),
    r( "2. [Some item]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_hard_ressed_items()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( hr( 123 ) )

  -- When
  loot( item( "Hearthstone", 123 ) )

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (HR)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_soft_ressed_items_by_one_player()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ) )

  -- When
  loot( item( "Hearthstone", 123 ) )

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (SR by Psikutas)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_soft_ressed_items_by_two_players()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) )

  -- When
  loot( item( "Hearthstone", 123 ) )

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (SR by Obszczymucha and Psikutas)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_soft_ressed_items_by_two_players_separately_for_each_item()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) )

  -- When
  loot( item( "Hearthstone", 123 ), item( "Hearthstone", 123 ) )

  -- Then
  assert_messages(
    r( "2 items dropped:" ),
    r( "1. [Hearthstone] (SR by Obszczymucha)" ),
    r( "2. [Hearthstone] (SR by Psikutas)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_soft_ressed_items_by_three_players()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Ponpon", 123 ) )

  -- When
  loot( item( "Hearthstone", 123 ) )

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (SR by Obszczymucha, Ponpon and Psikutas)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_soft_ressed_items_by_two_players_with_multiple_rolls()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Psikutas", 123 ) )

  -- When
  loot( item( "Hearthstone", 123 ) )

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (SR by Obszczymucha and Psikutas [2 rolls])" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_hr_items_first()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( hr( 1337 ) )

  -- When
  loot( item( "Wirt's Third Leg", 222 ), item( "Onyxia's Droppings", 1337 ) )

  -- Then
  assert_messages(
    r( "2 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Wirt's Third Leg]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_single_res_sr_items_alphabetically_after_hr_items()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 111 ), hr( 1337 ) )

  -- When
  loot( item( "Hearthstone", 123 ), item( "Wirt's Third Leg", 222 ), item( "Onyxia's Droppings", 1337 ), item( "Dick", 111 ) )

  -- Then
  assert_messages(
    r( "4 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Dick] (SR by Obszczymucha)" ),
    r( "3. [Hearthstone] (SR by Psikutas)" ),
    r( "4. [Wirt's Third Leg]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_not_sort_items_items_with_the_same_amount_of_softressers_if_there_is_more_than_one_softresser()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Psikutas", 111 ), sr( "Obszczymucha", 111 ), hr( 1337 ) )

  -- When
  loot( item( "Hearthstone", 123 ), item( "Wirt's Third Leg", 222 ), item( "Onyxia's Droppings", 1337 ), item( "Dick", 111 ) )

  -- Then
  assert_messages(
    r( "4 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Hearthstone] (SR by Obszczymucha and Psikutas)" ),
    r( "3. [Dick] (SR by Obszczymucha and Psikutas)" ),
    r( "4. [Wirt's Third Leg]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_sort_softres_player_counts_ascending()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Psikutas", 111 ), sr( "Obszczymucha", 111 ), sr( "Ponpon", 111 ), hr( 1337 ) )

  -- When
  loot( item( "Hearthstone", 123 ), item( "Wirt's Third Leg", 222 ), item( "Onyxia's Droppings", 1337 ), item( "Dick", 111 ) )

  -- Then
  assert_messages(
    r( "4 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Hearthstone] (SR by Obszczymucha and Psikutas)" ),
    r( "3. [Dick] (SR by Obszczymucha, Ponpon and Psikutas)" ),
    r( "4. [Wirt's Third Leg]" )
  )
end

utils.mock_libraries()
utils.load_real_stuff()

os.exit( lu.LuaUnit.run() )
