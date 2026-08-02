RollFor = RollFor or {}
local m = RollFor

if m.Tree then return end

local M = {}

---@class TreeNode
---@field children TreeNode[]? nil marks a leaf
---@field data table opaque payload -- completely opaque to this module.

---@param data table
---@param children TreeNode[]
---@return TreeNode
function M.new_node( data, children )
  return { data = data, children = children }
end

---@param data table
---@return TreeNode
function M.new_leaf( data )
  return { data = data }
end

-- Generic depth-first traversal. `visit` is called for every node, in order, until either the
-- tree is exhausted or `visit` asks to stop. It may return three things:
--   1. `descend` (boolean, default true) -- false skips this node's children only, the walk
--      otherwise continues on with this node's siblings/uncles as normal.
--   2. `child_context` (any, defaults to the same `context`) -- passed down to this node's own
--      children, letting callers thread accumulated state down a branch (e.g. "are all ancestors
--      checked so far") without this module knowing what that state means.
--   3. `stop` (boolean, default false) -- true aborts the *entire* walk immediately, anywhere in
--      the tree, not just this branch. This is what lets callers short-circuit (e.g. all_checked
--      stopping at the first unchecked node instead of visiting the whole tree every time).
-- Doesn't know or care what `data` holds, whether a node is "checked"/"expanded"/anything else --
-- purely structural.
---@param nodes TreeNode[]
---@param context any initial context passed to the top-level nodes
---@param visit fun( node: TreeNode, depth: number, context: any ): boolean?, any?, boolean?
---@param depth number? internal
---@return boolean stopped true if `visit` requested an early stop
function M.walk( nodes, context, visit, depth )
  depth = depth or 0

  for _, node in ipairs( nodes ) do
    local descend, child_context, stop = visit( node, depth, context )
    if stop then return true end

    if child_context == nil then child_context = context end

    if node.children and descend ~= false then
      if M.walk( node.children, child_context, visit, depth + 1 ) then return true end
    end
  end

  return false
end

m.Tree = M
return M
