package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local u = require( "test/utils" )
local lu = u.luaunit()
local player, leader = u.player, u.raid_leader
local is_in_party, is_in_raid = u.is_in_party, u.is_in_raid
local c, p, r = u.console_message, u.party_message, u.raid_message
local run_command = u.run_command

---@type ModuleRegistry
local module_registry = {
  { module_name = "ChatApi", mock = "mocks/ChatApi", variable_name = "chat" }
}

-- The modules will be injected here using the above module_registry.
local m = {}

HowToRollSpec = {}

function HowToRollSpec:should_not_show_how_to_roll_if_not_in_a_group()
  -- Given
  player( "Psikutas" )

  -- When
  run_command( "HTR" )

  -- Then
  m.chat.assert(
    c( "RollFor: Not in a group." )
  )
end

function HowToRollSpec:should_show_how_to_roll_if_in_party()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  run_command( "HTR" )

  -- Then
  m.chat.assert(
    p( "How to roll:" ),
    p( "For main-spec, type: /roll" ),
    p( "For off-spec, type: /roll 99" ),
    p( "For transmog, type: /roll 98" )
  )
end

function HowToRollSpec:should_show_how_to_roll_if_in_raid()
  -- Given
  player( "Psikutas" )
  is_in_raid( "Psikutas", "Obszczymucha" )

  -- When
  run_command( "HTR" )

  -- Then
  m.chat.assert(
    r( "How to roll:" ),
    r( "For main-spec, type: /roll" ),
    r( "For off-spec, type: /roll 99" ),
    r( "For transmog, type: /roll 98" )
  )
end

function HowToRollSpec:should_show_how_to_roll_if_in_raid_and_a_leader()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  run_command( "HTR" )

  -- Then
  m.chat.assert(
    r( "How to roll:" ),
    r( "For main-spec, type: /roll" ),
    r( "For off-spec, type: /roll 99" ),
    r( "For transmog, type: /roll 98" )
  )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run() )
