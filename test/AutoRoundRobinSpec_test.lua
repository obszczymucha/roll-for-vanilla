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

-- The queue with the core players marked, for the specs where who survives is the point.
---@param rf table
---@param category string?
---@return string[]
local function marked( rf, category )
  local result = {}

  for _, player in ipairs( rf.auto_round_robin.get_queue( category or "Gems" ) ) do
    table.insert( result, player.core and player.name .. " (core)" or player.name )
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
    r( "Obszczymucha receives [Crimson Spinel] (gems round robin)." ),
    c( "RollFor: Obszczymucha received [Crimson Spinel]." )
  )

  eq( rf.awarded_loot.has_item_been_awarded( "Obszczymucha", alid( 32227 ) ), true )
  eq( queue( rf ), { "Psikutas", "Obszczymucha" } )
  rf.rolling_popup.should_be_hidden()
end

-- The announcement is the only thing the toggle silences: the item is still handed out, still
-- recorded, and the queue still moves.
function AutoRoundRobinSpec:should_award_without_announcing_when_announcements_are_off()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = raid( { auto_round_robin = true, auto_round_robin_announce = false } )
      :loot_facade( loot_facade ):chat( chat ):build()

  rf.round_robin_list.enable( gem )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, gem )

  -- Then
  chat.assert( c( "RollFor: Obszczymucha received [Crimson Spinel]." ) )

  eq( rf.awarded_loot.has_item_been_awarded( "Obszczymucha", alid( 32227 ) ), true )
  eq( queue( rf ), { "Psikutas", "Obszczymucha" } )
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

-- Only the item the rotation takes drops out of the announcement. The rest of the window is
-- still what dropped, and the count is the count of what is actually up for grabs.
function AutoRoundRobinSpec:should_announce_only_the_items_the_rotation_does_not_take()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )
  local other = i( "Hearthstone", 6948 )

  local rf = raid():loot_facade( loot_facade ):chat( chat ):build()
  rf.round_robin_list.enable( gem )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, gem, other )

  -- Then
  chat.assert(
    r( "Princess Kenny dropped 1 item:", "1. [Hearthstone]" ),
    r( "Obszczymucha receives [Crimson Spinel] (gems round robin)." ),
    c( "RollFor: Obszczymucha received [Crimson Spinel]." )
  )
end

-- Switching the drop announcement back on puts the item in the list as well as handing it out.
function AutoRoundRobinSpec:should_announce_the_drop_when_drop_announcements_are_on()
  -- Given
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = raid( { auto_round_robin = true, auto_round_robin_announce_drops = true } )
      :loot_facade( loot_facade ):chat( chat ):build()

  rf.round_robin_list.enable( gem )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, gem )

  -- Then
  chat.assert(
    r( "Princess Kenny dropped 1 item:", "1. [Crimson Spinel]" ),
    r( "Obszczymucha receives [Crimson Spinel] (gems round robin)." ),
    c( "RollFor: Obszczymucha received [Crimson Spinel]." )
  )
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

-- The ignore list: the items Trash is told to leave alone. It is the only thing that can stop the
-- fallback claiming an uncatalogued item of a ticked quality, and it stops nothing else -- see
-- should_offer_the_catalogues_categories_in_order for the other half of it, that it owns no queue.
--
-- Surefooted is Uncommon, which the builder's default threshold admits, so what these specs turn
-- on is the ignore list alone.
function AutoRoundRobinTrashSpec:should_not_claim_an_item_on_the_ignore_list()
  -- Given
  local loot_facade = mock_loot_facade()
  local formula = builder.qi( "Formula: Enchant Boots - Surefooted", 22545, 2 )

  local rf = raid():loot_facade( loot_facade ):build()
  rf.round_robin_list.enable_trash( 2 )
  rf.round_robin_list.ignore_trash( formula.id )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, formula )

  -- Then
  eq( queue( rf, "Trash" ), { "Obszczymucha", "Psikutas" } )
