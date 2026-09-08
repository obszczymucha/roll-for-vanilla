package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

-- The methods AutoLootFrame calls on a tree_node row, checked against the real widget.
--
-- This suite exists because of a crash it would have caught. AutoLootFrame gained
-- SetLabelTooltip (a row saying why it is greyed out) while GuiElements did not, and every
-- window built on it went on passing its tests: the frame specs render through the popup
-- mocks, which fabricate a widget that answers to anything. Nothing anywhere asked the real
-- widget whether it had the methods its only caller calls. Opening the window in the game
-- answered that immediately.
--
-- So this is not a test of what the widget draws -- that is the client's business -- but of
-- the seam between the two files, which is a list of method names and nothing more.

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
u.mock_wow_api()
require( "src/modules" )
local GuiElements = require( "src/GuiElements" )
local PopupBuilder = require( "src/PopupBuilder" )
local GuiElements_frame_builder = require( "src/FrameBuilder" )

-- Every method AutoLootFrame calls on the row it is handed. Read off the file rather than
-- remembered: a new call there should fail here, not in the game.
local REQUIRED = {
  "ClearAllPoints",
  "SetChecked",
  "SetDepth",
  "SetDesaturated",
  "SetExpandable",
  "SetHeight",
  "SetItem",
  "SetLabelStyle",
  "SetLabelTooltip",
  "SetPoint",
  "SetScale",
  "SetScript",
  "SetText",
  "SetWidth"
}

TreeNodeContractSpec = {}

function TreeNodeContractSpec:should_answer_every_method_auto_loot_frame_calls()
  local row = GuiElements.tree_node( u.modules().api.CreateFrame( "Frame" ) )
  local missing = {}

  for _, name in ipairs( REQUIRED ) do
    if type( row[ name ] ) ~= "function" then table.insert( missing, name ) end
  end

  eq( missing, {} )
end

-- A label row has no item to ask the client about, so its tooltip is plain text this widget
-- holds onto. Nil is how a row says it has nothing to explain.
function TreeNodeContractSpec:should_take_a_label_tooltip_and_take_it_back()
  local row = GuiElements.tree_node( u.modules().api.CreateFrame( "Frame" ) )

  row:SetLabelTooltip( { "Ignored", "The loot threshold is above this quality." } )
  row:SetLabelTooltip( nil )
end

-- The same seam for the widgets ListPopup draws its lines with. Every window built on
-- ListPopup -- core's and any extension's -- goes through these calls, so a widget missing
-- one of them is a crash in whichever window happens to use that line type.
-- The client's dropdown API, which nothing else in this harness needs: no core spec has ever
-- constructed a real dropdown, which is part of why nobody noticed the widget was missing a
-- method its only caller calls. Stubbed here rather than in test/utils.lua, so the four
-- vendored copies of that file stay identical.
local function mock_dropdown_api()
  local api = u.modules().api

  api.UIDropDownMenu_SetWidth = function() end
  api.UIDropDownMenu_Initialize = function() end
  api.UIDropDownMenu_CreateInfo = function() return {} end
  api.UIDropDownMenu_AddButton = function() end
  api.UIDropDownMenu_SetSelectedValue = function() end
  api.UIDropDownMenu_SetText = function() end
  api.ToggleDropDownMenu = function() end
end

ListPopupContractSpec = {}

local LIST_POPUP_REQUIRED = {
  dropdown = { "SetText", "SetDropdownWidth", "SetOptions", "SetValue" },
  text = { "SetText" },
  button = { "SetText", "SetScript" }
}

function ListPopupContractSpec:should_answer_every_method_list_popup_calls()
  mock_dropdown_api()

  local missing = {}

  for line_type, methods in pairs( LIST_POPUP_REQUIRED ) do
    local widget = GuiElements[ line_type ]( u.modules().api.CreateFrame( "Frame" ) )

    for _, name in ipairs( methods ) do
      if type( widget[ name ] ) ~= "function" then
        table.insert( missing, string.format( "%s.%s", line_type, name ) )
      end
    end
  end

  table.sort( missing )

  eq( missing, {} )
end

-- Two seams, same failure mode as the widgets above. Every window in every addon is
-- assembled by chaining builder methods and then calling methods on what comes back, and
-- every spec that renders one does it through doubles that answer to anything -- so a
-- builder that stopped providing one of these would be found by opening a window rather
-- than by a test. set_max_scroll_lines was exactly that.
BuilderContractSpec = {}

-- Everything ListPopup, the auto-robin windows and the extension options pages chain.
local BUILDER_REQUIRED = {
  "name", "parent", "point", "gui_elements", "movable", "on_drag_stop", "strata",
  "self_centered_anchor", "anchor_point", "hidden", "backdrop_color", "border_color",
  "no_border", "scrollable", "on_scroll", "esc", "build"
}

-- Everything they then call on the popup it builds.
local POPUP_REQUIRED = {
  "add_line", "clear", "position", "get_anchor_point",
  "set_scroll_total", "set_max_scroll_lines",
  "Show", "Hide", "IsVisible"
}

---@return PopupBuilder
local function builder()
  return PopupBuilder.modern( GuiElements_frame_builder, 0, 0, 0 )
end

function BuilderContractSpec:should_answer_every_method_its_callers_chain()
  local b = builder()
  local missing = {}

  for _, name in ipairs( BUILDER_REQUIRED ) do
    if type( b[ name ] ) ~= "function" then table.insert( missing, name ) end
  end

  eq( missing, {} )
end

-- Chained, not merely present: each one has to answer with the builder or the next call in
-- the chain is on nil. no_border is the one this branch added and master never had, so it
-- is the one most likely to be dropped by a future wholesale copy from over there.
function BuilderContractSpec:should_answer_with_itself_so_the_calls_chain()
  local b = builder()

  eq( b:no_border(), b )
  eq( b:movable(), b )
  eq( b:hidden(), b )
end

PopupContractSpec = {}

function PopupContractSpec:should_answer_every_method_list_popup_calls()
  local popup = builder()
      :name( "RollForPopupContractProbe" )
      :gui_elements( GuiElements )
      :scrollable( { line_types = "text", max_lines = 5 } )
      :build()

  local missing = {}

  for _, name in ipairs( POPUP_REQUIRED ) do
    if type( popup[ name ] ) ~= "function" then table.insert( missing, name ) end
  end

  eq( missing, {} )
end

os.exit( lu.LuaUnit.run() )
