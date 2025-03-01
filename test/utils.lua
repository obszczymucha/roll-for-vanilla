package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua;../RollFor/libs/vanilla/LibStub/?.lua"

local M = {}

local m_slashcmdlist = {}
local m_messages = {}
local m_event_callback = nil
local m_tick_fn = nil
local m_repeating_tick_fn = nil
local m_rolling_item_name = nil
local m_is_master_looter = false
local m_player_name = nil
local m_target = nil
local m_loot_confirm_callback = nil

---@diagnostic disable-next-line: undefined-field
local lua50 = table.setn and true or false

if not lua50 then
  function getfenv()
    return _G
  end

  if not unpack then
    function unpack( t, i, j )
      i = i or 1
      j = j or #t

      if i > j then
        return
      end

      return t[ i ], unpack( t, i + 1, j )
    end
  end
end

M.debug_enabled = true

function M.princess()
  return "kenny"
end

function M.debug( message )
  if not M.debug_enabled then return end
  print( string.format( "[ debug ]: %s", message ) )
end

function M.debugln( message )
  if not M.debug_enabled then return end
  print( "\n" )
  M.debug( message )
end

---@param message string
---@param chat_type ChatType|"CONSOLE"
function M.chat_message( message, chat_type )
  return { message = message, type = chat_type }
end

function M.party_message( message )
  return M.chat_message( message, "PARTY" )
end

---@return ... ChatMessage[]
function M.raid_message( ... )
  local args = { ... }

  local result = {}

  for i = 1, #args do
    table.insert( result, M.chat_message( args[ i ], "RAID" ) )
  end

  ---@diagnostic disable-next-line: deprecated
  return function() return table.unpack( result ) end
end

function M.raid_warning( message )
  return M.chat_message( message, "RAID_WARNING" ) ---@type ChatMessage
end

function M.console_message( message )
  return M.chat_message( message, "CONSOLE" ) ---@type ChatMessage
end

