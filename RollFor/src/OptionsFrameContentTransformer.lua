RollFor = RollFor or {}
local m = RollFor

if m.OptionsFrameContentTransformer then return end

local M = {}

local blue = m.colors.blue

---@param label string
---@param width number
local function button_definition( label, width )
  return { type = "button", label = label, width = width }
end

M.button_definitions = {
  [ "Close" ] = button_definition( "Close", 70 )
}

---@alias OptionsFrameButtonType
---| "Close"

---@class OptionsFrameButtonWithCallback
---@field type OptionsFrameButtonType
---@field callback fun()
---@field should_display_callback fun(): boolean

---@class OptionsFrameContentTransformer
---@field transform fun( data: OptionsFrameData ): table

---@param content table
---@param buttons OptionsFrameButtonWithCallback[]
local function add_buttons( content, buttons )
  for _, button in ipairs( buttons or {} ) do
    local definition = M.button_definitions[ button.type ]
    if not definition then error( string.format( "Unsupported button type: %s", button.type or "nil" ) ) end

    if not button.should_display_callback or button.should_display_callback() then
      table.insert( content, {
        type = definition.type,
        label = definition.label,
        width = definition.width,
        on_click = button.callback
      } )
    end
  end
end

---@param content table
---@param title string?
local function add_title( content, title )
  if not title then return end

  table.insert( content, { type = "text", value = blue( title ), padding = 6 } )
end

---@alias OptionsSetting BooleanSetting|NumberSetting|ConstrainedNumberSetting|StringChoiceSetting

---@class BooleanSetting
---@field type "boolean"
---@field label string
---@field value boolean
---@field on_change fun( value: boolean )

---@class NumberSetting
---@field type "number"
---@field label string
---@field value number
---@field precision number
---@field on_change fun( value: number )

---@class ConstrainedNumberSetting
---@field type "constrained_number"
---@field label string
---@field value number
---@field precision number
---@field min number
---@field max number
---@field on_change fun( value: number )

---@class ValueLabel
---@field value any
---@field label string

---@class StringChoiceSetting
---@field type "choice"
---@field label string
---@field value any
---@field choices ValueLabel[]
---@field on_change fun( value: any )

---@param content table
---@param setting BooleanSetting
---@param padding number
local function add_checkbox( content, setting, padding )
  table.insert( content, {
    type = "checkbox",
    label = setting.label,
    value = setting.value,
    on_click = setting.on_change,
    padding = padding
  } )
end

---@param content table
---@param setting NumberSetting
---@param padding number
local function add_editbox( content, setting, padding )
  table.insert( content, {
    type = "editbox",
    label = setting.label,
    value = setting.value,
    precision = setting.precision,
    on_change = setting.on_change,
    padding = padding
  } )
end

---@param content table
---@param setting ConstrainedNumberSetting
---@param padding number
local function add_slider( content, setting, padding )
  table.insert( content, {
    type = "slider",
    label = setting.label,
    value = setting.value,
    precision = setting.precision,
    min = setting.min,
    max = setting.max,
    on_change = setting.on_change,
    padding = padding
  } )
end

---@param content table
---@param setting StringChoiceSetting
---@param padding number
local function add_dropdown( content, setting, padding )
  table.insert( content, {
    type = "dropdown",
    label = setting.label,
    value = setting.value,
    options = setting.choices,
    on_change = setting.on_change,
    padding = padding
  } )
end

---@class OptionsFrameData
---@field title string?
---@field settings OptionsSetting[]
---@field buttons OptionsFrameButtonWithCallback[]

---@param data OptionsFrameData
local function transform( data )
  ---@param type "boolean"|"number"|"constrained_number"|"choice"
  local function get_padding( type )
    if type == "boolean" then
      return 2
    elseif type == "number" then
      return 7
    elseif type == "constrained_number" then
      return 7
    else
      return 5
    end
  end

  local content = {}

  add_title( content, data.title )

  for i, setting in ipairs( data.settings ) do
    local padding = i == 1 and 10 or get_padding( setting.type )

    if setting.type == "boolean" then
      add_checkbox( content, setting, padding )
    elseif setting.type == "number" then
      add_editbox( content, setting, padding )
    elseif setting.type == "constrained_number" then
      add_slider( content, setting, padding )
    elseif setting.type == "choice" then
      add_dropdown( content, setting, padding )
    end
  end

  add_buttons( content, data.buttons )

  return content
end

function M.new()
  return {
    transform = transform
  }
end

m.OptionsFrameContentTransformer = M
return M
