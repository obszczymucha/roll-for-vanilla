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
    r( "Obszczymucha receives [Crimson Spinel] (gems round robin)." ),
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
    r( "Obszczymucha receives [Crimson Spinel] (gems round robin)." ),
    c( "RollFor: Obszczymucha received [Crimson Spinel]." ),
    r( "Psikutas receives [Crimson Spinel] (gems round robin)." ),
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

-- The Trash fallback: no item ids, just a quality. Everything below is about which items reach it
-- and which don't -- the awarding itself is the same pass, already covered above.
--
-- The threshold half of the rule is not retested per quality here because it isn't Trash's own
-- code: is_awardable rejects anything under the loot threshold before the category is even asked
-- (see should_skip_an_uncommon_trash_item_when_the_threshold_is_rare for the one that proves the
-- two compose). The builder's default threshold is Uncommon, so both rows are live by default.
AutoRoundRobinTrashSpec = {}

function AutoRoundRobinTrashSpec:should_award_an_uncatalogued_uncommon_item_from_the_trash_queue()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local junk = builder.qi( "Felcloth", 14256, 2 )

  local rf = raid():loot_facade( loot_facade ):chat( chat ):build()
  rf.round_robin_list.enable_trash( 2 )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, junk )

  -- Then
  chat.assert(
    r( "Princess Kenny dropped 1 item:", "1. [Felcloth]" ),
    r( "Obszczymucha receives [Felcloth] (trash round robin)." ),
    c( "RollFor: Obszczymucha received [Felcloth]." )
  )

  eq( queue( rf, "Trash" ), { "Psikutas", "Obszczymucha" } )
end

function AutoRoundRobinTrashSpec:should_award_an_uncatalogued_rare_item_from_the_trash_queue()
  -- Given
  local loot_facade = mock_loot_facade()
  local junk = builder.qi( "Blue Thing", 14257, 3 )

  local rf = raid():loot_facade( loot_facade ):build()
  rf.round_robin_list.enable_trash( 3 )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, junk )

  -- Then
  eq( queue( rf, "Trash" ), { "Psikutas", "Obszczymucha" } )
end

-- Ticking Uncommon says nothing about Rare. Each row is its own opt-in.
function AutoRoundRobinTrashSpec:should_ignore_a_quality_whose_row_is_not_ticked()
  -- Given
  local loot_facade = mock_loot_facade()
  local junk = builder.qi( "Blue Thing", 14257, 3 )

  local rf = raid():loot_facade( loot_facade ):build()
  rf.round_robin_list.enable_trash( 2 )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, junk )

  -- Then
  eq( queue( rf, "Trash" ), { "Obszczymucha", "Psikutas" } )
end

-- An epic is never nobody's business, so the fallback never claims one however it got there.
-- Explicit categories are unaffected -- the shipping Gems are all Epic and are awarded above.
function AutoRoundRobinTrashSpec:should_never_claim_an_epic()
  -- Given
  local loot_facade = mock_loot_facade()
  local epic = builder.qi( "Purple Thing", 14258, 4 )

  local rf = raid():loot_facade( loot_facade ):build()
  rf.round_robin_list.enable_trash( 2 )
  rf.round_robin_list.enable_trash( 3 )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, epic )

  -- Then
  eq( queue( rf, "Trash" ), { "Obszczymucha", "Psikutas" } )
end

-- Unticking Hearts means "don't round robin Heart of Darkness", not "round robin it out of a
-- different queue". A catalogued item that no enabled category claimed stops rather than falling
-- through, even though its quality would otherwise make it trash.
function AutoRoundRobinTrashSpec:should_not_claim_a_catalogued_item_whose_category_is_off()
  -- Given
  local loot_facade = mock_loot_facade()
  local heart = builder.qi( "Heart of Darkness", 32428, 3 )

  local rf = raid():loot_facade( loot_facade ):build()
  rf.round_robin_list.enable_trash( 3 )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, heart )

  -- Then
  eq( queue( rf, "Trash" ), { "Obszczymucha", "Psikutas" } )
end

-- A catalogued item that IS claimed goes to its own queue, not to Trash, even with both ticked.
function AutoRoundRobinTrashSpec:should_prefer_a_real_category_over_the_fallback()
  -- Given
  local loot_facade = mock_loot_facade()
  local heart = builder.qi( "Heart of Darkness", 32428, 3 )

  local rf = raid():loot_facade( loot_facade ):build()
  rf.round_robin_list.enable( heart, "Hearts" )
  rf.round_robin_list.enable_trash( 3 )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, heart )

  -- Then
  eq( queue( rf, "Hearts" ), { "Psikutas", "Obszczymucha" } )
  eq( queue( rf, "Trash" ), { "Obszczymucha", "Psikutas" } )
end

-- The two guards compose: the threshold rejects the item before the category is asked, so the
-- Uncommon row is inert while the threshold sits above Uncommon however it is ticked. This is
-- what the window greys the row to explain.
function AutoRoundRobinTrashSpec:should_skip_an_uncommon_trash_item_when_the_threshold_is_rare()
  -- Given
  local loot_facade = mock_loot_facade()
  local junk = builder.qi( "Felcloth", 14256, 2 )

  local rf = raid():loot_facade( loot_facade ):loot_threshold( 3 ):build()
  rf.round_robin_list.enable_trash( 2 )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, junk )

  -- Then
  eq( queue( rf, "Trash" ), { "Obszczymucha", "Psikutas" } )