function M.mock_wow_api()
  M.modules().lua.time = os.time
  M.modules().lua.random = math.random
  M.modules().api.UISpecialFrames = {}
  M.modules().api.InCombatLockdown = function() return false end
  M.modules().api.IsAltKeyDown = function() return false end
  M.modules().api.GetAddOnMetadata = function() return "2.6" end -- version
  M.modules().api.tinsert = table.insert
  M.modules().api.PlaySound = function() end
  M.modules().api.C_ChatInfo = {}
  M.modules().api.C_ChatInfo.SendAddonMessage = function() end
  M.modules().api.IsShiftKeyDown = function() return false end
  M.modules().api.IsControlKeyDown = function() return false end
  M.modules().api.GetItemInfo = function() return nil, nil, 4 end
  M.modules().api.UIFrameFade = function() end
  M.modules().api.UnitIsConnected = function() return true end
  M.modules().api.UnitGUID = function() return "PrincessKenny" end
  M.modules().api.LootSlot = function() end
  M.modules().api.GetLootMethod = function() return "master" end
  M.modules().api.IsInGroup = function() return true end
  M.modules().api.SOUNDKIT = {
    IG_MAIN_MENU_OPEN = 850,
    IG_MAIN_MENU_CLOSE = 851
  }

  M.modules().api.CreateFrame = function( _, frame_name )
    local frame = {
      RegisterEvent = function() end,
      SetScript = function( self, name, callback )
        if frame_name == "RollForFrame" and name == "OnEvent" then
          M.debug( "Registered OnEvent callback." )
          m_event_callback = callback
        end

        if name == "OnClick" then
          self.OnClickCallback = callback
        end

        if name == "OnHide" then
          self.OnHideCallback = callback
        end

        if name == "OnTextChanged" then
          self.OnTextChangedCallback = callback
        end
      end,
      Show = function( self ) self.visible = true end,
      Hide = function( self )
        self.visible = false
        if self.OnHideCallback then self.OnHideCallback() end
      end,
      Enable = function() end,
      Disable = function() end,
      ClearAllPoints = function() end,
      SetBackdrop = function() end,
      SetBackdropColor = function() end,
      SetBackdropBorderColor = function() end,
      SetFrameStrata = function() end,
      SetFrameLevel = function() end,
      SetOwner = function() end,
      RegisterForClicks = function() end,
      RegisterForDrag = function() end,
      SetHighlightTexture = function() end,
      GetFrameLevel = function() return 0 end,
      GetName = function() return "PrincessKenny" end,
      CreateTexture = function()
        return {
          SetWidth = function() end,
          SetHeight = function() end,
          SetTexture = function() end,
          SetPoint = function() end,
          SetTexCoord = function() end,
          Show = function() end,
          Hide = function() end,
          SetBlendMode = function() end,
          SetAllPoints = function() end,
        }
      end,
      SetWidth = function() end,
      GetWidth = function() return 20 end,
      SetHeight = function() end,
      GetHeight = function() return 100 end,
      SetScale = function() end,
      GetScale = function() return 1 end,
      GetScript = function() end,
      GetFontString = function()
        return {
          SetPoint = function() end,
        }
      end,
      SetAlpha = function() end,
      SetFocus = function() end,
      SetPoint = function() end,
      SetMovable = function() end,
      SetResizable = function() end,
      SetMinResize = function() end,
      SetToplevel = function() end,
      EnableMouse = function() end,
      SetAllPoints = function() end,
      SetNormalTexture = function() end,
      SetScrollChild = function() end,
      SetMultiLine = function() end,
      SetTextInsets = function() end,
      SetAutoFocus = function() end,
      SetFontObject = function() end,
      UpdateScrollChildRect = function() end,
      ClearLines = function() end,
      NumLines = function() return 0 end,
      SetPushedTexture = function() end,
      SetText = function( self, text )
        self.text = text
        if self.OnTextChangedCallback then self.OnTextChangedCallback() end
      end,
      GetText = function( self )
        return self.text
      end,
      IsVisible = function( self ) return self.visible end,
      CreateFontString = function()
        return {
          Hide = function() end,
          Show = function() end,
          ClearAllPoints = function() end,
          SetPoint = function() end,
          SetText = function() end,
          SetTextColor = function() end,
          GetStringWidth = function() return 0 end,
          GetWidth = function() return 100 end,
          GetHeight = function() return 20 end,
          GetText = function() return "Font string text" end,
          SetWidth = function() end,
          SetNonSpaceWrap = function() end,
          SetHeight = function() end,
          SetJustifyH = function() end,
          SetScale = function() end,
        }
      end,
      Click = function( self )
        if self.OnClickCallback then self:OnClickCallback() end
      end,
      SetLootItem = function() end,
    }

    if frame_name then _G[ frame_name ] = frame end

    return frame
  end

  M.modules().api.LOOTFRAME_NUMBUTTONS = 4
  M.modules().api.StaticPopupDialogs = {}
  M.modules().api.RAID_CLASS_COLORS = {
    [ "DRUID" ] = { colorStr = "ffff7d0a" },
    [ "HUNTER" ] = { colorStr = "ffabd473" },
    [ "MAGE" ] = { colorStr = "ff3fc7eb" },
    [ "PALADIN" ] = { colorStr = "fff58cba" },
    [ "PRIEST" ] = { colorStr = "ffffffff" },
    [ "ROGUE" ] = { colorStr = "fffff569" },
    [ "SHAMAN" ] = { colorStr = "ff0070de" },
    [ "WARLOCK" ] = { colorStr = "ff8788ee" },
    [ "WARRIOR" ] = { colorStr = "ffabd473" }
  }

  M.modules().api.ITEM_QUALITY_COLORS = {
    { r = 1, g = 1, b = 1, a = 1, hex = "asd" },
    { r = 1, g = 1, b = 1, a = 1, hex = "blue" },
    { r = 1, g = 1, b = 1, a = 1, hex = "green" },
    { r = 1, g = 1, b = 1, a = 1, hex = "purple" },
    { r = 1, g = 1, b = 1, a = 1, hex = "ass" },
    { r = 1, g = 1, b = 1, a = 1, hex = "princess" },
    { r = 1, g = 1, b = 1, a = 1, hex = "kenny" }
  }
  M.modules().api.FONT_COLOR_CODE_CLOSE = "|r"

  return M.modules().api
end

function M.highlight( word )
  return string.format( "|cffff9f69%s|r", word )
end

function M.decolorize( input )
  return string.gsub( input, "|c%x%x%x%x%x%x%x%x([^|]+)|r", "%1" )
end

function M.parse_item_link( item_link )
  return string.gsub( item_link, "|c%x%x%x%x%x%x%x%x|Hitem:%d+.*|h(.*)|h|r", "%1" )
end

function M.parse_tooltip_item_link( item_link )
  return string.gsub( item_link, "^item:(%d+):.*$", "%1" )
end

local function load_libstub()
  ---@diagnostic disable-next-line: lowercase-global
  strmatch = string.match
  require( "LibStub" )

  ---@diagnostic disable-next-line: undefined-global
  return LibStub
