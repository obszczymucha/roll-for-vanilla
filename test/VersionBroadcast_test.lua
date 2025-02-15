package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
local m = require( "src/modules" )

VersionBroadcastSpec = {}

function VersionBroadcastSpec.should_recognize_my_version_as_newer()
  -- Given
  local mine = "3.7"
  local theirs = "2.123"

  -- When
  local result = m.is_new_version( mine, theirs )

  -- Then
  eq( result, false )
end

function VersionBroadcastSpec.should_recognize_their_version_as_newer()
  -- Given
  local mine = "3.7"
  local theirs = "3.11"

  -- When
  local result = m.is_new_version( mine, theirs )

  -- Then
  eq( result, true )
end

function VersionBroadcastSpec.should_not_recognize_their_version_as_newer_cuz_they_are_the_fukin_same_lol()
  -- Given
  local mine = "3.7"
  local theirs = "3.7"

  -- When
  local result = m.is_new_version( mine, theirs )

  -- Then
  eq( result, false )
end

function VersionBroadcastSpec.should_recognize_their_version_as_newer_if_they_have_a_bug_fix()
  -- Given
  local mine = "3.7"
  local theirs = "3.7.1"

  -- When
  local result = m.is_new_version( mine, theirs )

  -- Then
  eq( result, true )
end

function VersionBroadcastSpec.should_not_recognize_their_version_as_newer_if_i_have_a_bug_fix()
  -- Given
  local mine = "3.7.2"
  local theirs = "3.7"

  -- When
  local result = m.is_new_version( mine, theirs )

  -- Then
  eq( result, false )
end

os.exit( lu.LuaUnit.run() )
