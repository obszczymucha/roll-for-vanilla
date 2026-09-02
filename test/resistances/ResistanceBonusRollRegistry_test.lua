---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
local Db = require( "src/Db" )
require( "src/AutoLootDb" )
local ResistanceBonusRollRegistry = require( "src/resistances/ResistanceBonusRollRegistry" )

u.mock_wow_api()

local SHAHRAZ = "Mother Shahraz"
local COUNCIL = "The Illidari Council"
local ILLIDAN = "Illidan Stormrage"

-- Frozen, so entries can be asserted whole rather than "some number near now".
local NOW = 1700000000

-- Stands in for BossKilled: the registry only ever subscribes to it.
local function mock_boss_killed()
  local listeners = {}

  return {
    subscribe = function( listener ) table.insert( listeners, listener ) end,
    kill = function( boss_name )
      for _, listener in ipairs( listeners ) do listener( boss_name ) end
    end
  }
end

-- Stands in for ResistanceBonusRollEligibility: the registry only reads get_rows.
---@param rows table[]?
local function mock_eligibility( rows )
  local m_rows = rows or {}

  return {
    get_rows = function() return m_rows end,
    set_rows = function( new_rows ) m_rows = new_rows end
  }
end

---@param name string
---@param eligible boolean
local function player( name, eligible )
  return { player_name = name, class = "Warrior", eligible = eligible, reason = "Manual" }
end

-- Real catalogue ids, one per granting boss plus one that isn't. count_for_item resolves
-- the item through AutoLootDb, so made-up ids would only ever prove that unknown items
-- grant nothing.
local SHAHRAZ_ITEM = 32370   -- Nadina's Pendant of Purity
local COUNCIL_ITEM = 32331   -- Cloak of the Illidari Council
local ILLIDAN_ITEM = 32235   -- Cursed Vision of Sargeras
local SUPREMUS_ITEM = 32250  -- Pauldrons of Abyssal Fury -- Black Temple, but not a granting boss
local UNKNOWN_ITEM = 999999

---@param boss_name string
---@param timestamp number?
---@param class PlayerClass? -- every grant in this file is Warrior unless stated otherwise
local function entry( boss_name, timestamp, class )
  return { boss_name = boss_name, class = class or "Warrior", timestamp = timestamp or NOW }
end

---@param boss_name string
---@param item_id number
---@param roll number
---@param timestamp number?
local function used_entry( boss_name, item_id, roll, timestamp )
  local result = entry( boss_name, timestamp )
  result.used_on = { item_id = item_id, item_link = string.format( "[%s]", item_id ), roll = roll, timestamp = timestamp or NOW }

  return result
end

---@param sut table
---@param player_name string
---@param item_id number
---@param roll number
local function spend( sut, player_name, item_id, roll )
  return sut.use( player_name, item_id, string.format( "[%s]", item_id ), roll )
end

---@param rows table[]?
local function registry( rows )
  -- The real thing, not a plain table: the saved db is a proxy that forwards reads and
  -- writes but has no keys of its own, and code that forgets that passes happily
  -- against a plain table.
  local saved = {}
  local boss_killed = mock_boss_killed()
  local eligibility = mock_eligibility( rows )

  RollFor.lua.time = function() return NOW end

  local sut = ResistanceBonusRollRegistry.new( Db.new( saved )( "registry" ), boss_killed, eligibility )

  sut.boss_killed = boss_killed
  sut.eligibility = eligibility
  sut.stored = function() return saved.registry.players end

  -- What the addon printed, with the "RollFor: " prefix and the colors stripped --
  -- neither is what these tests are about.
  sut.printed = {}

  RollFor.api.DEFAULT_CHAT_FRAME = {
    AddMessage = function( _, message )
      local plain = u.decolorize( message ) or message
      table.insert( sut.printed, (string.gsub( plain, "^RollFor: ", "" )) )
    end
  }

  return sut
end

BonusRollRegistrySpec = {}

