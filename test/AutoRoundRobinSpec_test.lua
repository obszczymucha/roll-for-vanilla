package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local builder = require( "test/IntegrationTestBuilder" )
local new_roll_for = builder.new_roll_for
local mock_loot_facade, mock_chat, i, p = builder.mock_loot_facade, builder.mock_chat, builder.i, builder.p
local r, c = u.raid_message, u.console_message
local alid = RollFor.AwardedLoot.awarded_loot_item_data

-- The award pass end to end: a loot window opens, the round-robin selection runs against the
-- master loot candidates for the slot, and the winner is paid, announced and recorded. The
-- selection algorithm itself is covered on its own in AutoRoundRobin_test.
--
-- The builder pins the draw to the first of the tied candidates (sorted by name), so every
-- expected winner below is nameable rather than a coin flip.

---@param rf table
---@param loot_facade table
---@param ... table -- the items in the window
local function loot( rf, loot_facade, ... )
  u.mock_table_function( "UnitName", { player = "Psikutas", target = "Princess Kenny" } )
  u.mock_master_loot_candidates( { "Psikutas", "Obszczymucha" } )
  local master_loot = u.mock_async_master_loot( loot_facade )

  loot_facade.notify( "LootOpened", ... )
  master_loot.flush()
end

---@param rf table
---@param player_name string
local function served_cycle( rf, player_name )
  return rf.autorobin_db.pool[ player_name ]
end

AutoRoundRobinSpec = {}

function AutoRoundRobinSpec:should_award_announce_and_record_an_enabled_item()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :chat( chat )
      :config( { auto_round_robin = true } )
      :build()

  rf.round_robin_list.enable( gem )

  -- When
  loot( rf, loot_facade, gem )

  -- Then
  chat.assert(
    r( "Princess Kenny dropped 1 item:", "1. [Crimson Spinel]" ),
    r( "Obszczymucha receives [Crimson Spinel] (round robin)." ),
    c( "RollFor: Obszczymucha received [Crimson Spinel]." )
  )

  eq( rf.awarded_loot.has_item_been_awarded( "Obszczymucha", alid( 32227 ) ), true )
  rf.rolling_popup.should_be_hidden()
end

-- The very first award finds everybody already seeded at cycle 1, so it turns the cycle over
-- before serving anyone -- exactly the worked example in the spec.
function AutoRoundRobinSpec:should_turn_the_cycle_over_and_record_the_winner_under_the_new_one()
  -- Given
  local loot_facade = mock_loot_facade()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :config( { auto_round_robin = true } )
      :build()

  rf.round_robin_list.enable( gem )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( rf, loot_facade, gem )

  -- Then
  eq( rf.auto_round_robin.get_cycle(), 2 )
  eq( served_cycle( rf, "Obszczymucha" ), 2 )
  eq( served_cycle( rf, "Psikutas" ), 1 )
end

-- Two copies of one gem in one window are two awards to two different players, which only works
-- because the pass iterates by slot rather than by item id.
function AutoRoundRobinSpec:should_award_two_copies_of_the_same_item_to_two_different_players()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :chat( chat )
      :config( { auto_round_robin = true } )
      :build()

  rf.round_robin_list.enable( gem )

  -- When
  loot( rf, loot_facade, gem, gem )

  -- Then
  chat.assert(
    r( "Princess Kenny dropped 2 items:", "1. 2x[Crimson Spinel]" ),
    r( "Obszczymucha receives [Crimson Spinel] (round robin)." ),
    -- AwardedLoot's own confirmation that the award went into the loot history, which is the
    -- second half of "recorded like every other master-loot award".
    c( "RollFor: Obszczymucha received [Crimson Spinel]." ),
    r( "Psikutas receives [Crimson Spinel] (round robin)." ),
    c( "RollFor: Psikutas received [Crimson Spinel]." )
  )

  eq( served_cycle( rf, "Obszczymucha" ), 2 )
  eq( served_cycle( rf, "Psikutas" ), 2 )
end

