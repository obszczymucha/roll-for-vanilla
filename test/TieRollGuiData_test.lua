package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua;../RollFor/libs/LibStub/?.lua"

local lu = require( "luaunit" )
local test_utils = require( "test/utils" )
test_utils.mock_wow_api()
test_utils.load_libstub()
local m = require( "src/modules" )
local types = require( "src/Types" )
local blue = m.colors.blue
local mod = require( "src/TieRollGuiData" )

local MS = types.RollType.MainSpec

TieRollGuiDataSpec = {}

local function p( player_name, player_class )
  return { name = player_name, class = player_class }
end

local function mock_group_roster( players )
  return {
    find_player = function( player_name )
      for _, player in ipairs( players ) do
        if player.name == player_name then return player end
      end
    end
  }
end

function TieRollGuiDataSpec:should_generate_gui_data_for_the_first_tie_start()
  -- Given
  local group_roster = mock_group_roster( { p( "Psikutas", "Warrior" ), p( "Obszczymucha", "Druid" ), p( "Ponpon", "Priest" ) } )
  local gui_data = mod.new( group_roster )
  gui_data.start( { "Psikutas", "Obszczymucha", "Ponpon" }, MS, 69 )

  -- When
  local result = gui_data.get()

  -- Then
  lu.assertEquals( result,
    {
      { type = "text", value = string.format( "There was a tie (%s):", blue( "69" ) ), padding = 10 },
      { type = "roll", player_name = "Obszczymucha",                                   player_class = "Druid",   roll_type = MS, padding = 7 },
      { type = "roll", player_name = "Ponpon",                                         player_class = "Priest",  roll_type = MS },
      { type = "roll", player_name = "Psikutas",                                       player_class = "Warrior", roll_type = MS },
      { type = "text", value = "Waiting for remaining rolls...",                       padding = 10 }
    } )
end

function TieRollGuiDataSpec:should_add_rolls_to_the_first_tie_iteration()
  -- Given
  local group_roster = mock_group_roster( { p( "Psikutas", "Warrior" ), p( "Obszczymucha", "Druid" ), p( "Ponpon", "Priest" ) } )
  local gui_data = mod.new( group_roster )
  gui_data.start( { "Psikutas", "Obszczymucha", "Ponpon" }, MS, 69 )
  gui_data.add_roll( "Psikutas", 42 )
  gui_data.add_roll( "Ponpon", 13 )

  -- When
  local result = gui_data.get()

  -- Then
  lu.assertEquals( result,
    {
      { type = "text", value = string.format( "There was a tie (%s):", blue( "69" ) ), padding = 10 },
      { type = "roll", player_name = "Psikutas",                                       player_class = "Warrior", roll_type = MS, roll = 42, padding = 7 },
      { type = "roll", player_name = "Ponpon",                                         player_class = "Priest",  roll_type = MS, roll = 13 },
      { type = "roll", player_name = "Obszczymucha",                                   player_class = "Druid",   roll_type = MS },
      { type = "text", value = "Waiting for remaining rolls...",                       padding = 10 }
    } )
end

function TieRollGuiDataSpec:should_remove_waiting_message_if_everone_rolled_in_the_first_tie_iteration()
  -- Given
  local group_roster = mock_group_roster( { p( "Psikutas", "Warrior" ), p( "Obszczymucha", "Druid" ), p( "Ponpon", "Priest" ) } )
  local gui_data = mod.new( group_roster )
  gui_data.start( { "Psikutas", "Obszczymucha", "Ponpon" }, MS, 69 )
  gui_data.add_roll( "Psikutas", 42 )
  gui_data.add_roll( "Ponpon", 13 )
  gui_data.add_roll( "Obszczymucha", 14 )

  -- When
  local result = gui_data.get()

  -- Then
  lu.assertEquals( result,
    {
      { type = "text", value = string.format( "There was a tie (%s):", blue( "69" ) ), padding = 10 },
      { type = "roll", player_name = "Psikutas",                                       player_class = "Warrior", roll_type = MS, roll = 42, padding = 7 },
      { type = "roll", player_name = "Obszczymucha",                                   player_class = "Druid",   roll_type = MS, roll = 14 },
      { type = "roll", player_name = "Ponpon",                                         player_class = "Priest",  roll_type = MS, roll = 13 }
    } )
end

