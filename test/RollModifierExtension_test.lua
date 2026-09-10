---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

-- The seam as an extension actually reaches it.
--
-- RollModifiers_test drives RollingLogicUtils directly, which proves the fold. This proves
-- the wiring: that `ctx.roll_modifier.register` exists on the context core hands out, that
-- a modifier registered from on_enable is in play by the time anybody rolls, and that a
-- *disabled* extension contributes nothing -- which is the mechanism, not a special case.

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )

utils.mock_wow_api()
utils.mock_libraries()
utils.load_real_stuff()

local Extensions = RollFor.Extensions
local RS = RollFor.Types.RollingStrategy

-- What the extension saw, and what it managed to register.
local seen = { registered = nil, context_field = nil }

Extensions.register( {
  name = "modifier_probe",
  title = "Modifier Probe",
  api_version = Extensions.API_VERSION,
  on_enable = function( ctx )
    seen.context_field = type( ctx.roll_modifier ) == "table" and type( ctx.roll_modifier.register ) == "function"

    seen.registered = ctx.roll_modifier.register( {
      name = "probe_bonus",
      rounds = { RS.SoftResRoll },
      delta = function( player ) return player.name == "Psikutas" and 30 or nil end
    } )
  end
} )

Extensions.register( {
  name = "disabled_modifier_probe",
  title = "Disabled Modifier Probe",
  api_version = Extensions.API_VERSION,
  default_enabled = false,
  on_enable = function( ctx )
    ctx.roll_modifier.register( {
      name = "should_never_be_registered",
      rounds = { RS.SoftResRoll },
      delta = function() return 100 end
    } )
  end
} )

RollFor.RollingLogicUtils.clear_modifiers()
utils.player( "Psikutas" )

local RLU = RollFor.RollingLogicUtils
local ITEM = { id = 123, name = "Hearthstone" }

ContextSpec = {}

function ContextSpec:should_offer_roll_modifier_on_the_extension_context()
  eq( seen.context_field, true )
end

function ContextSpec:should_have_accepted_the_registration()
  eq( seen.registered, true )
end

-- The API number an extension has to declare to see the field at all. Bumping it is what
-- keeps an extension written against this seam from half-loading on an older RollFor.
function ContextSpec:should_have_arrived_in_api_version_4()
  eq( Extensions.API_VERSION, 4 )
end

EffectSpec = {}

function EffectSpec:should_apply_the_registered_modifier()
  local total, adjustments = RLU.apply_modifiers( { name = "Psikutas", rolls = 1 }, ITEM, 50, RS.SoftResRoll )

  eq( total, 80 )
  eq( adjustments, { { by = "probe_bonus", delta = 30 } } )
end

function EffectSpec:should_leave_a_player_the_modifier_has_no_opinion_about_alone()
  eq( RLU.apply_modifiers( { name = "Obszczymucha", rolls = 1 }, ITEM, 50, RS.SoftResRoll ), 50 )
end

-- on_enable does not run for a disabled extension, so its modifier never arrives. No flag
-- to keep in step with the checkbox, and nothing to unregister.
function EffectSpec:should_not_have_registered_the_disabled_extensions_modifier()
  eq( RLU.apply_modifiers( { name = "Psikutas", rolls = 1 }, ITEM, 50, RS.SoftResRoll ), 80 )
end

os.exit( lu.LuaUnit.run() )
