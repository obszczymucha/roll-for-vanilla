RollFor = RollFor or {}
local m = RollFor

if m.BuffScanner then return end

local M = m.Module.new( "BuffScanner" )

local getn = m.getn

local MAX_BUFFS = 40

---@class BuffData
---@field name string
---@field tooltip_data string[]? -- only for buffs the caller asked to read

---@class BuffScanner
---@field get_buffs fun( unit: string, tooltip_buffs: table<string, boolean>? ): BuffData[]

---@param api table
---@param tooltip_reader TooltipReader
---@return BuffScanner
function M.new( api, tooltip_reader )
  -- Auras of group members are already on the client, so this needs no inspect
  -- and no waiting. Names are cheap; reading a tooltip is not, so only the
  -- buffs the caller names get one.
  ---@param unit string
  ---@param tooltip_buffs table<string, boolean>? -- names worth reading a tooltip for
  ---@return BuffData[]
  local function get_buffs( unit, tooltip_buffs )
    local result = {}
    local names = {}

    for i = 1, MAX_BUFFS do
      local name = api.UnitBuff( unit, i )
      if not name then break end

      local buff = { name = name }

      if tooltip_buffs and tooltip_buffs[ name ] then
        buff.tooltip_data = tooltip_reader.get_unit_buff_lines( unit, i )
      end

      table.insert( result, buff )
      table.insert( names, name )
    end

    M.debug.add( string.format( "%s: %s", unit,
      getn( names ) > 0 and table.concat( names, ", " ) or "no buffs" ) )

    return result
  end

  ---@type BuffScanner
  return {
    get_buffs = get_buffs
  }
end

m.BuffScanner = M
return M
