---@diagnostic disable: inject-field
local M = {}

local u = require( "test/utils" )
local _, eq = u.luaunit( "assertEquals" )
require( "src/ListPopup" ) -- the window shell the frame is built on
local ResistanceFrame = require( "src/resistances/ResistanceFrame" )

local function strip_functions( t )
  for _, line in ipairs( t ) do
    for k, v in pairs( line ) do
      if type( v ) == "function" then
        line[ k ] = nil
      elseif type( v ) == "table" then
        -- The checkbox row carries its options in a nested list, each with its
        -- own callback. Those are wiring, not what the line says.
        strip_functions( v )
      end
    end
  end

  return t
end

-- Only the title is decolorized. The row cells keep their color codes on
-- purpose: the class color and the red dash of a failed inspect are part of
-- what the rows are supposed to say.
local function cleanse( t )
  return u.map( strip_functions( t ), function( v )
    if v.type == "text" and v.value then
      v.value = u.decolorize( v.value ) or v.value
    end

    return v
  end )
end

---@class ResistanceFrameMock : ResistanceFrame
---@field content fun(): table
---@field should_display fun( ...: table ): table
---@field is_visible fun(): boolean
---@field should_be_visible fun()
---@field should_be_hidden fun()
---@field click fun( button_type: ResistanceFrameButtonType )
---@field clear_row fun( player_name: string )
---@field toggle_option fun( label: string, value: boolean )
---@field render_count fun(): number

---@param popup_builder PopupBuilder
---@param resistance_check ResistanceCheck
---@param db table
---@param registry ResistanceRegistry
---@param announcer ResistanceAnnouncer
function M.new( popup_builder, resistance_check, db, registry, announcer )
  local transformed_content
  local renders = 0
  local model ---@type ResistanceFrameData?

  local real_transformer = require( "src/resistances/ResistanceFrameContentTransformer" ).new( registry )

  ---@type ResistanceFrameContentTransformer
  local spying_transformer = {
    transform = function( data )
      model = data
      renders = renders + 1
      transformed_content = real_transformer.transform( data )
      return transformed_content
    end
  }

  local frame = ResistanceFrame.new( popup_builder, spying_transformer, resistance_check, announcer, db )

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

  frame.toggle_option = function( label, value )
    if not model then return end

    for _, option in ipairs( model.options or {} ) do
      if option.label == label then
        option.on_click( value )
        return
      end
    end

    error( string.format( "There was no %s option to toggle.", label ), 2 )
  end

  frame.clear_row = function( player_name )
    if not model then return end

    for _, row in ipairs( model.rows or {} ) do
      if row.player_name == player_name then
        row.on_clear()
        return
      end
    end

    error( string.format( "There was no row for %s to clear.", player_name ), 2 )
  end

  local function should_be_visible( level )
    if not frame.is_visible() then
      error( "Resistance frame is hidden.", level )
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
      error( "Resistance frame is visible.", 2 )
    end
  end

  ---@type ResistanceFrameMock
  return frame
end

return M
