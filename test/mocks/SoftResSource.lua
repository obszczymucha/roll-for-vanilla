-- The soft-res source core's own suite tests against.
--
-- THIS IS DELIBERATELY DUMB. It is the six read methods over a literal table and nothing
-- else: no group filtering, no awarded-loot filtering, no name matching, no import, no
-- persistence. If a test of yours needs any of those, that test belongs in
-- RollForSoftResIt, not here -- move it rather than teaching this double another
-- behaviour. Core has no soft-res implementation left to test; what it has is consumers,
-- and consumers only need data to arrive.
--
-- Built from the same `u.soft_res_item( player, item_id, quality )` / `u.hard_res_item`
-- vocabulary the suites already speak, so a test reads the same as it did before.

local M = {}

-- `find_class` is the one thing here that is not a plain table read: every real source
-- hands consumers rollers that carry a class, because its present-players decorator looks
-- one up while it filters. The rows core renders are built from that field, so the double
-- would misrepresent the data shape without it. It enriches only -- a player who is not in
-- the group still comes back, with no class. That is the half this double refuses to copy.
---@param entries table[] -- soft_res_item / hard_res_item entries
---@param find_class fun( player_name: string ): string?
---@return SoftRes
function M.new( entries, find_class )
  local softres_data = {}
  local hardres_data = {}

  for _, entry in ipairs( entries or {} ) do
    if entry.soft_res then
      local item = softres_data[ entry.item_id ] or { rollers = {} }
      softres_data[ entry.item_id ] = item

      local roller

      for _, r in ipairs( item.rollers ) do
        if r.name == entry.player then roller = r end
      end

      if roller then
        -- Duplicate entries are what grant extra rolls, same as the real import.
        roller.rolls = roller.rolls + 1
      else
        table.insert( item.rollers, {
          name = entry.player,
          rolls = 1,
          type = "Roller",
          class = find_class and find_class( entry.player ) or nil
        } )
      end
    else
      hardres_data[ entry.item_id ] = true
    end
  end

  for _, item in pairs( softres_data ) do
    table.sort( item.rollers, function( left, right ) return left.name < right.name end )
  end

  local function get( item_data )
    local item = softres_data[ item_data.item_id ]
    return item and RollFor.clone( item.rollers ) or {}
  end

  local function get_all_rollers()
    local by_name = {}

    for _, item in pairs( softres_data ) do
      for _, roller in ipairs( item.rollers ) do
        by_name[ roller.name ] = roller
      end
    end

    local result = {}
    for _, roller in pairs( by_name ) do table.insert( result, roller ) end

    return result
  end

  local function is_player_softressing( player_name, item_data )
    local items = item_data and { softres_data[ item_data.item_id ] } or softres_data

    for _, item in pairs( items ) do
      for _, roller in ipairs( item.rollers ) do
        if roller.name == player_name then return true end
      end
    end

    return false
  end

  local function get_items()
    local result = {}

    for item_id in pairs( softres_data ) do
      table.insert( result, RollFor.SoftRes.softres_item_data( item_id, 1 ) )
    end

    return result
  end

  local function get_hr_item_ids()
    return RollFor.keys( hardres_data )
  end

  local function is_item_hardressed( item_id )
    return hardres_data[ item_id ] and true or false
  end

  return {
    get = get,
    get_all_rollers = get_all_rollers,
    is_player_softressing = is_player_softressing,
    get_items = get_items,
    get_hr_item_ids = get_hr_item_ids,
    is_item_hardressed = is_item_hardressed
  }
end

return M
