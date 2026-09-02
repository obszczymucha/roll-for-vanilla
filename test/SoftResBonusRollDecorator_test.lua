package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types", "SoftResDataTransformer" )
require( "src/modules" )
require( "src/AutoLootDb" )
local Db = require( "src/Db" )
local SoftRes = require( "src/SoftRes" )
local ResistanceBonusRollRegistry = require( "src/resistances/ResistanceBonusRollRegistry" )
local SoftResBonusRollDecorator = require( "src/SoftResBonusRollDecorator" )
local sid = SoftRes.softres_item_data

u.mock_wow_api()

local SHAHRAZ = "Mother Shahraz"
local COUNCIL = "The Illidari Council"
local ILLIDAN = "Illidan Stormrage"

local SHAHRAZ_ITEM = 32370  -- Nadina's Pendant of Purity
local COUNCIL_ITEM = 32331  -- Cloak of the Illidari Council
local SUPREMUS_ITEM = 32250 -- Black Temple, but not a granting boss

-- The decorator's job is to add a number to what the wrapped softres already returned,
-- so the thing it wraps is a stub that hands back exactly what the test says.
---@param rollers table[]
local function stub_softres( rollers )
  local stored = rollers

  return {
    get = function() return u.clone( stored ) end,
    get_all_rollers = function() return u.clone( stored ) end,
    stored = function() return stored end
  }
end

---@param enabled boolean?
local function stub_config( enabled )
  return {
    resistance_bonus_rolls_enabled = function()
      if enabled == nil then return true end
      return enabled
    end
  }
end

---@param name string
---@param rolls number?
local function roller( name, rolls )
  return { name = name, rolls = rolls or 1, class = "Warrior", type = "Roller" }
end

-- Grants are written straight into the registry below, so its two collaborators are inert:
-- it only ever subscribes to the kill feed and reads eligibility's rows, and neither has
-- anything to say here.
---@return BossKilled
local function inert_boss_killed()
  ---@diagnostic disable-next-line: missing-fields
  return { subscribe = function() end }
end

---@return ResistanceBonusRollEligibility
local function inert_eligibility()
  ---@diagnostic disable-next-line: missing-fields
  return { get_rows = function() return {} end }
end

---@param grants table<string, string[]>
local function registry( grants )
  local saved = {}
  local result = ResistanceBonusRollRegistry.new( Db.new( saved )( "registry" ), inert_boss_killed(), inert_eligibility() )

  for player_name, bosses in pairs( grants or {} ) do
    for _, boss_name in ipairs( bosses ) do
      result.grant( player_name, boss_name, "Warrior" )
    end
  end

  return result
end

---@param rollers table[]
---@param grants table<string, string[]>?
---@param enabled boolean?
local function decorator( rollers, grants, enabled )
  local softres = stub_softres( rollers )
  local sut = SoftResBonusRollDecorator.new( softres, registry( grants ), stub_config( enabled ) )
  sut.wrapped = softres

  return sut
end

SoftResBonusRollDecoratorSpec = {}

function SoftResBonusRollDecoratorSpec:should_annotate_each_soft_resser_with_their_bonus_rolls()
  -- Given
  local sut = decorator(
    { roller( "Drutree" ), roller( "Mendunia" ) },
    { Drutree = { SHAHRAZ, COUNCIL }, Mendunia = { COUNCIL } } )

  -- When
  local result = sut.get( sid( COUNCIL_ITEM, 1 ) )

  -- Then
  eq( result, {
    { name = "Drutree", rolls = 1, bonus_rolls = 2, class = "Warrior", type = "Roller" },
    { name = "Mendunia", rolls = 1, bonus_rolls = 1, class = "Warrior", type = "Roller" }
  } )
end

-- A bonus roll is never a ticket into a roll the player wasn't already in: the decorator
-- only ever annotates who the wrapped softres already returned.
function SoftResBonusRollDecoratorSpec:should_not_add_a_player_who_did_not_soft_res()
  -- Given
  local sut = decorator( { roller( "Drutree" ) }, { Drutree = { ILLIDAN }, Mendunia = { ILLIDAN } } )

  -- When
  local result = sut.get( sid( COUNCIL_ITEM, 1 ) )

  -- Then
  eq( u.map( result, function( p ) return p.name end ), { "Drutree" } )
end

function SoftResBonusRollDecoratorSpec:should_annotate_zero_for_an_item_from_a_boss_that_grants_nothing()
  -- Given
  local sut = decorator( { roller( "Drutree" ) }, { Drutree = { SHAHRAZ } } )

  -- When
  local result = sut.get( sid( SUPREMUS_ITEM, 1 ) )

  -- Then
  eq( result, { { name = "Drutree", rolls = 1, bonus_rolls = 0, class = "Warrior", type = "Roller" } } )
end

function SoftResBonusRollDecoratorSpec:should_annotate_zero_for_a_player_holding_only_later_ranked_rolls()
  -- Given
  local sut = decorator( { roller( "Drutree" ) }, { Drutree = { COUNCIL } } )

  -- When
  local result = sut.get( sid( SHAHRAZ_ITEM, 1 ) )

  -- Then
  eq( result, { { name = "Drutree", rolls = 1, bonus_rolls = 0, class = "Warrior", type = "Roller" } } )
end

function SoftResBonusRollDecoratorSpec:should_annotate_nothing_when_the_feature_is_off()
  -- Given
  local sut = decorator( { roller( "Drutree" ) }, { Drutree = { SHAHRAZ } }, false )

  -- When
  local result = sut.get( sid( SHAHRAZ_ITEM, 1 ) )

  -- Then
  eq( result, { { name = "Drutree", rolls = 1, class = "Warrior", type = "Roller" } } )
end

function SoftResBonusRollDecoratorSpec:should_not_touch_the_stored_soft_res_data()
  -- SoftRes.get hands back a clone, so annotating in place is safe -- but only as long as
  -- that stays true, which is what this pins.
  -- Given
  local sut = decorator( { roller( "Drutree" ) }, { Drutree = { SHAHRAZ } } )

  -- When
  sut.get( sid( SHAHRAZ_ITEM, 1 ) )

  -- Then
  eq( sut.wrapped.stored(), { { name = "Drutree", rolls = 1, class = "Warrior", type = "Roller" } } )
end

function SoftResBonusRollDecoratorSpec:should_pass_everything_else_through_to_the_wrapped_softres()
  -- Given
  local sut = decorator( { roller( "Drutree" ) }, { Drutree = { SHAHRAZ } } )

  -- Then (get_all_rollers is not the bonus-roll path and must stay untouched)
  eq( sut.get_all_rollers(), { { name = "Drutree", rolls = 1, class = "Warrior", type = "Roller" } } )
end

os.exit( lu.LuaUnit.run( "-v", "-T", "Spec", "-m", "should", "-o", "text" ) )
