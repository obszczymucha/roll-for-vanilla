---@diagnostic disable: inject-field
local M = {}

local u = require( "test/utils" )
local _, eq = u.luaunit( "assertEquals" )
local OptionsFrame = require( "src/OptionsFrame" )

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

local function cleanse( t )
  return u.map( strip_functions( t ), function( v )
    if v.type == "text" and v.value then
      v.value = u.decolorize( v.value ) or v.value
    end

    return v
  end )
end

---@class OptionsFrameMock : OptionsFrame
---@field content fun(): table
---@field should_display fun( ...: table ): table
---@field is_visible fun(): boolean
---@field should_be_visible fun()
---@field should_be_hidden fun()
---@field click fun( button_type: OptionsFrameButtonType )
---@field toggle_setting fun( label: string )
---@field change_slider fun( label: string, value: number )
---@field change_editbox fun( label: string, value: number )
---@field change_dropdown fun( label: string, value: any )

---@param popup_builder PopupBuilder
---@param config Config
---@param db table
function M.new( popup_builder, config, db )
  local transformed_content
  local model ---@type OptionsFrameData?

  local real_transformer = require( "src/OptionsFrameContentTransformer" ).new()

  ---@type OptionsFrameContentTransformer
  local spying_transformer = {
    transform = function( data )
      model = data
      transformed_content = real_transformer.transform( data )
      return transformed_content
    end
  }

  local options = OptionsFrame.new( popup_builder, spying_transformer, config, db )
  options.content = function() return transformed_content and cleanse( transformed_content ) or {} end

  options.is_visible = function()
    local frame = options and options.get_frame()
    return frame and frame:IsVisible() or false
  end

  options.click = function( button_type )
    if not model then return end

    if not model.buttons then
      error( "There were no buttons to click." )
    end

    for _, button in ipairs( model.buttons ) do
      if button.type == button_type then button.callback() end
    end
  end

  -- Settings are one flat list now, and they carry no key -- the label is what identifies a
  -- control to someone reading the options window, so that is what tests address it by.
  local function find_setting( label )
    if not model or not model.settings then
      error( "There were no settings to change.", 3 )
    end

    for _, setting in ipairs( model.settings ) do
      if setting.label == label then return setting end
    end

    error( string.format( "There was no setting labelled: %s", label ), 3 )
  end

  local function change_setting( label, value )
    find_setting( label ).on_change( value )
  end

  options.toggle_setting = function( label )
    local setting = find_setting( label )
    setting.on_change( not setting.value )
  end

  options.change_slider = change_setting
  options.change_editbox = change_setting
  options.change_dropdown = change_setting

  local function should_be_visible( level )
    if not options.is_visible() then
      error( "Options frame is hidden.", level )
    end
  end

  options.should_display = function( ... )
    should_be_visible( 3 )
    eq( transformed_content and cleanse( transformed_content ) or {}, { ... }, _, _, 3 )
  end

  options.should_be_visible = function()
    should_be_visible( 2 )
  end

  options.should_be_hidden = function()
    if options.is_visible() then
      error( "Options frame is visible.", 2 )
    end
  end

  ---@type OptionsFrameMock
  return options
end

return M