end

function M.mock_library( name, object )
  -- error("mocking stuff", 2)
  load_libstub()
  ---@diagnostic disable-next-line: undefined-global
  local result = LibStub:NewLibrary( name, 1 )
  if not result then return nil end
  if not object then return result end

  for k, v in pairs( object ) do
    result[ k ] = v
  end

  return result
end

function M.mock_api()
  M.mock_slashcmdlist()
  M.mock( "IsInGuild", false )
  M.mock( "IsInGroup", false )
  M.mock( "IsInParty", false )
  M.mock( "IsInRaid", false )
  M.mock( "UnitIsFriend", false )
  M.mock( "InCombatLockdown", false )
  M.mock( "UnitName", "Psikutas" )
  M.mock( "UnitClass", "Warrior" )
  M.mock( "GetRealZoneText", "Elwynn Forest" )
  M.mock( "UnitIsGroupLeader", false )

  -- Loot Interface
  M.mock( "GetLootSlotLink" )
  M.mock( "GetLootSlotInfo" )
  M.mock( "GetLootSlotType" )
  M.mock( "GetNumLootItems" )

  M.zone_name()
  M.loot_threshold( 2 )
  M.mock_loot_frame()
end

function M.modules()
  require( "src/modules" )
  ---@diagnostic disable-next-line: undefined-global
  return RollFor
end

function M.mock_slashcmdlist()
  M.modules().api.SlashCmdList = m_slashcmdlist
end

function M.get_messages()
  return m_messages
end

function M.mock( funcName, result )
  if type( result ) == "function" then
    M.modules().api[ funcName ] = result
  else
    M.modules().api[ funcName ] = function() return result end
  end
end

function M.mock_object( name, result )
  M.modules().api[ name ] = result
end

function M.run_command( command, args )
  local f = m_slashcmdlist[ command ]

  if f then
    if not lua50 then
      arg = {
        n = 1,
        [ 1 ] = args
      }
    end

    f( args )

    if not lua50 then
      ---@diagnostic disable-next-line: assign-type-mismatch
      arg = nil
    end
  else
    M.debugln( string.format( "No callback provided for command: ", command ) )
  end
end

function M.roll_for( item_name, count, item_id )
  M.run_command( "RF", string.format( "%s%s", count and string.format( "%sx", count ) or "", M.item_link( item_name, item_id ) ) )
  m_rolling_item_name = item_name
end

function M.roll_for_raw( raw_text )
  M.run_command( "RF", raw_text )
end

function M.raid_roll( item_name, item_id, count )
  local link = M.item_link( item_name, item_id )
  M.run_command( "RR", count and count > 1 and string.format( "%sx%s", count, link ) or link )
end

function M.raid_roll_raw( raw_text )
  M.run_command( "RR", raw_text )
end

function M.insta_raid_roll( item_name, item_id, count )
  local link = M.item_link( item_name, item_id )
  M.run_command( "IRR", count and count > 1 and string.format( "%sx%s", count, link ) or link )
end

function M.insta_raid_roll_raw( raw_text )
  M.run_command( "IRR", raw_text )
end

function M.cancel_rolling()
  M.run_command( "CR" )
end

function M.finish_rolling()
  M.run_command( "FR" )
end

function M.fire_event( name, ... )
  if not m_event_callback then
    print( "No event callback!" )
    return
  end

  if lua50 then
    ---@diagnostic disable-next-line: lowercase-global
    event = name
    ---@diagnostic disable-next-line: lowercase-global
    arg1, arg2, arg3, arg4, arg5 = unpack( { ... } )
  end

  m_event_callback( nil, name, ... )

  if lua50 then
    ---@diagnostic disable-next-line: lowercase-global
    event = nil
    ---@diagnostic disable-next-line: lowercase-global
    arg1, arg2, arg3, arg4, arg5 = nil, nil, nil, nil, nil
  end
end

function M.roll( player_name, roll, lower_bound, upper_bound )
  M.fire_event(
    "CHAT_MSG_SYSTEM",
    string.format( "%s rolls %d (%s-%d)", player_name, roll, upper_bound and lower_bound or 1, not upper_bound and lower_bound or upper_bound or 100 )
  )
end

function M.roll_os( player_name, roll )
  M.fire_event( "CHAT_MSG_SYSTEM", string.format( "%s rolls %d (1-99)", player_name, roll ) )
end