function BonusRollRegistrySpec:should_start_empty()
  -- Given
  local sut = registry()

  -- Then
  eq( sut.count( "Psikutas" ), 0 )
  eq( sut.get( "Psikutas" ), {} )
  eq( sut.get_rows(), {} )
end

function BonusRollRegistrySpec:should_grant_a_roll_to_every_eligible_player_on_a_granting_kill()
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.count( "Psikutas" ), 1 )
  eq( sut.count( "Obszczymucha" ), 1 )
end

function BonusRollRegistrySpec:should_not_grant_a_roll_to_an_ineligible_player()
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", false ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.count( "Psikutas" ), 1 )
  eq( sut.count( "Obszczymucha" ), 0 )
end

function BonusRollRegistrySpec:should_grant_for_each_of_the_three_bosses()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )

  -- When
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( COUNCIL )
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.count( "Psikutas" ), 3 )
end

function BonusRollRegistrySpec:should_not_grant_for_any_other_boss()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )

  -- When
  sut.boss_killed.kill( "Teron Gorefiend" )
  sut.boss_killed.kill( "Lady Vashj" )
  sut.boss_killed.kill( "Gurtogg Bloodboil" )

  -- Then
  eq( sut.count( "Psikutas" ), 0 )
  eq( sut.printed, {} )
end

function BonusRollRegistrySpec:should_store_each_roll_as_its_own_entry()
  -- A count answers "how many" and nothing else. The entries also say which boss paid
  -- for each one and when.
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )

  -- When
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.get( "Psikutas" ), { entry( SHAHRAZ ), entry( ILLIDAN ) } )
  eq( sut.stored(), { [ "Psikutas" ] = { entry( SHAHRAZ ), entry( ILLIDAN ) } } )
end

function BonusRollRegistrySpec:should_stamp_every_roll_from_one_kill_with_the_same_time()
  -- They were earned by the same event, and reading them back should say so.
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.get( "Psikutas" )[ 1 ].timestamp, NOW )
  eq( sut.get( "Obszczymucha" )[ 1 ].timestamp, sut.get( "Psikutas" )[ 1 ].timestamp )
end

function BonusRollRegistrySpec:should_announce_a_kills_payout_in_one_line()
  -- A kill pays out to the whole raid at once, so it gets one line and not one per
  -- player. Who they were is what the /rfbr list is for.
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.printed, { "Bonus Roll granted to 2 players." } )
end

function BonusRollRegistrySpec:should_say_player_singular_when_a_kill_pays_out_to_one()
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", false ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.printed, { "Bonus Roll granted to 1 player." } )
end

function BonusRollRegistrySpec:should_grant_by_hand()
  -- Given
  local sut = registry()

  -- When
  sut.grant( "Psikutas", ILLIDAN, "Warrior", NOW )

  -- Then
  eq( sut.get( "Psikutas" ), { entry( ILLIDAN ) } )
  eq( sut.printed, { "Bonus Roll granted to Psikutas (1 total)." } )
end

function BonusRollRegistrySpec:should_stamp_a_hand_granted_roll_with_the_current_time()
  -- Given
  local sut = registry()

  -- When
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )

  -- Then
  eq( sut.get( "Psikutas" ), { entry( ILLIDAN, NOW ) } )
end

