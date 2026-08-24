package.path = "./?.lua;" .. package.path .. ";../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
local ResistanceRegistry = require( "src/resistances/ResistanceRegistry" )
local ResistanceParser = require( "src/resistances/ResistanceParser" )

local Shadow = ResistanceRegistry.ResistanceType.Shadow
local Fire = ResistanceRegistry.ResistanceType.Fire
local Frost = ResistanceRegistry.ResistanceType.Frost

-- The only thing the parser needs from the game is what the schools are called.
local parser = ResistanceParser.new( {
  RESISTANCE1_NAME = "Holy Resistance",
  RESISTANCE2_NAME = "Fire Resistance",
  RESISTANCE3_NAME = "Nature Resistance",
  RESISTANCE4_NAME = "Frost Resistance",
  RESISTANCE5_NAME = "Shadow Resistance",
  RESISTANCE6_NAME = "Arcane Resistance",
  ITEM_RESIST_ALL = "+%d All Resistances"
}, ResistanceRegistry.new() )

local function shadow( gear ) return parser.parse( gear )[ Shadow ] end

ResistanceParserSpec = {}

function ResistanceParserSpec:should_sum_resistance_across_equipped_items()
  eq( shadow( {
    [ 1 ] = { "Bloodvine Lens", "Binds when picked up", "+10 Shadow Resistance" },
    [ 5 ] = { "Robe of the Void", "+15 Shadow Resistance" },
    [ 15 ] = { "Cloak of Warding", "+5 Shadow Resistance" }
  } ), 30 )
end

function ResistanceParserSpec:should_keep_the_schools_apart()
  -- Given
  local totals = parser.parse( {
    [ 1 ] = { "Flameguard Gauntlets", "+20 Fire Resistance" },
    [ 5 ] = { "Robe of the Void", "+15 Shadow Resistance" }
  } )

  -- Then
  eq( totals[ Fire ], 20 )
  eq( totals[ Shadow ], 15 )
  eq( totals[ Frost ], 0 )
end

function ResistanceParserSpec:should_count_all_resistances_lines_for_every_school()
  -- Given: the item plus its enchant
  local totals = parser.parse( { [ 15 ] = { "Onyxia Scale Cloak", "+8 All Resistances", "+5 All Resistances" } } )

  -- Then
  eq( totals[ Shadow ], 13 )
  eq( totals[ Fire ], 13 )
  eq( totals[ Frost ], 13 )
end

function ResistanceParserSpec:should_handle_verbose_wording()
  eq( shadow( { [ 13 ] = { "Some Trinket", "Equip: Increases your Shadow Resistance by 12." } } ), 12 )
end

function ResistanceParserSpec:should_ignore_case()
  eq( shadow( { [ 13 ] = { "Some Trinket", "increases shadow resistance by 12" } } ), 12 )
end

function ResistanceParserSpec:should_not_count_set_bonuses()
  eq( shadow( {
    [ 5 ] = {
      "Nemesis Robes",
      "+15 Shadow Resistance",
      "Nemesis Raiment (0/8)",
      "(4) Set: +20 Shadow Resistance"
    }
  } ), 15 )
end

function ResistanceParserSpec:should_take_one_value_per_line()
  eq( shadow( { [ 5 ] = { "Robe", "+15 Shadow Resistance for 30 sec" } } ), 15 )
end

function ResistanceParserSpec:should_be_zero_for_naked_units()
  eq( shadow( {} ), 0 )
end

function ResistanceParserSpec:should_ignore_lines_without_a_school()
  eq( shadow( { [ 5 ] = { "Robe of the Void", "Binds when picked up", "Durability 100 / 100", "Requires Level 60" } } ), 0 )
end

function ResistanceParserSpec:should_read_the_resistance_a_well_fed_buff_grants()
  eq( parser.parse_all_schools( {
    "Well Fed",
    "Resistance to all schools of magic increased by 8."
  } ), 8 )
end

function ResistanceParserSpec:should_read_nothing_from_a_buff_that_grants_no_resistance()
  eq( parser.parse_all_schools( {
    "Well Fed",
    "Stamina and Spirit increased by 6."
  } ), 0 )
end

function ResistanceParserSpec:should_read_nothing_when_there_is_no_tooltip()
  eq( parser.parse_all_schools( nil ), 0 )
end

function ResistanceParserSpec:should_keep_well_fed_out_of_the_gear_totals()
  -- The two are counted separately, so the same lines through parse() are worth
  -- nothing: gear never says it this way.
  eq( shadow( { [ 1 ] = { "Resistance to all schools of magic increased by 8." } } ), 0 )
end

function ResistanceParserSpec:should_read_one_slot_on_its_own()
  -- Given: the neck is slot 2
  local totals = parser.parse_slot( {
    [ 2 ] = { "Pendant of Frozen Flame", "+40 Shadow Resistance" },
    [ 5 ] = { "Robe of the Void", "+15 Shadow Resistance" }
  }, 2 )

  -- Then
  eq( totals[ Shadow ], 40 )
end

function ResistanceParserSpec:should_read_zero_from_an_empty_slot()
  eq( parser.parse_slot( { [ 5 ] = { "Robe of the Void", "+15 Shadow Resistance" } }, 2 )[ Shadow ], 0 )
end

os.exit( lu.LuaUnit.run() )
