---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
require( "src/DebugBuffer" )
require( "src/Module" )
local Db = require( "src/Db" )
require( "src/ItemCatalogue" ) -- the catalogue helpers AutoLootDb delegates its seeding and queries to
require( "src/AutoLootDb" )
local BossKilled = require( "src/BossKilled" )

-- Real item ids from the real catalogue, not a fixture: the whole job of this
-- module is turning an id into a boss name, and a made-up id would only prove
-- the test agrees with itself.
local ROBE_OF_HATEFUL_ECHOES = 30056 -- Hydross the Unstable, Serpentshrine Cavern
local FATHOMSTONE = 30049           -- Hydross the Unstable, same boss
local VESTMENTS_OF_THE_SEA_WITCH = 30107 -- Lady Vashj, Serpentshrine Cavern
local CORD_OF_SCREAMING_TERRORS = 30064 -- The Lurker Below
-- Listed under Trash in four different raids, so it names no boss at all.
local ADAMANTITE_CHERRY_BOMB = 32897
local NOT_IN_THE_CATALOGUE = 6948 -- Hearthstone
-- Shared by all three Opera bosses, so it names none of them.
local BEASTMAW_PAULDRONS = 28589
local RIBBON_OF_SACRIFICE = 28590
-- Romulo and Julianne's own drops, which nobody else has.
local MASQUERADE_GOWN = 28578
local ROMULOS_POISON_VIAL = 28579
local WICKED_WITCHS_HAT = 28586 -- The Wizard of Oz

local function boss_killed()
  -- The real thing, not a plain table: the saved db is a proxy that forwards
  -- reads and writes but has no keys of its own, and code that forgets that
  -- passes happily against a plain table.
  local saved = {}
  local sut = BossKilled.new( Db.new( saved )( "boss_killed" ) )

  sut.stored = function() return saved.boss_killed.bosses end

  -- Everything the listeners were told, in order.
  sut.killed = {}
  sut.subscribe( function( boss_name ) table.insert( sut.killed, boss_name ) end )

  return sut
end

BossKilledSpec = {}

function BossKilledSpec:should_report_nobody_as_killed_before_anything_drops()
  -- Given
  local sut = boss_killed()

  -- Then
  eq( sut.is_killed( "Hydross the Unstable" ), false )
  eq( sut.get_killed_bosses(), {} )
end

function BossKilledSpec:should_register_the_boss_an_item_belongs_to()
  -- Given
  local sut = boss_killed()

  -- When
  sut.on_item_dropped( ROBE_OF_HATEFUL_ECHOES )

  -- Then
  eq( sut.is_killed( "Hydross the Unstable" ), true )
  eq( sut.get_killed_bosses(), { "Hydross the Unstable" } )
end

function BossKilledSpec:should_notify_subscribers_with_the_boss_name()
  -- Given
  local sut = boss_killed()

  -- When
  sut.on_item_dropped( ROBE_OF_HATEFUL_ECHOES )

  -- Then
  eq( sut.killed, { "Hydross the Unstable" } )
end

function BossKilledSpec:should_notify_every_subscriber()
  -- Given
  local sut = boss_killed()
  local second = {}
  sut.subscribe( function( boss_name ) table.insert( second, boss_name ) end )

  -- When
  sut.on_item_dropped( VESTMENTS_OF_THE_SEA_WITCH )

  -- Then
  eq( sut.killed, { "Lady Vashj" } )
  eq( second, { "Lady Vashj" } )
end

function BossKilledSpec:should_ignore_another_item_from_a_boss_already_killed()
  -- A boss drops several items at once and the loot window can be reopened, so
  -- the same kill arrives many times over. Only the first one is an event.
  -- Given
  local sut = boss_killed()
  sut.on_item_dropped( ROBE_OF_HATEFUL_ECHOES )

  -- When
  sut.on_item_dropped( FATHOMSTONE )
  sut.on_item_dropped( ROBE_OF_HATEFUL_ECHOES )

  -- Then
  eq( sut.killed, { "Hydross the Unstable" } )
  eq( sut.get_killed_bosses(), { "Hydross the Unstable" } )
end

