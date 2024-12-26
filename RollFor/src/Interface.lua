RollFor = RollFor or {}
local m = RollFor

if m.Interface then return end

local M = {}

function M.validate( implementation, arg1, arg2, arg3, arg4, arg5 )
  assert( type( implementation ) == "table", "'implementation' must be a table." )

  for _, interface in ipairs( { arg1, arg2, arg3, arg4, arg5 } ) do
    for method_name, expected_type in pairs( interface ) do
      local v = implementation[ method_name ]

      if type( v ) ~= expected_type then
        error( string.format( "'%s' must be a %s, got %s.", method_name, expected_type, type( v ), debug.traceback() ), 2 )
      end
    end
  end
end

m.Interface = M
return M
