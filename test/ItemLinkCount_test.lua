---@diagnostic disable: missing-fields
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

-- The stack count an item link draws in front of itself ("2x [Item]"), and what colour it is in.
--
-- Highlight orange by default, which is what every window has always shown. A window whose rows
-- already spend that colour on something else -- the pending list draws an orange SR indicator
-- right next to the count -- says so when it builds the widget rather than living with two
-- oranges a foot apart meaning different things.

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
u.multi_require_src( "DebugBuffer", "Module", "Types" )
u.mock_wow_api()
require( "src/ItemUtils" )
local GuiElements = require( "src/GuiElements" )

local link = u.item_link( "Cowl of Gul'dan", 32332 )

-- The colour is applied by wrapping the text, so a spy in its place is what the widget was told
-- to colour and with what.
local function spy()
  local calls = {}

  return function( text )
    table.insert( calls, text )
    return text
  end, function() return calls end
end

---@param count_color fun( text: string ): string|nil
---@param count number
local function drawn( count_color, count )
  local parent = u.modules().api.CreateFrame( "Frame" )
  local widget = GuiElements.item_link_with_icon( parent, nil, nil, count_color )

  widget:SetItem( { link = link, count = count }, "item:32332" )

  return widget
end

ItemLinkCountSpec = {}

function ItemLinkCountSpec:should_colour_the_count_with_the_colour_it_was_given()
  local color, calls = spy()

  drawn( color, 2 )

  eq( calls(), { "2x" } )
end

-- Nothing to say when there is only one of it, so nothing is coloured either.
function ItemLinkCountSpec:should_draw_no_count_for_a_single_item()
  local color, calls = spy()

  drawn( color, 1 )

  eq( calls(), {} )
end

-- Every window that never asked keeps the orange it has always had.
function ItemLinkCountSpec:should_fall_back_to_the_highlight_colour()
  local parent = u.modules().api.CreateFrame( "Frame" )
  local widget = GuiElements.item_link_with_icon( parent )
  local drawn_text

  widget.count.SetText = function( _, text ) drawn_text = text end
  widget:SetItem( { link = link, count = 2 }, "item:32332" )

  eq( drawn_text, RollFor.colors.hl( "2x" ) )
end

os.exit( lu.LuaUnit.run() )
