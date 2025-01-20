RollFor = RollFor or {}
local m = RollFor

if m.EventFrame then return end

local M = m.Module.new( "EventFrame" )

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

  frame:SetScript( "OnEvent", function()
    ---@diagnostic disable-next-line: undefined-global
    event_handler( event, arg1, arg2, arg3, arg4, arg5 )
  end )

  return {
    subscribe = subscribe
  }
end

m.EventFrame = M
return M
