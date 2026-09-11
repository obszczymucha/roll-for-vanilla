---@diagnostic disable: missing-fields
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

-- The two CHAT_MSG_LOOT shapes, parsed where the component that acts on them lives.
--
-- This used to be a gmatch pair inside LootFacadeListener's register_core, which meant the
-- dispatcher knew how a loot message is spelled and no test could reach the parsing without
-- standing up the whole pipeline. Here it is one handler like every other, so the two
-- branches -- somebody else receiving, and you receiving -- are each a case.

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_wow_api()
u.mock( "GiveMasterLoot", function() end )
require( "src/modules" )
require( "src/Types" )
require( "src/ItemUtils" )
require( "src/DebugBuffer" )
require( "src/Module" )
local MasterLoot = require( "src/MasterLoot" )

local hearthstone = { id = 6948, link = u.item_link( "Hearthstone", 6948 ), quantity = 1 }

-- Confirmed-and-awaiting is the only state on_loot_received does anything in, so every case
-- starts there: the award has been confirmed, the loot frame has gone, and the chat message is
-- the only word that it landed.
---@param recipient string
local function confirmed_for( recipient )
  local awarded = {}
  local confirm

  local master_loot = MasterLoot.new(
    { get_index = function() return 1 end },
    { on_loot_awarded = function( item_id, item_link, player_name )
      table.insert( awarded, { item_id = item_id, item_link = item_link, player_name = player_name } )
    end },
    { get_slot = function() return 1 end, is_looting = function() return false end },
    { subscribe = function( _, callback ) confirm = callback end },
    { get_name = function() return "Psikutas" end }
  )

  confirm( { player = { name = recipient, class = "Warrior", type = "ItemCandidate" }, item = hearthstone } )

  return master_loot, awarded
end

ChatMsgLootSpec = {}

function ChatMsgLootSpec:should_award_on_a_message_naming_a_player()
  -- Given
  local master_loot, awarded = confirmed_for( "Obszczymucha" )

  -- When
  master_loot.on_chat_msg_loot( string.format( "Obszczymucha receives loot: %s", hearthstone.link ) )

  -- Then
  eq( awarded, { { item_id = 6948, item_link = hearthstone.link, player_name = "Obszczymucha" } } )
end

-- "You" is not a name the message carries, so the handler has to ask who the player is.
function ChatMsgLootSpec:should_award_on_a_message_naming_you()
  -- Given
  local master_loot, awarded = confirmed_for( "Psikutas" )

  -- When
  master_loot.on_chat_msg_loot( string.format( "You receive loot: %s", hearthstone.link ) )

  -- Then
  eq( awarded, { { item_id = 6948, item_link = hearthstone.link, player_name = "Psikutas" } } )
end

-- Loot messages arrive for everything anybody picks up. Without an item link there is no item
-- id, and nothing to reconcile an award against.
function ChatMsgLootSpec:should_ignore_a_message_with_no_item_link()
  -- Given
  local master_loot, awarded = confirmed_for( "Obszczymucha" )

  -- When
  master_loot.on_chat_msg_loot( "Obszczymucha receives loot: 3 Copper." )

  -- Then
  eq( awarded, {} )
end

os.exit( lu.LuaUnit.run() )
