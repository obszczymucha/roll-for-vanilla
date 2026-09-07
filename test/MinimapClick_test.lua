---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_libraries()
u.load_real_stuff_and_inject( {}, {} )
local EventBus = require( "src/EventBus" )

-- Left click on the minimap button is nothing but `event_bus.notify( "minimap_icon_left_
-- click" )` -- see src/MinimapButton.lua's frame.OnClick. What decides whether that opens
-- the options window is main.lua's create_components(): after every extension has had its
-- chance to subscribe (on_enable/on_ready), core installs itself as the fallback only if
-- EventBus.has_subscribers says nobody claimed the click yet.
FallbackMechanismSpec = {}

function FallbackMechanismSpec:should_open_options_when_nobody_claimed_the_click()
  local bus = EventBus.new()
  local opened = {}

  -- The exact pattern main.lua installs at the end of create_components().
  if not bus.has_subscribers( "minimap_icon_left_click" ) then
    bus.subscribe( "minimap_icon_left_click", function() table.insert( opened, true ) end )
  end

  bus.notify( "minimap_icon_left_click" )

  eq( opened, { true } )
end

function FallbackMechanismSpec:should_not_open_options_when_something_already_claimed_the_click()
  local bus = EventBus.new()
  local opened, claimed = {}, {}

  bus.subscribe( "minimap_icon_left_click", function() table.insert( claimed, true ) end )

  if not bus.has_subscribers( "minimap_icon_left_click" ) then
    bus.subscribe( "minimap_icon_left_click", function() table.insert( opened, true ) end )
  end

  bus.notify( "minimap_icon_left_click" )

  eq( claimed, { true } )
  eq( opened, {} )
end

-- On the real, fully wired addon with no source extension installed, nothing claims the
-- click, so the fallback is what runs. Core used to claim it for its own soft-res window;
-- there is no such window in core any more, and this is what the button does for a user
-- who has not installed a source.
RealAddonClickSpec = {}

function RealAddonClickSpec:should_have_a_claimed_click_after_a_real_login()
  u.player( "Psikutas" )
  local rf = u.load_roll_for()

  -- The fallback is itself a subscriber, so the click is always answered by something.
  eq( rf.event_bus.has_subscribers( "minimap_icon_left_click" ), true )
end

function RealAddonClickSpec:should_open_options_with_no_source_installed()
  u.player( "Psikutas" )
  local rf = u.load_roll_for()

  local opened = {}
  rf.interface_options.open = function() table.insert( opened, true ) end

  rf.event_bus.notify( "minimap_icon_left_click" )

  eq( opened, { true } )
end

os.exit( lu.LuaUnit.run() )
