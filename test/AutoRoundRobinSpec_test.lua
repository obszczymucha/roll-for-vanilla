package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local builder = require( "test/IntegrationTestBuilder" )
local new_roll_for = builder.new_roll_for
local mock_loot_facade, mock_chat, i, p = builder.mock_loot_facade, builder.mock_chat, builder.i, builder.p
local r, c = u.raid_message, u.console_message
local alid = RollFor.AwardedLoot.awarded_loot_item_data

-- The award pass end to end: a loot window opens, the item's category names a queue, the first
-- player in that queue who can receive gets it and goes to the back. The queue operations
-- themselves are covered on their own in AutoRoundRobin_test.
--
-- The roster is sorted by class then name (see GroupRoster), so a queue seeded from
-- Obszczymucha (Druid) and Psikutas (Warrior) starts in that order.

---@param loot_facade table
---@param ... table -- the items in the window
local function loot( loot_facade, ... )
  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_master_loot_candidates( { "Psikutas", "Obszczymucha" } )
  local master_loot = u.mock_async_master_loot( loot_facade )

  loot_facade.notify( "LootOpened", ... )
  master_loot.flush()
end

---@param rf table
---@param category string?
---@return string[]
local function queue( rf, category )
  local result = {}

  for _, player in ipairs( rf.auto_round_robin.get_queue( category or "Gems" ) ) do
    table.insert( result, player.name )
  end

  return result
end

---@param config table?
local function raid( config )
  return new_roll_for()
      :raid_roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :config( config or { auto_round_robin = true } )
end

AutoRoundRobinSpec = {}

function AutoRoundRobinSpec:should_award_announce_and_record_the_head_of_the_queue()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = raid():loot_facade( loot_facade ):chat( chat ):build()
  rf.round_robin_list.enable( gem )
  rf.auto_round_robin.on_group_changed()

  eq( queue( rf ), { "Obszczymucha", "Psikutas" } )

  -- When
  loot( loot_facade, gem )

  -- Then
  chat.assert(
    r( "Princess Kenny dropped 1 item:", "1. [Crimson Spinel]" ),
    r( "Obszczymucha receives [Crimson Spinel] (Gems round robin)." ),
    c( "RollFor: Obszczymucha received [Crimson Spinel]." )
  )

  eq( rf.awarded_loot.has_item_been_awarded( "Obszczymucha", alid( 32227 ) ), true )
  eq( queue( rf ), { "Psikutas", "Obszczymucha" } )
  rf.rolling_popup.should_be_hidden()
end

-- The queue is seeded on the first loot window even if no roster update has landed yet, so the
-- feature works the moment it is switched on.
function AutoRoundRobinSpec:should_seed_the_queue_from_the_roster_without_a_roster_update()
  -- Given
  local loot_facade = mock_loot_facade()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = raid():loot_facade( loot_facade ):build()
  rf.round_robin_list.enable( gem )
  rf.auto_round_robin.on_group_changed()

  -- Then
  eq( queue( rf ), { "Obszczymucha", "Psikutas" } )
end

-- Two copies of one gem in one window are two awards to two different players, which only works
-- because the pass iterates by slot rather than by item id.
function AutoRoundRobinSpec:should_award_two_copies_to_the_first_two_in_the_queue()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = raid():loot_facade( loot_facade ):chat( chat ):build()
  rf.round_robin_list.enable( gem )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, gem, gem )

  -- Then
  chat.assert(
    r( "Princess Kenny dropped 2 items:", "1. 2x[Crimson Spinel]" ),
    r( "Obszczymucha receives [Crimson Spinel] (Gems round robin)." ),
    c( "RollFor: Obszczymucha received [Crimson Spinel]." ),
    r( "Psikutas receives [Crimson Spinel] (Gems round robin)." ),
    c( "RollFor: Psikutas received [Crimson Spinel]." )
  )

  eq( queue( rf ), { "Obszczymucha", "Psikutas" } )
end

-- Each category owns an independent queue: taking a gem does not move you down the Marks queue.
function AutoRoundRobinSpec:should_keep_each_categorys_queue_independent()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )
  local mark = i( "Mark of the Illidari", 32897 )

  local rf = raid():loot_facade( loot_facade ):chat( chat ):build()
  rf.round_robin_list.enable( gem, "Gems" )
  rf.round_robin_list.enable( mark, "Marks" )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, gem )

  -- Then -- the Gems queue moved and the Marks queue did not
  eq( queue( rf, "Gems" ), { "Psikutas", "Obszczymucha" } )
  eq( queue( rf, "Marks" ), { "Obszczymucha", "Psikutas" } )

  -- When
  loot( loot_facade, mark )

  -- Then -- so the Marks drop goes to the head of its own queue, not to whoever is next for gems
  eq( queue( rf, "Marks" ), { "Psikutas", "Obszczymucha" } )
end