function BonusRollRegistrySpec:should_grant_again_when_eligibility_changes_between_kills()
  -- Eligibility is read at the moment of the kill, not cached.
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", false ) } )
  sut.boss_killed.kill( SHAHRAZ )

  -- When
  sut.eligibility.set_rows( { player( "Psikutas", false ), player( "Obszczymucha", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.get( "Psikutas" ), { entry( SHAHRAZ ) } )
  eq( sut.get( "Obszczymucha" ), { entry( ILLIDAN ) } )
end

function BonusRollRegistrySpec:should_grant_nothing_when_nobody_is_eligible()
  -- Said out loud rather than passed over in silence: a granting boss dying with nobody
  -- eligible almost always means the scan was never run, and silence is how you find
  -- that out after the loot is gone.
  -- Given
  local sut = registry( { player( "Psikutas", false ), player( "Obszczymucha", false ) } )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.get_rows(), {} )
  eq( sut.printed, { "No one is eligible for a Bonus Roll. Run Infer in /rfbonus." } )
end

function BonusRollRegistrySpec:should_list_players_most_rolls_first_then_by_name()
  -- Alphabetically these are Bomanz, Obszczymucha, Psikutas -- a different name at
  -- every position below, so nothing here can pass on a name sort alone.
  -- Given
  local sut = registry()
  sut.grant( "Bomanz", ILLIDAN, "Warrior" )
  sut.grant( "Psikutas", SHAHRAZ, "Warrior" )
  sut.grant( "Psikutas", COUNCIL, "Warrior" )
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )
  sut.grant( "Obszczymucha", SHAHRAZ, "Warrior" )
  sut.grant( "Obszczymucha", ILLIDAN, "Warrior" )

  -- Then
  eq( u.map( sut.get_rows(), function( row ) return { row.player_name, row.count } end ), {
    { "Psikutas", 3 },
    { "Obszczymucha", 2 },
    { "Bomanz", 1 }
  } )
end

function BonusRollRegistrySpec:should_print_the_list()
  -- Given
  local sut = registry()
  sut.grant( "Psikutas", SHAHRAZ, "Warrior" )
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )
  sut.grant( "Obszczymucha", ILLIDAN, "Warrior" )
  sut.printed = {}
  RollFor.api.DEFAULT_CHAT_FRAME.AddMessage = function( _, message )
    table.insert( sut.printed, (string.gsub( u.decolorize( message ) or message, "^RollFor: ", "" )) )
  end

  -- When
  sut.list()

  -- Then
  eq( sut.printed, {
    "Bonus rolls:",
    "  Psikutas: 2",
    "  Obszczymucha: 1"
  } )
end

function BonusRollRegistrySpec:should_say_so_when_there_is_nothing_to_list()
  -- Given
  local sut = registry()

  -- When
  sut.list()

  -- Then
  eq( sut.printed, { "No bonus rolls granted yet." } )
end

function BonusRollRegistrySpec:should_empty_everything_on_reset()
  -- The saved db is a proxy, so clearing it key by key silently does nothing.
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- When
  sut.reset()

  -- Then
  eq( sut.stored(), {} )
  eq( sut.count( "Psikutas" ), 0 )
  eq( sut.get_rows(), {} )
end

function BonusRollRegistrySpec:should_keep_rolls_for_a_player_who_left_the_group()
  -- A roll is earned, so leaving doesn't spend it and shouldn't hide it either.
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- When
  sut.eligibility.set_rows( { player( "Psikutas", true ) } )

  -- Then
  eq( sut.count( "Obszczymucha" ), 1 )
  eq( u.map( sut.get_rows(), function( row ) return row.player_name end ), { "Obszczymucha", "Psikutas" } )
end

function BonusRollRegistrySpec:should_remember_rolls_across_a_reload()
  -- A second module over the same saved table is what a /reload looks like.
  -- Given
  local saved = {}
  local db = Db.new( saved )
  local first = ResistanceBonusRollRegistry.new( db( "registry" ), mock_boss_killed(), mock_eligibility() )
  first.grant( "Psikutas", ILLIDAN, "Warrior", NOW )

  -- When
  local second = ResistanceBonusRollRegistry.new( db( "registry" ), mock_boss_killed(), mock_eligibility() )

  -- Then
  eq( second.get( "Psikutas" ), { entry( ILLIDAN ) } )
  eq( second.count( "Psikutas" ), 1 )
end

function BonusRollRegistrySpec:should_notify_on_a_hand_granted_roll()
  -- Given
  local sut = registry()
  local notifications = 0
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )

  -- Then
  eq( notifications, 1 )
