package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local u = require( "test/utils" )
local lu = u.luaunit()
local player = u.player
local trade_with, cancel_trade = u.trade_with, u.cancel_trade
local trade_complete, trade_cancelled_by_recipient = u.trade_complete, u.trade_cancelled_by_recipient
local trade_items, recipient_trades_items = u.trade_items, u.recipient_trades_items
local c = u.console_message
local tick = u.tick

require( "src/modules" )
local mod = require( "src/TradeTracker" )
mod.debug_enabled = true

---@type ModuleRegistry
local module_registry = {
  { module_name = "ChatApi", mock = "mocks/ChatApi", variable_name = "chat" }
}

-- The modules will be injected here using the above module_registry.
local m = {}

TradeTrackerIntegrationSpec = {}

function TradeTrackerIntegrationSpec:should_log_trading_process_when_trade_cancelled_by_you()
  -- Given
  player( "Psikutas" )
  trade_with( "Obszczymucha" )

  -- When
  cancel_trade()

  -- Then
  m.chat.assert(
    c( "RollFor: Started trading with Obszczymucha." ),
    c( "RollFor: Trading with Obszczymucha was canceled." )
  )
end

function TradeTrackerIntegrationSpec:should_log_trading_process_when_trade_cancelled_by_the_recipient()
  -- Given
  player( "Psikutas" )
  trade_with( "Obszczymucha" )

  -- When
  trade_cancelled_by_recipient()

  -- Then
  m.chat.assert(
    c( "RollFor: Started trading with Obszczymucha." ),
    c( "RollFor: Trading with Obszczymucha was canceled." )
  )
end

function TradeTrackerIntegrationSpec:should_log_trading_process_when_trade_is_complete()
  -- Given
  player( "Psikutas" )
  trade_with( "Obszczymucha" )

  -- When
  trade_complete()
  tick() -- Gotta tick, cuz we have no choice but to hack it with a timer in TBC.

  -- Then
  m.chat.assert(
    c( "RollFor: Started trading with Obszczymucha." ),
    c( "RollFor: Trading with Obszczymucha complete." )
  )
end

TradeTrackerSpec = {}

function TradeTrackerIntegrationSpec:should_call_back_with_recipient_name()
  -- Given
  local result
  ---@diagnostic disable-next-line: undefined-global
  local ace_timer = LibStub( "AceTimer-3.0" )
  local chat_api = require( "mocks/ChatApi" ).new()
  local mocked_chat = require( "mocks/Chat" ).new( chat_api, "PARTY" )
  local trade_tracker = mod.new( ace_timer, mocked_chat, function( recipient ) result = recipient end )
  trade_with( "Obszczymucha", trade_tracker )

  -- When
  trade_complete( trade_tracker )
  tick()

  -- Then
  lu.assertEquals( result, "Obszczymucha" )
end

function TradeTrackerIntegrationSpec:should_call_back_with_items_given()
  -- Given
  local result
  ---@diagnostic disable-next-line: undefined-global
  local ace_timer = LibStub( "AceTimer-3.0" )
  local chat_api = require( "mocks/ChatApi" ).new()
  local mocked_chat = require( "mocks/Chat" ).new( chat_api, "PARTY" )
  local trade_tracker = mod.new( ace_timer, mocked_chat, function( _, giving_items ) result = giving_items end )
  player( "Psikutas" )
  trade_with( "Obszczymucha", trade_tracker )
  trade_items( trade_tracker, { item_link = "fake item link", quantity = 1 } )

  -- When
  trade_complete( trade_tracker )
  tick()

  -- Then
  lu.assertEquals( result, {
    { link = "fake item link", quantity = 1 }
  } )
end

function TradeTrackerIntegrationSpec:should_call_back_with_items_received()
  -- Given
  local result
  ---@diagnostic disable-next-line: undefined-global
  local ace_timer = LibStub( "AceTimer-3.0" )
  local chat_api = require( "mocks/ChatApi" ).new()
  local mocked_chat = require( "mocks/Chat" ).new( chat_api, "PARTY" )
  local trade_tracker = mod.new( ace_timer, mocked_chat, function( _, _, receiving_items ) result = receiving_items end )
  player( "Psikutas" )
  trade_with( "Obszczymucha", trade_tracker )
  recipient_trades_items( trade_tracker, { item_link = "fake item link", quantity = 1 } )

  -- When
  trade_complete( trade_tracker )
  tick()

  -- Then
  lu.assertEquals( result, {
    { link = "fake item link", quantity = 1 }
  } )
