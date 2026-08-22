package.path = "./?.lua;" .. package.path .. ";../../?.lua;../../RollFor/?.lua;../../RollFor/libs/?.lua"

require( "src/bcc/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
local ResistanceRegistry = require( "src/resistances/ResistanceRegistry" )

local Shadow = ResistanceRegistry.ResistanceType.Shadow
local Fire = ResistanceRegistry.ResistanceType.Fire

local registry = ResistanceRegistry.new()

local function shadow( ... )
  return registry.resolve( { ... } )[ Shadow ]
end

local function fire( ... )
  return registry.resolve( { ... } )[ Fire ]
end

local SP = "Shadow Protection"
local PRAYER = "Prayer of Shadow Protection"
local SHADOW_AURA = "Shadow Resistance Aura"
local FIRE_AURA = "Fire Resistance Aura"
local MOTW = "Mark of the Wild"
local GOTW = "Gift of the Wild"
local FLASK = "Flask of Chromatic Wonder"
local NOISE = "Power Word: Fortitude"

ShadowResistanceSpec = {}

function ShadowResistanceSpec:should_grant_70_for_any_of_the_shadow_buffs()
  eq( shadow( SP ), 70 )
  eq( shadow( PRAYER ), 70 )
  eq( shadow( SHADOW_AURA ), 70 )
end

function ShadowResistanceSpec:should_not_stack_the_shadow_buffs_with_each_other()
  eq( shadow( SP, SHADOW_AURA ), 70 )
  eq( shadow( SP, PRAYER, SHADOW_AURA ), 70 )
end

function ShadowResistanceSpec:should_fall_back_to_the_wild_buff()
  eq( shadow( MOTW ), 25 )
  eq( shadow( GOTW ), 25 )
  eq( shadow( MOTW, GOTW ), 25 )
end

function ShadowResistanceSpec:should_ignore_the_wild_buff_when_a_shadow_buff_is_up()
  eq( shadow( SP, MOTW ), 70 )
  eq( shadow( SHADOW_AURA, GOTW ), 70 )
end

function ShadowResistanceSpec:should_stack_the_flask_on_top_of_anything()
  eq( shadow( FLASK ), 35 )
  eq( shadow( PRAYER, FLASK ), 105 )
  eq( shadow( MOTW, FLASK ), 60 )
end

function ShadowResistanceSpec:should_be_zero_when_unbuffed()
  eq( shadow(), 0 )
  eq( shadow( NOISE ), 0 )
end

FireResistanceSpec = {}

function FireResistanceSpec:should_grant_70_for_the_paladin_aura()
  eq( fire( FIRE_AURA ), 70 )
end

function FireResistanceSpec:should_fall_back_to_the_wild_buff()
  eq( fire( MOTW ), 25 )
  eq( fire( GOTW ), 25 )
end

function FireResistanceSpec:should_ignore_the_wild_buff_when_the_aura_is_up()
  eq( fire( FIRE_AURA, MOTW ), 70 )
end

function FireResistanceSpec:should_stack_the_flask_on_top_of_anything()
  eq( fire( FLASK ), 35 )
  eq( fire( FIRE_AURA, FLASK ), 105 )
  eq( fire( MOTW, FLASK ), 60 )
end

function FireResistanceSpec:should_be_zero_when_unbuffed()
  eq( fire(), 0 )
  eq( fire( NOISE ), 0 )
end

function FireResistanceSpec:should_not_be_granted_by_the_shadow_buffs()
  eq( fire( SP ), 0 )
  eq( fire( PRAYER ), 0 )
  eq( fire( SHADOW_AURA ), 0 )
end

BothSchoolsSpec = {}

function BothSchoolsSpec:should_resolve_each_school_independently()
  -- Given
  local result = registry.resolve( { PRAYER, MOTW, FLASK, NOISE } )

  -- Then: the priest buff covers shadow, Mark of the Wild still carries fire,
  -- and the flask adds to both.
  eq( result, { [ Shadow ] = 105, [ Fire ] = 60 } )
end

function BothSchoolsSpec:should_cover_both_schools_with_the_wild_buff()
  -- Given
  local result = registry.resolve( { GOTW } )

  -- Then
  eq( result, { [ Shadow ] = 25, [ Fire ] = 25 } )
end

DefaultReportedTypeSpec = {}

function DefaultReportedTypeSpec:should_report_shadow_by_default()
  local reported_type, value = registry.default_reported_type( { [ Shadow ] = 60, [ Fire ] = 40 } )

  eq( reported_type, Shadow )
  eq( value, 60 )
end

function DefaultReportedTypeSpec:should_report_fire_when_the_unit_is_in_a_fire_set()
  local reported_type, value = registry.default_reported_type( { [ Shadow ] = 0, [ Fire ] = 151 } )

  eq( reported_type, Fire )
  eq( value, 151 )
end

function DefaultReportedTypeSpec:should_stay_on_shadow_at_the_threshold()
  local reported_type, value = registry.default_reported_type( { [ Shadow ] = 10, [ Fire ] = 150 } )

  eq( reported_type, Shadow )
  eq( value, 10 )
end

function DefaultReportedTypeSpec:should_honour_a_custom_threshold()
  eq( registry.default_reported_type( { [ Shadow ] = 10, [ Fire ] = 60 }, 50 ), Fire )
end

os.exit( lu.LuaUnit.run() )
