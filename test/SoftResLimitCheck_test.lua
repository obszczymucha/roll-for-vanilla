package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local sr, make_data = u.soft_res_item, u.create_softres_data
u.mock_wow_api()
require( "src/modules" )
require( "src/Types" )
require( "src/AutoLootDb" )
require( "src/SoftResDataTransformer" )
local soft_res = require( "src/SoftRes" )
local mod = require( "src/SoftResLimitCheck" )

-- Black Temple's first 6 bosses.
local NAJENTUS, NAJENTUS2, NAJENTUS3, SUPREMUS = 32239, 32240, 32241, 32256

-- Black Temple's last 3 bosses.
local SHAHRAZ, SHAHRAZ2, COUNCIL, ILLIDAN = 32367, 32366, 32331, 32524

local NOT_IN_CATALOGUE = 999999

local function softres( ... )
  local result = soft_res.new( {} )
  result.import( make_data( ... ) )

  return result
end

SoftResLimitCheckSpec = {}

function SoftResLimitCheckSpec:should_not_report_anything_if_the_budget_is_not_exceeded()
  -- Given
  local data = softres(
    sr( "Psikutas", NAJENTUS ), sr( "Psikutas", NAJENTUS2 ), sr( "Psikutas", SUPREMUS ), sr( "Psikutas", ILLIDAN )
  )

  -- Expect
  eq( mod.find_violations( data ), {} )
end

function SoftResLimitCheckSpec:should_allow_the_whole_budget_on_the_last_3_bosses()
  -- Given
  local data = softres(
    sr( "Psikutas", SHAHRAZ ), sr( "Psikutas", SHAHRAZ2 ), sr( "Psikutas", COUNCIL ), sr( "Psikutas", ILLIDAN )
  )

  -- Expect
  eq( mod.find_violations( data ), {} )
end

function SoftResLimitCheckSpec:should_report_a_4th_soft_res_outside_the_last_3_bosses()
  -- Given
  local data = softres(
    sr( "Psikutas", NAJENTUS ), sr( "Psikutas", NAJENTUS2 ), sr( "Psikutas", NAJENTUS3 ), sr( "Psikutas", SUPREMUS )
  )

  -- Expect
  eq( mod.find_violations( data ), { { name = "Psikutas", regular = 4, total = 4 } } )
end

function SoftResLimitCheckSpec:should_report_a_5th_soft_res_on_the_last_3_bosses()
  -- Given
  local data = softres(
    sr( "Psikutas", NAJENTUS ), sr( "Psikutas", NAJENTUS2 ), sr( "Psikutas", SUPREMUS ),
    sr( "Psikutas", SHAHRAZ ), sr( "Psikutas", ILLIDAN )
  )

  -- Expect
  eq( mod.find_violations( data ), { { name = "Psikutas", regular = 3, total = 5 } } )
end

function SoftResLimitCheckSpec:should_count_items_that_are_not_in_the_catalogue_as_regular_soft_resses()
  -- Given
  local data = softres(
    sr( "Psikutas", NAJENTUS ), sr( "Psikutas", NAJENTUS2 ), sr( "Psikutas", SUPREMUS ),
    sr( "Psikutas", NOT_IN_CATALOGUE )
  )

  -- Expect
  eq( mod.find_violations( data ), { { name = "Psikutas", regular = 4, total = 4 } } )
end

function SoftResLimitCheckSpec:should_count_the_same_item_soft_ressed_twice_twice()
  -- Given
  local data = softres(
    sr( "Psikutas", NAJENTUS ), sr( "Psikutas", NAJENTUS ), sr( "Psikutas", NAJENTUS2 ), sr( "Psikutas", SUPREMUS )
  )

  -- Expect
  eq( mod.find_violations( data ), { { name = "Psikutas", regular = 4, total = 4 } } )
end

function SoftResLimitCheckSpec:should_report_violating_players_sorted_by_name()
  -- Given
  local data = softres(
    sr( "Psikutas", NAJENTUS ), sr( "Psikutas", NAJENTUS2 ), sr( "Psikutas", NAJENTUS3 ), sr( "Psikutas", SUPREMUS ),
    sr( "Obszczymucha", NAJENTUS ), sr( "Obszczymucha", SHAHRAZ ), sr( "Obszczymucha", COUNCIL ),
    sr( "Obszczymucha", ILLIDAN ), sr( "Obszczymucha", SHAHRAZ2 ),
    sr( "Ponpon", NAJENTUS ), sr( "Ponpon", ILLIDAN )
  )

  -- Expect
  eq( mod.find_violations( data ), {
    { name = "Obszczymucha", regular = 1, total = 5 },
    { name = "Psikutas",     regular = 4, total = 4 }
  } )
end

function SoftResLimitCheckSpec:should_print_a_message_for_each_violating_player()
  -- Given
  local data = softres(
    sr( "Psikutas", NAJENTUS ), sr( "Psikutas", NAJENTUS2 ), sr( "Psikutas", NAJENTUS3 ), sr( "Psikutas", SUPREMUS ),
    sr( "Obszczymucha", SHAHRAZ ), sr( "Obszczymucha", SHAHRAZ2 ), sr( "Obszczymucha", COUNCIL ),
    sr( "Obszczymucha", ILLIDAN ), sr( "Obszczymucha", NAJENTUS )
  )

  local group_roster = { find_player = function() return nil end }
  local messages = {}
  local pretty_print = RollFor.pretty_print
  RollFor.pretty_print = function( message, _color_fn, _module_name ) table.insert( messages, message ) end

  -- When
  mod.report( data, group_roster )
  RollFor.pretty_print = pretty_print

  -- Then
  eq( messages, {
    "Obszczymucha soft-ressed |cffff9f695|r items (max |cffff9f694|r).",
    "Psikutas soft-ressed |cffff9f694|r items outside the last 3 bosses (max |cffff9f693|r)."
  } )
end

os.exit( lu.LuaUnit.run() )