end

-- Every row is its own opt-in, the same as Trash's qualities: an entry sitting in the catalogue
-- unticked is not on the ignore list.
function AutoRoundRobinTrashSpec:should_claim_an_ignore_list_item_whose_row_is_not_ticked()
  -- Given
  local loot_facade = mock_loot_facade()
  local formula = builder.qi( "Formula: Enchant Boots - Surefooted", 22545, 2 )

  local rf = raid():loot_facade( loot_facade ):build()
  rf.round_robin_list.enable_trash( 2 )
  rf.round_robin_list.set_category_enabled( true, RollFor.AutoRoundRobinDb.TRASH_IGNORED )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, formula )

  -- Then
  eq( queue( rf, "Trash" ), { "Psikutas", "Obszczymucha" } )
end

-- Unticking the category switches the whole list off without losing which rows were ticked.
function AutoRoundRobinTrashSpec:should_claim_an_ignore_list_item_when_the_whole_list_is_off()
  -- Given
  local loot_facade = mock_loot_facade()
  local formula = builder.qi( "Formula: Enchant Boots - Surefooted", 22545, 2 )

  local rf = raid():loot_facade( loot_facade ):build()
  rf.round_robin_list.enable_trash( 2 )
  rf.round_robin_list.ignore_trash( formula.id )
  rf.round_robin_list.set_category_enabled( false, RollFor.AutoRoundRobinDb.TRASH_IGNORED )
  rf.auto_round_robin.on_group_changed()

  -- When
  loot( loot_facade, formula )

  -- Then
  eq( queue( rf, "Trash" ), { "Psikutas", "Obszczymucha" } )
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

-- A reset is the group being reapplied: it throws away the order and the transients, and the
-- core players survive it. Which is why it cannot empty a queue -- that is the x button's job.
function AutoRoundRobinEditingSpec:should_reset_every_queue_to_the_core_players_and_the_group()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )
  rf.auto_round_robin.cycle( "Gems", 1 )
  rf.auto_round_robin.add_player( "Marks", "Ohhaimark" )

  eq( rf.auto_round_robin.is_pristine(), false )

  -- When
  rf.auto_round_robin.reset()

  -- Then -- Ohhaimark was added by hand, so they keep their place at the front of the rebuild
  eq( queue( rf, "Gems" ), { "Ohhaimark", "Obszczymucha", "Psikutas" } )
  eq( queue( rf, "Marks" ), { "Ohhaimark", "Obszczymucha", "Psikutas" } )
  eq( rf.auto_round_robin.is_pristine(), true )
end

-- Nothing to throw away, so the window does not stop to ask. A queue that is exactly what a
-- reset would rebuild is pristine however it got that way, core players and all.
function AutoRoundRobinEditingSpec:should_be_pristine_with_core_players_in_the_order_a_reset_would_leave()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()

  eq( rf.auto_round_robin.is_pristine(), true )

  -- When -- promoting somebody moves nobody
  rf.auto_round_robin.set_core( "Gems", 1, true )

  -- Then
  eq( rf.auto_round_robin.is_pristine(), true )
end

AutoRoundRobinCoreSpec = {}

function AutoRoundRobinCoreSpec:should_add_a_player_by_hand_as_core()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()

  -- When
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )

  -- Then -- the roster brought the other two in, so only the typed name is core
  eq( marked( rf ), { "Obszczymucha", "Psikutas", "Ohhaimark (core)" } )
end

function AutoRoundRobinCoreSpec:should_carry_core_on_the_rows_the_window_draws()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.set_core( "Gems", 2, true )

  -- When
  local rows = rf.auto_round_robin.get_rows( "Gems" )

  -- Then
  eq( rows[ 1 ].core, false )
  eq( rows[ 2 ].core, true )
end

