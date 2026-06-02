RollFor = RollFor or {}
local m = RollFor

if m.RollForBroadcast then return end

local M = {}

local CHANNEL = "RollForSync"

---@param roll_controller RollController
---@param config Config
function M.new( roll_controller, config )
  ---@diagnostic disable-next-line: undefined-global
  local lib_stub = LibStub
  local ace_comm = lib_stub and lib_stub( "AceComm-3.0", true )
  local lib_serialize = lib_stub and lib_stub( "LibSerialize", true )
  local lib_deflate = lib_stub and lib_stub( "LibDeflate", true )

  if not ace_comm or not lib_serialize or not lib_deflate then
    error( "RollForBroadcast: required libs (AceComm-3.0, LibSerialize, LibDeflate) are not available." )
  end

  local function group_channel()
    if m.api.IsInRaid() then
      return "RAID"
    elseif m.api.IsInGroup() then
      return "PARTY"
    end
  end

  local function encode( payload )
    local ok, result = pcall( function()
      local serialized = lib_serialize:Serialize( payload )
      local compressed = lib_deflate:CompressDeflate( serialized, { level = 5 } )
      return lib_deflate:EncodeForWoWAddonChannel( compressed )
    end )
    if ok then return result end
  end

  local active = false
  local tie_roll_type = nil
  local tie_players = nil

  local function send( payload )
    local channel = group_channel()
    if not channel then return end
    local encoded = encode( payload )
    if not encoded then return end
    ace_comm:SendCommMessage( CHANNEL, encoded, channel, nil, "BULK" )
  end

  local function send_whisper( player_name, payload )
    local encoded = encode( payload )
    if not encoded then return end
    ace_comm:SendCommMessage( CHANNEL, encoded, "WHISPER", player_name, "BULK" )
  end

  local function send_if_active( payload )
    if not active then return end
    send( payload )
  end

  ---@class SyncEventItem
  ---@field type "RF_ITEM"
  ---@field link ItemLink
  ---@field count number
  ---@field quantity number

  ---@class SyncEventStart
  ---@field type "RF_START"
  ---@field strategy RollingStrategyType
  ---@field link ItemLink
  ---@field count number
  ---@field quantity number
  ---@field seconds number
  ---@field ms_threshold number
  ---@field os_threshold number
  ---@field rolls RollData[]

  ---@param event RollingStartedEvent
  local function on_rolling_started( event )
    if not event or not event.item then return end
    active = true

    ---@type SyncEventItem
    local item_event = { type = "RF_ITEM", link = event.item.link, count = event.item_count, quantity = event.item_quantity }
    send( item_event )

    if event.strategy_type ~= "SoftResRoll" or m.getn( event.rolls ) > 0 then
      ---@type SyncEventStart
      local start_event = {
        type = "RF_START",
        strategy = event.strategy_type,
        link = event.item.link,
        count = event.item_count,
        quantity = event.item_quantity,
        seconds = event.seconds,
        ms_threshold = config.ms_roll_threshold(),
        os_threshold = config.os_roll_threshold(),
        rolls = event.rolls
      }

      send( start_event )
    end
  end

  ---@class SyncEventRoll
  ---@field type "RF_ROLL"
  ---@field roll_type RollType
  ---@field player_name string
  ---@field player_class string
  ---@field roll number

  ---@param data RollEvent
  local function on_roll( data )
    if not data then return end

    ---@type SyncEventRoll
    local event = {
      type = "RF_ROLL",
      roll_type = data.roll_type,
      player_name = data.player_name,
      player_class = data.player_class,
      roll = data.roll
    }

    send_if_active( event )
  end

  local function on_tick( data )
    if not data then return end
    send_if_active( { type = "RF_TICK", seconds_left = data.seconds_left } )
  end

  roll_controller.subscribe( "rolling_started", on_rolling_started )
  roll_controller.subscribe( "roll", on_roll )
  roll_controller.subscribe( "tick", on_tick )

  roll_controller.subscribe( "winners_found", function( data )
    if not data then return end
    for _, winner in ipairs( data.winners ) do
      send_if_active( {
        type = "RF_WIN",
        strategy = data.rolling_strategy,
        name = winner.name,
        class = winner.class,
        roll_type = winner.roll_type,
        roll = winner
            .winning_roll
      } )
    end
  end )

  roll_controller.subscribe( "there_was_a_tie", function( data )
    if not data then return end
    tie_roll_type = data.roll_type
    tie_players = {}
    for _, player in ipairs( data.players ) do
      table.insert( tie_players, { name = player.name, class = player.class } )
    end
    send_if_active( { type = "RF_TIE", players = tie_players, roll = data.roll, roll_type = data.roll_type } )
  end )

  roll_controller.subscribe( "waiting_for_rolls", function()
    send_if_active( { type = "RF_WAIT" } )
  end )

  roll_controller.subscribe( "tie_start", function()
    if not active or not tie_players then return end
    local payload = { type = "RF_TIE_ROLL", roll_type = tie_roll_type, ms = config.ms_roll_threshold(), os_roll = config.os_roll_threshold() }
    for _, player in ipairs( tie_players ) do
      send_whisper( player.name, payload )
    end
  end )

  roll_controller.subscribe( "rolling_finished", function()
    send_if_active( { type = "RF_FINISH" } )
    active = false
  end )

  roll_controller.subscribe( "cancel_rolling", function()
    send_if_active( { type = "RF_CANCEL" } )
    active = false
  end )

  return {}
end

m.RollForBroadcast = M
return M