end

-- Everything below is one defect: what "both parties accepted" is read off.
--
-- TRADE_ACCEPT_UPDATE carries two numbers, 0 or 1, and never nil -- playerAccepted and
-- targetAccepted are both `Nilable = false` in the client's TradeInfoDocumentation -- and 0
-- is true in Lua. So a plain truth test is satisfied by the first update of every trade,
-- which the header above records as (1,0) or (0,1): one party has accepted, which is the
-- precise opposite of what the flag is supposed to mean.
--
-- These cover the three things that flag is load-bearing for: the giving list, the
-- receiving list, and whether a closed trade happened at all.

-- The item lists are locked once both have accepted, so that a late change can't rewrite
-- what is already going through. Read a single accept as both and the lock comes down while
-- the trade is still being filled: the item is handed over, and the award that should follow
-- it never happens -- no on_loot_awarded, and no "<player> received <item>."
--
-- What survives is whatever was already in slot 1 at TRADE_SHOW, which is what dragging an
-- item straight onto a player leaves there. Hence one item awarded and the rest silent.
function TradeTrackerIntegrationSpec:should_record_an_item_put_in_after_one_party_accepted()
  -- Given
  local result
  ---@diagnostic disable-next-line: undefined-global
  local ace_timer = LibStub( "AceTimer-3.0" )
  local chat_api = require( "mocks/ChatApi" ).new()
  local mocked_chat = require( "mocks/Chat" ).new( chat_api, "PARTY" )
  local trade_tracker = mod.new( ace_timer, mocked_chat, function( _, giving_items ) result = giving_items end )
  player( "Psikutas" )
  trade_with( "Obszczymucha", trade_tracker )

  -- Only the recipient has accepted so far.
  trade_tracker.on_trade_accept_update( 0, 1 )
  trade_items( trade_tracker, { item_link = "fake item link", quantity = 1 } )

  -- When
  trade_complete( trade_tracker )
  tick()

  -- Then
  lu.assertEquals( result, {
    { link = "fake item link", quantity = 1 }
  } )
end

-- The same lock, on the other side of the window. This one is how an award gets taken back:
-- the winner trading the item to us is what main.lua reads the receiving list for.
function TradeTrackerIntegrationSpec:should_record_an_item_received_after_one_party_accepted()
  -- Given
  local result
  ---@diagnostic disable-next-line: undefined-global
  local ace_timer = LibStub( "AceTimer-3.0" )
  local chat_api = require( "mocks/ChatApi" ).new()
  local mocked_chat = require( "mocks/Chat" ).new( chat_api, "PARTY" )
  local trade_tracker = mod.new( ace_timer, mocked_chat, function( _, _, receiving_items ) result = receiving_items end )
  player( "Psikutas" )
  trade_with( "Obszczymucha", trade_tracker )

  trade_tracker.on_trade_accept_update( 1, 0 )
  recipient_trades_items( trade_tracker, { item_link = "fake item link", quantity = 1 } )

  -- When
  trade_complete( trade_tracker )
  tick()

  -- Then
  lu.assertEquals( result, {
    { link = "fake item link", quantity = 1 }
  } )
end

-- "Obviously trade is not successful if TRADE_CLOSED was received before both parties
-- accepted" -- the header's words. Read one accept as both and this window, which the
-- recipient walked away from, is a completed trade: the callback runs and every item in it
-- is recorded as awarded to somebody who never received it.
function TradeTrackerIntegrationSpec:should_not_complete_a_trade_only_one_party_accepted()
  -- Given
  local completed = false
  ---@diagnostic disable-next-line: undefined-global
  local ace_timer = LibStub( "AceTimer-3.0" )
  local chat_api = require( "mocks/ChatApi" ).new()
  local mocked_chat = require( "mocks/Chat" ).new( chat_api, "PARTY" )
  local trade_tracker = mod.new( ace_timer, mocked_chat, function() completed = true end )
  player( "Psikutas" )
  trade_with( "Obszczymucha", trade_tracker )
  trade_items( trade_tracker, { item_link = "fake item link", quantity = 1 } )

  -- When
  trade_tracker.on_trade_accept_update( 1, 0 )
  trade_tracker.on_trade_closed()
  tick()

  -- Then
  lu.assertEquals( completed, false )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