function BossKilledSpec:should_register_each_boss_separately()
  -- Given
  local sut = boss_killed()

  -- When
  sut.on_item_dropped( VESTMENTS_OF_THE_SEA_WITCH )
  sut.on_item_dropped( ROBE_OF_HATEFUL_ECHOES )
  sut.on_item_dropped( CORD_OF_SCREAMING_TERRORS )

  -- Then
  eq( sut.killed, { "Lady Vashj", "Hydross the Unstable", "The Lurker Below" } )
  -- The list itself is sorted, so a caller displaying it gets the same order
  -- every time regardless of what dropped first.
  eq( sut.get_killed_bosses(), { "Hydross the Unstable", "Lady Vashj", "The Lurker Below" } )
end

function BossKilledSpec:should_ignore_a_trash_drop()
  -- Trash is not a boss, and the same trash items are listed under four
  -- different raids, so the name wouldn't even say which one it came from.
  -- Given
  local sut = boss_killed()

  -- When
  sut.on_item_dropped( ADAMANTITE_CHERRY_BOMB )

  -- Then
  eq( sut.killed, {} )
  eq( sut.get_killed_bosses(), {} )
end

function BossKilledSpec:should_ignore_an_item_that_isnt_in_the_catalogue()
  -- Given
  local sut = boss_killed()

  -- When
  sut.on_item_dropped( NOT_IN_THE_CATALOGUE )

  -- Then
  eq( sut.killed, {} )
  eq( sut.get_killed_bosses(), {} )
end

function BossKilledSpec:should_ignore_a_missing_item_id()
  -- Given
  local sut = boss_killed()

  -- When
  sut.on_item_dropped( nil )

  -- Then
  eq( sut.killed, {} )
end

function BossKilledSpec:should_ignore_an_item_the_opera_bosses_share()
  -- Karazhan's Opera picks one of three bosses per lockout and all three drop
  -- these, so nothing in the id says which one died. The catalogue would hand
  -- back one of the candidates, which is exactly the guess not worth making.
  -- Given
  local sut = boss_killed()

  -- When
  sut.on_item_dropped( BEASTMAW_PAULDRONS )
  sut.on_item_dropped( RIBBON_OF_SACRIFICE )

  -- Then
  eq( sut.killed, {} )
  eq( sut.get_killed_bosses(), {} )
end

function BossKilledSpec:should_still_name_the_opera_boss_from_an_item_only_it_drops()
  -- Each Opera boss has four of its own, which is what the shared six are
  -- ignored in favour of.
  -- Given
  local sut = boss_killed()

  -- When
  sut.on_item_dropped( MASQUERADE_GOWN )

  -- Then
  eq( sut.killed, { "Romulo and Julianne" } )
end

function BossKilledSpec:should_name_the_opera_boss_even_when_shared_items_drop_alongside()
  -- The realistic case: the loot holds both kinds and only the unique one is
  -- allowed to speak.
  -- Given
  local sut = boss_killed()

  -- When
  sut.on_item_dropped( BEASTMAW_PAULDRONS )
  sut.on_item_dropped( WICKED_WITCHS_HAT )
  sut.on_item_dropped( RIBBON_OF_SACRIFICE )

  -- Then
  eq( sut.killed, { "The Wizard of Oz" } )
end

function BossKilledSpec:should_ignore_a_shared_item_even_after_its_boss_was_identified()
  -- Given
  local sut = boss_killed()
  sut.on_item_dropped( ROMULOS_POISON_VIAL )

  -- When
  sut.on_item_dropped( BEASTMAW_PAULDRONS )

  -- Then
  eq( sut.killed, { "Romulo and Julianne" } )
  eq( sut.get_killed_bosses(), { "Romulo and Julianne" } )
end

function BossKilledSpec:should_ignore_every_item_on_the_ignore_list()
  -- Whatever the list holds, none of it may name a boss -- including via the
  -- catalogue, which resolves all six of these perfectly happily.
  -- Given
  local sut = boss_killed()

  -- When
  for item_id in pairs( BossKilled.ignored_items ) do
    sut.on_item_dropped( item_id )
  end

  -- Then
  eq( sut.killed, {} )
  eq( sut.get_killed_bosses(), {} )
end

