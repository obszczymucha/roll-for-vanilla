RollFor = RollFor or {}
local m = RollFor

if m.Sandbox then return end

local M = {}

---@class Sandbox
---@field run fun()

function M.new()
  local function run()
    m.info( "Happy testing!" )
  end

  ---@type Sandbox
  return {
    run = run
  }
end

m.Sandbox = M
return M
