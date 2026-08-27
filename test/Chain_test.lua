---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local utils = require( "test/utils" )
local lu, eq = utils.luaunit( "assertEquals" )
require( "src/modules" )
local Chain = require( "src/Chain" )

-- Links that wrap a string, so the built value spells out the order they ran in. A chain
-- that stacked wrongly is otherwise indistinguishable from one that stacked correctly:
-- both produce something with the right interface.
---@param label string
local function wrap( label )
  return function( inner ) return string.format( "%s(%s)", label, inner ) end
end

-- A value that is deliberately not a ChainLink. Typed as `any` because that is exactly
-- what add() accepts: it takes whatever it is given and decides. The name says why the
-- checker has nothing to flag here.
---@param value any
---@return any
local function malformed( value )
  return value
end

---@param chain Chain
---@param name string
---@param anchors table?
local function link( chain, name, anchors )
  local definition = { name = name, factory = wrap( name ) }

  for key, value in pairs( anchors or {} ) do definition[ key ] = value end

  chain.add( definition )
end

ChainOrderSpec = {}

function ChainOrderSpec:should_build_the_base_alone_when_there_are_no_links()
  local chain = Chain.new( "test" )

  eq( chain.build( "base" ).final, "base" )
end

function ChainOrderSpec:should_stack_unanchored_links_in_registration_order()
  local chain = Chain.new( "test" )
  link( chain, "one" )
  link( chain, "two" )

  eq( chain.build( "base" ).final, "two(one(base))" )
end

function ChainOrderSpec:should_put_a_link_anchored_after_base_at_the_bottom()
  local chain = Chain.new( "test" )
  link( chain, "one" )
  link( chain, "two", { after = Chain.BASE } )

  eq( chain.build( "base" ).final, "one(two(base))" )
end

function ChainOrderSpec:should_insert_a_link_after_a_named_link()
  local chain = Chain.new( "test" )
  link( chain, "one" )
  link( chain, "three" )
  link( chain, "two", { after = "one" } )

  eq( chain.build( "base" ).final, "three(two(one(base)))" )
end

function ChainOrderSpec:should_insert_a_link_before_a_named_link()
  local chain = Chain.new( "test" )
  link( chain, "one" )
  link( chain, "three" )
  link( chain, "two", { before = "three" } )

  eq( chain.build( "base" ).final, "three(two(one(base)))" )
end

-- The soft-res case: an extension knows it belongs between two core links and says so.
function ChainOrderSpec:should_honour_both_anchors_at_once()
  local chain = Chain.new( "test" )
  link( chain, "awarded_loot" )
  link( chain, "present_players", { after = "awarded_loot" } )
  link( chain, "nether_vortex", { after = "awarded_loot", before = "present_players" } )

  eq( chain.build( "sr" ).final, "present_players(nether_vortex(awarded_loot(sr)))" )
end

function ChainOrderSpec:should_break_ties_between_two_links_wanting_the_same_slot_by_registration_order()
  local chain = Chain.new( "test" )
  link( chain, "core" )
  link( chain, "first", { after = "core" } )
  link( chain, "second", { after = "core" } )

  eq( chain.build( "base" ).final, "first(second(core(base)))" )
end

function ChainOrderSpec:should_report_the_link_names_in_order()
  local chain = Chain.new( "test" )
  link( chain, "one" )
  link( chain, "two", { after = Chain.BASE } )

  eq( chain.names(), { "two", "one" } )
  eq( chain.has( "one" ), true )
  eq( chain.has( Chain.BASE ), true )
  eq( chain.has( "nope" ), false )
end

ChainTapSpec = {}

function ChainTapSpec:should_capture_the_value_before_a_link()
  local chain = Chain.new( "test" )
  link( chain, "awarded_loot" )
  link( chain, "present_players", { after = "awarded_loot" } )
  chain.tap( { name = "unfiltered", before = "present_players" } )

  eq( chain.build( "sr" ).tap( "unfiltered" ), "awarded_loot(sr)" )
end

function ChainTapSpec:should_capture_the_value_after_a_link()
  local chain = Chain.new( "test" )
  link( chain, "one" )
  link( chain, "two" )
  chain.tap( { name = "halfway", after = "one" } )

  eq( chain.build( "base" ).tap( "halfway" ), "one(base)" )
end

function ChainTapSpec:should_capture_the_base_itself()
  local chain = Chain.new( "test" )
  link( chain, "one" )
  chain.tap( { name = "raw", after = Chain.BASE } )

  eq( chain.build( "base" ).tap( "raw" ), "base" )
end

function ChainTapSpec:should_capture_the_end_of_the_chain_when_unanchored()
  local chain = Chain.new( "test" )
  link( chain, "one" )
  chain.tap( { name = "final" } )

  eq( chain.build( "base" ).tap( "final" ), "one(base)" )
