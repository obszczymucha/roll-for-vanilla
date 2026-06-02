RollFor = RollFor or {}
local m = RollFor

if m.GargulBridge then return end

local M = {}

local GARGUL_CHANNEL = "GargulComm2"
local GARGUL_VERSION = "9.2.3"
local GARGUL_MIN_VERSION = "7.7.19"
local ACTION_BROADCAST_SOFT_RES = 3
local ACTION_REQUEST_SOFT_RES_DATA = 8
local ACTION_START_ROLL_OFF = 10
local ACTION_STOP_ROLL_OFF = 11

---@param player_info PlayerInfo
---@param roll_controller RollController
---@param config Config
---@param get_import_string fun(): string?
---@param softres SoftRes
function M.new( player_info, roll_controller, config, get_import_string, softres )
  ---@diagnostic disable-next-line: undefined-global
  local lib_stub = LibStub
  local ace_comm = lib_stub and lib_stub( "AceComm-3.0", true )
  local lib_serialize = lib_stub and lib_stub( "LibSerialize", true )
  local lib_deflate = lib_stub and lib_stub( "LibDeflate", true )

  if not ace_comm or not lib_serialize or not lib_deflate then return end

  local roll_in_progress = false
  local tied_players = nil
  local tie_roll_type = nil

  local function rolls_for_type( roll_type )
    if roll_type == "OffSpec" then
      return { { "OS", 1, config.os_roll_threshold() } }
    elseif roll_type == "Transmog" then
      return { { "TMOG", 1, config.tmog_roll_threshold() } }
    end
    return { { "MS", 1, config.ms_roll_threshold() } }
  end

  local function group_channel()
    if m.api.IsInRaid() then
      return "RAID"
    elseif m.api.IsInGroup() then
      return "PARTY"
    end
  end

  local function sender_fqn()
    local name = player_info.get_name()
    local realm = m.api.GetRealmName and m.api.GetRealmName() or ""
    if realm ~= "" then return name .. "-" .. realm end
    return name
  end

  local function encode( payload )
    local ok, result = pcall( function()
      local serialized = lib_serialize:Serialize( payload )
      local compressed = lib_deflate:CompressDeflate( serialized, { level = 5 } )
      return lib_deflate:EncodeForWoWAddonChannel( compressed )
    end )
    if ok then return result end
  end

  local function send_to( action, content, distribution, target )
    local encoded = encode( {
      a = action,
      b = content,
      c = sender_fqn(),
      m = GARGUL_MIN_VERSION,
      v = GARGUL_VERSION,
    } )
    if not encoded then return end
    ace_comm:SendCommMessage( GARGUL_CHANNEL, encoded, distribution, target, "BULK" )
  end

  local function send( action, content )
    local channel = group_channel()
    if not channel then return end
    send_to( action, content, channel, nil )
  end

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

  ace_comm:RegisterComm( GARGUL_CHANNEL, function( _, encoded, _, sender )
    local payload = decode( encoded )
    if not payload then return end

    if payload.a == ACTION_REQUEST_SOFT_RES_DATA then
      local import_string = get_import_string and get_import_string()
      if import_string then
        send_to( ACTION_BROADCAST_SOFT_RES, import_string, "WHISPER", sender )
      end
    end
  end )

  local function supported_rolls( strategy_type )
    if strategy_type == "SoftResRoll" then
      return { { "MS", 1, config.ms_roll_threshold() } }
    end

    local rolls = {
      { "MS", 1, config.ms_roll_threshold() },
      { "OS", 1, config.os_roll_threshold() },
    }

    if config.tmog_rolling_enabled() then
      table.insert( rolls, { "TMOG", 1, config.tmog_roll_threshold() } )
    end

    return rolls
  end

  ---@param event RollingStartedEvent
  local function on_rolling_started( event )
    if not event or not event.item or not event.seconds then return end

    roll_in_progress = true
    local content = {
      item = event.item.link,
      time = math.max( math.ceil( event.seconds * 1.7 ), 5 ),
      bth = "",
      SupportedRolls = supported_rolls( event.strategy_type ),
    }

    if event.strategy_type == "SoftResRoll" and softres then
      for _, roller in ipairs( softres.get( event.item.id ) ) do
        send_to( ACTION_START_ROLL_OFF, content, "WHISPER", roller.name )
      end
    else
      send( ACTION_START_ROLL_OFF, content )
    end
  end

  local function on_rolling_finished()
    if not roll_in_progress then return end
    roll_in_progress = false
    send( ACTION_STOP_ROLL_OFF, nil )
  end

  roll_controller.subscribe( "rolling_started", on_rolling_started )
  roll_controller.subscribe( "rolling_finished", on_rolling_finished )
  roll_controller.subscribe( "cancel_rolling", on_rolling_finished )

  roll_controller.subscribe( "waiting_for_rolls", function()
    roll_in_progress = false
  end )

  roll_controller.subscribe( "there_was_a_tie", function( data )
    if not data then return end

    if roll_in_progress then
      roll_in_progress = false
      send( ACTION_STOP_ROLL_OFF, nil )
    end

    tied_players = data.players
    tie_roll_type = data.roll_type
  end )

  roll_controller.subscribe( "tie_start", function( data )
    if not tied_players or not data then return end
    local item = data.tracker_data and data.tracker_data.item
    if not item then return end

    roll_in_progress = true
    local content = {
      item = item.link,
      time = 30,
      bth = "",
      SupportedRolls = rolls_for_type( tie_roll_type ),
    }
    for _, player in ipairs( tied_players ) do
      send_to( ACTION_START_ROLL_OFF, content, "WHISPER", player.name )
    end
    tied_players = nil
    tie_roll_type = nil
  end )

  return {
    broadcast_softres = function( import_string )
      send( ACTION_BROADCAST_SOFT_RES, import_string )
    end,
  }
end

m.GargulBridge = M
return M