end

function BonusRollRegistrySpec:should_notify_once_for_a_kill_that_pays_out_to_several_players()
  -- A kill grants to everyone eligible at once. A listening frame redrawing once per
  -- player it pays out to would be the same mistake infer() avoids on the eligibility
  -- side.
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )
  local notifications = 0
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( notifications, 1 )
end

function BonusRollRegistrySpec:should_not_notify_a_kill_that_pays_out_to_nobody()
  -- Given
  local sut = registry( { player( "Psikutas", false ) } )
  local notifications = 0
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( notifications, 0 )
end

function BonusRollRegistrySpec:should_notify_on_reset()
  -- Given
  local sut = registry()
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )
  local notifications = 0
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.reset()

  -- Then
  eq( notifications, 1 )
end

function BonusRollRegistrySpec:should_notify_every_subscriber()
  -- Given
  local sut = registry()
  local first, second = 0, 0
  sut.subscribe( function() first = first + 1 end )
  sut.subscribe( function() second = second + 1 end )

  -- When
  sut.grant( "Psikutas", ILLIDAN, "Warrior" )

  -- Then
  eq( first, 1 )
  eq( second, 1 )
end

CountForItemSpec = {}

-- The worked example that drove the rule: kill Mother, then the Council, before
-- distributing anything. A Mother item is worth one bonus roll, because only the Mother
-- grant existed when Mother died.
function CountForItemSpec:should_offer_one_roll_on_a_mother_item_when_mother_and_council_both_granted()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( COUNCIL )

  -- Then
  eq( sut.count_for_item( "Psikutas", SHAHRAZ_ITEM ), 1 )
end

-- ...and the other half of it: a Council item is worth two, because at the Council kill
-- the player was still holding the unused Mother roll.
function CountForItemSpec:should_offer_two_rolls_on_a_council_item_when_mother_and_council_both_granted()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( COUNCIL )

  -- Then
  eq( sut.count_for_item( "Psikutas", COUNCIL_ITEM ), 2 )
end

function CountForItemSpec:should_offer_every_roll_on_an_illidan_item()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( COUNCIL )
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.count_for_item( "Psikutas", ILLIDAN_ITEM ), 3 )
end

function CountForItemSpec:should_offer_nothing_on_an_earlier_bosss_item_when_only_a_later_boss_granted()
  -- The Mother-item-after-a-Council-grant case: the roll didn't exist when Mother died.
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( COUNCIL )

  -- Then
  eq( sut.count_for_item( "Psikutas", SHAHRAZ_ITEM ), 0 )
  eq( sut.count_for_item( "Psikutas", COUNCIL_ITEM ), 1 )
end

function CountForItemSpec:should_offer_nothing_on_an_item_from_a_boss_that_grants_nothing()
  -- This is what confines bonus rolls to Mother/Council/Illidan loot.
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.count_for_item( "Psikutas", SUPREMUS_ITEM ), 0 )
end

function CountForItemSpec:should_offer_nothing_on_an_item_the_catalogue_does_not_know()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- Then
  eq( sut.count_for_item( "Psikutas", UNKNOWN_ITEM ), 0 )
  eq( sut.count_for_item( "Psikutas", nil ), 0 )
end

function CountForItemSpec:should_offer_nothing_to_a_player_with_no_rolls()
  -- Given
  local sut = registry()

  -- Then
  eq( sut.count_for_item( "Psikutas", ILLIDAN_ITEM ), 0 )
end

function CountForItemSpec:should_not_offer_a_roll_that_was_already_spent()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( COUNCIL )

  -- When
  spend( sut, "Psikutas", COUNCIL_ITEM, 87 )

  -- Then
  eq( sut.count_for_item( "Psikutas", COUNCIL_ITEM ), 1 )
end

