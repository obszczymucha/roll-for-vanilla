RollFor = RollFor or {}
local m = RollFor

if m.TradeTracker then return end

M = {}

M.debug_enabled = false

-- So it seems that in 2.4.3 trading is a little fucked.
-- A successful trade goes like this
-- TRADE_SHOW
-- TRADE_ACCEPT_UPDATE (either 1,0 or 0,1)
-- TRADE_ACCEPT_UPDATE (1,1)
-- TRADE_CLOSED

-- Whereas an unsuccessful trade goes like this (full bags):
-- TRADE_SHOW
-- TRADE_ACCEPT_UPDATE (either 1,0 or 0,1)
-- TRADE_ACCEPT_UPDATE (1,1)
-- TRADE_CLOSED
-- TRADE_REQUEST_CANCEL

-- Obviously trade is not successful if TRADE_CLOSED was
-- received before both parties accepted.

-- It seems there's no easy way to determing a successful trade
-- other than waiting a bit and checking if TRADE_REQUEST_CANCEL
-- was submitted or not.

function M.new( ace_timer, trade_complete_callback )
  local m_trading = false
  local m_items_giving = {}
  local m_items_receiving = {}
  local m_both_parties_accepted = false
  local m_recipient_name = nil
  local m_trade_canceled = false
  local m_received_trade_close = false -- Server sends multiple ones. Probably server bug.

  local pretty_print = m.pretty_print

  local function highlight( text )
    return string.format( "|cffff9f69%s|r", text )
  end

  local function finalize_trading()
    if M.debug_enabled then
      if m_trade_canceled then
        pretty_print( string.format( "Trading with %s was canceled.", highlight( m_recipient_name ) ) )
        return
      end

      pretty_print( string.format( "Trading with %s complete.", highlight( m_recipient_name ) ) )

      for _, v in pairs( m_items_giving ) do
        if v then pretty_print( string.format( "Traded: %sx%s", v.quantity, v.link ) ) end
      end

      for _, v in pairs( m_items_receiving ) do
        if v then pretty_print( string.format( "Received: %sx%s", v.quantity, v.link ) ) end
      end
    end

    if not m_trade_canceled then
      trade_complete_callback( m_recipient_name, m_items_giving, m_items_receiving )
    end
  end

  local function on_trade_player_item_changed( slot )
    if m_both_parties_accepted then return end

    local _, _, quantity = m.api.GetTradePlayerItemInfo( slot )
    local item_link = m.api.GetTradePlayerItemLink( slot )

    if quantity and item_link then
      if M.debug_enabled then
        pretty_print( string.format( "Giving in slot %s: %sx%s", slot, quantity, item_link ) )
      end

      m_items_giving[ slot ] = { quantity = quantity, link = item_link }
    else
      if M.debug_enabled and m_items_giving[ slot ] then
        pretty_print( string.format( "Giving slot %s cleared.", slot ) )
      end

      m_items_giving[ slot ] = nil
    end
  end

  local function on_trade_show()
    m_recipient_name = m.api.TradeFrameRecipientNameText:GetText() or "Unknown"

    if M.debug_enabled then
      pretty_print( string.format( "Started trading with %s.", highlight( m_recipient_name ) ) )
    end

    m_trading = true
    m_both_parties_accepted = false
    m_trade_canceled = false
    m_items_giving = {}
    m_items_receiving = {}
    m_received_trade_close = false

    -- When dragging an item onto a player, there's no event. Let's simulate it.
    on_trade_player_item_changed( 1 )
  end

  local function on_trade_target_item_changed( slot )
    if m_both_parties_accepted then return end

    local _, _, quantity = m.api.GetTradeTargetItemInfo( slot )
    local item_link = m.api.GetTradeTargetItemLink( slot )

    if quantity and item_link then
      if M.debug_enabled then
        pretty_print( string.format( "Receiving in slot %s: %sx%s", slot, quantity, item_link ) )
      end

      m_items_receiving[ slot ] = { quantity = quantity, link = item_link }
    else
      if M.debug_enabled and m_items_receiving[ slot ] then
        pretty_print( string.format( "Receiving slot %s cleared.", slot ) )
      end

      m_items_receiving[ slot ] = nil
    end
  end

  local function on_trade_closed()
    if not m_trading or m_received_trade_close then return end
    m_received_trade_close = true

    if m_both_parties_accepted then
      ace_timer.ScheduleTimer( M, finalize_trading, 0.5 )
      return
    end

    pretty_print( string.format( "Trading with %s was canceled.", highlight( m_recipient_name ) ) )
    m_trading = false
  end

  local function on_trade_accept_update( player_accepted, target_accepted )
    if player_accepted and target_accepted then
      m_both_parties_accepted = true
    end
  end

  local function on_trade_request_cancel()
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