end

-- Trash is a queue like any other, so taking a green does not move you down the Gems rotation.
function AutoRoundRobinTrashSpec:should_keep_the_trash_queue_independent_of_the_others()
  -- Given
  local loot_facade = mock_loot_facade()
  local gem = i( "Crimson Spinel", 32227 )
  local junk = builder.qi( "Felcloth", 14256, 2 )

  local rf = raid():loot_facade( loot_facade ):build()
  rf.round_robin_list.enable( gem )
  rf.round_robin_list.enable_trash( 2 )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, junk )

  -- Then
  eq( queue( rf, "Trash" ), { "Psikutas", "Obszczymucha" } )
  eq( queue( rf, "Gems" ), { "Obszczymucha", "Psikutas" } )
end

-- is_category_active is what a display addon asks instead of re-deriving the rule from the saved
-- variables (see RollForApi). It answers the award pass's own question with no item in hand: the
-- feature, the selection and the loot threshold, together.
AutoRoundRobinGetRowsSpec = {}

function AutoRoundRobinGetRowsSpec:should_return_the_whole_queue_without_a_limit()
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()

  eq( #rf.auto_round_robin.get_rows( "Gems" ), 2 )
end

function AutoRoundRobinGetRowsSpec:should_return_at_most_the_limit_from_the_front()
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()

  local rows = rf.auto_round_robin.get_rows( "Gems", 1 )

  eq( #rows, 1 )
  eq( rows[ 1 ].name, "Obszczymucha" )
end

-- A limit longer than the queue is not padding.
function AutoRoundRobinGetRowsSpec:should_ignore_a_limit_past_the_end()
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()

  eq( #rf.auto_round_robin.get_rows( "Gems", 10 ), 2 )
end

AutoRoundRobinIsCategoryActiveSpec = {}

---@param rf table
---@param category string?
local function active( rf, category )
  return rf.auto_round_robin.is_category_active( category or "Gems" )
end

function AutoRoundRobinIsCategoryActiveSpec:should_be_active_when_the_category_has_a_ticked_item()
  local rf = raid():build()
  rf.round_robin_list.enable( i( "Crimson Spinel", 32227 ) )

  eq( active( rf ), true )
end

function AutoRoundRobinIsCategoryActiveSpec:should_be_inactive_when_the_feature_is_off()
  local rf = raid( { auto_round_robin = false } ):build()
  rf.round_robin_list.enable( i( "Crimson Spinel", 32227 ) )

  eq( active( rf ), false )
end

function AutoRoundRobinIsCategoryActiveSpec:should_be_inactive_for_a_category_that_does_not_exist()
  eq( active( raid():build(), "Tabards" ), false )
end

function AutoRoundRobinIsCategoryActiveSpec:should_be_inactive_when_the_category_itself_is_unticked()
  local rf = raid():build()
  rf.round_robin_list.enable( i( "Crimson Spinel", 32227 ) )
  rf.round_robin_list.set_category_enabled( false, "Gems" )

  eq( active( rf ), false )
end

function AutoRoundRobinIsCategoryActiveSpec:should_be_inactive_when_nothing_under_it_is_ticked()
  local rf = raid():build()
  rf.round_robin_list.set_category_enabled( true, "Gems" )

  eq( active( rf ), false )
end

-- Everything ticked sits below the threshold, so GiveMasterLoot would refuse all of it and the
-- queue can never move.
function AutoRoundRobinIsCategoryActiveSpec:should_be_inactive_when_the_threshold_is_above_everything_ticked()
  local rf = raid():loot_threshold( 4 ):build()
  rf.round_robin_list.enable( builder.qi( "Mark of the Illidari", 32897, 2 ), "Marks" )

  eq( active( rf, "Marks" ), false )
end

function AutoRoundRobinIsCategoryActiveSpec:should_be_active_for_trash_when_a_ticked_quality_clears_the_threshold()
  local rf = raid():build()
  rf.round_robin_list.enable_trash( 2 )

  eq( active( rf, "Trash" ), true )
end

function AutoRoundRobinIsCategoryActiveSpec:should_be_inactive_for_trash_when_the_threshold_outranks_its_ticked_quality()
  local rf = raid():loot_threshold( 3 ):build()
  rf.round_robin_list.enable_trash( 2 )

  eq( active( rf, "Trash" ), false )
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

-- Trash comes last and is a category like any other from here on: it owns a queue, gets synced
-- from the roster and can be edited. What makes it the fallback is only where it sorts and the
-- fact that it names qualities instead of item ids (see AutoRoundRobinDb).
function AutoRoundRobinEditingSpec:should_offer_the_catalogues_categories_in_order()
  eq( raid():build().auto_round_robin.get_categories(), { "Gems", "Marks", "Hearts", "Trash" } )
end

os.exit( lu.LuaUnit.run() )