function M.mock_random_roll( player_name, roll, upper_bound, f )
  M.mock( "RandomRoll", function()
    if f and type( f ) == "function" then f( player_name, roll, 1, upper_bound ) else M.roll( player_name, roll, 1, upper_bound ) end
  end )
  M.mock( "GetMasterLootCandidate", function() return {} end )
end

function M.mock_multiple_random_roll( values )
  local invocation_count = 0

  M.mock( "RandomRoll", function()
    invocation_count = invocation_count + 1
    local value = values[ invocation_count ]

    local f = value[ 4 ]

    if f and type( f ) == "function" then
      f( value[ 1 ], value[ 2 ], 1, value[ 3 ] )
    else
      M.roll( value[ 1 ], value[ 2 ], value[ 3 ] )
    end
  end )

  M.mock( "GetMasterLootCandidate", function() return {} end )
end

function M.init()
  M.mock_api()
  M.fire_login_events()
  M.import_soft_res( nil )
  m_is_master_looter = false
end

function M.fire_login_events()
  M.fire_event( "PLAYER_LOGIN" )
  M.fire_event( "PLAYER_ENTERING_WORLD" )
end

function M.raid_leader( name )
  return function() return name, 1, nil, nil, "Warrior", nil, nil, nil, nil, nil, m_is_master_looter end
end

function M.raid_member( name )
  return function() return name, 0, nil, nil, "Warrior" end
end

function M.mock_table_function( name, values )
  M.modules().api[ name ] = function( key )
    local value = values[ key ]

    if type( value ) == "function" then
      return value()
    else
      return value
    end
  end
end

---@param name string
---@param id number?
function M.item_link( name, id )
  return string.format( "|cff9d9d9d|Hitem:%s::::::::20:257::::::|h[%s]|h|r", id or "3299", name )
end

function M.dump( o )
  if not o then return "nil" end
  if type( o ) ~= 'table' then return tostring( o ) end

  local entries = 0
  local s = "{"

  for k, v in pairs( o ) do
    if (entries == 0) then s = s .. " " end

    local key = type( k ) ~= "number" and '"' .. k .. '"' or k

    if (entries > 0) then s = s .. ", " end

    s = s .. "[" .. key .. "] = " .. M.dump( v )
    entries = entries + 1
  end

  if (entries > 0) then s = s .. " " end
  return s .. "}"
end

function M.pdump( o )
  print( M.dump( o ) )
end

function M.flatten( target, source )
  if type( target ) ~= "table" then return end

  for i = 1, #source do
    local value = source[ i ]

    if type( value ) == "function" then
      local args = { value() }
      M.flatten( target, args )
    else
      table.insert( target, value )
    end
  end
end

function M.is_in_party( ... )
  local players = { ... }
  M.mock( "IsInGroup", true )
  M.mock( "IsInRaid", false )

  if #players > 1 then
    local party = {
      [ "player" ] = players[ 1 ]
    }

    for i = 2, #players do
      party[ "party" .. i - 1 ] = players[ i ]
    end

    M.mock_table_function( "UnitName", party )
  end

  M.mock_table_function( "GetRaidRosterInfo", players )
  M.fire_event( "GROUP_ROSTER_UPDATE" )
end

function M.add_normal_raider_ranks( players )
  local result = {}

  for i = 1, #players do
    local value = players[ i ]

    if type( value ) == "string" then
      table.insert( result, M.raid_member( value ) )
    else
      table.insert( result, value )
    end
  end

  return result
end

function M.is_in_raid( ... )
  local players = M.add_normal_raider_ranks( { ... } )
  M.mock( "IsInGroup", true )
  M.mock( "IsInRaid", true )
  M.mock_table_function( "GetRaidRosterInfo", players )
  M.mock_table_function( "GetMasterLootCandidate", players )
  M.fire_event( "GROUP_ROSTER_UPDATE" )
end

M.LootQuality = {
  Poor = 0,
  Common = 1,
  Uncommon = 2,
  Rare = 3,
  Epic = 4,
  Legendary = 5
}

function M.loot_threshold( threshold )
  M.mock( "GetLootThreshold", threshold )
end

function M.zone_name( zone )
  M.mock( "GetRealZoneText", zone or "Elwynn Forest" )
end

function M.mock_blizzard_loot_buttons()
  for i = 1, M.modules().api.LOOTFRAME_NUMBUTTONS do
    local name = "LootButton" .. i
    M.mock_object( name, {
      GetName = function() return name end,
      GetScript = function() end,
      SetScript = function( self, event, callback )
        if event == "OnClick" then
          ---@diagnostic disable-next-line: lowercase-global
          this = self
          self.OnClickCallback = callback
          ---@diagnostic disable-next-line: lowercase-global
          this = nil
        end
      end,
      Click = function( self )
        if self.OnClickCallback then
          self:OnClickCallback()
        else
          M.debugln( string.format( "No OnClick callback provided for button: ", name ) )
        end
      end
    } )
  end

  M.mock( "GetLootSlotType", function() return 1 end )