-- Conflicts resolve in auto-loot's favour, and the queue must not move for an item it never
-- handed out.
function AutoRoundRobinSpec:should_leave_an_item_auto_loot_claims_alone_and_not_move_the_queue()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = raid( { auto_loot = true, auto_round_robin = true, auto_loot_messages = true } )
      :loot_facade( loot_facade ):chat( chat ):build()

  rf.auto_loot_list.enable( gem )
  rf.round_robin_list.enable( gem )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, gem )

  -- Then
  chat.assert(
    r( "Princess Kenny dropped 1 item:", "1. [Crimson Spinel]" ),
    c( "RollFor: Auto-looting [Crimson Spinel]." )
  )

  eq( queue( rf ), { "Obszczymucha", "Psikutas" } )
end

function AutoRoundRobinSpec:should_award_nothing_when_the_feature_is_off()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = raid( { auto_round_robin = false } ):loot_facade( loot_facade ):chat( chat ):build()
  rf.round_robin_list.enable( gem )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, gem )

  -- Then
  chat.assert( r( "Princess Kenny dropped 1 item:", "1. [Crimson Spinel]" ) )
  eq( queue( rf ), { "Obszczymucha", "Psikutas" } )
end

function AutoRoundRobinSpec:should_award_nothing_that_is_not_on_the_list()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )
  local other = i( "Hearthstone", 6948 )

  local rf = raid():loot_facade( loot_facade ):chat( chat ):build()
  rf.round_robin_list.enable( gem )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, other )

  -- Then
  chat.assert( r( "Princess Kenny dropped 1 item:", "1. [Hearthstone]" ) )
  eq( queue( rf ), { "Obszczymucha", "Psikutas" } )
end

-- Below the master loot threshold an item isn't master-lootable at all, so GiveMasterLoot would
-- quietly do nothing and the queue would move for an award that never happened. This is not
-- hypothetical for the shipping catalogue: Mark of the Illidari is Uncommon.
function AutoRoundRobinSpec:should_skip_items_below_the_master_loot_threshold()
  -- Given
  local loot_facade = mock_loot_facade()
  local mark = builder.qi( "Mark of the Illidari", 32897, 2 )

  local rf = raid():loot_facade( loot_facade ):loot_threshold( 3 ):build()
  rf.round_robin_list.enable( mark )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, mark )

  -- Then
  eq( queue( rf ), { "Obszczymucha", "Psikutas" } )
end

AutoRoundRobinEditingSpec = {}

function AutoRoundRobinEditingSpec:should_add_a_player_who_is_not_in_the_group()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()

  -- When
  local added = rf.auto_round_robin.add_player( "Gems", "Ohhaimark", "Warrior" )

  -- Then
  eq( added, true )
  eq( queue( rf ), { "Obszczymucha", "Psikutas", "Ohhaimark" } )
end

function AutoRoundRobinEditingSpec:should_refuse_a_duplicate()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()

  -- When
  local added, why = rf.auto_round_robin.add_player( "Gems", "psikutas" )

  -- Then
  eq( added, false )
  lu.assertStrContains( why, "already in the Gems queue" )
  eq( queue( rf ), { "Obszczymucha", "Psikutas" } )
end

function AutoRoundRobinEditingSpec:should_refuse_a_blank_name()
  local rf = raid():build()

  eq( rf.auto_round_robin.add_player( "Gems", "   " ), false )
end

function AutoRoundRobinEditingSpec:should_remove_a_player()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()

  -- When
  rf.auto_round_robin.remove_player( "Gems", 1 )

  -- Then
  eq( queue( rf ), { "Psikutas" } )
end

-- Somebody taken out on purpose comes straight back on the next roster update, because sync only
-- knows who is in the group and not why they left the queue. Removing is for people who are not
-- in your group; the x button on somebody standing next to you is temporary by nature.
function AutoRoundRobinEditingSpec:should_re_add_a_removed_group_member_on_the_next_roster_update()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.remove_player( "Gems", 1 )

  -- When
  rf.auto_round_robin.on_group_changed()

  -- Then -- at the back, which is where anybody the queue has not seen before goes
  eq( queue( rf ), { "Psikutas", "Obszczymucha" } )
end

function AutoRoundRobinEditingSpec:should_reset_every_queue_back_to_the_group()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )
  rf.auto_round_robin.cycle( "Gems", 1 )
  rf.auto_round_robin.add_player( "Marks", "Ohhaimark" )

  eq( rf.auto_round_robin.is_pristine(), false )

  -- When
  rf.auto_round_robin.reset()

  -- Then
  eq( queue( rf, "Gems" ), { "Obszczymucha", "Psikutas" } )
  eq( queue( rf, "Marks" ), { "Obszczymucha", "Psikutas" } )
  eq( rf.auto_round_robin.is_pristine(), true )
end

function AutoRoundRobinEditingSpec:should_offer_the_catalogues_categories_in_order()
  eq( raid():build().auto_round_robin.get_categories(), { "Gems", "Marks", "Hearts" } )
end

os.exit( lu.LuaUnit.run() )
