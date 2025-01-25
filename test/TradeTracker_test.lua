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

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
