local M = {}

local MockType = {
  SMART_TABLE = 1,
  PACKED_VALUE = 1 -- We want the mocked function to unpack
}

function M.mock( function_name, value )
  return { function_name = function_name, value = value }
end

function M.smart_table( value )
  return { mocked_type = MockType.SMART_TABLE, value = value }
end

function M.packed_value( value )
  return { mocked_type = MockType.PACKED_VALUE, value = value }
end

function M.mock_api( ... )
  local result = {}

  local function mock_function( v )
    if type( v ) == "function" then
      local values = v()

      for _, value in pairs( values ) do
        mock_function( value )
      end
    elseif v.value == nil then
      return
    elseif type( v.value ) ~= "table" or v.value.mocked_type == nil then
      result[ v.function_name ] = function() return v.value end
    elseif v.value.mocked_type == MockType.SMART_TABLE then
      result[ v.function_name ] = function( key )
        local value = v.value.value[ key ]

        if value and value.mocked_type == MockType.PACKED_VALUE then
          return unpack( value.value )
        else
          return value
        end
      end
    elseif v.value.mocked_type == MockType.PACKED_VALUE then
      result[ v.function_name ] = function() return unpack( v.value.value ) end
    end
  end

  for _, v in pairs( { ... } ) do
    -- Returning a function allows us to mock multiple functions together.
    -- See GroupRoster_text.lua -> player().
    mock_function( v )
  end

  return function() return result end
end

return M
