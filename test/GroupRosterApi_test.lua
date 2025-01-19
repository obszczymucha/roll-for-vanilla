package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local api = require( "test/mocks/GroupRosterApi" )
local types = require( "src/Types" )
local make_player = types.make_player
local C = types.PlayerClass

---@param name string
---@param class PlayerClass
local function p( name, class ) return make_player( name, class, true ) end
local p1 = p( "Ohhaimark", C.Warrior )
local p2 = p( "Obszczymucha", C.Druid )
local p3 = p( "Psikutas", C.Priest )
local p4 = p( "Jogobobek", C.Mage )
local p5 = p( "Dupeczka", C.Warlock )
local p6 = p( "Ponpon", C.Hunter )

GroupRosterApiSpec = {}

function GroupRosterApiSpec:should_return_is_in_party()
  eq( api.new().IsInParty(), nil )
  eq( api.new( nil, true ).IsInParty(), nil )
  eq( api.new( { p1 } ).IsInParty(), nil )
  eq( api.new( { p1 }, true ).IsInParty(), nil )
  eq( api.new( { p1, p2 }, true ).IsInParty(), nil )
  eq( api.new( { p1, p2 } ).IsInParty(), 1 )
end

function GroupRosterApiSpec:should_return_is_in_raid()
  eq( api.new().IsInRaid(), nil )
  eq( api.new( nil, true ).IsInRaid(), nil )
  eq( api.new( { p1 } ).IsInRaid(), nil )
  eq( api.new( { p1 }, true ).IsInRaid(), nil )
  eq( api.new( { p1, p2 }, true ).IsInRaid(), 1 )
  eq( api.new( { p1, p2 } ).IsInRaid(), nil )

  eq( api.new( { p1, p2, p3, p4, p5 } ).IsInRaid(), nil )
  eq( api.new( { p1, p2, p3, p4, p5, p6 } ).IsInRaid(), 1 )
end

UnitNameSpec = {}

function UnitNameSpec:should_nil_for_all_party_units()
  for unit in pairs( api.party_units ) do
    eq( api.new().UnitName( unit ), nil )
  end
end

function UnitNameSpec:should_return_name_for_player()
  eq( api.new( { p1 } ).UnitName( "player" ), "Ohhaimark" )
  eq( api.new( { p1 }, true ).UnitName( "player" ), "Ohhaimark" )
end

function UnitNameSpec:should_return_name_for_party_member()
  local party = { p1, p2, p3, p4, p5 }
  eq( api.new( party ).UnitName( "player" ), "Ohhaimark" )
  eq( api.new( party ).UnitName( "party1" ), "Obszczymucha" )
  eq( api.new( party ).UnitName( "party2" ), "Psikutas" )
  eq( api.new( party ).UnitName( "party3" ), "Jogobobek" )
  eq( api.new( party ).UnitName( "party4" ), "Dupeczka" )

  local raid = { p1, p2, p3, p4, p5, p6 }
  eq( api.new( raid ).UnitName( "player" ), "Ohhaimark" )
  eq( api.new( raid ).UnitName( "party1" ), "Obszczymucha" )
  eq( api.new( raid ).UnitName( "party2" ), "Psikutas" )
  eq( api.new( raid ).UnitName( "party3" ), "Jogobobek" )
  eq( api.new( raid ).UnitName( "party4" ), "Dupeczka" )
  eq( api.new( raid ).UnitName( "party5" ), nil )
end

function UnitNameSpec:should_not_return_a_name_for_raid_members_if_not_in_the_raid()
  local party = { p1, p2, p3, p4, p5 }
  eq( api.new( party ).UnitName( "raid1" ), nil )
  eq( api.new( party ).UnitName( "raid2" ), nil )
  eq( api.new( party ).UnitName( "raid3" ), nil )
  eq( api.new( party ).UnitName( "raid4" ), nil )
  eq( api.new( party ).UnitName( "raid4" ), nil )
end

function UnitNameSpec:should_not_return_a_name_for_raid_members_if_in_the_raid()
  local party = { p1, p2, p3, p4, p5 }
  eq( api.new( party, true ).UnitName( "raid1" ), "Ohhaimark" )
  eq( api.new( party, true ).UnitName( "raid2" ), "Obszczymucha" )
  eq( api.new( party, true ).UnitName( "raid3" ), "Psikutas" )
  eq( api.new( party, true ).UnitName( "raid4" ), "Jogobobek" )
  eq( api.new( party, true ).UnitName( "raid5" ), "Dupeczka" )
end

function UnitNameSpec:should_return_name_for_raid_member()
  local raid = {}

  for i = 1, 40 do
    table.insert( raid, p( "Player" .. i, C.Warrior ) )
  end

  local f = api.new( raid, true ).UnitName

  for i = 1, 40 do
    eq( f( "raid" .. i ), "Player" .. i )
  end
end

os.exit( lu.LuaUnit.run() )