function AutoRoundRobinCoreSpec:should_promote_a_player_the_roster_brought_in()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()

  -- When
  rf.auto_round_robin.set_core( "Gems", 2, true )

  -- Then
  eq( marked( rf ), { "Obszczymucha", "Psikutas (core)" } )
end

function AutoRoundRobinCoreSpec:should_demote_a_player_who_was_added_by_hand()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )

  -- When
  rf.auto_round_robin.set_core( "Gems", 1, false )

  -- Then
  eq( marked( rf ), { "Ohhaimark" } )
end

-- Demoting is not removing: they keep their place and their turn, and are simply not carried
-- into the next group.
function AutoRoundRobinCoreSpec:should_leave_a_demoted_player_where_they_are()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )
  rf.auto_round_robin.move_player( "Gems", 3, -1 )

  -- When
  rf.auto_round_robin.set_core( "Gems", 2, false )

  -- Then
  eq( queue( rf ), { "Obszczymucha", "Ohhaimark", "Psikutas" } )
end

function AutoRoundRobinCoreSpec:should_do_nothing_for_a_position_that_is_not_there()
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()

  rf.auto_round_robin.set_core( "Gems", 9, true )

  eq( marked( rf ), { "Obszczymucha", "Psikutas" } )
end

AutoRoundRobinAbsenceSpec = {}

---@param rows AutoRoundRobinRow[]
---@return string[]
local function row_names( rows )
  local result = {}

  for _, row in ipairs( rows ) do table.insert( result, row.name ) end

  return result
end

-- Hidden, not dropped. They keep their place and take the next drop they are around for, which
-- is the whole reason the queue and who can receive are kept apart.
function AutoRoundRobinAbsenceSpec:should_leave_out_somebody_who_is_not_in_the_group()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )

  -- Then
  eq( row_names( rf.auto_round_robin.get_rows( "Gems" ) ), { "Obszczymucha", "Psikutas" } )
  eq( queue( rf ), { "Obszczymucha", "Psikutas", "Ohhaimark" } )
end

-- Winning sends you to the back of the group, not to the back of the queue. Ohhaimark is not in
-- the raid, so he neither climbs a place when somebody in front of him is served nor gets jumped
-- by the winner on their way past: he holds the rank he had and takes his turn when he shows up.
function AutoRoundRobinAbsenceSpec:should_leave_an_absent_players_rank_alone_when_somebody_is_served()
  -- Given -- Obszczymucha, Ohhaimark (not in the raid), Psikutas
  local loot_facade = mock_loot_facade()
  local gem = i( "Crimson Spinel", 32227 )

  local rf = raid():loot_facade( loot_facade ):build()
  rf.round_robin_list.enable( gem )
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )
  rf.auto_round_robin.move_player( "Gems", 3, -1 )

  eq( queue( rf ), { "Obszczymucha", "Ohhaimark", "Psikutas" } )

  -- When
  loot( loot_facade, gem )

  -- Then -- Ohhaimark is still second; Obszczymucha went behind Psikutas, not behind everybody
  eq( queue( rf ), { "Psikutas", "Ohhaimark", "Obszczymucha" } )
end

-- A row acts on the queue, so it carries the index the queue knows it by rather than the one it
-- was drawn at.
function AutoRoundRobinAbsenceSpec:should_carry_the_queue_position_past_the_players_it_left_out()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )
  rf.auto_round_robin.move_player( "Gems", 3, -1 )

  -- When -- Obszczymucha, Ohhaimark (hidden), Psikutas
  local rows = rf.auto_round_robin.get_rows( "Gems" )

  -- Then
  eq( rows[ 1 ].position, 1 )
  eq( rows[ 2 ].position, 3 )
end

-- The limit is how many rows to draw, so it counts what is drawn.
function AutoRoundRobinAbsenceSpec:should_count_the_limit_against_the_rows_it_returns()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )
  rf.auto_round_robin.move_player( "Gems", 3, -1 )

  -- Then
  eq( row_names( rf.auto_round_robin.get_rows( "Gems", 1 ) ), { "Obszczymucha" } )
  eq( row_names( rf.auto_round_robin.get_rows( "Gems", 2 ) ), { "Obszczymucha", "Psikutas" } )
