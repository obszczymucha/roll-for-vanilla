---@diagnostic disable: missing-fields
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

-- Who gets an item automatically, and core doing the handing out.
--
-- The thing under test is the ledger. GiveMasterLoot is asynchronous, so a slot a policy has
-- taken is still in the corpse when the next one looks at it -- which is why the rotation used
-- to reach through a global to ask auto-loot what it claimed, and why a policy that claimed an
-- item it then could not take meant nobody got it.

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_wow_api()
require( "src/modules" )
require( "src/Types" )
require( "src/ItemUtils" )
require( "src/DebugBuffer" )
require( "src/Module" )
local AwardPolicies = require( "src/AwardPolicies" )

---@param id number
local function item( id )
  return { id = id, name = "Item " .. id, link = u.item_link( "Item " .. id, id ), type = "DroppedItem" }
end

-- What the client actually does, as far as anybody here has established: the first award in a
-- pass lands and the rest are refused without a word. Nothing in the suite could tell the two
-- implementations apart before this, because the existing mock accepts every award.
---@param loot_facade { notify: fun( event: string, slot: number? ) }
local function refusing_master_loot( loot_facade )
  local sent = {}
  local accepting = true

  u.mock( "GiveMasterLoot", function( slot )
    if not accepting then return end

    accepting = false
    table.insert( sent, slot )
  end )

  return {
    sent = sent,
    -- The server confirming the last award landed, which is the loot window moving on and the
    -- only thing that makes the next award go through.
    confirm = function()
      local slot = table.remove( sent, 1 )
      if not slot then return end

      accepting = true
      loot_facade.notify( slot )
    end
  }
end

-- A store shaped like the one db( "award_order" ) hands over: absent until somebody saves, and
-- recording every write so "core never writes on startup" is something a test can see.
local function order_db()
  local store = { writes = 0 }

  return setmetatable( {}, {
    __index = function( _, key ) return store[ key ] end,
    __newindex = function( _, key, value )
      store[ key ] = value
      if key == "names" then store.writes = store.writes + 1 end
    end
  } ), store
end

---@param items table<number, table>
local function policies_over( items )
  local awarded = {}

  local award_policies = AwardPolicies.new( order_db() )

  award_policies.attach(
    { get_items_by_slot = function() return items end },
    { is_master_looter = function() return true end },
    -- Everybody is a candidate except "Absent", who is nobody's candidate anywhere.
    { get_index = function( _, name ) return name ~= "Absent" and 1 or nil end }
  )

  return award_policies, awarded
end

---@param name string
---@param recipient_for fun( slot: number, item: table ): string?
local function policy( name, recipient_for, awarded, asked )
  return {
    name = name,
    title = name,
    decide = function( slot, dropped )
      if asked then table.insert( asked, string.format( "%s:%s", name, slot ) ) end

      return recipient_for( slot, dropped )
    end,
    on_awarded = function( slot, _, recipient )
      if awarded then table.insert( awarded, string.format( "%s:%s:%s", name, slot, recipient ) ) end
    end
  }
end

ClaimSpec = {}

function ClaimSpec:should_record_the_policy_that_took_the_slot()
  -- Given
  local award_policies = policies_over( { [ 1 ] = item( 111 ) } )
  award_policies.register( policy( "auto_loot", function() return "Psikutas" end ) )

  -- When
  award_policies.on_loot_opened()

  -- Then
  eq( award_policies.claim_of( 1 ), "auto_loot" )
end

-- The first policy in order wins the slot, and a later one is never even asked about it.
--
-- This is where "auto-loot beats round robin" lives now. It used to be written down inside the
-- rotation, as a call through a global into the other addon -- the only place the rule existed
-- -- because GiveMasterLoot is asynchronous and the loot list still shows a slot auto-loot has
-- taken. The ledger answers that, and the order is the user's rather than one addon's opinion
-- of another.
function ClaimSpec:should_not_even_ask_a_later_policy_about_a_claimed_slot()
  -- Given
  local asked = {}
  local award_policies, awarded = policies_over( { [ 1 ] = item( 111 ) } )
  award_policies.register( policy( "auto_loot", function() return "Psikutas" end, awarded, asked ) )
  award_policies.register( policy( "auto_robin", function() return "Obszczymucha" end, awarded, asked ) )

  -- When
  award_policies.on_loot_opened()
  award_policies.on_loot_slot_cleared()

  -- Then
  eq( awarded, { "auto_loot:1:Psikutas" } )
  eq( asked, { "auto_loot:1" } )
  eq( award_policies.claim_of( 1 ), "auto_loot" )
end

-- The bug this fixes. A policy that wants an item it cannot actually hand over used to block
-- the next one from taking it and nobody got it at all -- because the claim came from a
-- predicate rather than from an award having been sent.
function ClaimSpec:should_let_the_next_policy_have_a_slot_the_first_one_cannot_take()
  -- Given
  local award_policies, awarded = policies_over( { [ 1 ] = item( 111 ) } )
  award_policies.register( policy( "auto_loot", function() return "Absent" end, awarded ) )
  award_policies.register( policy( "auto_robin", function() return "Obszczymucha" end, awarded ) )

  -- When
  award_policies.on_loot_opened()

  -- Then
  eq( awarded, { "auto_robin:1:Obszczymucha" } )
  eq( award_policies.claim_of( 1 ), "auto_robin" )
