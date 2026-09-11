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
require( "src/DebugBuffer" )
require( "src/Module" )
local mod = require( "src/TradeTracker" )

-- The trace is a rolling buffer shared by every tracker built in this file, so a test reads
-- back only what it appended itself.
local function debug_mark()
  local messages = mod.debug.get()
  local last = messages[ #messages ]

  return last and last.index or 0
end

local function debug_since( mark )
  local result = {}

  for _, message in ipairs( mod.debug.get() ) do
    if message.index > mark then table.insert( result, message.text ) end
  end

  return result
end

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
  local mark = debug_mark()
  trade_with( "Obszczymucha" )

  -- When
  cancel_trade()

  -- Then
  m.chat.assert( c( "RollFor: Trading with Obszczymucha was canceled." ) )
  lu.assertEquals( debug_since( mark ), {
    "TRADE_SHOW (Obszczymucha)",
    "TRADE_ACCEPT_UPDATE( 0, 0 )",
    "TRADE_CLOSED",
    "Trading with Obszczymucha was canceled."
  } )
end

function TradeTrackerIntegrationSpec:should_log_trading_process_when_trade_cancelled_by_the_recipient()
  -- Given
  player( "Psikutas" )
  local mark = debug_mark()
  trade_with( "Obszczymucha" )

  -- When
  trade_cancelled_by_recipient()

  -- Then
  m.chat.assert( c( "RollFor: Trading with Obszczymucha was canceled." ) )
  lu.assertEquals( debug_since( mark ), {
    "TRADE_SHOW (Obszczymucha)",
    "TRADE_REQUEST_CANCEL",
    "TRADE_CLOSED",
    "Trading with Obszczymucha was canceled."
  } )
end

function TradeTrackerIntegrationSpec:should_log_trading_process_when_trade_is_complete()
  -- Given
  player( "Psikutas" )
  local mark = debug_mark()
  trade_with( "Obszczymucha" )

  -- When
  trade_complete()
  tick() -- Gotta tick, cuz we have no choice but to hack it with a timer in TBC.

  -- Then
  m.chat.assert_no_messages()
  lu.assertEquals( debug_since( mark ), {
    "TRADE_SHOW (Obszczymucha)",
    "TRADE_ACCEPT_UPDATE( 1, 1 )",
    "TRADE_CLOSED",
    "Trading with Obszczymucha complete."
  } )
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

-- Everything below is about the accept states, which are two numbers, 0 or 1, and never
-- nil -- playerAccepted and targetAccepted are both `Nilable = false` in the client's
-- TradeInfoDocumentation.

-- Recording stops at TRADE_CLOSED, not at an accept: an accept is retracted the moment
-- either party touches the window again, so an item put in after one is still traded. Stop
-- recording there and the item is handed over with no award behind it -- no
-- on_loot_awarded, and no "<player> received <item>."
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

-- The same, on the other side of the window. This one is how an award gets taken back:
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

-- A trade that fails after both parties are done with it -- full bags is the usual way --
-- closes exactly like one that went through, and only says otherwise afterwards, with
-- TRADE_REQUEST_CANCEL. Decide at the close and every item in that window is recorded as
-- awarded to somebody who never received it.
function TradeTrackerIntegrationSpec:should_not_complete_a_trade_cancelled_after_it_closed()
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
  trade_tracker.on_trade_request_cancel()
  tick()

  -- Then
  lu.assertEquals( completed, false )
  chat_api.assert( c( "Trading with Obszczymucha was canceled." ) )
end

-- The live client is under no obligation to announce (1,1). The second accept is what
-- completes the trade, so the update that would carry it is the one the server never gets
-- to send: TRADE_CLOSED arrives with the last seen state still showing one party accepted.
-- Requiring (1,1) at close turns every such trade into "Trading with <player> was canceled."
-- and drops the award on the floor.
function TradeTrackerIntegrationSpec:should_complete_a_trade_that_never_reported_both_accepts()
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
  trade_tracker.on_trade_accept_update( 0, 1 )
  trade_tracker.on_trade_closed()
  tick()

  -- Then
  lu.assertEquals( result, {
    { link = "fake item link", quantity = 1 }
  } )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
