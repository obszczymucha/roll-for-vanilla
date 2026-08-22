RollFor = RollFor or {}
local m = RollFor

if m.GearScanner then return end

local M = m.Module.new( "GearScanner" )

local getn = m.getn

-- Shirt (4) and tabard (19) carry no stats worth reading.
local slots = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

---@alias GearLines table<number, string[]> -- equipment slot to tooltip lines

---@class GearScanner
---@field get_gear_lines fun( unit: string ): GearLines
---@field scan_unit fun( unit: string, callback: fun( gear: GearLines?, error: InspectError? ), on_retry: (fun( unit: string, retry: number ))? )

---@param api table
---@param tooltip_reader TooltipReader
---@param inspector Inspector
---@return GearScanner
function M.new( api, tooltip_reader, inspector )
  -- Everything the tooltips say about what the unit is wearing. What to make of
  -- it is the caller's business.
  ---@param unit string
  ---@return GearLines
  local function get_gear_lines( unit )
    local result = {}

    for i = 1, getn( slots ) do
      local slot = slots[ i ]
      local lines = tooltip_reader.get_inventory_item_lines( unit, slot )

      if lines then result[ slot ] = lines end
    end

    return result
  end

  -- Same, for a unit that has to be inspected first.
  ---@param unit string
  ---@param callback fun( gear: GearLines?, error: InspectError? )
  ---@param on_retry (fun( unit: string, retry: number ))?
  local function scan_unit( unit, callback, on_retry )
    if api.UnitIsUnit( unit, "player" ) then
      callback( get_gear_lines( unit ) )
      return
    end

    inspector.inspect( unit, function( inspected_unit, _, error_type )
      if error_type then
        callback( nil, error_type )
        return
      end

      callback( get_gear_lines( inspected_unit ) )
    end, on_retry )
  end

  ---@type GearScanner
  return {
    get_gear_lines = get_gear_lines,
    scan_unit = scan_unit
  }
end

m.GearScanner = M
return M
