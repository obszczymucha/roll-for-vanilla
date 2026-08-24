RollFor = RollFor or {}
local m = RollFor

if m.ResistanceParser then return end

local M = {}

local getn = m.getn

-- The phrase Well Fed food uses for the resistance it grants.
local ALL_SCHOOLS = "all schools of magic"

---@alias ResistanceTotals table<ResistanceType, number>

---@class ResistanceParser
---@field parse fun( gear: GearLines ): ResistanceTotals
---@field parse_slot fun( gear: GearLines, slot: number ): ResistanceTotals
---@field parse_all_schools fun( lines: string[]? ): number

-- Turns tooltip text into resistance numbers. Reads nothing from the game
-- beyond the localized names of the schools.
---@param api table
---@param registry ResistanceRegistry
---@return ResistanceParser
function M.new( api, registry )
  local Armor = m.ResistanceRegistry.ResistanceType.Armor
  -- "Shadow Resistance", localized by the client.
  local function resistance_name( resistance_type )
    return api[ "RESISTANCE" .. resistance_type .. "_NAME" ]
  end

  -- ITEM_RESIST_ALL is a format string ("+%d All Resistances"). Everything up to
  -- and including the placeholder is dropped, leaving something to search for.
  local function all_resistances_name()
    local format_string = api.ITEM_RESIST_ALL
    if type( format_string ) ~= "string" then return nil end

    local name = string.gsub( format_string, ".*%%%d?%$?d", "" )
    name = string.gsub( name, "^[%s%+]+", "" )
    name = string.gsub( name, "%s+$", "" )

    if name == "" then return nil end
    return name
  end

  local function build_needles( resistance_type )
    local result = {}
    local name = resistance_name( resistance_type )

    if name then table.insert( result, name ) end

    -- Armor isn't a magic school, so "All Resistances" doesn't apply to it.
    if resistance_type ~= Armor then
      local all = all_resistances_name()
      if all then table.insert( result, all ) end
    end

    return result
  end

  -- A line that mentions the school has exactly one number on it, whether it
  -- reads "+10 Shadow Resistance" or "Increases shadow resistance by 60".
  -- Matching the name and taking that number sidesteps per-locale formats, and
  -- the comparison ignores case because spell text isn't capitalized.
  local function get_value( line, needle )
    if not string.find( string.lower( line ), string.lower( needle ), 1, true ) then return nil end

    local value = string.match( line, "(%-?%d+)" )
    return value and tonumber( value ) or nil
  end

  -- Set bonuses are listed on every piece of the set, so counting them would
  -- multiply them. The set block starts with a "Name (0/8)" header.
  local function is_set_bonus_header( line )
    return string.find( line, "%(%d+/%d+%)" ) and true or false
  end

  local function sum_lines( lines, needles )
    local total = 0

    for i = 1, getn( lines ) do
      local line = lines[ i ]

      if is_set_bonus_header( line ) then break end

      for j = 1, getn( needles ) do
        local value = get_value( line, needles[ j ] )

        if value then
          total = total + value
          break
        end
      end
    end

    return total
  end

  -- Sums what the gear grants per school, enchants included. Buffs, consumables
  -- and set bonuses are not part of this.
  ---@param gear GearLines
  ---@return ResistanceTotals
  local function parse( gear )
    local types = registry.all_resistance_types()
    local needles = {}
    local totals = {}

    for i = 1, getn( types ) do
      needles[ types[ i ] ] = build_needles( types[ i ] )
      totals[ types[ i ] ] = 0
    end

    for _, lines in pairs( gear ) do
      for i = 1, getn( types ) do
        local resistance_type = types[ i ]
        totals[ resistance_type ] = totals[ resistance_type ] + sum_lines( lines, needles[ resistance_type ] )
      end
    end

    return totals
  end

  -- One slot on its own, so a caller can ask what a single piece brings -- the
  -- resistance neck, say -- without knowing anything about tooltips.
  ---@param gear GearLines
  ---@param slot number
  ---@return ResistanceTotals -- all zeros when nothing is in that slot
  local function parse_slot( gear, slot )
    return parse( { [ slot ] = gear[ slot ] } )
  end

  -- Food says "Resistance to all schools of magic increased by 8." -- no client
  -- format string exposes that wording, so the distinctive part of it is matched
  -- directly. A client that words it differently reads 0 rather than guessing.
  ---@param lines string[]?
  ---@return number -- 0 when nothing in the lines says this
  local function parse_all_schools( lines )
    if not lines then return 0 end

    for i = 1, getn( lines ) do
      local value = get_value( lines[ i ], ALL_SCHOOLS )
      if value then return value end
    end

    return 0
  end

  ---@type ResistanceParser
  return {
    parse = parse,
    parse_slot = parse_slot,
    parse_all_schools = parse_all_schools
  }
end

m.ResistanceParser = M
return M