end

function M.mock_unit_name()
  M.mock_table_function( "UnitName", { [ "player" ] = m_player_name, [ "target" ] = m_target } )
end

function M.mock_shift_key_pressed( value )
  M.mock( "IsShiftKeyDown", function() return value end )
end

function M.mock_alt_key_pressed( value )
  M.mock( "IsAltKeyDown", function() return value end )
end

function M.mock_control_key_pressed( value )
  M.mock( "IsControlKeyDown", function() return value end )
end

function M.load_roll_for()
  return require( "main" )
end

function M.force_require( name )
  package.loaded[ name ] = nil
  return require( name )
end

function M.multi_require_src( ... )
  local modules = { ... }

  for _, module in ipairs( modules ) do
    require( string.format( "src/%s", module ) )
  end
end

function M.mock_loot_frame()
  M.mock_object( "LootFrame", {
    GetFrameLevel = function() return 10 end,
    UnregisterAllEvents = function() end,
  } )
end

function M.player( name, config )
  if config then
    RollFor.Config = config
  else
    M.force_require( "src/Config" )
  end

  M.init()
  m_player_name = name
  m_target = nil
  M.mock_unit_name()
  M.mock( "IsInGroup", false )
  M.mock( "GetMasterLootCandidate", nil )
  M.mock_loot_frame()
  local rf = M.load_roll_for()
  M.fire_event( "PLAYER_ENTERING_WORLD" )

  -- TODO: Maybe awarded loot shouldn't be accessible.
  rf.awarded_loot.clear()
end

function M.master_looter( name, config )
  M.player( name, config )
  M.mock( "GetLootMethod", function() return "master", 0 end )
  m_is_master_looter = true
end

function M.rolling_not_in_progress()
  return M.console_message( "RollFor: Rolling not in progress." )
end

-- Return console message first then its equivalent raid message.
-- This returns a function, we check for that later to do the magic.
function M.console_and_raid_message( message )
  return function()
    return M.console_message( string.format( "RollFor: %s", message ) ), M.raid_message( message )
  end
end

-- Return console message first then its equivalent raid warning message.
-- This returns a function, we check for that later to do the magic.
function M.console_and_raid_warning( message )
  return function()
    return M.console_message( string.format( "RollFor: %s", message ) ), M.raid_warning( message )
  end
end

function M.tick()
  if not m_tick_fn then
    M.debug( "Tick function not set." )
    return
  end

  m_tick_fn()
  m_tick_fn = nil
end

function M.repeating_tick( times )
  if not m_repeating_tick_fn then
    M.debug( "Repeating tick function not set." )
    return
  end

  local count = times or 1

  for _ = 1, count do
    m_repeating_tick_fn()
  end
end

function M.mock_ace_timer()
  ---@type AceTimer
  return {
    ScheduleTimer = function( _, f )
      m_tick_fn = f
      return 1337
    end,
    ScheduleRepeatingTimer = function( _, f )
      m_repeating_tick_fn = f
      return 2
    end,
    CancelTimer = function( _, timer_id )
      if timer_id == 1 then m_tick_fn = nil end
      if timer_id == 2 then m_repeating_tick_fn = nil end
    end
  }
end

function M.mock_libraries()
  m_tick_fn = nil
  m_repeating_tick_fn = nil
  M.mock_wow_api()
  M.mock_library( "AceTimer-3.0", M.mock_ace_timer() )
end

---@alias ModuleRegistryEntry { module_name: string, variable_name: string, mock: (string|function)? }
---@alias ModuleRegistry ModuleRegistryEntry[]

---@param module_registry ModuleRegistry
---@param target_table table
function M.load_real_stuff_and_inject( module_registry, target_table )
  local wrapper = require( "mocks/ModuleWrapper" )

  M.load_real_stuff( function( module_name )
    for _, entry in ipairs( module_registry ) do
      local location = string.format( "src/%s", entry.module_name )

      if module_name == location then
        local module = entry.mock and type( entry.mock ) == "string" and require( entry.mock --[[@as string]] ) or
            entry.mock and type( entry.mock ) == "function" and entry.mock() or
            require( module_name )

        if type( module ) == "function" then
          error( module_name )
        end

        local result = wrapper.new( module, function( instance ) if entry.variable_name then target_table[ entry.variable_name ] = instance end end )
        RollFor[ entry.module_name ] = result
        target_table[ entry.module_name ] = module
        return result
      end
    end

    return require( module_name )
  end )
