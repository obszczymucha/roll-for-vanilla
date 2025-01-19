package.path = "./?.lua;" .. "./test/?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local api = require( "mocks/GroupRosterApi" )
local types = require( "src/Types" )
local make_player = types.make_player
local C = types.PlayerClass

---@param name string
---@param class PlayerClass
---@param online boolean?
local function p( name, class, online )
  if online == nil then return make_player( name, class, true ) end
  return make_player( name, class, online )
end

local p1 = p( "Ohhaimark", C.Warrior )
local p2 = p( "Obszczymucha", C.Druid, false )
local p3 = p( "Psikutas", C.Priest )
local p4 = p( "Jogobobek", C.Mage, false )
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

  for i = 1, 40 do
    eq( api.new( party ).UnitName( string.format( "raid%s", i ) ), nil )
  end
end

function UnitNameSpec:should_return_a_name_for_raid_members_if_in_the_raid()
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

UnitIsConnectedSpec = {}

function UnitIsConnectedSpec:should_not_return_online_status_for_raid_members_if_not_in_the_raid()
  local party = { p1, p2, p3, p4, p5 }

  for i = 1, 40 do
    eq( api.new( party ).UnitIsConnected( string.format( "raid%s", i ) ), nil )
  end
end

function UnitIsConnectedSpec:should_return_a_name_for_raid_members_if_in_the_raid()
  local party = { p1, p2, p3, p4, p5 }
  eq( api.new( party, true ).UnitIsConnected( "raid1" ), true )
  eq( api.new( party, true ).UnitIsConnected( "raid2" ), false )
  eq( api.new( party, true ).UnitIsConnected( "raid3" ), true )
  eq( api.new( party, true ).UnitIsConnected( "raid4" ), false )
  eq( api.new( party, true ).UnitIsConnected( "raid5" ), true )
end

function UnitIsConnectedSpec:should_return_true_online_status_for_all_raid_members()
  local raid = {}

  for i = 1, 40 do
    table.insert( raid, p( "Player" .. i, C.Warrior, true ) )
  end

  local f = api.new( raid, true ).UnitIsConnected

  for i = 1, 40 do
    eq( f( "raid" .. i ), true )
  end
end

function UnitIsConnectedSpec:should_return_false_online_status_for_all_raid_members()
  local raid = {}

  for i = 1, 40 do
    table.insert( raid, p( "Player" .. i, C.Warrior, false ) )
  end

  local f = api.new( raid, true ).UnitIsConnected

  for i = 1, 40 do
    eq( f( "raid" .. i ), false )
  end
end

UnitClassSpec = {}

function UnitClassSpec:should_nil_for_all_party_units()
  for unit in pairs( api.party_units ) do
    eq( api.new().UnitClass( unit ), nil )
  end
end

function UnitClassSpec:should_return_name_for_player()
  eq( api.new( { p1 } ).UnitClass( "player" ), C.Warrior )
  eq( api.new( { p1 }, true ).UnitClass( "player" ), C.Warrior )
end

function UnitClassSpec:should_return_name_for_party_member()
  local party = { p1, p2, p3, p4, p5 }
  eq( api.new( party ).UnitClass( "player" ), C.Warrior )
  eq( api.new( party ).UnitClass( "party1" ), C.Druid )
  eq( api.new( party ).UnitClass( "party2" ), C.Priest )
  eq( api.new( party ).UnitClass( "party3" ), C.Mage )
  eq( api.new( party ).UnitClass( "party4" ), C.Warlock )

  local raid = { p1, p2, p3, p4, p5, p6 }
  eq( api.new( raid ).UnitClass( "player" ), C.Warrior )
  eq( api.new( raid ).UnitClass( "party1" ), C.Druid )
  eq( api.new( raid ).UnitClass( "party2" ), C.Priest )
  eq( api.new( raid ).UnitClass( "party3" ), C.Mage )
  eq( api.new( raid ).UnitClass( "party4" ), C.Warlock )
  eq( api.new( raid ).UnitClass( "party5" ), nil )
end

function UnitClassSpec:should_not_return_a_name_for_raid_members_if_not_in_the_raid()
  local party = { p1, p2, p3, p4, p5 }

  for i = 1, 40 do
    eq( api.new( party ).UnitClass( string.format( "raid%s", i ) ), nil )
  end
end

function UnitClassSpec:should_return_a_name_for_raid_members_if_in_the_raid()
  local party = { p1, p2, p3, p4, p5 }
  eq( api.new( party, true ).UnitClass( "raid1" ), C.Warrior )
  eq( api.new( party, true ).UnitClass( "raid2" ), C.Druid )
  eq( api.new( party, true ).UnitClass( "raid3" ), C.Priest )
  eq( api.new( party, true ).UnitClass( "raid4" ), C.Mage )
  eq( api.new( party, true ).UnitClass( "raid5" ), C.Warlock )
end

function UnitClassSpec:should_return_name_for_raid_member()
  local raid = {}

  for i = 1, 40 do
    table.insert( raid, p( "Player" .. i, C.Warrior ) )
  end

  local f = api.new( raid, true ).UnitClass

  for i = 1, 40 do
    eq( f( "raid" .. i ), C.Warrior )
  end
end

os.exit( lu.LuaUnit.run() )
