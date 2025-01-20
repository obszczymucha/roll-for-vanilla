RollFor = RollFor or {}
local m = RollFor

local M = {}

function M.new( module, new_callback_fn )
  local decoratee = m.clone( module )
  local original_new = decoratee.new

  if original_new then
    decoratee.new = function( ... )
      local result = original_new( unpack( { ... } ) )
      new_callback_fn( result )
      return result
    end
  end

  return decoratee
end

return M
