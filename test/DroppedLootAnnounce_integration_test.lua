package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local m = require( "src/modules" )
local fr = utils.force_require

local player = utils.player
local leader = utils.raid_leader
local is_in_raid = utils.is_in_raid
local loot_threshold = utils.loot_threshold
local mock_blizzard_loot_buttons = utils.mock_blizzard_loot_buttons
local LootQuality = utils.LootQuality
local r = utils.raid_message
local master_looter = utils.master_looter
local assert_messages = utils.assert_messages
local item = utils.item
local targetting_enemy = utils.targetting_enemy
local soft_res = utils.soft_res
local hr = utils.hard_res_item
local sr = utils.soft_res_item
local mock = utils.mock

local loot_event_facade

local function loot()
  loot_event_facade.notify( "LootOpened" )
end

local function dropped( ... )
  RollFor.LootList = nil
  local loot_list = fr( "mocks/LootList" )

  local slot = 1
  local items = m.map( { ... }, function( i )
    if not i.slot then
      i.slot = slot
      slot = slot + 1
    end

    if not i.quality then i.quality = 4 end

    return i
  end )

  loot_list.items = items
end

DroppedLootAnnounceIntegrationSpec = {}

function DroppedLootAnnounceIntegrationSpec:should_not_show_loot_that_dropped_if_not_a_master_looter()
  -- Given
  dropped()
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
  dropped( item( "Hearthstone", 123, 3 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  loot_threshold( LootQuality.Epic )
  mock( "GiveMasterLoot" )

  -- When
  loot()

  -- Then
  assert_messages(
  )
end

function DroppedLootAnnounceIntegrationSpec:should_only_show_loot_once()
  -- Given
  dropped( item( "Hearthstone", 123 ), item( "Hearthstone", 123 ), item( "Some item", 400 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  targetting_enemy( "Moroes" )

  -- When
  loot()
  loot()

  -- Then
  assert_messages(
    r( "Moroes dropped 3 items:" ),
    r( "1. 2x[Hearthstone]" ),
    r( "2. [Some item]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_loot_that_dropped_if_a_master_looter_and_targetting_an_enemy()
  -- Given
  dropped( item( "Hearthstone", 123 ), item( "Some item", 400 ) )
  master_looter( "Psikutas" )
  targetting_enemy( "Instructor Razuvious" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "Instructor Razuvious dropped 2 items:" ),
    r( "1. [Hearthstone]" ),
    r( "2. [Some item]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_not_announce_badges_of_justice()
  -- Given
  dropped( item( "Hearthstone", 123 ), item( "Badge of Justice", 29434 ), item( "Some item", 400 ) )
  master_looter( "Psikutas" )
  targetting_enemy( "Netherspite" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  utils.mock( "UnitGUID", "PrincessKenny_123" )
  loot_threshold( LootQuality.Epic )
  mock_blizzard_loot_buttons()

  -- When
  loot()

  -- Then
  assert_messages(
    r( "Netherspite dropped 2 items:" ),
    r( "1. [Hearthstone]" ),
    r( "2. [Some item]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_hard_ressed_items()
  -- Given
  dropped( item( "Hearthstone", 123 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( hr( 123 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (HR)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_soft_ressed_items_by_one_player()
  -- Given
  dropped( item( "Hearthstone", 123 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (SR by Psikutas)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_soft_ressed_items_by_two_players()
  -- Given
  dropped( item( "Hearthstone", 123 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (SR by Obszczymucha and Psikutas)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_soft_ressed_items_by_two_players_separately_for_each_item()
  -- Given
  dropped( item( "Hearthstone", 123 ), item( "Hearthstone", 123 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "2 items dropped:" ),
    r( "1. [Hearthstone] (SR by Obszczymucha)" ),
    r( "2. [Hearthstone] (SR by Psikutas)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_soft_ressed_items_by_three_players()
  -- Given
  dropped( item( "Hearthstone", 123 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Ponpon", 123 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (SR by Obszczymucha, Ponpon and Psikutas)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_soft_ressed_items_by_two_players_with_multiple_rolls()
  -- Given
  dropped( item( "Hearthstone", 123 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Psikutas", 123 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (SR by Obszczymucha and Psikutas [2 rolls])" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_hr_items_first()
  -- Given
  dropped( item( "Wirt's Third Leg", 222 ), item( "Onyxia's Droppings", 1337 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( hr( 1337 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "2 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Wirt's Third Leg]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_single_res_sr_items_alphabetically_after_hr_items()
  -- Given
  dropped( item( "Hearthstone", 123 ), item( "Wirt's Third Leg", 222 ), item( "Onyxia's Droppings", 1337 ), item( "Dick", 111 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 111 ), hr( 1337 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "4 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Dick] (SR by Obszczymucha)" ),
    r( "3. [Hearthstone] (SR by Psikutas)" ),
    r( "4. [Wirt's Third Leg]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_not_sort_items_items_with_the_same_amount_of_softressers_if_there_is_more_than_one_softresser()
  -- Given
  dropped( item( "Hearthstone", 123 ), item( "Wirt's Third Leg", 222 ), item( "Onyxia's Droppings", 1337 ), item( "Dick", 111 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Psikutas", 111 ), sr( "Obszczymucha", 111 ), hr( 1337 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "4 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Dick] (SR by Obszczymucha and Psikutas)" ),
    r( "3. [Hearthstone] (SR by Obszczymucha and Psikutas)" ),
    r( "4. [Wirt's Third Leg]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_sort_softres_player_counts_ascending()
  -- Given
  dropped( item( "Hearthstone", 123 ), item( "Wirt's Third Leg", 222 ), item( "Onyxia's Droppings", 1337 ), item( "Dick", 111 ) )
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Psikutas", 111 ), sr( "Obszczymucha", 111 ), sr( "Ponpon", 111 ), hr( 1337 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "4 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Hearthstone] (SR by Obszczymucha and Psikutas)" ),
    r( "3. [Dick] (SR by Obszczymucha, Ponpon and Psikutas)" ),
    r( "4. [Wirt's Third Leg]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_not_announce_greens_and_blues_if_there_are_more_that_5_items()
  -- Given
  dropped(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222 ),
    item( "Onyxia's Droppings", 1337 ),
    item( "Dick", 111 ),
    item( "Chuj", 333, 3 ),
    item( "Dupa", 444, 2 ),
    item( "Princess", 555, 2 )
  )
  master_looter( "Psikutas" )
  loot_threshold( LootQuality.Uncommon )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Psikutas", 111 ), sr( "Obszczymucha", 111 ), sr( "Ponpon", 111 ), hr( 1337 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "7 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Hearthstone] (SR by Obszczymucha and Psikutas)" ),
    r( "3. [Dick] (SR by Obszczymucha, Ponpon and Psikutas)" ),
    r( "4. [Wirt's Third Leg]" ),
    r( "5. [Chuj]" ),
    r( "and 2 more items..." )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_announce_greens_and_blues_if_there_are_less_or_equal_than_5_items()
  -- Given
  dropped(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222 ),
    item( "Onyxia's Droppings", 1337 ),
    item( "Dick", 111 ),
    item( "Chuj", 333, 3 )
  )
  master_looter( "Psikutas" )
  loot_threshold( LootQuality.Uncommon )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Psikutas", 111 ), sr( "Obszczymucha", 111 ), sr( "Ponpon", 111 ), hr( 1337 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "5 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Hearthstone] (SR by Obszczymucha and Psikutas)" ),
    r( "3. [Dick] (SR by Obszczymucha, Ponpon and Psikutas)" ),
    r( "4. [Wirt's Third Leg]" ),
    r( "5. [Chuj]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_announce_all_sr_items_even_if_theres_more_than_5()
  -- Given
  dropped(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222 ),
    item( "Onyxia's Droppings", 1337 ),
    item( "Dick", 111 ),
    item( "Chuj", 333, 3 ),
    item( "Dupa", 444, 3 )
  )
  master_looter( "Psikutas" )
  loot_threshold( LootQuality.Uncommon )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Jogobobek" )
  soft_res(
    sr( "Psikutas", 123 ),
    sr( "Obszczymucha", 123 ),
    sr( "Psikutas", 111 ),
    sr( "Obszczymucha", 111 ),
    sr( "Ponpon", 111 ),
    hr( 1337 ),
    sr( "Jogobobek", 222 ),
    sr( "Jogobobek", 333 ),
    sr( "Jogobobek", 444 )
  )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "6 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Wirt's Third Leg] (SR by Jogobobek)" ),
    r( "3. [Dupa] (SR by Jogobobek)" ),
    r( "4. [Chuj] (SR by Jogobobek)" ),
    r( "5. [Hearthstone] (SR by Obszczymucha and Psikutas)" ),
    r( "6. [Dick] (SR by Obszczymucha, Ponpon and Psikutas)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_sort_non_sr_items_by_quality_and_name()
  -- Given
  dropped(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222, 2 ),
    item( "Onyxia's Droppings", 1337, 2 ),
    item( "Dick", 111, 3 ),
    item( "Chuj", 333, 3 ),
    item( "Dupa", 444, 4 ),
    item( "Princess", 555, 4 )
  )
  master_looter( "Psikutas" )
  loot_threshold( LootQuality.Uncommon )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Jogobobek" )
  soft_res( sr( "Psikutas", 123 ) )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "7 items dropped:" ),
    r( "1. [Hearthstone] (SR by Psikutas)" ),
    r( "2. [Dupa]" ),
    r( "3. [Princess]" ),
    r( "4. [Chuj]" ),
    r( "5. [Dick]" ),
    r( "and 2 more items..." )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_announce_all_sr_items_even_if_theres_more_than_5_and_include_the_last_one()
  -- Given
  dropped(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222 ),
    item( "Onyxia's Droppings", 1337 ),
    item( "Dick", 111 ),
    item( "Chuj", 333, 2 ),
    item( "Dupa", 444, 3 ),
    item( "PrincessKenny", 555, 2 )
  )
  master_looter( "Psikutas" )
  loot_threshold( LootQuality.Uncommon )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Jogobobek" )
  soft_res(
    sr( "Psikutas", 123 ),
    sr( "Obszczymucha", 123 ),
    sr( "Psikutas", 111 ),
    sr( "Obszczymucha", 111 ),
    sr( "Ponpon", 111 ),
    hr( 1337 ),
    sr( "Jogobobek", 222 ),
    sr( "Jogobobek", 333 ),
    sr( "Jogobobek", 444 )
  )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "7 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Wirt's Third Leg] (SR by Jogobobek)" ),
    r( "3. [Dupa] (SR by Jogobobek)" ),
    r( "4. [Chuj] (SR by Jogobobek)" ),
    r( "5. [Hearthstone] (SR by Obszczymucha and Psikutas)" ),
    r( "6. [Dick] (SR by Obszczymucha, Ponpon and Psikutas)" ),
    r( "7. [PrincessKenny]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_announce_all_sr_items_even_if_theres_more_than_5_and_trim_the_rest()
  -- Given
  dropped(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222 ),
    item( "Onyxia's Droppings", 1337 ),
    item( "Dick", 111 ),
    item( "Chuj", 333, 2 ),
    item( "Dupa", 444, 3 ),
    item( "Princess", 444, 2 ),
    item( "Kenny", 555, 2 )
  )
  master_looter( "Psikutas" )
  loot_threshold( LootQuality.Uncommon )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Jogobobek" )
  soft_res(
    sr( "Psikutas", 123 ),
    sr( "Obszczymucha", 123 ),
    sr( "Psikutas", 111 ),
    sr( "Obszczymucha", 111 ),
    sr( "Ponpon", 111 ),
    hr( 1337 ),
    sr( "Jogobobek", 222 ),
    sr( "Jogobobek", 333 ),
    sr( "Jogobobek", 444 )
  )

  -- When
  loot()

  -- Then
  assert_messages(
    r( "8 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Wirt's Third Leg] (SR by Jogobobek)" ),
    r( "3. [Dupa] (SR by Jogobobek)" ),
    r( "4. [Chuj] (SR by Jogobobek)" ),
    r( "5. [Hearthstone] (SR by Obszczymucha and Psikutas)" ),
    r( "6. [Dick] (SR by Obszczymucha, Ponpon and Psikutas)" ),
    r( "and 2 more items..." )
  )
end

utils.mock_libraries()
utils.load_real_stuff( function( module_name )
  if module_name == "src/LootList" then require( "mocks/LootList" ) end
  if module_name == "src/api/LootEventFacade" then
    loot_event_facade = require( "mocks/LootEventFacade" )
    return loot_event_facade
  end

  return require( module_name )
end )
utils.mock_blizzard_loot_buttons()

os.exit( lu.LuaUnit.run() )
