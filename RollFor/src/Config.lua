---@diagnostic disable-next-line: undefined-global
local modules = LibStub( "RollFor-Modules" )
if modules.Config then return end

local m = modules
local info = m.pretty_print
local print_header = m.print_header
local hl = m.colors.hl
local blue = m.colors.blue
local grey = m.colors.grey
local RollType = m.Types.RollType

local M = {}

function M.new( db )
  local callbacks = {}
  local toggles = {
    [ "auto_loot" ] = { cmd = "auto-loot", display = "Auto-loot", help = "toggle auto-loot", hidden = true },
    [ "show_ml_warning" ] = { cmd = "ml", display = "Master loot warning", help = "toggle master loot warning" },
    [ "auto_raid_roll" ] = { cmd = "auto-rr", display = "Auto raid-roll", help = "toggle auto raid-roll" },
    [ "auto_group_loot" ] = { cmd = "auto-group-loot", display = "Auto group loot", help = "toggle auto group loot" },
    [ "auto_master_loot" ] = { cmd = "auto-master-loot", display = "Auto master loot", help = "toggle auto master loot" },
    [ "rolling_tip" ] = { cmd = "rolling-tip", display = "Rolling tip", help = "toggle rolling tip window" },
    [ "rolling_popup_lock" ] = { cmd = "rolling-popup-lock", display = "Rolling popup lock", help = "toggle rolling popup lock" },
    [ "raid_roll_again" ] = { cmd = "raid-roll-again", display = string.format( "%s button", hl( "Raid roll again" ) ), help = string.format( "toggle %s button", hl( "Raid roll again" ) ) },
    [ "rolling_popup" ] = { cmd = "rolling-popup", display = "Rolling popup", help = "toggle rolling popup" },
    [ "insta_raid_roll" ] = { cmd = "insta-rr", display = "Insta raid-roll", help = "toggle insta raid-roll" },
  }

  local function notify_subscribers( event, value )
    if not callbacks[ event ] then return end

    for _, callback in ipairs( callbacks[ event ] ) do
      callback( value )
    end
  end

  local function init()
    if not db.ms_roll_threshold then db.ms_roll_threshold = 100 end
    if not db.os_roll_threshold then db.os_roll_threshold = 99 end
    if not db.tmog_roll_threshold then db.tmog_roll_threshold = 98 end
    if db.tmog_rolling_enabled == nil then db.tmog_rolling_enabled = true end
    if db.rolling_tip == nil then db.rolling_tip = true end
    if db.rolling_popup == nil then db.rolling_popup = true end
    if db.show_ml_warning == nil then db.show_ml_warning = true end
    if db.default_rolling_time_seconds == nil then db.default_rolling_time_seconds = 8 end
  end

  local function print( toggle_key )
    local toggle = toggles[ toggle_key ]
    if not toggle then return end

    local value = toggle.negate and not db[ toggle_key ] or db[ toggle_key ]
    info( string.format( "%s is %s.", toggles[ toggle_key ].display, value and m.msg.enabled or m.msg.disabled ) )
    notify_subscribers( toggle_key, value )
  end

  local function toggle( toggle_key )
    return function()
      if db[ toggle_key ] then
        db[ toggle_key ] = false
      else
        db[ toggle_key ] = true
      end

      print( toggle_key )
    end
  end

  local function reset_rolling_popup()
    info( "Rolling popup position has been reset." )
    notify_subscribers( "reset_rolling_popup" )
  end

  local function print_roll_thresholds()
    local ms_threshold = db.ms_roll_threshold
    local os_threshold = db.os_roll_threshold
    local tmog_threshold = db.tmog_roll_threshold
    local tmog_info = string.format( ", %s %s", hl( "TMOG" ), tmog_threshold ) or ""

    info( string.format( "Roll thresholds: %s %s, %s %s%s", hl( "MS" ), ms_threshold, hl( "OS" ), os_threshold, tmog_info ) )
  end

  local function print_transmog_rolling_setting( show_threshold )
    local tmog_rolling_enabled = db.tmog_rolling_enabled
    local threshold = show_threshold and tmog_rolling_enabled and string.format( " (%s)", hl( db.tmog_roll_threshold ) ) or ""
    info( string.format( "Transmog rolling is %s%s.", tmog_rolling_enabled and m.msg.enabled or m.msg.disabled, threshold ) )
  end

  local function print_pfui_integration_setting()
    if not m.uses_pfui() then return end
    info( string.format( "%s integration is %s.", m.msg.pfui, db.pfui_integration_enabled and m.msg.enabled or m.msg.disabled ) )
  end

  local function print_default_rolling_time()
    info( string.format( "Default rolling time: %s seconds", hl( db.default_rolling_time_seconds ) ) )
  end

  local function print_settings()
    print_header( "RollFor Configuration" )
    print_default_rolling_time()
    print_roll_thresholds()
    print_transmog_rolling_setting()
    print_pfui_integration_setting()

    for toggle_key, setting in pairs( toggles ) do
      if not setting.hidden then
        print( toggle_key )
      end
    end

    m.print( string.format( "For more info, type: %s", hl( "/rf config help" ) ) )
  end

  local function configure_default_rolling_time( args )
    if args == "config default-rolling-time" then
      print_default_rolling_time()
      return
    end

    for value in string.gmatch( args, "config default%-rolling%-time (%d+)" ) do
      local v = tonumber( value )

      if v < 4 then
        info( string.format( "Default rolling time must be at least %s seconds.", hl( "4" ) ) )
        return
      end

      if v > 15 then
        info( string.format( "Default rolling time must be at most %s seconds.", hl( "15" ) ) )
        return
      end

      db.default_rolling_time_seconds = v
      print_default_rolling_time()
      return
    end

    info( string.format( "Usage: %s <threshold>", hl( "/rf config ms" ) ) )
  end

  local function configure_ms_threshold( args )
    for value in string.gmatch( args, "config ms (%d+)" ) do
      db.ms_roll_threshold = tonumber( value )
      print_roll_thresholds()
      return
    end

    info( string.format( "Usage: %s <threshold>", hl( "/rf config ms" ) ) )
  end

  local function configure_os_threshold( args )
    for value in string.gmatch( args, "config os (%d+)" ) do
      db.os_roll_threshold = tonumber( value )
      print_roll_thresholds()
      return
    end

    info( string.format( "Usage: %s <threshold>", hl( "/rf config os" ) ) )
  end

  local function configure_tmog_threshold( args )
    if args == "config tmog" then
      db.tmog_rolling_enabled = not db.tmog_rolling_enabled
      print_transmog_rolling_setting( true )
      return
    end

    for value in string.gmatch( args, "config tmog (%d+)" ) do
      db.tmog_roll_threshold = tonumber( value )
      print_roll_thresholds()
      return
    end

    info( string.format( "Usage: %s <threshold>", hl( "/rf config tmog" ) ) )
  end

  local function print_help()
    local v = function( name ) return string.format( "%s%s%s", hl( "<" ), grey( name ), hl( ">" ) ) end
    local function rfc( cmd ) return string.format( "%s%s", blue( "/rf config" ), cmd and string.format( " %s", hl( cmd ) ) or "" ) end

    print_header( "RollFor Configuration Help" )
    m.print( string.format( "%s - show configuration", rfc() ) )
    m.print( string.format( "%s - toggle minimap icon", rfc( "minimap" ) ) )
    m.print( string.format( "%s - lock/unlock minimap icon", rfc( "minimap lock" ) ) )
    m.print( string.format( "%s - show default rolling time", rfc( "default-rolling-time" ) ) )
    m.print( string.format( "%s %s - set default rolling time", rfc( "default-rolling-time" ), v( "seconds" ) ) )
    m.print( string.format( "%s - show MS rolling threshold ", rfc( "ms" ) ) )
    m.print( string.format( "%s %s - set MS rolling threshold ", rfc( "ms" ), v( "threshold" ) ) )
    m.print( string.format( "%s - show OS rolling threshold ", rfc( "os" ) ) )
    m.print( string.format( "%s %s - set OS rolling threshold ", rfc( "os" ), v( "threshold" ) ) )
    m.print( string.format( "%s - toggle TMOG rolling", rfc( "tmog" ) ) )
    m.print( string.format( "%s %s - set TMOG rolling threshold", rfc( "tmog" ), v( "threshold" ) ) )

    if m.uses_pfui() then
      m.print( string.format( "%s - toggle %s integration", rfc( "pfui" ), m.msg.pfui ) )
    end

    for _, setting in pairs( toggles ) do
      if not setting.hidden then
        m.print( string.format( "%s - %s", rfc( setting.cmd ), setting.help ) )
      end
    end

    m.print( string.format( "%s - reset rolling popup position", rfc( "reset-rolling-popup" ) ) )
  end

  local function toggle_pfui_integration()
    if db.pfui_integration_enabled then
      db.pfui_integration_enabled = false
    else
      db.pfui_integration_enabled = true
    end

    print_pfui_integration_setting()
  end

  local function enable_pfui_integration()
    db.pfui_integration_enabled = true
    db.pfui_integration_info_showed = true
  end

  local function disable_pfui_integration()
    db.pfui_integration_enabled = false
    db.pfui_integration_info_showed = true
  end

  local function lock_minimap_button()
    db.minimap_button_locked = true
    info( string.format( "Minimap button is %s.", m.msg.locked ) )
    notify_subscribers( "minimap_button_locked", true )
  end

  local function unlock_minimap_button()
    db.minimap_button_locked = false
    info( string.format( "Minimap button is %s.", m.msg.unlocked ) )
    notify_subscribers( "minimap_button_locked", false )
  end

  local function hide_minimap_button()
    db.minimap_button_hidden = true
    notify_subscribers( "minimap_button_hidden", true )
  end

  local function show_minimap_button()
    db.minimap_button_hidden = false
    notify_subscribers( "minimap_button_hidden", false )
  end

  local function on_command( args )
    if args == "config" then
      print_settings()
      return
    end

    if args == "config help" then
      print_help()
      return
    end

    for toggle_key, setting in pairs( toggles ) do
      if args == string.format( "config %s", setting.cmd ) then
        toggle( toggle_key )()
        return
      end
    end

    if args == "config reset-rolling-popup" then
      reset_rolling_popup()
      return
    end

    if args == "config minimap" then
      if db.minimap_button_hidden then
        show_minimap_button()
      else
        hide_minimap_button()
      end

      return
    end

    if args == "config minimap lock" then
      if db.minimap_button_locked then
        unlock_minimap_button()
      else
        lock_minimap_button()
      end

      return
    end

    if string.find( args, "^config ms" ) then
      configure_ms_threshold( args )
      return
    end

    if string.find( args, "^config os" ) then
      configure_os_threshold( args )
      return
    end

    if string.find( args, "^config tmog" ) then
      configure_tmog_threshold( args )
      return
    end

    if args == "config pfui" and m.uses_pfui() then
      toggle_pfui_integration()
      return
    end

    if string.find( args, "^config default%-rolling%-time" ) then
      configure_default_rolling_time( args )
      return
    end

    print_help()
  end

  local function subscribe( event, callback )
    callbacks[ event ] = callbacks[ event ] or {}
    table.insert( callbacks[ event ], callback )
  end

  local function roll_threshold( roll_type )
    local threshold = (roll_type == RollType.MainSpec or roll_type == RollType.SoftRes) and db.ms_roll_threshold or
        roll_type == RollType.OffSpec and db.os_roll_threshold or
        db.tmog_roll_threshold
    local threshold_str = string.format( "/roll%s", threshold == 100 and "" or string.format( " %s", threshold ) )

    return {
      value = threshold,
      str = threshold_str
    }
  end

  init()

  local function get( setting_key ) return function() return db[ setting_key ] end end
  local function printfn( setting_key ) return function() print( setting_key ) end end

  local config = {
    configure_ms_threshold = configure_ms_threshold,
    configure_os_threshold = configure_os_threshold,
    configure_tmog_threshold = configure_tmog_threshold,
    disable_pfui_integration = disable_pfui_integration,
    enable_pfui_integration = enable_pfui_integration,
    hide_minimap_button = hide_minimap_button,
    lock_minimap_button = lock_minimap_button,
    minimap_button_hidden = get( "minimap_button_hidden" ),
    minimap_button_locked = get( "minimap_button_locked" ),
    ms_roll_threshold = get( "ms_roll_threshold" ),
    on_command = on_command,
    os_roll_threshold = get( "os_roll_threshold" ),
    pf_integration_info_showed = get( "pfui_integration_info_showed" ),
    pfui_integration_enabled = get( "pfui_integration_enabled" ),
    print = print,
    print_help = print_help,
    print_raid_roll_settings = printfn( "auto_raid_roll" ),
    reset_rolling_popup = reset_rolling_popup,
    roll_threshold = roll_threshold,
    show_minimap_button = show_minimap_button,
    show_rolling_tip = get( "rolling_tip" ),
    subscribe = subscribe,
    tmog_roll_threshold = get( "tmog_roll_threshold" ),
    tmog_rolling_enabled = get( "tmog_rolling_enabled" ),
    toggle_pfui_integration = toggle( "pfui_integration_enabled" ),
    unlock_minimap_button = unlock_minimap_button,
    default_rolling_time_seconds = get( "default_rolling_time_seconds" ),
  }

  for toggle_key, _ in pairs( toggles ) do
    config[ toggle_key ] = get( toggle_key )
    config[ "toggle_" .. toggle_key ] = toggle( toggle_key )
  end

  return config
end

modules.Config = M
return M
