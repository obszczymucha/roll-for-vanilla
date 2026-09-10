package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua"

-- The roll-value seam.
--
-- `roll_pools` decides how many rolls a player gets; `roll_modifiers` decides what one is
-- worth. Core registers nothing in it, so everything below is about what happens when an
-- extension does -- and the first case is the one that matters most: an empty list has to
-- be today's behaviour exactly, or every existing suite is measuring the wrong thing.

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )

u.mock_wow_api()
require( "src/modules" )
require( "src/Types" )
require( "src/ItemUtils" )
require( "src/Ordering" )
local RLU = require( "src/RollingLogicUtils" )

local RS = RollFor.Types.RollingStrategy

-- Both built through core's own constructors, so they are the shapes a modifier is really
-- handed rather than the subset these cases happen to read.
---@type Item
local ITEM = RollFor.ItemUtils.make_item( 123, "Hearthstone", "[Hearthstone]", 4 )
---@type RollingPlayer
local PLAYER = RollFor.Types.make_rolling_player( "Psikutas", RollFor.Types.PlayerClass.Warrior, true, 1 )

local errors

local function capture_errors()
  errors = {}
  RollFor.api.DEFAULT_CHAT_FRAME = {
    AddMessage = function( _, message ) table.insert( errors, (u.decolorize( message )) ) end
  }
end

local function complained_about( fragment )
  for _, message in ipairs( errors ) do
    if string.find( message, fragment, 1, true ) then return true end
  end

  return false
end

-- Every spec built by `static` is a delta; a case wanting an adjust registers it itself.
local function reset( ... )
  RLU.clear_modifiers()
  capture_errors()

  for _, spec in ipairs( { ... } ) do RLU.register_delta( spec ) end
end

---@param name string
---@param amount number|fun( player: table, item: table ): number?
---@param rounds string[]?
local function static( name, amount, rounds )
  return {
    name = name,
    rounds = rounds or { RS.SoftResRoll },
    apply = type( amount ) == "function" and amount or function() return amount end
  }
end

RegistrationSpec = {}

function RegistrationSpec:should_accept_a_delta_modifier()
  reset()
  eq( RLU.register_delta( static( "sr_plus", 30 ) ), true )
end

function RegistrationSpec:should_accept_an_adjust_modifier()
  reset()

  eq( RLU.register_adjust( {
    name = "cap",
    rounds = { RS.SoftResRoll },
    apply = function() return 0 end
  } ), true )
end

-- There is no case here for "declared both" or "declared neither". Neither is a shape you
-- can write: the kind is which registrar you called, and each spec carries exactly one
-- `apply`. That is the point of there being two of them.
function RegistrationSpec:should_take_its_kind_from_the_registrar_it_came_in_through()
  reset()

  RLU.register_adjust( {
    name = "cap",
    rounds = { RS.SoftResRoll },
    apply = function( _, _, _, current ) return current > 100 and 100 - current or 0 end
  } )

  -- It applies...
  eq( RLU.apply_modifiers( PLAYER, ITEM, 120, RS.SoftResRoll ), 100 )

  -- ...and it is not previewable, because an adjust never is.
  eq( RLU.preview_adjustments( PLAYER, ITEM, RS.SoftResRoll ), nil )
end

function RegistrationSpec:should_refuse_something_that_is_not_a_table()
  reset()
  -- The wrong type is the point of the case.
  ---@diagnostic disable-next-line: param-type-mismatch
  eq( RLU.register_delta( "sr_plus" ), false )
  eq( complained_about( "must be a table" ), true )
end

function RegistrationSpec:should_refuse_a_missing_name()
  reset()
  -- The missing name is the point of the case.
  ---@diagnostic disable-next-line: missing-fields
  eq( RLU.register_delta( { rounds = { RS.SoftResRoll }, apply = function() end } ), false )
  eq( complained_about( "'name' must be a non-empty string" ), true )
end

function RegistrationSpec:should_refuse_a_duplicate_name()
  reset( static( "sr_plus", 30 ) )

  eq( RLU.register_delta( static( "sr_plus", 10 ) ), false )
  eq( complained_about( "already registered" ), true )
end

-- One namespace across both kinds: `by` in a RollAdjustment says which modifier made it,
-- and two of them answering to one name would make that unreadable.
function RegistrationSpec:should_refuse_a_duplicate_name_across_the_two_registrars()
  reset( static( "sr_plus", 30 ) )

  eq( RLU.register_adjust( { name = "sr_plus", rounds = { RS.SoftResRoll }, apply = function() end } ), false )
  eq( complained_about( "already registered" ), true )
end