end

function ClaimSpec:should_leave_a_slot_no_policy_wants_unclaimed()
  -- Given
  local award_policies = policies_over( { [ 1 ] = item( 111 ) } )
  award_policies.register( policy( "auto_loot", function() return nil end ) )

  -- When
  award_policies.on_loot_opened()

  -- Then
  eq( award_policies.claim_of( 1 ), nil )
end

-- Slots mean something else on the next corpse, and LOOT_CLOSED can fire without
-- LOOT_SLOT_CLEARED -- the master looter assigning an item and walking away does it. Clearing
-- on open is the one of the two that survives the client skipping an event.
function ClaimSpec:should_clear_the_ledger_when_a_loot_window_opens()
  -- Given
  local items = { [ 1 ] = item( 111 ) }
  local award_policies = policies_over( items )
  local wanted = true
  award_policies.register( policy( "auto_loot", function() return wanted and "Psikutas" or nil end ) )

  award_policies.on_loot_opened()
  eq( award_policies.claim_of( 1 ), "auto_loot" )

  -- When
  wanted = false
  award_policies.on_loot_opened()

  -- Then
  eq( award_policies.claim_of( 1 ), nil )
end

CoinSpec = {}

-- Coins carry no item id, and looting one is behind a secure button the API cannot press.
function CoinSpec:should_skip_a_slot_with_no_item_id()
  -- Given
  local award_policies, awarded = policies_over( { [ 1 ] = { type = "Coin", amount_text = "3 Copper" } } )
  award_policies.register( policy( "auto_loot", function() return "Psikutas" end, awarded ) )

  -- When
  award_policies.on_loot_opened()

  -- Then
  eq( awarded, {} )
  eq( award_policies.claim_of( 1 ), nil )
end

GuardSpec = {}

function GuardSpec:should_not_award_anything_when_the_player_is_not_master_looter()
  -- Given
  local awarded = {}
  local award_policies = AwardPolicies.new( order_db() )
  award_policies.attach(
    { get_items_by_slot = function() return { [ 1 ] = item( 111 ) } end },
    { is_master_looter = function() return false end },
    { get_index = function() return 1 end } )
  award_policies.register( policy( "auto_loot", function() return "Psikutas" end, awarded ) )

  -- When
  award_policies.on_loot_opened()

  -- Then
  eq( awarded, {} )
end

-- Shift is the standard "don't do the automatic thing" modifier. Core checks it once, for
-- every policy, which is what auto-loot's copy of it claimed to be and stopped being the
-- moment there were two of them.
function GuardSpec:should_not_award_anything_while_shift_is_held()
  -- Given
  local award_policies, awarded = policies_over( { [ 1 ] = item( 111 ) } )
  award_policies.register( policy( "auto_loot", function() return "Psikutas" end, awarded ) )
  u.mock( "IsShiftKeyDown", function() return true end )

  -- When
  award_policies.on_loot_opened()
  u.mock( "IsShiftKeyDown", function() return false end )

  -- Then
  eq( awarded, {} )
end

ChainingSpec = {}

-- One award goes out per pass, and nothing is claimed that was not sent. Anything else claims
-- slots the client silently refused and leaves them in the corpse with nothing to retry them.
function ChainingSpec:should_send_one_award_per_pass()
  -- Given
  local items = { [ 1 ] = item( 111 ), [ 2 ] = item( 222 ), [ 3 ] = item( 333 ) }
  local award_policies, awarded = policies_over( items )
  award_policies.register( policy( "auto_loot", function() return "Psikutas" end, awarded ) )
  refusing_master_loot( { notify = function() end } )

  -- When
  award_policies.on_loot_opened()

  -- Then
  eq( awarded, { "auto_loot:1:Psikutas" } )
  eq( award_policies.claim_of( 2 ), nil )
  eq( award_policies.claim_of( 3 ), nil )
end

-- The disagreement the suite could not see. One implementation loops over every slot and
-- assumes they all land; the other hands out one and waits for the slot to clear. Sending one
-- at a time and running again on each LOOT_SLOT_CLEARED ends the same way under both stories:
-- one loot window opened, everything assigned.
function ChainingSpec:should_assign_every_slot_even_when_the_client_refuses_a_batch()
  -- Given
  local items = { [ 1 ] = item( 111 ), [ 2 ] = item( 222 ), [ 3 ] = item( 333 ) }
  local award_policies, awarded = policies_over( items )
  award_policies.register( policy( "auto_loot", function() return "Psikutas" end, awarded ) )

  local client = refusing_master_loot( { notify = function( slot )
    items[ slot ] = nil
    award_policies.on_loot_slot_cleared()
  end } )

  -- When
  award_policies.on_loot_opened()
  client.confirm()
  client.confirm()
  client.confirm()

  -- Then
  eq( awarded, { "auto_loot:1:Psikutas", "auto_loot:2:Psikutas", "auto_loot:3:Psikutas" } )