end

AutoRoundRobinNewGroupSpec = {}

-- The transients were the last group and have no claim on this one. The core players keep their
-- place and their order at the front.
function AutoRoundRobinNewGroupSpec:should_drop_the_transients_and_keep_the_core()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )
  rf.auto_round_robin.set_core( "Gems", 2, true )

  -- When
  rf.auto_round_robin.on_new_group()

  -- Then -- Obszczymucha was transient, so they lost their place and came back off the roster
  eq( marked( rf ), { "Psikutas (core)", "Ohhaimark (core)", "Obszczymucha" } )
end

-- A demoted player who is not in the group has nothing left holding them there.
function AutoRoundRobinNewGroupSpec:should_drop_a_demoted_player_who_is_not_in_the_group()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )
  rf.auto_round_robin.set_core( "Gems", 3, false )

  -- When
  rf.auto_round_robin.on_new_group()

  -- Then
  eq( queue( rf ), { "Obszczymucha", "Psikutas" } )
end

function AutoRoundRobinNewGroupSpec:should_do_it_to_every_category()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.add_player( "Marks", "Ohhaimark" )

  -- When
  rf.auto_round_robin.on_new_group()

  -- Then
  eq( marked( rf, "Marks" ), { "Ohhaimark (core)", "Obszczymucha", "Psikutas" } )
  eq( marked( rf, "Hearts" ), { "Obszczymucha", "Psikutas" } )
end

-- EventHandler runs the roster sync first on the very event a new group arrives on, so this has
-- to survive the group being appended a moment before the transients are dropped. Dropping
-- without re-syncing would throw away the group it had just been handed.
function AutoRoundRobinNewGroupSpec:should_keep_the_group_that_the_roster_sync_appended_first()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.add_player( "Gems", "Ohhaimark" )

  -- When -- the order EventHandler fires them in
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.on_new_group()

  -- Then
  eq( marked( rf ), { "Ohhaimark (core)", "Obszczymucha", "Psikutas" } )
end

-- A core player stepping out and coming back must not be demoted by the roster update that
-- readmits them, or leaving the raid for a minute would quietly cost them the flag.
function AutoRoundRobinNewGroupSpec:should_not_demote_a_core_player_the_roster_sync_sees_again()
  -- Given
  local rf = raid():build()
  rf.auto_round_robin.on_group_changed()
  rf.auto_round_robin.set_core( "Gems", 1, true )

  -- When
  rf.auto_round_robin.on_group_changed()

  -- Then
  eq( marked( rf ), { "Obszczymucha (core)", "Psikutas" } )
end

-- Trash comes last and is a category like any other from here on: it owns a queue, gets synced
-- from the roster and can be edited. What makes it the fallback is only where it sorts and the
-- fact that it names qualities instead of item ids (see AutoRoundRobinDb).
function AutoRoundRobinEditingSpec:should_offer_the_catalogues_categories_in_order()
  eq( raid():build().auto_round_robin.get_categories(), { "Marks", "Hearts", "Gems", "Trash" } )
end

-- The ignore list hands nothing out, so it has no rotation to keep. Leaving it out of the
-- categories above is the whole of how that happens: queues are written lazily, keyed by the
-- names in that list, so a name that never appears in it never gets one -- not from the roster
-- sync below, and not from anything else.
function AutoRoundRobinEditingSpec:should_not_create_a_queue_for_the_ignore_list()
  -- Given
  local rf = raid():build()

  -- When
  rf.auto_round_robin.on_group_changed()

  -- Then
  eq( rf.autorobin_db.queues[ RollFor.AutoRoundRobinDb.TRASH_IGNORED ], nil )
end

os.exit( lu.LuaUnit.run() )