-- The memo is one slot keyed by item id, so alternating between two items has to keep
-- answering for the item it was asked about and not for the last one it saw.
function CountForItemSpec:should_keep_answering_correctly_when_asked_about_two_items_in_turn()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( COUNCIL )

  -- Then
  eq( sut.count_for_item( "Psikutas", SHAHRAZ_ITEM ), 1 )
  eq( sut.count_for_item( "Psikutas", COUNCIL_ITEM ), 2 )
  eq( sut.count_for_item( "Psikutas", SHAHRAZ_ITEM ), 1 )
  eq( sut.count_for_item( "Psikutas", SUPREMUS_ITEM ), 0 )
  eq( sut.count_for_item( "Psikutas", COUNCIL_ITEM ), 2 )
end

UseSpec = {}

function UseSpec:should_stamp_the_entry_with_what_it_was_spent_on()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- When
  spend( sut, "Psikutas", ILLIDAN_ITEM, 87 )

  -- Then
  eq( sut.get( "Psikutas" ), { used_entry( ILLIDAN, ILLIDAN_ITEM, 87 ) } )
end

function UseSpec:should_return_a_token_pointing_at_the_entry_it_spent()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( COUNCIL )

  -- When
  local token = spend( sut, "Psikutas", COUNCIL_ITEM, 87 )

  -- Then
  eq( token, { player_name = "Psikutas", index = 1 } )
end

-- The whole reason use() picks the earliest: spend the Council roll on a Mother item and
-- the Mother roll survives to pay for a second Mother item it never earned.
function UseSpec:should_spend_the_earliest_usable_entry_not_the_newest()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( COUNCIL )

  -- When
  spend( sut, "Psikutas", COUNCIL_ITEM, 87 )

  -- Then
  eq( sut.get( "Psikutas" ), { used_entry( SHAHRAZ, COUNCIL_ITEM, 87 ), entry( COUNCIL ) } )
end

function UseSpec:should_not_offer_a_second_bonus_roll_on_a_second_mother_item()
  -- Given (Mother + Council rolls; one already spent on a Mother item)
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( COUNCIL )
  spend( sut, "Psikutas", SHAHRAZ_ITEM, 87 )

  -- Then (the surviving Council roll is worth nothing on Mother loot)
  eq( sut.count_for_item( "Psikutas", SHAHRAZ_ITEM ), 0 )
  eq( sut.count_for_item( "Psikutas", COUNCIL_ITEM ), 1 )
end

function UseSpec:should_change_nothing_when_the_player_has_nothing_usable()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( COUNCIL )

  -- When
  local token = spend( sut, "Psikutas", SHAHRAZ_ITEM, 87 )

  -- Then
  eq( token, nil )
  eq( sut.get( "Psikutas" ), { entry( COUNCIL ) } )
end

function UseSpec:should_change_nothing_for_an_item_from_a_boss_that_grants_nothing()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- When
  local token = spend( sut, "Psikutas", SUPREMUS_ITEM, 87 )

  -- Then
  eq( token, nil )
  eq( sut.get( "Psikutas" ), { entry( ILLIDAN ) } )
end

function UseSpec:should_persist_the_spend()
  -- The saved db is a proxy: mutating the entries list without writing it back does
  -- nothing at all.
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- When
  spend( sut, "Psikutas", ILLIDAN_ITEM, 87 )

  -- Then
  eq( sut.stored(), { [ "Psikutas" ] = { used_entry( ILLIDAN, ILLIDAN_ITEM, 87 ) } } )
end

function UseSpec:should_notify_so_an_open_frame_redraws()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( ILLIDAN )
  local notifications = 0
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  spend( sut, "Psikutas", ILLIDAN_ITEM, 87 )

  -- Then
  eq( notifications, 1 )
end

RefundSpec = {}

function RefundSpec:should_clear_the_spend_and_restore_the_count()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( ILLIDAN )
  local token = spend( sut, "Psikutas", ILLIDAN_ITEM, 87 )

  -- When
  sut.refund( { token } )

  -- Then
  eq( sut.get( "Psikutas" ), { entry( ILLIDAN ) } )
  eq( sut.count( "Psikutas" ), 1 )
  eq( sut.count_for_item( "Psikutas", ILLIDAN_ITEM ), 1 )