function TieRollGuiDataSpec:should_generate_gui_data_for_the_next_tie_start()
  -- Given
  local group_roster = mock_group_roster( { p( "Psikutas", "Warrior" ), p( "Obszczymucha", "Druid" ), p( "Ponpon", "Priest" ) } )
  local gui_data = mod.new( group_roster )
  gui_data.start( { "Psikutas", "Obszczymucha", "Ponpon" }, MS, 69 )
  gui_data.add_roll( "Psikutas", 42 )
  gui_data.add_roll( "Ponpon", 13 )
  gui_data.add_roll( "Obszczymucha", 42 )
  gui_data.start( { "Psikutas", "Obszczymucha" }, MS, 42 )

  -- When
  local result = gui_data.get()

  -- Then
  lu.assertEquals( result,
    {
      { type = "text", value = string.format( "There was a tie (%s):", blue( "69" ) ), padding = 10 },
      { type = "roll", player_name = "Obszczymucha",                                   player_class = "Druid",   roll_type = MS, roll = 42,  padding = 7 },
      { type = "roll", player_name = "Psikutas",                                       player_class = "Warrior", roll_type = MS, roll = 42 },
      { type = "roll", player_name = "Ponpon",                                         player_class = "Priest",  roll_type = MS, roll = 13 },
      { type = "text", value = string.format( "There was a tie (%s):", blue( "42" ) ), padding = 10 },
      { type = "roll", player_name = "Obszczymucha",                                   player_class = "Druid",   roll_type = MS, padding = 7 },
      { type = "roll", player_name = "Psikutas",                                       player_class = "Warrior", roll_type = MS },
      { type = "text", value = "Waiting for remaining rolls...",                       padding = 10 }
    } )
end

function TieRollGuiDataSpec:should_add_rolls_to_the_next_tie_iteration()
  -- Given
  local group_roster = mock_group_roster( { p( "Psikutas", "Warrior" ), p( "Obszczymucha", "Druid" ), p( "Ponpon", "Priest" ) } )
  local gui_data = mod.new( group_roster )
  gui_data.start( { "Psikutas", "Obszczymucha", "Ponpon" }, MS, 69 )
  gui_data.add_roll( "Psikutas", 42 )
  gui_data.add_roll( "Ponpon", 13 )
  gui_data.add_roll( "Obszczymucha", 42 )
  gui_data.start( { "Psikutas", "Obszczymucha" }, MS, 42 )
  gui_data.add_roll( "Psikutas", 69 )

  -- When
  local result = gui_data.get()

  -- Then
  lu.assertEquals( result,
    {
      { type = "text", value = string.format( "There was a tie (%s):", blue( "69" ) ), padding = 10 },
      { type = "roll", player_name = "Obszczymucha",                                   player_class = "Druid",   roll_type = MS, roll = 42, padding = 7 },
      { type = "roll", player_name = "Psikutas",                                       player_class = "Warrior", roll_type = MS, roll = 42 },
      { type = "roll", player_name = "Ponpon",                                         player_class = "Priest",  roll_type = MS, roll = 13 },
      { type = "text", value = string.format( "There was a tie (%s):", blue( "42" ) ), padding = 10 },
      { type = "roll", player_name = "Psikutas",                                       player_class = "Warrior", roll_type = MS, roll = 69, padding = 7 },
      { type = "roll", player_name = "Obszczymucha",                                   player_class = "Druid",   roll_type = MS },
      { type = "text", value = "Waiting for remaining rolls...",                       padding = 10 }
    } )
end

function TieRollGuiDataSpec:should_remove_waiting_message_if_everone_rolled_in_the_next_tie_iteration()
  -- Given
  local group_roster = mock_group_roster( { p( "Psikutas", "Warrior" ), p( "Obszczymucha", "Druid" ), p( "Ponpon", "Priest" ) } )
  local gui_data = mod.new( group_roster )
  gui_data.start( { "Psikutas", "Obszczymucha", "Ponpon" }, MS, 69 )
  gui_data.add_roll( "Psikutas", 42 )
  gui_data.add_roll( "Ponpon", 13 )
  gui_data.add_roll( "Obszczymucha", 42 )
  gui_data.start( { "Psikutas", "Obszczymucha" }, MS, 42 )
  gui_data.add_roll( "Psikutas", 69 )
  gui_data.add_roll( "Obszczymucha", 100 )

  -- When
  local result = gui_data.get()

  -- Then
  lu.assertEquals( result,
    {
      { type = "text", value = string.format( "There was a tie (%s):", blue( "69" ) ), padding = 10 },
      { type = "roll", player_name = "Obszczymucha",                                   player_class = "Druid",   roll_type = MS, roll = 42,  padding = 7 },
      { type = "roll", player_name = "Psikutas",                                       player_class = "Warrior", roll_type = MS, roll = 42 },
      { type = "roll", player_name = "Ponpon",                                         player_class = "Priest",  roll_type = MS, roll = 13 },
      { type = "text", value = string.format( "There was a tie (%s):", blue( "42" ) ), padding = 10 },
      { type = "roll", player_name = "Obszczymucha",                                   player_class = "Druid",   roll_type = MS, roll = 100, padding = 7 },
      { type = "roll", player_name = "Psikutas",                                       player_class = "Warrior", roll_type = MS, roll = 69 }
    } )
end

os.exit( lu.LuaUnit.run() )