end

function M.load_real_stuff( req )
  local r = req or require

  load_libstub()
  r( "src/bcc/compat" )
  r( "src/modules" )
  M.mock_api()
  r( "src/DebugBuffer" )
  r( "src/Module" )
  r( "src/Db" )
  r( "src/Types" )
  r( "src/Interface" )
  r( "src/ItemUtils" )
  r( "src/LootFacade" )
  r( "src/EventFrame" )
  r( "src/WowApi" )
  r( "src/PlayerInfo" )
  r( "src/EventBus" )
  r( "src/ChatApi" )
  r( "src/Chat" )
  r( "src/Config" )
  r( "src/RollingLogicUtils" )
  r( "src/DroppedLoot" )
  r( "src/DroppedLootAnnounce" )
  r( "src/TradeTracker" )
  r( "src/SoftResDataTransformer" )
  r( "src/SoftRes" )
  r( "src/SoftResGui" )
  r( "src/AwardedLoot" )
  r( "src/SoftResAwardedLootDecorator" )
  r( "src/SoftResPresentPlayersDecorator" )
  r( "src/SoftResAbsentPlayersDecorator" )
  r( "src/SoftResMatchedNameDecorator" )
  r( "src/GroupRoster" )
  r( "src/NameAutoMatcher" )
  r( "src/NameManualMatcher" )
  r( "src/NameMatchReport" )
  r( "src/EventHandler" )
  r( "src/VersionBroadcast" )
  r( "src/LootAwardCallback" )
  r( "src/MasterLoot" )
  r( "src/SoftResCheck" )
  r( "src/NonSoftResRollingLogic" )
  r( "src/SoftResRollingLogic" )
  r( "src/TieRollingLogic" )
  r( "src/RaidRollRollingLogic" )
  r( "src/MasterLootCandidateSelectionFrame" )
  r( "src/UsagePrinter" )
  r( "src/MinimapButton" )
  r( "src/MasterLootWarning" )
  r( "src/AutoLoot" )
  r( "src/WinnerTracker" )
  r( "src/LootAwardPopup" )
  r( "src/MasterLootCandidates" )
  r( "src/NewGroupEvent" )
  r( "src/BossList" )
  r( "src/AutoGroupLoot" )
  r( "src/AutoMasterLoot" )
  r( "src/FrameBuilder" )
  r( "src/PopupBuilder" )
  r( "src/RollTracker" )
  r( "src/LootController" )
  r( "src/RollController" )
  r( "src/RollingPopup" )
  r( "src/WinnersPopup" )
  r( "src/TieRollGuiData" )
  r( "src/SoftResRollGuiData" )
  r( "src/RollingPopupContentTransformer" )
  r( "src/WelcomePopup" )
  r( "src/InstaRaidRollRollingLogic" )
  r( "src/LootList" )
  r( "src/SoftResLootListDecorator" )
  r( "src/LootFrame" )
  r( "src/RollForAd" )
  r( "src/LootAutoProcess" )
  r( "src/RollingStrategyFactory" )
  r( "src/RollingLogic" )
  r( "src/ArgsParser" )
  r( "src/RollResultAnnouncer" )
  r( "src/LootFacadeListener" )
  r( "src/TooltipReader" )
  r( "src/UiReloadPopup" )
  r( "src/Sandbox" )
  r( "src/GuiElements" )
  r( "src/ModernLootFrameSkin" )
  r( "src/OgLootFrameSkin" )
  -- r( "Libs/LibDeflate/LibDeflate" )
  r( "src/bcc/Json" )
  r( "main" )
end

function M.rolling_finished()
  return M.console_message( string.format( "RollFor: Rolling for [%s] finished.", m_rolling_item_name ) )
end

function M.item( name, id, quality, bind_type )
  return { name = name, id = id, source_id = 123, quality = quality or 4, link = M.item_link( name, id ), bind = bind_type }
end

function M.targetting_enemy( name )
  m_target = name
  M.mock_unit_name()
  M.mock( "UnitIsFriend", false )
end

function M.targetting_player( name )
  m_target = name
  M.mock_unit_name()
  M.mock( "UnitIsFriend", true )
end

function M.import_soft_res( data )
  local rf = M.load_roll_for()
  rf.import_softres_data( data )

  return rf
end

