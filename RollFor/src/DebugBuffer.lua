RollFor = RollFor or {}
local m = RollFor

if m.DebugBuffer then return end

local M = {}

local pp = m.pretty_print

---@class DebugBuffer
---@field add fun( message: string )
---@field show fun()
---@field enable fun()
---@field disable fun()
---@field toggle fun()
function M.new( module_name, max_size )
  local messages = {}
  local head = 0
  local count = 0
  local debug_enabled = false

  local function add( message )
    head = head + 1

    if head > max_size then
      head = 1
    end

    messages[ head ] = message

    if count < max_size then
      count = count + 1
    end

    if debug_enabled then
      pp( message, m.colors.grey, module_name )
    end
  end

  local function show()
    local start = head - count + 1

    if start < 1 then
      start = start + max_size
    end

    for i = 1, count do
      local idx = start + i - 1

      if idx > max_size then
        idx = idx - max_size
      end

      pp( messages[ idx ], m.colors.grey, module_name )
    end
  end

  local function print_debug_status()
    pp( string.format( "Debug %s.", debug_enabled and m.msg.enabled or m.msg.disabled, m.colors.grey, module_name ), m.colors.grey, module_name )
  end

  local function enable()
    debug_enabled = true
    print_debug_status()
  end

  local function disable()
    debug_enabled = false
    print_debug_status()
  end

  local function toggle()
    debug_enabled = not debug_enabled
    print_debug_status()
  end

  return {
    add = add,
    show = show,
    enable = enable,
    disable = disable,
    toggle = toggle
  }
end

m.DebugBuffer = M
return M
