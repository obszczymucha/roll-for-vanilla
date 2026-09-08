---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )

-- ctx.on_rf_command lets an extension own a subcommand of core's /rf, so its window opens
-- the way every other RollFor window does instead of from a slash command users have to
-- learn separately.
--
-- The dispatch order is the whole point: core's own subcommands are matched first, and an
-- extension asking for one of them is refused out loud rather than quietly losing to it.

utils.mock_wow_api()
utils.mock_libraries()
utils.load_real_stuff()

local Extensions = RollFor.Extensions

local calls = {}
local complaints = {}

local function record( name )
  return function( args ) table.insert( calls, { name = name, args = args } ) end
end

Extensions.register( {
  name = "rf_command_probe",
  title = "Rf Command Probe",
  api_version = Extensions.API_VERSION,
  on_enable = function( ctx )
    local err = RollFor.err
    ---@diagnostic disable-next-line: duplicate-set-field
    RollFor.err = function( message ) table.insert( complaints, message ) end

    ctx.on_rf_command( "probe", record( "probe" ) )

    -- Refused: core answers these itself.
    ctx.on_rf_command( "config", record( "hijacked_config" ) )
    -- Refused: a subcommand is the first word, so a name with a space could never match.
    ctx.on_rf_command( "two words", record( "two_words" ) )
    -- Refused: taken, by this very extension a few lines up.
    ctx.on_rf_command( "probe", record( "second_probe" ) )

    RollFor.err = err
  end
} )

utils.player( "Psikutas" )

utils.load_roll_for()

-- /rf config prints, and core's printer goes straight to the chat frame rather than
-- through the Chat the rest of the addon uses. One of these specs runs it on purpose.
RollFor.api.DEFAULT_CHAT_FRAME = { AddMessage = function() end }

local function run( args )
  calls = {}
  utils.run_command( "RF", args )
  return calls
end

RfCommandSpec = {}

function RfCommandSpec:should_route_the_subcommand_to_the_extension_that_registered_it()
  eq( run( "probe" ), { { name = "probe", args = "" } } )
end

-- Everything after the first word is handed over unparsed: what a subcommand's arguments
-- mean is the extension's business, not core's.
function RfCommandSpec:should_hand_over_everything_after_the_first_word()
  eq( run( "probe queue" ), { { name = "probe", args = "queue" } } )
  eq( run( "probe reset now" ), { { name = "probe", args = "reset now" } } )
end

function RfCommandSpec:should_not_route_a_word_that_merely_starts_the_same()
  eq( run( "probemachine" ), {} )
end

function RfCommandSpec:should_leave_an_unregistered_subcommand_alone()
  eq( run( "nonsense" ), {} )
end

RfCommandRefusalSpec = {}

-- Refused rather than shadowed: an extension quietly taking over /rf config would be a bug
-- nobody could see.
function RfCommandRefusalSpec:should_refuse_one_of_cores_own_subcommands()
  eq( run( "config" ), {} )
end

function RfCommandRefusalSpec:should_say_why_it_refused_each_one()
  eq( table.getn( complaints ), 3 )

  local reasons = {}
  for _, complaint in ipairs( complaints ) do
    table.insert( reasons, string.find( complaint, "RollFor's own", 1, true ) and "cores_own"
      or string.find( complaint, "single word", 1, true ) and "not_a_word"
      or string.find( complaint, "already taken", 1, true ) and "taken"
      or complaint )
  end

  eq( reasons, { "cores_own", "not_a_word", "taken" } )
end

-- The first registration stands. A second one losing silently would leave two extensions
-- disagreeing about who owns the command with nothing to say which won.
function RfCommandRefusalSpec:should_keep_the_first_registration_when_a_name_is_taken_twice()
  eq( run( "probe" ), { { name = "probe", args = "" } } )
end

os.exit( lu.LuaUnit.run() )
