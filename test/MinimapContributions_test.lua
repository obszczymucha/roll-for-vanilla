---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_libraries()
u.load_real_stuff_and_inject( {}, {} )
local EventBus = require( "src/EventBus" )
local MinimapButton = require( "src/MinimapButton" )

local function api() return RollFor.api end

---@param show_commands boolean? -- defaults to true, so the ordering specs below can keep
--- asserting where a contribution's commands land among core's
local function mock_config( show_commands )
  return {
    minimap_button_locked = function() return false end,
    minimap_button_hidden = function() return false end,
    minimap_tooltip_commands = function() return show_commands ~= false end,
    subscribe = function() end
  }
end

-- A GameTooltip stand-in that just records everything written to it, in order.
local function make_tooltip()
  local tooltip = { lines = {} }
  tooltip.SetOwner = function() end
  tooltip.SetText = function( self, text ) table.insert( self.lines, text ) end
  tooltip.AddLine = function( self, text ) table.insert( self.lines, text ) end
  tooltip.Show = function() end
  tooltip.Hide = function() end
  return tooltip
end

---@param lines string[]
---@param needle string
---@return number?
local function index_of_line( lines, needle )
  for i, line in ipairs( lines ) do
    if string.find( line, needle, 1, true ) then return i end
  end
end

---@param contributions MinimapContribution[]
---@param show_commands boolean?
---@return string[] -- the tooltip's lines after OnEnter ran
local function render_tooltip( contributions, show_commands )
  MinimapButton.new( api, {}, mock_config( show_commands ), EventBus.new(), contributions )

  local frame = _G[ "RollForMinimapButton" ]
  local tooltip = make_tooltip()
  _G[ "GameTooltip" ] = tooltip

  frame.OnEnter( frame )

  return tooltip.lines
end

TooltipOrderingSpec = {}

function TooltipOrderingSpec:should_list_a_contributions_commands_after_cores_own()
  local lines = render_tooltip( { {
    commands = { { cmd = "/sr", description = "manage softres" } }
  } } )

  local core_line = index_of_line( lines, "/htr" )
  local contributed_line = index_of_line( lines, "/sr" )

  eq( core_line ~= nil, true )
  eq( contributed_line ~= nil, true )
  eq( contributed_line > core_line, true )
end

function TooltipOrderingSpec:should_list_commands_from_two_contributions_in_registration_order()
  local lines = render_tooltip( {
    { commands = { { cmd = "/first", description = "one" } } },
    { commands = { { cmd = "/second", description = "two" } } }
  } )

  local first = index_of_line( lines, "/first" )
  local second = index_of_line( lines, "/second" )

  eq( first ~= nil and second ~= nil, true )
  eq( first < second, true )
end

function TooltipOrderingSpec:should_use_the_first_contributions_hint()
  local lines = render_tooltip( {
    { hint = "Click to foo." },
    { hint = "Click to bar." }
  } )

  eq( index_of_line( lines, "Click to foo." ) ~= nil, true )
  eq( index_of_line( lines, "Click to bar." ), nil )
end

function TooltipOrderingSpec:should_fall_back_to_a_hint_when_no_contribution_supplies_one()
  local lines = render_tooltip( { { commands = { { cmd = "/foo", description = "foo" } } } } )

  eq( index_of_line( lines, "Click to open options." ) ~= nil, true )
end

function TooltipOrderingSpec:should_default_the_hint_with_no_contributions_at_all()
  local lines = render_tooltip( {} )

  eq( index_of_line( lines, "Click to open options." ) ~= nil, true )
end

function TooltipOrderingSpec:should_append_each_contributions_status_lines_after_the_hint()
  local lines = render_tooltip( { {
    status = function() return { color = "Orange", lines = { "Missing softres:", "Drutree" } } end
  } } )

  local hint_line = index_of_line( lines, "Click to open options." )
  local status_line = index_of_line( lines, "Missing softres:" )
  local name_line = index_of_line( lines, "Drutree" )

  eq( hint_line ~= nil and status_line ~= nil and name_line ~= nil, true )
  eq( status_line > hint_line, true )
  eq( name_line, status_line + 1 )
end

function TooltipOrderingSpec:should_omit_a_status_block_when_status_has_no_lines()
  local lines = render_tooltip( { {
    status = function() return { color = "Green" } end
  } } )

  eq( index_of_line( lines, "Missing" ), nil )
end

