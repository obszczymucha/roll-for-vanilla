---@diagnostic disable: inject-field
local M = {}

local u = require( "test/utils" )
local _, eq = u.luaunit( "assertEquals" )
require( "src/ListPopup" ) -- the window shell the frame is built on
local ResistanceBonusRollFrame = require( "src/resistances/ResistanceBonusRollFrame" )

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

-- Only the title is decolorized.
local function cleanse( t )
  return u.map( strip_functions( t ), function( v )
    if v.type == "text" and v.value then
      v.value = u.decolorize( v.value ) or v.value
    end

    return v
  end )
end

---@class ResistanceBonusRollFrameMock : ResistanceBonusRollFrame
---@field content fun(): table
---@field should_display fun( ...: table ): table
---@field is_visible fun(): boolean
---@field should_be_visible fun()
---@field should_be_hidden fun()
---@field click fun( button_type: BonusRollFrameButtonType )
---@field render_count fun(): number

---@param popup_builder PopupBuilder
---@param registry ResistanceBonusRollRegistry
---@param group_roster GroupRoster
---@param db table
function M.new( popup_builder, registry, group_roster, db )
  local transformed_content
  local renders = 0
  local model ---@type BonusRollFrameData?

  local real_transformer = require( "src/resistances/ResistanceBonusRollFrameContentTransformer" ).new()

  ---@type BonusRollFrameContentTransformer
  local spying_transformer = {
    transform = function( data )
      model = data
      renders = renders + 1
      transformed_content = real_transformer.transform( data )
      return transformed_content
    end
  }

  local frame = ResistanceBonusRollFrame.new( popup_builder, spying_transformer, registry, group_roster, db )

  frame.content = function() return transformed_content and cleanse( transformed_content ) or {} end
  frame.render_count = function() return renders end

  frame.is_visible = function()
    local popup = frame and frame.get_frame()
    return popup and popup:IsVisible() or false
  end

  frame.click = function( button_type )
    if not model then return end

    if not model.buttons then
      error( "There were no buttons to click." )
    end

    for _, button in ipairs( model.buttons ) do
      if button.type == button_type then button.callback() end
    end
  end

  local function should_be_visible( level )
    if not frame.is_visible() then
      error( "Bonus roll frame is hidden.", level )
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
      error( "Bonus roll frame is visible.", 2 )
    end
  end

  ---@type ResistanceBonusRollFrameMock
  return frame
end

return M
