package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
require( "src/modules" )
local Tree = require( "src/Tree" )

TreeSpec = {}

function TreeSpec:should_create_a_branch_node_with_the_given_data_and_children()
  local child = Tree.new_leaf( { id = 1 } )
  local node = Tree.new_node( { name = "Boss" }, { child } )

  eq( node.data, { name = "Boss" } )
  eq( node.children, { child } )
end

function TreeSpec:should_create_a_leaf_node_with_no_children()
  local node = Tree.new_leaf( { id = 1 } )

  eq( node.data, { id = 1 } )
  eq( node.children, nil )
end

TreeWalkSpec = {}

function TreeWalkSpec:should_visit_every_node_in_depth_first_order_by_default()
  local grandchild = Tree.new_leaf( { name = "grandchild" } )
  local child = Tree.new_node( { name = "child" }, { grandchild } )
  local root = Tree.new_node( { name = "root" }, { child } )

  local visited = {}
  Tree.walk( { root }, nil, function( node ) table.insert( visited, node.data.name ) end )

  eq( visited, { "root", "child", "grandchild" } )
end

function TreeWalkSpec:should_pass_the_current_depth_to_visit()
  local grandchild = Tree.new_leaf( { name = "grandchild" } )
  local child = Tree.new_node( { name = "child" }, { grandchild } )
  local root = Tree.new_node( { name = "root" }, { child } )

  local depths = {}
  Tree.walk( { root }, nil, function( node, depth ) depths[ node.data.name ] = depth end )

  eq( depths, { root = 0, child = 1, grandchild = 2 } )
end

function TreeWalkSpec:should_skip_a_nodes_children_when_visit_returns_false()
  local grandchild = Tree.new_leaf( { name = "grandchild" } )
  local child = Tree.new_node( { name = "child" }, { grandchild } )
  local root = Tree.new_node( { name = "root" }, { child } )

  local visited = {}
  Tree.walk( { root }, nil, function( node )
    table.insert( visited, node.data.name )
    return node.data.name ~= "child" -- skip descending past "child"
  end )

  eq( visited, { "root", "child" } )
end

function TreeWalkSpec:should_stop_the_entire_walk_immediately_when_visit_requests_it()
  -- second_child and its own child would be visited next if the walk didn't actually stop.
  local first_childs_child = Tree.new_leaf( { name = "first_childs_child" } )
  local first_child = Tree.new_node( { name = "first_child" }, { first_childs_child } )
  local second_childs_child = Tree.new_leaf( { name = "second_childs_child" } )
  local second_child = Tree.new_node( { name = "second_child" }, { second_childs_child } )
  local root = Tree.new_node( { name = "root" }, { first_child, second_child } )

  local visited = {}
  Tree.walk( { root }, nil, function( node )
    table.insert( visited, node.data.name )
    if node.data.name == "first_child" then return true, nil, true end -- stop right here
  end )

  eq( visited, { "root", "first_child" } )
end

function TreeWalkSpec:should_return_true_from_the_top_level_call_when_stopped()
  local root = Tree.new_leaf( { name = "root" } )

  local stopped = Tree.walk( { root }, nil, function() return false, nil, true end )

  eq( stopped, true )
end

function TreeWalkSpec:should_return_false_from_the_top_level_call_when_never_stopped()
  local root = Tree.new_leaf( { name = "root" } )

  local stopped = Tree.walk( { root }, nil, function() end )

  eq( stopped, false )
end

function TreeWalkSpec:should_thread_a_child_context_down_to_only_that_branchs_descendants()
  local leaf_a = Tree.new_leaf( { name = "a" } )
  local leaf_b = Tree.new_leaf( { name = "b" } )
  local branch_a = Tree.new_node( { name = "branch_a" }, { leaf_a } )
  local branch_b = Tree.new_node( { name = "branch_b" }, { leaf_b } )
  local root = Tree.new_node( { name = "root" }, { branch_a, branch_b } )

  local seen_context = {}
  Tree.walk( { root }, "root_context", function( node, _, context )
    seen_context[ node.data.name ] = context
    if node.data.name == "branch_a" then return true, "context_a" end
    if node.data.name == "branch_b" then return true, "context_b" end
  end )

  eq( seen_context.root, "root_context" )
  eq( seen_context.branch_a, "root_context" )
  eq( seen_context.branch_b, "root_context" )
  eq( seen_context.a, "context_a" ) -- only leaf_a's branch got the overridden context
  eq( seen_context.b, "context_b" ) -- only leaf_b's branch got the overridden context
end

os.exit( lu.LuaUnit.run() )
