RollFor = RollFor or {}
local m = RollFor

if m.SoftResNetherVortexDecorator then return end

local M = {}

local NETHER_VORTEX_ID = 30183
local getn = m.getn

---@param softres SoftRes
function M.new( softres )
  local sid = m.SoftRes.softres_item_data

  local function is_eligible( rolls, item_quantity )
    if item_quantity == 1 then
      return rolls == 1 or rolls == 3
    elseif item_quantity == 2 then
      return rolls == 2 or rolls == 3
    end

    return false
  end

  local function get( item_data )
    if item_data.item_id ~= NETHER_VORTEX_ID then
      return softres.get( item_data )
    end

    local rollers = softres.get( item_data )
    local result = {}

    for _, roller in ipairs( rollers ) do
      if is_eligible( roller.rolls, item_data.item_quantity ) then
        local filtered_roller = m.clone( roller )
        filtered_roller.rolls = 1
        table.insert( result, filtered_roller )
      end
    end

    return result
  end

  local function get_items()
    local items = softres.get_items()
    local result = {}
    local vortex_found = false

    for _, item_data in ipairs( items ) do
      if item_data.item_id ~= NETHER_VORTEX_ID then
        table.insert( result, item_data )
      else
        vortex_found = true
      end
    end

    if vortex_found then
      if getn( get( sid( NETHER_VORTEX_ID, 1 ) ) ) > 0 then
        table.insert( result, sid( NETHER_VORTEX_ID, 1 ) )
      end

      if getn( get( sid( NETHER_VORTEX_ID, 2 ) ) ) > 0 then
        table.insert( result, sid( NETHER_VORTEX_ID, 2 ) )
      end
    end

    return result
  end

  local decorator = m.clone( softres )
  decorator.get = get
  decorator.get_items = get_items

  return decorator
end

m.SoftResNetherVortexDecorator = M
return M