-- The single most likely mistake in this area: a button built before extensions register
-- (main.lua builds it in create_components(); extensions register in on_ready, which runs
-- later) must still show what gets registered after it exists, because contributions are
-- read at render time rather than snapshotted at construction.
RenderTimeSpec = {}

function RenderTimeSpec:should_show_a_contribution_registered_after_the_button_was_built()
  local contributions = {}
  MinimapButton.new( api, {}, mock_config(), EventBus.new(), contributions )

  -- Registered well after construction, simulating an extension's on_ready.
  table.insert( contributions, { commands = { { cmd = "/late", description = "arrived late" } } } )

  local frame = _G[ "RollForMinimapButton" ]
  local tooltip = make_tooltip()
  _G[ "GameTooltip" ] = tooltip
  frame.OnEnter( frame )

  eq( index_of_line( tooltip.lines, "/late" ) ~= nil, true )
end

-- Colour severity resolution lives in main.lua's refresh_minimap(), which recomputes from
-- the live RollFor.minimap_contributions list -- so this goes through the full addon
-- rather than MinimapButton in isolation.
ColourSeveritySpec = {}

function ColourSeveritySpec:should_pick_the_highest_severity_colour_across_contributions()
  u.player( "Psikutas" )
  local rf = u.load_roll_for()

  table.insert( rf.minimap_contributions, { status = function() return { color = rf.minimap_button.ColorType.Orange } end } )
  table.insert( rf.minimap_contributions, { status = function() return { color = rf.minimap_button.ColorType.Green } end } )

  rf.on_group_changed()

  eq( rf.minimap_button.get_icon_color(), rf.minimap_button.ColorType.Orange )
end

function ColourSeveritySpec:should_stay_white_when_nothing_reports_a_colour()
  u.player( "Psikutas" )
  local rf = u.load_roll_for()

  table.insert( rf.minimap_contributions, { hint = "no status at all" } )

  rf.on_group_changed()

  eq( rf.minimap_button.get_icon_color(), rf.minimap_button.ColorType.White )
end

function ColourSeveritySpec:should_reflect_a_contribution_registered_after_login()
  u.player( "Psikutas" )
  local rf = u.load_roll_for()

  -- Nothing loud yet.
  rf.on_group_changed()
  eq( rf.minimap_button.get_icon_color(), rf.minimap_button.ColorType.White )

  table.insert( rf.minimap_contributions, { status = function() return { color = rf.minimap_button.ColorType.Red } end } )
  rf.on_group_changed()

  eq( rf.minimap_button.get_icon_color(), rf.minimap_button.ColorType.Red )
end

CommandVisibilitySpec = {}

-- Off by default, and this is what off looks like: no core commands, no contributed ones,
-- and the hint still there. The hint is what the tooltip must never stop saying.
function CommandVisibilitySpec:should_draw_no_commands_when_the_setting_is_off()
  local lines = render_tooltip( { {
    commands = { { cmd = "/sr", description = "manage softres" } },
    hint = "Right click to manage softres."
  } }, false )

  eq( index_of_line( lines, "/htr" ), nil )
  eq( index_of_line( lines, "/rf config" ), nil )
  eq( index_of_line( lines, "/sr" ), nil )
  eq( index_of_line( lines, "Right click to manage softres." ) ~= nil, true )
end

function CommandVisibilitySpec:should_draw_them_when_the_setting_is_on()
  local lines = render_tooltip( { {
    commands = { { cmd = "/sr", description = "manage softres" } },
    hint = "Right click to manage softres."
  } }, true )

  eq( index_of_line( lines, "/htr" ) ~= nil, true )
  eq( index_of_line( lines, "/sr" ) ~= nil, true )
end

-- The title is not a command, so it stays either way -- an empty tooltip would read as a
-- broken button rather than as a setting being off.
function CommandVisibilitySpec:should_keep_the_title_with_the_commands_hidden()
  local lines = render_tooltip( {}, false )

  eq( index_of_line( lines, "RollFor" ) ~= nil, true )
end

-- Status lines are what a contribution has to *report* rather than what a user can type,
-- so they are not commands and the setting does not touch them.
function CommandVisibilitySpec:should_still_report_status_lines_with_the_commands_hidden()
  local lines = render_tooltip( { {
    status = function() return { color = "Red", lines = { "Found outdated softres data." } } end
  } }, false )

  eq( index_of_line( lines, "Found outdated softres data." ) ~= nil, true )
end

os.exit( lu.LuaUnit.run() )