function RegistrationSpec:should_refuse_a_modifier_that_takes_part_in_no_round()
  reset()
  eq( RLU.register_delta( { name = "sr_plus", rounds = {}, apply = function() end } ), false )
  eq( complained_about( "'rounds' must name at least one round" ), true )
end

function RegistrationSpec:should_refuse_an_apply_that_is_not_a_function()
  reset()
  -- The apply that is not a function is the point of the case.
  ---@diagnostic disable-next-line: assign-type-mismatch
  eq( RLU.register_delta( { name = "sr_plus", rounds = { RS.SoftResRoll }, apply = 30 } ), false )
  eq( complained_about( "'apply' must be a function" ), true )
end

ApplySpec = {}

-- The line every existing suite in this repo depends on.
function ApplySpec:should_leave_a_roll_alone_with_nothing_registered()
  reset()

  local total, adjustments = RLU.apply_modifiers( PLAYER, ITEM, 89, RS.SoftResRoll )

  eq( total, 89 )
  eq( adjustments, nil )
end

function ApplySpec:should_add_a_static_delta_and_record_it()
  reset( static( "sr_plus", 30 ) )

  local total, adjustments = RLU.apply_modifiers( PLAYER, ITEM, 89, RS.SoftResRoll )

  eq( total, 119 )
  eq( adjustments, { { by = "sr_plus", delta = 30 } } )
end

function ApplySpec:should_subtract_a_negative_delta()
  reset( static( "penalty", -15 ) )

  local total, adjustments = RLU.apply_modifiers( PLAYER, ITEM, 89, RS.SoftResRoll )

  eq( total, 74 )
  eq( adjustments, { { by = "penalty", delta = -15 } } )
end

-- 0 is truthy in Lua, so without the guard this would record an adjustment and the raid
-- would be told "89+0=89".
function ApplySpec:should_ignore_a_zero_delta()
  reset( static( "sr_plus", 0 ) )

  local total, adjustments = RLU.apply_modifiers( PLAYER, ITEM, 89, RS.SoftResRoll )

  eq( total, 89 )
  eq( adjustments, nil )
end

-- A modifier with nothing to say about this player answers nil rather than 0, and either
-- way it contributes nothing.
function ApplySpec:should_ignore_a_modifier_with_no_opinion()
  reset( static( "sr_plus", function() return nil end ) )

  local total, adjustments = RLU.apply_modifiers( PLAYER, ITEM, 89, RS.SoftResRoll )

  eq( total, 89 )
  eq( adjustments, nil )
end

function ApplySpec:should_keep_a_modifier_out_of_a_round_it_did_not_declare()
  reset( static( "sr_plus", 30, { RS.SoftResRoll } ) )

  eq( RLU.apply_modifiers( PLAYER, ITEM, 89, RS.TieRoll ), 89 )
  eq( RLU.apply_modifiers( PLAYER, ITEM, 89, RS.NormalRoll ), 89 )
  eq( RLU.apply_modifiers( PLAYER, ITEM, 89, RS.SoftResRoll ), 119 )
end

function ApplySpec:should_let_a_modifier_take_part_in_several_rounds()
  reset( static( "role_bonus", 20, { RS.SoftResRoll, RS.NormalRoll, RS.TieRoll } ) )

  eq( RLU.apply_modifiers( PLAYER, ITEM, 40, RS.TieRoll ), 60 )
  eq( RLU.apply_modifiers( PLAYER, ITEM, 40, RS.NormalRoll ), 60 )
end

-- The player and the item, and nothing else. That is what makes a delta previewable.
function ApplySpec:should_give_a_delta_the_player_and_the_item()
  local seen = {}
  reset( static( "sr_plus", function( player, item )
    seen = { player.name, item.id }
    return 5
  end ) )

  RLU.apply_modifiers( PLAYER, ITEM, 89, RS.SoftResRoll )

  eq( seen, { "Psikutas", 123 } )
end

-- The base roll and the running total, which is the pair a percentage or a cap needs.
function ApplySpec:should_give_an_adjust_the_base_roll_and_the_running_total()
  local seen

  reset( static( "sr_plus", 30 ) )

  RLU.register_adjust( {
    name = "cap",
    rounds = { RS.SoftResRoll },
    after = "sr_plus",
    apply = function( _, _, base, current )
      seen = { base, current }
      return current > 100 and 100 - current or 0
    end
  } )

  local total, adjustments = RLU.apply_modifiers( PLAYER, ITEM, 89, RS.SoftResRoll )

  eq( seen, { 89, 119 } )
  eq( total, 100 )
  eq( adjustments, { { by = "sr_plus", delta = 30 }, { by = "cap", delta = -19 } } )
end

AccumulationSpec = {}