end

function RefundSpec:should_refund_several_tokens_at_once()
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )
  sut.boss_killed.kill( ILLIDAN )
  local first = spend( sut, "Psikutas", ILLIDAN_ITEM, 87 )
  local second = spend( sut, "Obszczymucha", ILLIDAN_ITEM, 42 )

  -- When
  sut.refund( { first, second } )

  -- Then
  eq( sut.count( "Psikutas" ), 1 )
  eq( sut.count( "Obszczymucha" ), 1 )
end

function RefundSpec:should_notify_once_for_the_whole_batch()
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )
  sut.boss_killed.kill( ILLIDAN )
  local first = spend( sut, "Psikutas", ILLIDAN_ITEM, 87 )
  local second = spend( sut, "Obszczymucha", ILLIDAN_ITEM, 42 )
  local notifications = 0
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.refund( { first, second } )

  -- Then
  eq( notifications, 1 )
end

function RefundSpec:should_do_nothing_when_there_is_nothing_to_refund()
  -- Given
  local sut = registry()
  local notifications = 0
  sut.subscribe( function() notifications = notifications + 1 end )

  -- When
  sut.refund( {} )

  -- Then
  eq( notifications, 0 )
end

UnusedCountsSpec = {}

function UnusedCountsSpec:should_count_only_unused_rolls()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( ILLIDAN )

  -- When
  spend( sut, "Psikutas", ILLIDAN_ITEM, 87 )

  -- Then
  eq( sut.count( "Psikutas" ), 1 )
end

function UnusedCountsSpec:should_count_all_only_unused_rolls()
  -- A spent roll is not a loss, so the "this many will be lost" reset summary must not
  -- count it.
  -- Given
  local sut = registry( { player( "Psikutas", true ), player( "Obszczymucha", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- When
  spend( sut, "Psikutas", ILLIDAN_ITEM, 87 )

  -- Then
  eq( sut.count_all(), 1 )
end

function UnusedCountsSpec:should_report_unused_and_used_separately_in_the_rows()
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( SHAHRAZ )
  sut.boss_killed.kill( ILLIDAN )

  -- When
  spend( sut, "Psikutas", ILLIDAN_ITEM, 87 )

  -- Then
  local row = sut.get_rows()[ 1 ]
  eq( row.count, 1 )
  eq( row.used_count, 1 )
end

function UnusedCountsSpec:should_keep_a_fully_spent_player_in_the_rows_with_a_zero_count()
  -- The entries are the audit trail; the row is how it's read.
  -- Given
  local sut = registry( { player( "Psikutas", true ) } )
  sut.boss_killed.kill( ILLIDAN )

  -- When
  spend( sut, "Psikutas", ILLIDAN_ITEM, 87 )

  -- Then
  local row = sut.get_rows()[ 1 ]
  eq( row.player_name, "Psikutas" )
  eq( row.count, 0 )
  eq( row.used_count, 1 )
end

GrantingBossesSpec = {}

function GrantingBossesSpec:should_name_bosses_that_actually_exist_in_the_catalogue()
  -- These strings only ever arrive from BossKilled, which gets them from AutoLootDb.
  -- A typo here doesn't fail loudly -- it just silently stops granting -- so the names
  -- are checked against the catalogue rather than trusted.
  local found = {}

  for _, dungeon in pairs( RollFor.AutoLootDb.ids ) do
    for boss_name in pairs( dungeon.bosses or {} ) do
      if ResistanceBonusRollRegistry.granting_bosses[ boss_name ] then found[ boss_name ] = true end
    end
  end

  eq( found, {
    [ "Mother Shahraz" ] = true,
    [ "The Illidari Council" ] = true,
    [ "Illidan Stormrage" ] = true
  } )
end

os.exit( lu.LuaUnit.run() )