local function find_soft_res_entry( softreserves, player )
  for i = 1, #softreserves do
    if softreserves[ i ].name == player then
      return softreserves[ i ]
    end
  end

  return nil
end

function M.create_softres_data( ... )
  local items = { ... }
  local hardreserves = {}
  local softreserves = {}

  for i = 1, #items do
    local item = items[ i ]

    if item.soft_res then
      local entry = find_soft_res_entry( softreserves, item.player ) or {}

      if not entry.name then
        table.insert( softreserves, entry )
      end

      entry.name = item.player
      entry.items = entry.items or {}
      table.insert( entry.items, { id = item.item_id, quality = item.quality, sr_plus = item.sr_plus } )
    else
      table.insert( hardreserves, { id = item.item_id, quality = item.quality } )
    end
  end

  local data = {
    metadata = {
      id = 123
    },
    hardreserves = hardreserves,
    softreserves = softreserves
  }

  return data
end

function M.soft_res( ... )
  return M.import_soft_res( M.create_softres_data( ... ) )
end

function M.soft_res_item( player, item_id, quality, sr_plus )
  return { soft_res = true, player = player, item_id = item_id, quality = quality or 4, sr_plus = sr_plus }
end

function M.hard_res_item( item_id, quality )
  return { soft_res = false, item_id = item_id, quality = quality or 4 }
end

function M.award( player_name, item_name, item_id )
  local rf = M.load_roll_for()
  rf.loot_award_callback.on_loot_awarded( item_id, M.item_link( item_name, item_id ), player_name )
end

function M.load_libstub()
  error( "fuck", 2 )
  return load_libstub()
end

function M.trade_with( recipient, trade_tracker )
  M.mock_object( "TradeFrameRecipientNameText", { GetText = function() return recipient end } )
  M.mock_table_function( "GetTradePlayerItemInfo", { [ "1" ] = nil } )
  M.mock_table_function( "GetTradePlayerItemLink", { [ "1" ] = nil } )

  if trade_tracker then
    trade_tracker.on_trade_show()
  else
    M.fire_event( "TRADE_SHOW" )
  end
end

function M.cancel_trade( trade_tracker )
  if trade_tracker then
    trade_tracker.on_trade_accept_update( 0 )
    trade_tracker.on_trade_closed()
  else
    M.fire_event( "TRADE_ACCEPT_UPDATE", 0 )
    M.fire_event( "TRADE_CLOSED" )
  end
end

function M.trade_cancelled_by_recipient( trade_tracker )
  if trade_tracker then
    trade_tracker.on_trade_request_cancel()
  else
    M.fire_event( "TRADE_REQUEST_CANCEL" )
    M.fire_event( "TRADE_CLOSED" )
  end
end

function M.trade_complete( trade_tracker )
  if trade_tracker then
    trade_tracker.on_trade_accept_update( 1, 1 )
    trade_tracker.on_trade_closed()
  else
    M.fire_event( "TRADE_ACCEPT_UPDATE", 1, 1 )
    M.fire_event( "TRADE_CLOSED" )
  end
end

function M.map( t, f )
  if type( f ) ~= "function" then return t end
  local result = {}

  for _, v in pairs( t ) do
    local value = f( v )
    table.insert( result, value )
  end

  return result
end

function M.trade_items( trade_tracker, ... )
  local items = { ... }
  M.mock_table_function( "GetTradePlayerItemInfo", M.map( items, function( v ) return function() return _, _, v.quantity end end ) )
  M.mock_table_function( "GetTradePlayerItemLink", M.map( items, function( v ) return function() return v.item_link end end ) )

  for i = 1, #items do
    if trade_tracker then
      trade_tracker.on_trade_player_item_changed( i )
    else
      M.fire_event( "TRADE_PLAYER_ITEM_CHANGED", i )
    end
  end
end

function M.recipient_trades_items( trade_tracker, ... )
  local items = { ... }
  M.mock_table_function( "GetTradeTargetItemInfo", M.map( items, function( v ) return function() return _, _, v.quantity end end ) )
  M.mock_table_function( "GetTradeTargetItemLink", M.map( items, function( v ) return function() return v.item_link end end ) )

  for i = 1, #items do
    if trade_tracker then
      trade_tracker.on_trade_target_item_changed( i )
    else
      M.fire_event( "TRADE_TARGET_ITEM_CHANGED", i )
    end
  end
end

