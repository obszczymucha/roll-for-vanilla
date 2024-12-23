package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )

local player = utils.player
local trade_with = utils.trade_with
local cancel_trade = utils.cancel_trade
local trade_complete = utils.trade_complete
local trade_cancelled_by_recipient = utils.trade_cancelled_by_recipient
local trade_items = utils.trade_items
local recipient_trades_items = utils.recipient_trades_items
local assert_messages = utils.assert_messages
local c = utils.console_message
local tick = utils.tick

require( "src/modules" )
local mod = require( "src/TradeTracker" )
mod.debug_enabled = true

TradeTrackerIntegrationSpec = {}

function TradeTrackerIntegrationSpec:should_log_trading_process_when_trade_cancelled_by_you()
  -- Given
  player( "Psikutas" )
  trade_with( "Obszczymucha" )

  -- When
  cancel_trade()

  -- Then
  assert_messages(
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
  assert_messages(
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
  assert_messages(
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
  local trade_tracker = mod.new( ace_timer, function( recipient ) result = recipient end )
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
  local trade_tracker = mod.new( ace_timer, function( _, giving_items ) result = giving_items end )
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
  local trade_tracker = mod.new( ace_timer, function( _, _, receiving_items ) result = receiving_items end )
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

utils.mock_libraries()
utils.load_real_stuff()

os.exit( lu.LuaUnit.run() )
