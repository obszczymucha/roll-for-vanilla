package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local player = utils.player
local leader = utils.raid_leader
local is_in_raid = utils.is_in_raid
local rw = utils.raid_warning
local rolling_not_in_progress = utils.rolling_not_in_progress
local roll_for = utils.roll_for
local finish_rolling = utils.finish_rolling
local roll = utils.roll
local roll_os = utils.roll_os
local assert_messages = utils.assert_messages
local soft_res = utils.soft_res
local hr = utils.hard_res_item

HardResRollsSpec = {}

function HardResRollsSpec:should_announce_hr_and_ignore_all_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )
  soft_res( hr( 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Psikutas", 69 )
  roll_os( "Obszczymucha", 42 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "[Hearthstone] is hard-ressed." ),
    rolling_not_in_progress()
  )
end

utils.mock_libraries()
utils.load_real_stuff()

os.exit( lu.LuaUnit.run() )
