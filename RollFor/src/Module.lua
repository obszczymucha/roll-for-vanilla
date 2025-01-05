RollFor = RollFor or {}
local m = RollFor

if m.Module then return end

---@class RollForModule
---@field debug DebugBuffer

local M = {}

---@return RollForModule
function M.new( module_name, debug_size )
  ---@type DebugBuffer
  local debug_buffer = m.DebugBuffer.new( module_name, debug_size or 20 )

  return {
    debug = debug_buffer
  }
end

m.Module = M
return M
