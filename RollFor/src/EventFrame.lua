RollFor = RollFor or {}
local m = RollFor

if m.EventFrame then return end

local M = m.Module.new( "EventFrame" )
---@diagnostic disable-next-line: undefined-field
local lua50 = table.setn and true or false

function M.new( api )
  local frame = api.CreateFrame( "Frame" )
  local event_handlers = {}

  local function subscribe( event_name, callback )
    if not event_name then error( "event_name was nil." ) end
    if not event_handlers[ event_name ] then
      frame:RegisterEvent( event_name )
    end

    event_handlers[ event_name ] = event_handlers[ event_name ] or {}
    table.insert( event_handlers[ event_name ], callback )
  end

  local function event_handler( event, arg1, arg2, arg3, arg4, arg5 )
    for event_name, handlers in pairs( event_handlers ) do
      if event_name == event then
        M.debug.add( event_name )

        for _, handle_event in ipairs( handlers ) do
          handle_event( arg1, arg2, arg3, arg4, arg5 )
        end
      end
    end
  end

  frame:SetScript( "OnEvent", function( _, _event, _arg1, _arg2, _arg3, _arg4, _arg5 )
    ---@diagnostic disable-next-line: undefined-global
    local event = lua50 and event or _event
    ---@diagnostic disable-next-line: undefined-global
    local arg1 = lua50 and arg1 or _arg1
    ---@diagnostic disable-next-line: undefined-global
    local arg2 = lua50 and arg2 or _arg2
    ---@diagnostic disable-next-line: undefined-global
    local arg3 = lua50 and arg3 or _arg3
    ---@diagnostic disable-next-line: undefined-global
    local arg4 = lua50 and arg4 or _arg4
    ---@diagnostic disable-next-line: undefined-global
    local arg5 = lua50 and arg5 or _arg5
    ---@diagnostic disable-next-line: undefined-global
    event_handler( event, arg1, arg2, arg3, arg4, arg5 )
  end )

  return {
    subscribe = subscribe
  }
end

m.EventFrame = M
return M
