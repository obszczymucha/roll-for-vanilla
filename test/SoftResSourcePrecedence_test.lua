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
--
-- Since §5.0 the built-in is all-or-nothing: claiming the source slot means core adds no
-- backbone, no tap, no SoftResCheck, no gui and no /sr, so the probe below contributes
-- the backbone itself -- which is exactly what a real source extension has to do. The
-- chain the specs assert on is therefore entirely the extension's.

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
    -- Anchored to names that arrive later in this same on_enable. Under add-time anchor
    -- resolution this threw, was swallowed by Extensions.run's pcall, and left the
    -- extension quietly disabled -- which is what would have happened to
    -- RollForNetherVortex in Phase C, since addons load alphabetically and it declares
    -- itself before RollForSoftResIt contributes the links it sits between.
    ctx.softres_chain.add( {
      name = "probe_link",
      after = "awarded_loot",
      before = "present_players",
      factory = function( inner ) return inner end
    } )

    -- The backbone, contributed by the source rather than by core. Identity factories:
    -- these specs are about who owns the names and what order they land in, not about
    -- what the decorators do.
    ctx.softres_chain.add( { name = "matched_name", after = RollFor.Chain.BASE, factory = function( inner ) return inner end } )
    ctx.softres_chain.add( { name = "awarded_loot", after = "matched_name", factory = function( inner ) return inner end } )
    ctx.softres_chain.add( { name = "present_players", after = "awarded_loot", factory = function( inner ) return inner end } )
    ctx.softres_chain.tap( { name = "unfiltered", before = "present_players" } )

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

-- §5.0: core's built-in is all-or-nothing. Once an extension claims the source slot,
-- core contributes none of it -- not the store, not the matcher, not SoftResCheck, not
-- the gui, not the /sr family. Gating only the chain links was tried and fails at login:
-- SoftResCheck gets built on a nil "unfiltered" tap and core's minimap contribution dies
-- indexing it. These specs are what stops that half-measure coming back.
BuiltInSteppedAsideSpec = {}

function BuiltInSteppedAsideSpec:should_not_build_any_of_cores_softres_stack()
  eq( rf.softres_db, nil )
  eq( rf.unfiltered_softres, nil )
  eq( rf.name_matcher, nil )
  eq( rf.softres_check, nil )
  eq( rf.softres_gui, nil )
end

-- /src and /srs come from SoftResCheck.new, /sro from NameManualMatcher.new, /sr from
-- main.lua -- none of which ran, so none of them exist for the extension to collide with.
function BuiltInSteppedAsideSpec:should_not_register_the_slash_command_family()
  local commands = RollFor.api.SlashCmdList or {}

  eq( commands[ "SR" ], nil )
  eq( commands[ "SRO" ], nil )
  eq( commands[ "SRC" ], nil )
  eq( commands[ "SRS" ], nil )
end

-- The one core command that is not soft-res still registers, which is the point of the
-- extension being optional rather than load-bearing.
function BuiltInSteppedAsideSpec:should_still_register_cores_non_softres_commands()
  eq( type( (RollFor.api.SlashCmdList or {})[ "RFRESET" ] ), "function" )
end

-- Core's simulation subscriber imports into its own store, so it goes with the rest of
-- the built-in. /rfsetup's emit is still core's; answering it is the source's job.
function BuiltInSteppedAsideSpec:should_not_subscribe_to_simulation_started()
  eq( rf.event_bus.has_subscribers( "simulation_started" ), false )
end

-- Nothing painted the button, so nothing can index the SoftResCheck that was never built.
function BuiltInSteppedAsideSpec:should_not_contribute_to_the_minimap_button()
  eq( rf.minimap_contributions, {} )
end

ChainOrderingSpec = {}

function ChainOrderingSpec:should_place_an_extension_link_anchored_to_a_backbone_added_later()
  eq( rf.softres_chain.names(),
    { "matched_name", "awarded_loot", "probe_link", "present_players", "bonus_roll" } )
end

os.exit( lu.LuaUnit.run() )