-- The property the seam exists for: neither modifier knows the other is there, and core
-- knows what neither of them does.
function AccumulationSpec:should_accumulate_two_static_modifiers()
  reset( static( "sr_plus", 30 ), static( "role_bonus", 20 ) )

  local total, adjustments = RLU.apply_modifiers( PLAYER, ITEM, 50, RS.SoftResRoll )

  eq( total, 100 )
  eq( adjustments, { { by = "sr_plus", delta = 30 }, { by = "role_bonus", delta = 20 } } )
end

-- Addition commutes, so registration order changes the order they are listed in and
-- nothing else. It stops being free the moment somebody writes an `adjust`, which is why
-- the order is pinned rather than left to load order.
function AccumulationSpec:should_reach_the_same_total_whichever_order_they_registered_in()
  reset( static( "role_bonus", 20 ), static( "sr_plus", 30 ) )

  local total, adjustments = RLU.apply_modifiers( PLAYER, ITEM, 50, RS.SoftResRoll )

  eq( total, 100 )
  eq( adjustments, { { by = "role_bonus", delta = 20 }, { by = "sr_plus", delta = 30 } } )
end

OrderingSpec = {}

-- Ordering.place, the same vocabulary a soft-res chain link or a loot handler already uses.
-- role_bonus registered first, sr_plus anchored in front of it: the anchor wins, not the
-- registration order.
function OrderingSpec:should_honour_a_before_anchor()
  reset(
    static( "role_bonus", 20 ),
    { name = "sr_plus", rounds = { RS.SoftResRoll }, before = "role_bonus", apply = function() return 30 end } )

  local _, adjustments = RLU.apply_modifiers( PLAYER, ITEM, 50, RS.SoftResRoll )

  eq( adjustments, { { by = "sr_plus", delta = 30 }, { by = "role_bonus", delta = 20 } } )
end

function OrderingSpec:should_complain_about_an_anchor_that_is_not_there()
  reset( { name = "sr_plus", rounds = { RS.SoftResRoll }, after = "nobody", apply = function() return 30 end } )

  RLU.apply_modifiers( PLAYER, ITEM, 50, RS.SoftResRoll )

  eq( complained_about( "anchored after 'nobody'" ), true )
end

PreviewSpec = {}

function PreviewSpec:should_answer_nothing_with_nothing_registered()
  reset()
  eq( RLU.preview_adjustments( PLAYER, ITEM, RS.SoftResRoll ), nil )
  eq( RLU.format_preview_annotation( PLAYER, ITEM, RS.SoftResRoll ), "" )
end

function PreviewSpec:should_answer_what_a_static_modifier_would_add()
  reset( static( "sr_plus", 30 ) )

  eq( RLU.preview_adjustments( PLAYER, ITEM, RS.SoftResRoll ), { { by = "sr_plus", delta = 30 } } )
  eq( RLU.format_preview_annotation( PLAYER, ITEM, RS.SoftResRoll ), " (+30)" )
end

-- One number, not two: the breakdown is left to the winner announcement, where there is
-- room for it.
function PreviewSpec:should_sum_several_static_modifiers_into_one_annotation()
  reset( static( "sr_plus", 30 ), static( "role_bonus", 20 ) )

  eq( RLU.format_preview_annotation( PLAYER, ITEM, RS.SoftResRoll ), " (+50)" )
end

function PreviewSpec:should_show_a_negative_total()
  reset( static( "penalty", -15 ) )

  eq( RLU.format_preview_annotation( PLAYER, ITEM, RS.SoftResRoll ), " (-15)" )
end

-- Two that cancel out are worth nothing to say, the same as none at all.
function PreviewSpec:should_say_nothing_when_the_modifiers_cancel_out()
  reset( static( "sr_plus", 30 ), static( "penalty", -30 ) )

  eq( RLU.format_preview_annotation( PLAYER, ITEM, RS.SoftResRoll ), "" )
end

-- A dynamic modifier depends on the roll and has nothing to say before there is one. It
-- must not pretend otherwise.
function PreviewSpec:should_leave_a_dynamic_modifier_out_of_the_preview()
  reset( static( "sr_plus", 30 ) )
  RLU.register_adjust( { name = "cap", rounds = { RS.SoftResRoll }, apply = function() return -19 end } )

  eq( RLU.preview_adjustments( PLAYER, ITEM, RS.SoftResRoll ), { { by = "sr_plus", delta = 30 } } )
  eq( RLU.format_preview_annotation( PLAYER, ITEM, RS.SoftResRoll ), " (+30)" )
end

function PreviewSpec:should_respect_rounds()
  reset( static( "sr_plus", 30, { RS.SoftResRoll } ) )

  eq( RLU.format_preview_annotation( PLAYER, ITEM, RS.TieRoll ), "" )
end

os.exit( lu.LuaUnit.run() )