end

OrderSpec = {}

---@param db table
---@param names string[]
local function with_policies( db, names )
  local award_policies = AwardPolicies.new( db )
  for _, name in ipairs( names ) do award_policies.register( policy( name, function() end ) ) end
  return award_policies
end

---@param award_policies table
---@return string[]
local function order_of( award_policies )
  local result = {}
  for _, p in ipairs( award_policies.all() ) do table.insert( result, p.name ) end
  return result
end

-- Nothing saved and nothing core ships either, so registration order is all there is.
function OrderSpec:should_fall_back_to_registration_order_with_no_saved_order()
  local db = order_db()

  eq( order_of( with_policies( db, { "third_party", "another" } ) ), { "third_party", "another" } )
end

-- What core ships with itself, seeding the first run. Registration order is addon load order,
-- which is alphabetical by folder name, so it agrees here by accident -- register them the other
-- way round and the seed is what is being read.
function OrderSpec:should_seed_the_first_run_from_the_order_core_ships()
  local db = order_db()

  eq( order_of( with_policies( db, { "auto_robin", "auto_loot" } ) ), { "auto_loot", "auto_robin" } )
end

-- A name in the shipped order that nobody registered is ignored. No placeholder, no gap, no
-- error -- which is the whole of what separates a seed from the list of positions it replaced.
function OrderSpec:should_ignore_a_shipped_name_nobody_registered()
  local db = order_db()

  eq( order_of( with_policies( db, { "auto_robin" } ) ), { "auto_robin" } )
end

-- Anything core does not ship goes below what it does, in registration order. A newly installed
-- addon must not silently outrank an established one.
function OrderSpec:should_put_an_unknown_policy_below_the_ones_core_ships()
  local db = order_db()

  eq( order_of( with_policies( db, { "third_party", "auto_robin" } ) ), { "auto_robin", "third_party" } )
end

function OrderSpec:should_respect_a_saved_order()
  local db = order_db()
  db.names = { "auto_robin", "auto_loot" }

  eq( order_of( with_policies( db, { "auto_loot", "auto_robin" } ) ), { "auto_robin", "auto_loot" } )
end

-- Once a saved order exists it wins completely: a policy installed later appends at the bottom
-- even where the shipped order would have ranked it higher. The user's arrangement is not
-- re-sorted behind their back.
function OrderSpec:should_append_a_new_policy_at_the_bottom_of_a_saved_order()
  local db = order_db()
  db.names = { "auto_robin" }

  eq( order_of( with_policies( db, { "auto_loot", "auto_robin" } ) ), { "auto_robin", "auto_loot" } )
end

-- The addon is switched off, or uninstalled, or failed to load. It is skipped, not removed.
function OrderSpec:should_skip_a_saved_name_that_did_not_register()
  local db = order_db()
  db.names = { "auto_loot", "auto_robin" }

  eq( order_of( with_policies( db, { "auto_robin" } ) ), { "auto_robin" } )
end

-- Nothing but a deliberate move may change what is stored. Otherwise a session where an addon
-- failed to load -- or an alt without it -- would quietly rewrite the order to say it was never
-- there, and the position kept for it would be gone.
function OrderSpec:should_not_write_anything_on_load()
  local db, store = order_db()
  db.names = { "auto_loot", "auto_robin" }

  local award_policies = with_policies( db, { "auto_robin" } )
  order_of( award_policies )

  eq( store.writes, 1 ) -- the one this test made
end

MoveSpec = {}

function MoveSpec:should_swap_a_policy_with_its_neighbour()
  local db = order_db()
  local award_policies = with_policies( db, { "auto_loot", "auto_robin" } )

  eq( award_policies.move( 1, 1 ), true )
  eq( order_of( award_policies ), { "auto_robin", "auto_loot" } )
end

-- Deliberately no wrapping: an arrow on the last row sending that policy to the top reads as a
-- bug rather than as a rotation.
function MoveSpec:should_not_wrap_past_either_end()
  local db = order_db()
  local award_policies = with_policies( db, { "auto_loot", "auto_robin" } )

  eq( award_policies.move( 1, -1 ), false )
  eq( award_policies.move( 2, 1 ), false )
  eq( order_of( award_policies ), { "auto_loot", "auto_robin" } )
end

-- The move is persisted, and an absent policy keeps the slot it held -- so uninstalling and
-- reinstalling gets its position back rather than landing it at the bottom.
function MoveSpec:should_persist_the_move_and_leave_an_absent_policy_where_it_was()
  local db = order_db()
  db.names = { "auto_loot", "gone", "auto_robin" }

  local award_policies = with_policies( db, { "auto_loot", "auto_robin" } )

  eq( award_policies.move( 1, 1 ), true )
  eq( db.names, { "auto_robin", "gone", "auto_loot" } )
end

os.exit( lu.LuaUnit.run() )
