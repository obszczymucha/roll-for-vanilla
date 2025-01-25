package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local u = require( "test/utils" )
local lu = u.luaunit()
local player, leader, is_in_raid = u.player, u.raid_leader, u.is_in_raid
local rw = u.raid_warning
local rolling_not_in_progress, finish_rolling = u.rolling_not_in_progress, u.finish_rolling
local roll_for, roll, roll_os = u.roll_for, u.roll, u.roll_os
local soft_res, hr = u.soft_res, u.hard_res_item

---@type ModuleRegistry
local module_registry = {
  { module_name = "ChatApi", mock = "mocks/ChatApi", variable_name = "chat" }
}

-- The modules will be injected here using the above module_registry.
local m = {}

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
  m.chat.assert(
    rw( "[Hearthstone] is hard-ressed." ),
    rolling_not_in_progress()
  )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
