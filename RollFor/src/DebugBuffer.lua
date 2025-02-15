RollFor = RollFor or {}
local m = RollFor

if m.DebugBuffer then return end

local M = {}

M.modules = {}

-- Keeping a global index so we can later reconstruct the order of messages when printing only a subset of modules.
local message_index = 0

local pp = m.pretty_print

---@class DebugMessage
---@field index number
---@field text string

local colors = {
  "ff8080", -- soft pink
  "8aeb9f", -- mint green
  "80b8ff", -- light blue
  "ffb380", -- peach
  "b880ff", -- lavender
  "80ffb3", -- seafoam green
  "ffa680", -- light orange
  "80ffb3", -- pale turquoise
  "b880ff", -- light purple
  "ffb3b3", -- baby pink
  "80e2ff", -- sky blue
  "ffb380", -- cream
  "b3ff80", -- lime cream
  "ff80b3", -- rose pink
  "80ffa6"  -- pale mint
}

---@param text string
local function make_message( text )
  message_index = message_index + 1

  ---@type DebugMessage
  return { index = message_index, text = text }
end

---@class DebugBuffer
---@field add fun( message: string )
---@field show fun()
---@field enable fun( console: boolean )
---@field disable fun()
---@field toggle fun()
function M.new( module_name, max_size )
  local messages = {} ---@type DebugMessage[]
  local head = 0
  local count = 0
  local debug_enabled = false
  local console_enabled = false

  local function add( message )
    head = head + 1

    if head > max_size then
      head = 1
    end

    messages[ head ] = make_message( message )

    if count < max_size then
      count = count + 1
    end

    if debug_enabled then
      if console_enabled then
        print( string.format( "[%s]: %s", module_name, message ) )
      else
        pp( message, m.colors.grey, module_name )
      end
    end
  end

  local function get()
    local result = {}

    local start = head - count + 1

    if start < 1 then
      start = start + max_size
    end

    for i = 1, count do
      local idx = start + i - 1

      if idx > max_size then
        idx = idx - max_size
      end

      table.insert( result, messages[ idx ] )
    end

    return result
  end

  local function show()
    for _, message in ipairs( get() ) do
      pp( message.text, m.colors.grey, message.module_name )
    end
  end

  local function print_debug_status()
    if console_enabled then
      print( string.format( "\n[%s]: Debug %s.", module_name, debug_enabled and "enabled" or "disabled" ) )
    else
      pp( string.format( "Debug %s.", debug_enabled and m.msg.enabled or m.msg.disabled, m.colors.grey, module_name ), m.colors.grey, module_name )
    end
  end

  local function enable( console )
    debug_enabled = true
    console_enabled = console
    print_debug_status()
  end

  local function disable()
    debug_enabled = false
    console_enabled = false
    print_debug_status()
  end

  local function toggle()
    debug_enabled = not debug_enabled
    print_debug_status()
  end

  local result = {
    add = add,
    get = get,
    show = show,
    enable = enable,
    disable = disable,
    toggle = toggle,
    is_enabled = function() return debug_enabled end
  }

  M.modules[ module_name ] = result

  return result
end

M.disable_all = function()
  for _, module in pairs( M.modules ) do
    module.disable()
  end
end

local function get_colors( module_names )
  local result = {}
  local color_count = #colors
  local color_index = math.random( color_count ) - 1

  for _, module_name in ipairs( module_names ) do
    if color_index == color_count then
      color_index = 0
    else
      color_index = color_index + 1
    end

    result[ module_name ] = colors[ color_index ]
  end

  return result
end

---@param module_names string[]
local function show( module_names )
  local c = get_colors( module_names )
  local result = {}

  for _, module_name in ipairs( module_names ) do
    local mod = m[ module_name ]

    if mod and mod.debug then
      local dbg = mod.debug
      local messages = dbg.get() ---@type DebugMessage[]

      for _, message in ipairs( messages ) do
        table.insert( result, { module_name = module_name, index = message.index, text = message.text } )
      end
    end
  end

  table.sort( result, function( a, b ) return a.index < b.index end )

  if #result == 0 then
    pp( "No debug messages.", m.colors.grey )
    return
  end

  local msg = function( tag )
    return string.format(
      "Debug messages %s (%s %s):",
      tag,
      m.colors.blue( "RollFor" ),
      m.colors.hl( "v" .. m.get_addon_version().str )
    )
  end

  pp( msg( "start" ) )

  for _, message in ipairs( result ) do
    pp( message.text, m.colors.grey, m.colorize( c[ message.module_name ], message.module_name ) )
  end

  pp( msg( "end" ) )
end

function M.on_command( args )
  ---@param modules string
  local function parse_module_names( modules )
    local result = {}
    for module_name in string.gmatch( modules, "%S+" ) do
      table.insert( result, module_name )
    end

    return result
  end

  if args == "debug show" then
    show( { "RollController", "LootController" } )
    return
  end

  for command, modules in string.gmatch( args, "debug (.-) (.*)" ) do
    local module_names = parse_module_names( modules )

    if command == "show" then
      show( module_names )
      return
    end

    for _, module_name in ipairs( module_names ) do
      local mod = m[ module_name ]

      if mod and mod.debug then
        local dbg = mod.debug
        local f = dbg[ command ]

        if f then f() end
      end
    end

    return
  end
end

m.DebugBuffer = M
return M