-- Conflicts resolve in auto-loot's favour, and the rotation must not move for an item it never
-- handed out.
function AutoRoundRobinSpec:should_leave_an_item_auto_loot_claims_alone_and_not_move_the_cycle()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :chat( chat )
      :config( { auto_loot = true, auto_round_robin = true, auto_loot_messages = true } )
      :build()

  rf.auto_loot_list.enable( gem )
  rf.round_robin_list.enable( gem )

  -- When
  loot( rf, loot_facade, gem )

  -- Then
  chat.assert(
    r( "Princess Kenny dropped 1 item:", "1. [Crimson Spinel]" ),
    c( "RollFor: Auto-looting [Crimson Spinel]." )
  )

  eq( rf.auto_round_robin.get_cycle(), 1 )
  eq( rf.awarded_loot.has_item_been_awarded( "Obszczymucha", alid( 32227 ) ), false )
end

function AutoRoundRobinSpec:should_award_nothing_when_the_feature_is_off()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :chat( chat )
      :config( { auto_round_robin = false } )
      :build()

  rf.round_robin_list.enable( gem )

  -- When
  loot( rf, loot_facade, gem )

  -- Then
  chat.assert( r( "Princess Kenny dropped 1 item:", "1. [Crimson Spinel]" ) )

  eq( rf.auto_round_robin.get_cycle(), 1 )
  eq( rf.autorobin_db.pool, {} )
end

function AutoRoundRobinSpec:should_award_nothing_that_is_not_on_the_list()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )
  local other = i( "Hearthstone", 6948 )

  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :chat( chat )
      :config( { auto_round_robin = true } )
      :build()

  rf.round_robin_list.enable( gem )

  -- When
  loot( rf, loot_facade, other )

  -- Then
  chat.assert( r( "Princess Kenny dropped 1 item:", "1. [Hearthstone]" ) )

  eq( rf.auto_round_robin.get_cycle(), 1 )
end

-- Below the master loot threshold an item isn't master-lootable at all, so GiveMasterLoot would
-- quietly do nothing and the rotation would move for an award that never happened.
function AutoRoundRobinSpec:should_skip_items_below_the_master_loot_threshold()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local trinket = builder.qi( "Cheap Trinket", 32227, 1 )

  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :chat( chat )
      :config( { auto_round_robin = true } )
      :loot_threshold( 3 )
      :build()

  rf.round_robin_list.enable( trinket )

  -- When
  loot( rf, loot_facade, trinket )

  -- Then
  eq( rf.auto_round_robin.get_cycle(), 1 )
  eq( rf.autorobin_db.pool, {} )
end

AutoRoundRobinQueueSpec = {}

function AutoRoundRobinQueueSpec:should_list_who_is_owed_first()
  -- Given
  local loot_facade = mock_loot_facade()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :config( { auto_round_robin = true } )
      :build()

  rf.round_robin_list.enable( gem )
  loot( rf, loot_facade, gem )

  -- When
  local rows = rf.auto_round_robin.get_rows()

  -- Then -- Psikutas is a cycle behind, so he sorts first and is still waiting
  eq( rows[ 1 ].player_name, "Psikutas" )
  eq( rows[ 1 ].behind, 1 )
  eq( rows[ 2 ].player_name, "Obszczymucha" )
  eq( rows[ 2 ].behind, 0 )
end

function AutoRoundRobinQueueSpec:should_empty_the_pool_and_return_to_cycle_one_on_reset()
  -- Given
  local loot_facade = mock_loot_facade()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p( "Psikutas" ), p( "Obszczymucha" ) )
      :config( { auto_round_robin = true } )
      :build()

  rf.round_robin_list.enable( gem )
  loot( rf, loot_facade, gem )
  eq( rf.auto_round_robin.is_pristine(), false )

  -- When
  rf.auto_round_robin.reset()

  -- Then -- everybody present is back in at cycle 1, which is where a fresh rotation starts
  eq( rf.auto_round_robin.get_cycle(), 1 )
  eq( rf.autorobin_db.pool, { Psikutas = 1, Obszczymucha = 1 } )
  eq( rf.auto_round_robin.is_pristine(), true )
end

os.exit( lu.LuaUnit.run() )