-- local function get_player_frame_from_master_looter_frame( player_name )
--   for i = 1, 40 do
--     local button = _G[ "RollForLootFrameButton" .. i ]
--
--     if button and button.player and button.player.name == player_name then
--       return button
--     end
--   end
-- end
--
function M.master_loot( item_link )
  M.mock( "IsModifiedClick", false )
  M.mock( "CloseDropDownMenus", function() end )
  M.mock( "GetLootSlotLink", function() return item_link end )
  M.mock_object( "LootFrame", {} )
  -- local player_frame = get_player_frame_from_master_looter_frame( player_name )
  -- player_frame:Click()
end

function M.mock_softres_gui()
end

function M.confirm_master_looting( loot_event_facade, player, item_link )
  M.mock( "GiveMasterLoot", function() end )
  if m_loot_confirm_callback then m_loot_confirm_callback( player, item_link ) end
  loot_event_facade.notify( "LootSlotCleared", 1 )
end

function M.cancel_master_looting()
  M.modules().api.StaticPopup1Button2.fire_event( "OnClick" )
end

function M.clear_dropped_items_db()
  local rollfor = M.load_roll_for()
  rollfor.db.dropped_items = {}

  return rollfor
end

function M.read_file( file_name )
  local file = io.open( file_name, "r" )
  if not file then return nil end

  local content = file:read( "*a" )
  file:close()

  return content
end

function M.import_softres_via_gui( fixture_name )
  local sr_data = M.read_file( fixture_name )
  local sr_frame = _G[ "RollForSoftResLootFrame" ]
  sr_frame.editbox:SetText( sr_data )
  sr_frame.import_button.OnClickCallback()
end

function M.register_loot_confirm_callback( callback )
  m_loot_confirm_callback = callback
end

function M.modifier_keys_not_pressed()
  M.mock_shift_key_pressed( false )
  M.mock_alt_key_pressed( false )
  M.mock_control_key_pressed( false )
end

function M.modifier_key( keys )
  if not keys then
    M.modifier_keys_not_pressed()
    return
  end

  if keys.alt then
    M.mock_alt_key_pressed( true )
  end

  if keys.control then
    M.mock_control_key_pressed( true )
  end

  if keys.shift then
    M.mock_shift_key_pressed( true )
  end
end

function M.mock_math_random( expected_min, expected_max, value )
  M.modules().lua.math.random = function( given_min, given_max )
    if given_min ~= expected_min or given_max ~= expected_max then
      print(
        string.format(
          "Invalid math.random invocation. Expected: random(%s, %s)  Was: random(%s, %s)",
          expected_min,
          expected_max,
          given_min,
          given_max
        )
      )

      return 1337
    end

    return value
  end
end

function M.mock_multiple_math_random( values )
  local invocation_count = 0

  M.modules().lua.math.random = function( was_min, was_max )
    invocation_count = invocation_count + 1
    local expected_min = values[ invocation_count ][ 1 ]
    local expected_max = values[ invocation_count ][ 2 ]
    local value = values[ invocation_count ][ 3 ]

    if was_min ~= expected_min or was_max ~= expected_max then
      print(
        string.format(
          "Invalid math.random invocation. Was: random(%s, %s)  Expected: random(%s, %s)",
          was_min,
          was_max,
          expected_min,
          expected_max
        )
      )

      return 1337
    end

    return value
  end
end

function M.luaunit( ... )
  local result = {}
  local lu = require( "luaunit" )

  for _, name in ipairs( { ... } ) do
    table.insert( result, lu[ name ] )
  end

  return lu, table.unpack( result )
end

function M.mock_values( values )
  if type( values ) ~= "table" then error( "Argument is not a table. Use mock_value instead.", 2 ) end
  local invocation_count = 0

  return function()
    invocation_count = invocation_count + 1

    if invocation_count > #values then
      return nil
    end

    return values[ invocation_count ]
  end
end

function M.mock_value( v1, v2, v3, v4, v5, v6, v7, v8, v9 )
  local invocation_count = 0
  local values = { v1, v2, v3, v4, v5, v6, v7, v8, v9 }

  return function()
    invocation_count = invocation_count + 1

    if invocation_count > #values then
      return nil
    end

    return values[ invocation_count ]
  end
end

function M.info( message )
  print( "\n" .. message )
end

function M.noop() end

function M.clone( t )
  local result = {}

  if not t then return result end

  for k, v in pairs( t ) do
    result[ k ] = v
  end

  return result
end

function M.table_contains_value( t, value, f )
  if not t then return false end

  for _, v in pairs( t ) do
    local val = type( f ) == "function" and f( v ) or v
    if val == value then return true end
  end

  return false
end

return M