end

-- The point of taps: what "unfiltered" means belongs to core, so it keeps meaning the
-- same thing whether or not an extension put a link underneath it.
function ChainTapSpec:should_keep_its_meaning_when_an_extension_inserts_below_it()
  local function build( extended )
    local chain = Chain.new( "test" )
    link( chain, "awarded_loot" )
    link( chain, "present_players", { after = "awarded_loot" } )
    chain.tap( { name = "unfiltered", before = "present_players" } )

    if extended then link( chain, "nether_vortex", { after = "awarded_loot", before = "present_players" } ) end

    return chain.build( "sr" ).tap( "unfiltered" )
  end

  eq( build( false ), "awarded_loot(sr)" )
  eq( build( true ), "nether_vortex(awarded_loot(sr))" )
end

ChainErrorSpec = {}

---@param f fun()
---@param expected string
local function should_fail_with( f, expected )
  local ok, err = pcall( f )

  eq( ok, false )

  if not string.find( tostring( err ), expected, 1, true ) then
    lu.fail( string.format( "Expected the error to mention %q, got: %s", expected, tostring( err ) ) )
  end
end

-- A soft-res chain that silently appended a link it could not place would make wrong
-- loot decisions that nobody would trace back to the chain.
function ChainErrorSpec:should_refuse_an_unknown_after_anchor()
  local chain = Chain.new( "softres" )

  should_fail_with( function() link( chain, "mine", { after = "nope" } ) end,
    "anchored after 'nope', which is not in the chain" )
end

function ChainErrorSpec:should_refuse_an_unknown_before_anchor()
  local chain = Chain.new( "softres" )

  should_fail_with( function() link( chain, "mine", { before = "nope" } ) end,
    "anchored before 'nope', which is not in the chain" )
end

function ChainErrorSpec:should_name_the_chain_and_list_what_it_could_have_anchored_to()
  local chain = Chain.new( "softres" )
  link( chain, "awarded_loot" )

  should_fail_with( function() link( chain, "mine", { after = "nope" } ) end, "RollFor chain 'softres'" )
  should_fail_with( function() link( chain, "mine", { after = "nope" } ) end, "Known: base, awarded_loot." )
end

function ChainErrorSpec:should_refuse_contradictory_anchors()
  local chain = Chain.new( "softres" )
  link( chain, "one" )
  link( chain, "two", { after = "one" } )

  should_fail_with( function() link( chain, "mine", { after = "two", before = "one" } ) end,
    "cannot be both after 'two' and before 'one'" )
end

function ChainErrorSpec:should_refuse_a_duplicate_link_name()
  local chain = Chain.new( "softres" )
  link( chain, "one" )

  should_fail_with( function() link( chain, "one" ) end, "link 'one' is already in the chain" )
end

function ChainErrorSpec:should_refuse_the_reserved_base_name()
  local chain = Chain.new( "softres" )

  should_fail_with( function() link( chain, Chain.BASE ) end, "is a reserved link name" )
end

function ChainErrorSpec:should_refuse_a_link_without_a_factory()
  local chain = Chain.new( "softres" )

  should_fail_with( function() chain.add( malformed( { name = "mine" } ) ) end,
    "must have a 'factory' function" )
end

function ChainErrorSpec:should_refuse_a_duplicate_tap_name()
  local chain = Chain.new( "softres" )
  chain.tap( { name = "unfiltered" } )

  should_fail_with( function() chain.tap( { name = "unfiltered" } ) end, "tap 'unfiltered' is already declared" )
end

function ChainErrorSpec:should_refuse_a_tap_anchored_to_a_link_that_never_arrived()
  local chain = Chain.new( "softres" )
  chain.tap( { name = "unfiltered", before = "present_players" } )

  should_fail_with( function() chain.build( "sr" ) end,
    "tap 'unfiltered' is anchored before 'present_players', which is not in the chain" )
end

function ChainErrorSpec:should_refuse_a_factory_that_returns_nothing()
  local chain = Chain.new( "softres" )
  chain.add( { name = "mine", factory = function() return nil end } )

  should_fail_with( function() chain.build( "sr" ) end, "the factory for link 'mine' returned nil" )
end

function ChainErrorSpec:should_refuse_to_build_on_nothing()
  local chain = Chain.new( "softres" )

  should_fail_with( function() chain.build( nil ) end, "cannot build on a nil base" )
end

function ChainErrorSpec:should_refuse_an_unknown_tap_lookup()
  local chain = Chain.new( "softres" )
  local built = chain.build( "sr" )

  should_fail_with( function() return built.tap( "nope" ) end, "there is no tap called 'nope'" )
end

os.exit( lu.LuaUnit.run() )
