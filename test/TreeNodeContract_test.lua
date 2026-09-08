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

os.exit( lu.LuaUnit.run() )
