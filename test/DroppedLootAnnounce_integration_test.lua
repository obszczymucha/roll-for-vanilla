package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local _, item_utils = require( "src/modules" ), require( "src/ItemUtils" )

local player = utils.player
local leader = utils.raid_leader
local is_in_raid = utils.is_in_raid
local loot_threshold = utils.loot_threshold
local mock_blizzard_loot_buttons = utils.mock_blizzard_loot_buttons
local LootQuality = utils.LootQuality
local BindType = item_utils.BindType
local r = utils.raid_message
local master_looter = utils.master_looter
local item = utils.item
local targetting_enemy = utils.targetting_enemy
local soft_res = utils.soft_res
local hr = utils.hard_res_item
local sr = utils.soft_res_item
local mock = utils.mock

---@type ModuleRegistry
local module_registry = {
  { module_name = "LootFacade", mock = "mocks/LootFacade", variable_name = "loot_facade" },
  { module_name = "ChatApi",    mock = "mocks/ChatApi",    variable_name = "chat" },
  { module_name = "LootList",   mock = "mocks/LootList" }
}

-- The modules will be injected here using the above module_registry.
local m = {}

local function loot( ... )
  m.loot_facade.notify( "LootOpened", ... )
end

DroppedLootAnnounceIntegrationSpec = {}

function DroppedLootAnnounceIntegrationSpec:should_not_show_loot_that_dropped_if_not_a_master_looter()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  loot_threshold( LootQuality.Epic )

  -- When
  loot()

  -- Then
  m.chat.assert_no_messages()
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
  m.chat.assert_no_messages()
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
  m.chat.assert(
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
  m.chat.assert(
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
  m.chat.assert(
    r( "Netherspite dropped 2 items:" ),
    r( "1. [Hearthstone]" ),
    r( "2. [Some item]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_announce_bop_items_even_below_threshold()
  -- Given
  master_looter( "Psikutas" )
  targetting_enemy( "Netherspite" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  utils.mock( "UnitGUID", "PrincessKenny_123" )
  loot_threshold( LootQuality.Epic )
  mock_blizzard_loot_buttons()

  -- When
  loot(
    item( "Hearthstone", 123, LootQuality.Epic, BindType.BindOnPickup ),
    item( "Breadstick of Annihilation", 222, LootQuality.Rare, BindType.BindOnPickup ),
    item( "Breadstick of Slight Annoyance", 333, LootQuality.Common, BindType.BindOnPickup )
  )

  -- Then
  m.chat.assert(
    r( "Netherspite dropped 2 items:" ),
    r( "1. [Hearthstone]" ),
    r( "2. [Breadstick of Annihilation]" )
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
  m.chat.assert(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (HR)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_prio_hard_ressed_item_over_soft_ressed()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), hr( 123 ) )

  -- When
  loot( item( "Hearthstone", 123 ) )

  -- Then
  m.chat.assert(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone] (HR)" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_show_hard_and_soft_ressed_items()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), hr( 123 ) )

  -- When
  loot( item( "Hearthstone", 123 ), item( "Hearthstone", 123 ) )

  -- Then
  m.chat.assert(
    r( "2 items dropped:" ),
    r( "1. [Hearthstone] (HR)" ),
    r( "2. [Hearthstone] (SR by Psikutas)" )
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
  m.chat.assert(
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
  m.chat.assert(
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
  m.chat.assert(
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
  m.chat.assert(
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
  m.chat.assert(
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
  m.chat.assert(
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
  m.chat.assert(
    r( "4 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Dick] (SR by Obszczymucha)" ),
    r( "3. [Hearthstone] (SR by Psikutas)" ),
    r( "4. [Wirt's Third Leg]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_not_sort_items_items_with_the_same_amount_of_softressers_if_there_is_more_than_one_softresser()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Psikutas", 111 ), sr( "Obszczymucha", 111 ), hr( 1337 ) )

  -- When
  loot( item( "Hearthstone", 123 ), item( "Wirt's Third Leg", 222 ), item( "Onyxia's Droppings", 1337 ), item( "Dick", 111 ) )

  -- Then
  m.chat.assert(
    r( "4 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Dick] (SR by Obszczymucha and Psikutas)" ),
    r( "3. [Hearthstone] (SR by Obszczymucha and Psikutas)" ),
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
  m.chat.assert(
    r( "4 items dropped:" ),
    r( "1. [Onyxia's Droppings] (HR)" ),
    r( "2. [Hearthstone] (SR by Obszczymucha and Psikutas)" ),
    r( "3. [Dick] (SR by Obszczymucha, Ponpon and Psikutas)" ),
    r( "4. [Wirt's Third Leg]" )
  )
end

function DroppedLootAnnounceIntegrationSpec:should_not_announce_greens_and_blues_if_there_are_more_that_5_items()
  -- Given
  master_looter( "Psikutas" )
  loot_threshold( LootQuality.Uncommon )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Psikutas", 111 ), sr( "Obszczymucha", 111 ), sr( "Ponpon", 111 ), hr( 1337 ) )

  -- When
  loot(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222 ),
    item( "Onyxia's Droppings", 1337 ),
    item( "Dick", 111 ),
    item( "Chuj", 333, 3 ),
    item( "Dupa", 444, 2 ),
    item( "Princess", 555, 2 )
  )

  -- Then
  m.chat.assert(
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
  master_looter( "Psikutas" )
  loot_threshold( LootQuality.Uncommon )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Psikutas", 111 ), sr( "Obszczymucha", 111 ), sr( "Ponpon", 111 ), hr( 1337 ) )

  -- When
  loot(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222 ),
    item( "Onyxia's Droppings", 1337 ),
    item( "Dick", 111 ),
    item( "Chuj", 333, 3 )
  )

  -- Then
  m.chat.assert(
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
  loot(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222 ),
    item( "Onyxia's Droppings", 1337 ),
    item( "Dick", 111 ),
    item( "Chuj", 333, 3 ),
    item( "Dupa", 444, 3 )
  )

  -- Then
  m.chat.assert(
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
  master_looter( "Psikutas" )
  loot_threshold( LootQuality.Uncommon )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Jogobobek" )
  soft_res( sr( "Psikutas", 123 ) )

  -- When
  loot(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222, 2 ),
    item( "Onyxia's Droppings", 1337, 2 ),
    item( "Dick", 111, 3 ),
    item( "Chuj", 333, 3 ),
    item( "Dupa", 444, 4 ),
    item( "Princess", 555, 4 )
  )

  -- Then
  m.chat.assert(
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
  loot(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222 ),
    item( "Onyxia's Droppings", 1337 ),
    item( "Dick", 111 ),
    item( "Chuj", 333, 2 ),
    item( "Dupa", 444, 3 ),
    item( "PrincessKenny", 555, 2 )
  )

  -- Then
  m.chat.assert(
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
  loot(
    item( "Hearthstone", 123 ),
    item( "Wirt's Third Leg", 222 ),
    item( "Onyxia's Droppings", 1337 ),
    item( "Dick", 111 ),
    item( "Chuj", 333, 2 ),
    item( "Dupa", 444, 3 ),
    item( "Princess", 555, 2 ),
    item( "Kenny", 666, 2 )
  )

  -- Then
  m.chat.assert(
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
utils.load_real_stuff_and_inject( module_registry, m )
utils.mock_blizzard_loot_buttons()

os.exit( lu.LuaUnit.run() )