function BossKilledSpec:should_persist_the_kill_to_the_db()
  -- The saved db is a proxy, so writing through it key by key silently does
  -- nothing unless the set lives one level down.
  -- Given
  local sut = boss_killed()

  -- When
  sut.on_item_dropped( ROBE_OF_HATEFUL_ECHOES )

  -- Then
  eq( sut.stored(), { [ "Hydross the Unstable" ] = true } )
end

function BossKilledSpec:should_remember_kills_across_a_reload()
  -- A second module over the same saved table is what a /reload looks like.
  -- Given
  local saved = {}
  local db = Db.new( saved )
  local first = BossKilled.new( db( "boss_killed" ) )
  first.on_item_dropped( ROBE_OF_HATEFUL_ECHOES )

  -- When
  local second = BossKilled.new( db( "boss_killed" ) )

  -- Then
  eq( second.is_killed( "Hydross the Unstable" ), true )
  eq( second.get_killed_bosses(), { "Hydross the Unstable" } )
end

function BossKilledSpec:should_empty_everything_on_reset()
  -- Given
  local sut = boss_killed()
  sut.on_item_dropped( ROBE_OF_HATEFUL_ECHOES )
  sut.on_item_dropped( VESTMENTS_OF_THE_SEA_WITCH )

  -- When
  sut.reset()

  -- Then
  eq( sut.stored(), {} )
  eq( sut.is_killed( "Hydross the Unstable" ), false )
  eq( sut.get_killed_bosses(), {} )
end

function BossKilledSpec:should_not_announce_a_reset()
  -- Subscribers hear about kills. A reset is a correction to the record, not a
  -- boss dying.
  -- Given
  local sut = boss_killed()
  sut.on_item_dropped( ROBE_OF_HATEFUL_ECHOES )

  -- When
  sut.reset()

  -- Then
  eq( sut.killed, { "Hydross the Unstable" } )
end

function BossKilledSpec:should_register_a_boss_again_after_a_reset()
  -- Given
  local sut = boss_killed()
  sut.on_item_dropped( ROBE_OF_HATEFUL_ECHOES )
  sut.reset()

  -- When
  sut.on_item_dropped( FATHOMSTONE )

  -- Then
  eq( sut.killed, { "Hydross the Unstable", "Hydross the Unstable" } )
  eq( sut.is_killed( "Hydross the Unstable" ), true )
end

AutoLootDbFindBossSpec = {}

function AutoLootDbFindBossSpec:should_find_the_boss_that_drops_an_item()
  eq( RollFor.AutoLootDb.find_boss( ROBE_OF_HATEFUL_ECHOES ), "Hydross the Unstable" )
  eq( RollFor.AutoLootDb.find_boss( VESTMENTS_OF_THE_SEA_WITCH ), "Lady Vashj" )
  eq( RollFor.AutoLootDb.find_boss( CORD_OF_SCREAMING_TERRORS ), "The Lurker Below" )
end

function AutoLootDbFindBossSpec:should_find_nothing_for_trash_and_for_unknown_items()
  eq( RollFor.AutoLootDb.find_boss( ADAMANTITE_CHERRY_BOMB ), nil )
  eq( RollFor.AutoLootDb.find_boss( NOT_IN_THE_CATALOGUE ), nil )
  eq( RollFor.AutoLootDb.find_boss( nil ), nil )
end

function AutoLootDbFindBossSpec:should_answer_the_same_way_every_time_for_an_item_several_bosses_share()
  -- The catalogue still resolves the shared Opera items -- BossKilled screens
  -- them out rather than find_boss refusing to answer -- and pairs() order is
  -- not stable, so an unsorted walk could name a different boss on each call.
  local first = RollFor.AutoLootDb.find_boss( BEASTMAW_PAULDRONS )

  eq( first ~= nil, true )

  for _ = 1, 20 do
    eq( RollFor.AutoLootDb.find_boss( BEASTMAW_PAULDRONS ), first )
  end
end

function AutoLootDbFindBossSpec:should_find_the_boss_that_uniquely_drops_an_opera_item()
  eq( RollFor.AutoLootDb.find_boss( MASQUERADE_GOWN ), "Romulo and Julianne" )
  eq( RollFor.AutoLootDb.find_boss( WICKED_WITCHS_HAT ), "The Wizard of Oz" )
end

os.exit( lu.LuaUnit.run() )
