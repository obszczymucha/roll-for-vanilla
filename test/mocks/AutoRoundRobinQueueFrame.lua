---@diagnostic disable: inject-field
local M = {}

local u = require( "test/utils" )
local _, eq = u.luaunit( "assertEquals" )
require( "src/ListPopup" ) -- the window shell the frame is built on
local AutoRoundRobinQueueFrame = require( "src/AutoRoundRobinQueueFrame" )

local function strip_functions( t )
  for _, line in ipairs( t ) do
    for k, v in pairs( line ) do
      if type( v ) == "function" then
        line[ k ] = nil
      end
    end
  end

  return t
end

-- Only the title is decolorized. The row cells keep their colors, because which color a status
-- is drawn in is half of what the transformer decides.
local function cleanse( t )
  return u.map( strip_functions( t ), function( v )
    if v.type == "text" and v.value then
      v.value = u.decolorize( v.value ) or v.value
    end

    return v
  end )
end

---@class AutoRoundRobinQueueFrameMock : AutoRoundRobinQueueFrame
---@field content fun(): table
---@field should_display fun( ...: table ): table
---@field is_visible fun(): boolean
---@field should_be_visible fun()
---@field should_be_hidden fun()
---@field click fun( button_type: RoundRobinQueueFrameButtonType )

---@param popup_builder PopupBuilder
---@param round_robin AutoRoundRobin
---@param on_reset fun()
---@param db table
function M.new( popup_builder, round_robin, on_reset, db )
  local transformed_content
  local model ---@type RoundRobinQueueFrameData?

  local real_transformer = require( "src/AutoRoundRobinQueueFrameContentTransformer" ).new()

  ---@type RoundRobinQueueFrameContentTransformer
  local spying_transformer = {
    transform = function( data )
      model = data
      transformed_content = real_transformer.transform( data )
      return transformed_content
    end
  }

  local frame = AutoRoundRobinQueueFrame.new( popup_builder, spying_transformer, round_robin, on_reset, db )

  frame.content = function() return transformed_content and cleanse( transformed_content ) or {} end

  frame.is_visible = function()
    local popup = frame and frame.get_frame()
    return popup and popup:IsVisible() or false
  end

  frame.click = function( button_type )
    if not model then return end
    if not model.buttons then error( "There were no buttons to click." ) end

    for _, button in ipairs( model.buttons ) do
      if button.type == button_type then button.callback() end
    end
  end

  local function should_be_visible( level )
    if not frame.is_visible() then
      error( "Round robin queue frame is hidden.", level )
    end
  end

  frame.should_display = function( ... )
    should_be_visible( 3 )
    eq( transformed_content and cleanse( transformed_content ) or {}, { ... }, _, _, 3 )
  end

  frame.should_be_visible = function()
    should_be_visible( 2 )
  end

  frame.should_be_hidden = function()
    if frame.is_visible() then
      error( "Round robin queue frame is visible.", 2 )
    end
  end

  ---@type AutoRoundRobinQueueFrameMock
  return frame
end

return M
