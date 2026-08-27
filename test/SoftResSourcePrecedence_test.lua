---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )

-- Core registers its own soft-res as a source so that a user without a source extension
-- still has working soft-res. Registration is first-wins, so *where* core registers it
-- decides whether an extension can ever replace it: above Extensions.enable() and the
-- built-in always claims the slot, the `if not SoftResSource.get()` guard is dead code,
-- and an extension's register() is refused with "builtin is already registered".
--
-- That shipped once. Nothing caught it, because core's own soft-res kept working
-- perfectly -- the failure is only visible from an extension's side.

local EXTENSION = "source_probe"

utils.mock_wow_api()
utils.mock_libraries()
utils.load_real_stuff()

local Extensions = RollFor.Extensions
local SoftResSource = RollFor.SoftResSource

local probe_item = RollFor.SoftRes.softres_item_data( 123, 1 )

-- Deliberately not core's store: the six read methods over a literal, which is all a
-- source has to be.
local probe_store = {
  get = function() return {} end,
  get_all_rollers = function() return {} end,
  is_player_softressing = function() return false end,
  get_items = function() return { probe_item } end,
  get_hr_item_ids = function() return {} end,
  is_item_hardressed = function() return false end
}

-- Registered after the addon's files have loaded but before it builds its components,
-- which is the order the client produces: an extension addon runs at file scope, RollFor
-- builds at PLAYER_LOGIN.
Extensions.register( {
  name = EXTENSION,
  title = "Source Probe",
  api_version = Extensions.API_VERSION,
  on_enable = function( ctx )
    -- Anchored to names core does not add until after Extensions.enable() has run. Under
    -- add-time anchor resolution this threw, was swallowed by Extensions.run's pcall, and
    -- left the extension quietly disabled -- which is what would have happened to
    -- RollForNetherVortex in Phase C, since addons load alphabetically and it declares
    -- itself before RollForSoftResIt contributes the links it sits between.
    ctx.softres_chain.add( {
      name = "probe_link",
      after = "awarded_loot",
      before = "present_players",
      factory = function( inner ) return inner end
    } )

    ctx.softres_source.register( {
      id = "probe",
      title = "Source Probe",
      base = function() return probe_store end,
      has_data = function() return true end,
      get_import_string = function() return "probe-import-string" end
    } )
  end
} )

utils.player( "Psikutas" )

local rf = utils.load_roll_for()

SourcePrecedenceSpec = {}

function SourcePrecedenceSpec:should_let_an_extensions_source_win_over_cores_builtin()
  eq( SoftResSource.get().id, "probe" )
end

function SourcePrecedenceSpec:should_build_the_softres_chain_on_the_extensions_base()
  eq( SoftResSource.base(), probe_store )
  eq( rf.unfiltered_view.get_items(), { probe_item } )
end

-- What Gargul is answered with. Core's built-in would have replied with its own saved
-- string here.
function SourcePrecedenceSpec:should_answer_the_import_string_from_the_extension()
  eq( SoftResSource.get_import_string(), "probe-import-string" )
end

-- has_data() is what /rfsetup consults before refusing to run over real data.
function SourcePrecedenceSpec:should_answer_has_data_from_the_extension()
  eq( SoftResSource.has_data(), true )
end

ChainOrderingSpec = {}

function ChainOrderingSpec:should_place_an_extension_link_anchored_to_a_backbone_added_later()
  eq( rf.softres_chain.names(),
    { "matched_name", "awarded_loot", "probe_link", "present_players", "bonus_roll" } )
end

os.exit( lu.LuaUnit.run() )
