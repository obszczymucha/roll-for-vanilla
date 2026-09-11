RollFor = RollFor or {}
local m = RollFor

if m.TradeTracker then return end

local M = m.Module.new( "TradeTracker", 50 )

local hl = m.colors.hl

-- The client never tells us a trade went through.
-- A successful trade goes like this:
-- TRADE_SHOW
-- TRADE_ACCEPT_UPDATE (either 1,0 or 0,1)
-- TRADE_CLOSED

-- Whereas an unsuccessful one (full bags, or someone walked away) goes like this:
-- TRADE_SHOW
-- TRADE_ACCEPT_UPDATE (either 1,0 or 0,1)
-- TRADE_CLOSED
-- TRADE_REQUEST_CANCEL

-- The two are identical up to and including TRADE_CLOSED, so there's no easy way to
-- determine a successful trade other than waiting a bit after the close and checking
-- whether TRADE_REQUEST_CANCEL was submitted or not.

-- There is no (1,1) update to hold out for: the second accept is what completes the
-- trade, so the server closes it instead of announcing it. Requiring one at TRADE_CLOSED
-- read every completed trade as canceled and dropped the award on the floor.

-- What the accept states are good for is the opposite case: a window that closed with
-- nobody standing accepted cannot have completed, so that one needs no waiting.

---@param ace_timer AceTimer
---@param chat Chat
function M.new( ace_timer, chat, trade_complete_callback )
  local m_trading = false
  local m_items_giving = {}
  local m_items_receiving = {}
  local m_someone_accepted = false
  local m_recipient_name = nil
  local m_trade_canceled = false
  local m_received_trade_close = false -- Server sends multiple ones. Probably server bug.

  local function report_canceled()
    M.debug.add( string.format( "Trading with %s was canceled.", m_recipient_name ) )
    chat.info( string.format( "Trading with %s was canceled.", hl( m_recipient_name ) ) )
  end

  local function finalize_trading()
    m_trading = false

    if m_trade_canceled then
      report_canceled()
      return
    end

    M.debug.add( string.format( "Trading with %s complete.", m_recipient_name ) )

    for _, v in pairs( m_items_giving ) do
      if v then M.debug.add( string.format( "Traded: %sx%s", v.quantity, v.link ) ) end
    end

    for _, v in pairs( m_items_receiving ) do
      if v then M.debug.add( string.format( "Received: %sx%s", v.quantity, v.link ) ) end
    end

    trade_complete_callback( m_recipient_name, m_items_giving, m_items_receiving )
  end

  -- Both item lists are frozen at TRADE_CLOSED. Up until then whatever is in the window is
  -- what's being traded, no matter who has accepted -- a party can put an item in after the
  -- other one accepted, which just retracts that accept.
  local function on_trade_player_item_changed( slot )
    if not m_trading or m_received_trade_close then return end

    local _, _, quantity = m.api.GetTradePlayerItemInfo( slot )
    local item_link = m.api.GetTradePlayerItemLink( slot )

    if quantity and item_link then
      M.debug.add( string.format( "Giving in slot %s: %sx%s", slot, quantity, item_link ) )
      m_items_giving[ slot ] = { quantity = quantity, link = item_link }
    else
      if m_items_giving[ slot ] then M.debug.add( string.format( "Giving slot %s cleared.", slot ) ) end
      m_items_giving[ slot ] = nil
    end
  end

  local function on_trade_show()
    m_recipient_name = m.api.TradeFrameRecipientNameText:GetText() or "Unknown"

    M.debug.add( string.format( "TRADE_SHOW (%s)", m_recipient_name ) )

    m_trading = true
    m_someone_accepted = false
    m_trade_canceled = false
    m_items_giving = {}
    m_items_receiving = {}
    m_received_trade_close = false

    -- When dragging an item onto a player, there's no event. Let's simulate it.
    on_trade_player_item_changed( 1 )
  end

  local function on_trade_target_item_changed( slot )
    if not m_trading or m_received_trade_close then return end

    local _, _, quantity = m.api.GetTradeTargetItemInfo( slot )
    local item_link = m.api.GetTradeTargetItemLink( slot )

    if quantity and item_link then
      M.debug.add( string.format( "Receiving in slot %s: %sx%s", slot, quantity, item_link ) )
      m_items_receiving[ slot ] = { quantity = quantity, link = item_link }
    else
      if m_items_receiving[ slot ] then M.debug.add( string.format( "Receiving slot %s cleared.", slot ) ) end
      m_items_receiving[ slot ] = nil
    end
  end

  local function on_trade_closed()
    M.debug.add( "TRADE_CLOSED" )
    if not m_trading or m_received_trade_close then return end
    m_received_trade_close = true

    if m_trade_canceled or not m_someone_accepted then
      report_canceled()
      m_trading = false
      return
    end

    ace_timer.ScheduleTimer( M, finalize_trading, 0.5 )
  end

  -- Both states are numbers, 0 or 1, and never nil -- playerAccepted and targetAccepted are
  -- both `Nilable = false` in the client's TradeInfoDocumentation. 0 is true in Lua, so a
  -- plain truth test reads every update as an accept.
  ---@param player_accepted number
  ---@param target_accepted number
  local function on_trade_accept_update( player_accepted, target_accepted )
    M.debug.add( string.format( "TRADE_ACCEPT_UPDATE( %s, %s )", tostring( player_accepted ), tostring( target_accepted ) ) )

    -- The latest state, not a latch: cancelling an accept reports (0,0), and a window that
    -- closes there went nowhere.
    m_someone_accepted = player_accepted == 1 or target_accepted == 1
  end

  local function on_trade_request_cancel()
    M.debug.add( "TRADE_REQUEST_CANCEL" )
    if not m_trading then return end
    m_trade_canceled = true
  end

  return {
    on_trade_show = on_trade_show,
    on_trade_player_item_changed = on_trade_player_item_changed,
    on_trade_target_item_changed = on_trade_target_item_changed,
    on_trade_closed = on_trade_closed,
    on_trade_accept_update = on_trade_accept_update,
    on_trade_request_cancel = on_trade_request_cancel
  }
end

m.TradeTracker = M
return M
