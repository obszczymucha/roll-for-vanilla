---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_libraries()
u.load_real_stuff_and_inject( {}, {} )
local EventBus = require( "src/EventBus" )

-- Clicking the minimap button is nothing but a notify -- see src/MinimapButton.lua's
-- frame.OnClick, which picks the event from which button was pressed. What decides whether
-- the left one opens the options window is main.lua's create_components(): after every
-- extension has had its chance to subscribe (on_enable/on_ready), core installs itself as
-- the fallback only if EventBus.has_subscribers says nobody claimed the click yet.
--
-- The right one has no fallback. Core does nothing with it, so an unclaimed right click is
-- a no-op rather than a second way to open the options window.
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

-- Which event a click produces is the button's own doing, and the only thing that tells
-- the two apart. Reached through the real frame, because the mapping lives in the script
-- the client calls, not in anything main.lua can be asked about.
ButtonMappingSpec = {}

---@return table, string[]
local function clicked( button )
  u.player( "Psikutas" )
  local rf = u.load_roll_for()
  local notified = {}

  local notify = rf.event_bus.notify
  rf.event_bus.notify = function( event, ... )
    table.insert( notified, event )
    return notify( event, ... )
  end

  -- OnClick redraws the tooltip and hides it again, so there has to be one to redraw.
  _G[ "GameTooltip" ] = {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function() end,
    Show = function() end,
    Hide = function() end
  }
  RollFor.api.GameTooltip = _G[ "GameTooltip" ]

  local frame = _G[ "RollForMinimapButton" ]
  frame.OnClick( frame, button )
  rf.event_bus.notify = notify

  return rf, notified
end

function ButtonMappingSpec:should_notify_the_left_click_event_for_the_left_button()
  local _, notified = clicked( "LeftButton" )

  eq( notified, { "minimap_icon_left_click" } )
end

function ButtonMappingSpec:should_notify_the_right_click_event_for_the_right_button()
  local _, notified = clicked( "RightButton" )

  eq( notified, { "minimap_icon_right_click" } )
end

-- Middle-click, mouse4, and whatever else the client reports: anything that isn't the
-- right button is treated as the left one, which is what the button did before there were
-- two events at all.
function ButtonMappingSpec:should_treat_any_other_button_as_the_left_one()
  local _, notified = clicked( "MiddleButton" )

  eq( notified, { "minimap_icon_left_click" } )
end

RightClickSpec = {}

-- Nothing in core answers it, and core installs no fallback: with no source extension
-- installed, right-clicking the button does nothing at all.
function RightClickSpec:should_do_nothing_with_no_source_installed()
  local rf, notified = clicked( "RightButton" )

  eq( notified, { "minimap_icon_right_click" } )
  eq( rf.event_bus.has_subscribers( "minimap_icon_right_click" ), false )
end

-- The left one still opens options, which is the point of leaving it to core's fallback.
function RightClickSpec:should_not_have_taken_the_left_click_with_it()
  local rf = clicked( "RightButton" )

  eq( rf.event_bus.has_subscribers( "minimap_icon_left_click" ), true )
end

os.exit( lu.LuaUnit.run() )
