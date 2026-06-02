RollFor = RollFor or {}
local m = RollFor

if m.RollForReceiver then return end

local M = {}
local IU = m.ItemUtils
local hl = m.colors.hl

local CHANNEL = "RollForSync"

---@param rolling_popup RollingPopup
---@param db table
function M.new( rolling_popup, db )
  ---@diagnostic disable-next-line: undefined-global
  local lib_stub = LibStub
  local ace_comm = lib_stub and lib_stub( "AceComm-3.0", true )
  local lib_serialize = lib_stub and lib_stub( "LibSerialize", true )
  local lib_deflate = lib_stub and lib_stub( "LibDeflate", true )

  if not ace_comm or not lib_serialize or not lib_deflate then
    error( "RollForReceiver: required libs (AceComm-3.0, LibSerialize, LibDeflate) are not available." )
  end

  ---@class ReceiverState
  ---@field item_link string
  ---@field item_texture string?
  ---@field item_count number
  ---@field item_quantity number
  ---@field seconds_left number?
  ---@field rolls RollData[]
  ---@field winners table[]
  ---@field strategy_type string?
  ---@field buttons table[]
  ---@field waiting_for_rolls boolean?
  ---@field tie_iterations table[]?
  ---@field dismissed boolean?

  ---@type ReceiverState?
  local state = nil

  local function decode( encoded )
    local ok, result = pcall( function()
      local compressed = lib_deflate:DecodeForWoWAddonChannel( encoded )
      if not compressed then return nil end
      local decompressed = lib_deflate:DecompressDeflate( compressed )
      if not decompressed then return nil end
      local ok2, payload = lib_serialize:Deserialize( decompressed )
      if ok2 then return payload end
    end )
    if ok then return result end
  end

  local function get_texture( item_link )
    local item_id = IU.get_item_id( item_link )
    if not item_id then return nil end
    return m.get_item_texture( m.api, item_id )
  end

  local close_button = {
    type = "Close",
    callback = function()
      if state then
        state.dismissed = true

        if not db.reopen_hint_shown then
          m.info( string.format( "Use %s to re-open.", hl( "/rf" ) ) )
          db.reopen_hint_shown = true
        end
      end
      rolling_popup.hide()
    end
  }

  local function roll_button( type, threshold )
    return { type = type, callback = function() m.api.RandomRoll( 1, threshold ) end }
  end

  local function to_popup_data()
    ---@cast state ReceiverState
    if not state.item_texture then
      state.item_texture = get_texture( state.item_link )
    end
    if not state.strategy_type then
      return {
        type = "Item",
        item_link = state.item_link,
        item_tooltip_link = IU.get_tooltip_link( state.item_link ),
        item_texture = state.item_texture,
        item_count = state.item_count,
        buttons = state.buttons
      }
    end
    local roll_data = {
      type = "Roll",
      item_link = state.item_link,
      item_tooltip_link = IU.get_tooltip_link( state.item_link ),
      item_texture = state.item_texture,
      item_count = state.item_count,
      seconds_left = state.seconds_left,
      rolls = state.rolls,
      winners = state.winners,
      strategy_type = state.strategy_type,
      buttons = state.buttons,
      waiting_for_rolls = state.waiting_for_rolls or false
    }
    if state.tie_iterations and m.getn( state.tie_iterations ) > 0 then
      return { type = "Tie", roll_data = roll_data, tie_iterations = state.tie_iterations }
    end
    return roll_data
  end

  local function refresh()
    if not state or state.dismissed then return end
    rolling_popup:show()
    rolling_popup:refresh( to_popup_data() )
  end

  local function show()
    if not state or not state.dismissed then return false end
    state.dismissed = false
    rolling_popup:show()
    rolling_popup:refresh( to_popup_data() )
    return true
  end

  local handlers = {
    ---@param event SyncEventItem
    RF_ITEM = function( event )
      state = {
        item_link = event.link,
        item_texture = get_texture( event.link ),
        item_count = event.count,
        item_quantity = event.quantity,
        seconds_left = nil,
        rolls = {},
        winners = {},
        strategy_type = nil,
        buttons = { close_button },
        waiting_for_rolls = false
      }
      refresh()
    end,

    ---@param event SyncEventStart
    RF_START = function( event )
      if not state then
        state = {
          item_link = event.link,
          item_texture = get_texture( event.link ),
          item_count = event.count,
          item_quantity = event.quantity,
          rolls = {},
          winners = {},
          buttons = {}
        }
      end

      state.seconds_left = event.seconds
      state.rolls = event.rolls or {}
      state.strategy_type = event.strategy
      state.waiting_for_rolls = false
      state.buttons = event.strategy == "SoftResRoll"
          and { roll_button( "Roll", event.ms_threshold ), close_button }
          or { roll_button( "MS", event.ms_threshold ), roll_button( "OS", event.os_threshold ), close_button }
      refresh()
    end,

    RF_ROLL = function( payload )
      if not state then return end
      local roll_data = { roll_type = payload.roll_type, player_name = payload.player_name, player_class = payload.player_class, roll = payload.roll }
      if state.strategy_type == "TieRoll" and state.tie_iterations and m.getn( state.tie_iterations ) > 0 then
        local current = state.tie_iterations[ m.getn( state.tie_iterations ) ]
        m.RollingLogicUtils.update_roll( current.rolls, roll_data )
        m.RollingLogicUtils.sort_roll_data( current.rolls )
      elseif state.strategy_type == "SoftResRoll" then
        m.RollingLogicUtils.update_roll( state.rolls, roll_data )
        m.RollingLogicUtils.sort_roll_data( state.rolls )
      else
        table.insert( state.rolls, roll_data )
        m.RollingLogicUtils.sort_roll_data( state.rolls )
      end
      refresh()
    end,

    RF_TICK = function( payload )
      if not state then return end
      state.seconds_left = payload.seconds_left
      refresh()
    end,

    RF_WIN = function( payload )
      if not state then return end
      table.insert( state.winners, {
        name = payload.name,
        class = payload.class,
        roll_type = payload.roll_type,
        roll = payload.roll
      } )
      state.strategy_type = payload.strategy
      state.waiting_for_rolls = false
      refresh()
    end,

    RF_TIE = function( payload )
      if not state then return end
      state.seconds_left = nil
      state.strategy_type = "TieRoll"
      state.waiting_for_rolls = false
      state.buttons = { close_button }
      if not state.tie_iterations then state.tie_iterations = {} end
      local tie_rolls = {}
      for _, player in ipairs( payload.players ) do
        table.insert( tie_rolls, { roll_type = payload.roll_type, player_name = player.name, player_class = player.class, roll = nil } )
      end
      m.RollingLogicUtils.sort_roll_data( tie_rolls )
      table.insert( state.tie_iterations, { tied_roll = payload.roll, rolls = tie_rolls } )
      refresh()
    end,

    RF_TIE_ROLL = function( payload )
      if not state then return end
      local rt = payload.roll_type
      local btn = rt == "MainSpec" and roll_button( "MS", payload.ms ) or
          (rt == "OffSpec" or rt == "Transmog") and roll_button( "OS", payload.os_roll ) or
          roll_button( "Roll", payload.ms )
      state.buttons = { btn, close_button }
      state.waiting_for_rolls = true
      refresh()
    end,

    RF_WAIT = function()
      if not state then return end
      state.seconds_left = nil
      state.waiting_for_rolls = true
      refresh()
    end,

    RF_FINISH = function()
      if not state then return end
      state.seconds_left = nil
      state.buttons = { close_button }
      refresh()
    end,

    RF_CANCEL = function()
      if not state then return end
      if not state.dismissed then
        rolling_popup:show()
        rolling_popup:refresh( {
          type = "RollingCanceled",
          item_link = state.item_link,
          item_tooltip_link = IU.get_tooltip_link( state.item_link ),
          item_texture = state.item_texture,
          item_count = state.item_count,
          item_quantity = state.item_quantity,
          buttons = { close_button }
        } )
      end
      state = nil
    end
  }

  local function on_item_info_received( item_id )
    if not state or state.dismissed then return end
    if IU.get_item_id( state.item_link ) ~= item_id then return end
    refresh()
  end

  ace_comm:RegisterComm( CHANNEL, function( _, encoded, _, sender )
    if sender == m.api.UnitName( "player" ) then return end

    local payload = decode( encoded )
    if not payload or not payload.type then return end

    local handler = handlers[ payload.type ]
    if handler then handler( payload ) end
  end )

  return {
    show = show,
    on_item_info_received = on_item_info_received
  }
end

m.RollForReceiver = M
return M
