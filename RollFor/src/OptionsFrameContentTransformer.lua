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

---@class OptionsFrameBooleanSetting
---@field key string
---@field label string
---@field value boolean
---@field on_toggle fun()

---@param content table
---@param settings OptionsFrameBooleanSetting[]
local function add_settings( content, settings )
  for i, setting in ipairs( settings or {} ) do
    local padding = i == 1 and 10 or 2

    table.insert( content, {
      type = "checkbox",
      label = setting.label,
      value = setting.value,
      on_click = setting.on_toggle,
      padding = padding
    } )
  end
end

---@class OptionsFrameSliderSetting
---@field key string
---@field label string
---@field value number
---@field min number
---@field max number
---@field on_change fun( value: number )

---@param content table
---@param sliders OptionsFrameSliderSetting[]
local function add_sliders( content, sliders )
  for i, setting in ipairs( sliders or {} ) do
    local padding = i == 1 and 10 or 4

    table.insert( content, {
      type = "slider",
      label = setting.label,
      value = setting.value,
      min = setting.min,
      max = setting.max,
      on_change = setting.on_change,
      padding = padding
    } )
  end
end

---@class OptionsFrameEditboxSetting
---@field key string
---@field label string
---@field value number
---@field on_change fun( value: number ): boolean

---@param content table
---@param editboxes OptionsFrameEditboxSetting[]
local function add_editboxes( content, editboxes )
  for i, setting in ipairs( editboxes or {} ) do
    local padding = i == 1 and 10 or 4

    table.insert( content, {
      type = "editbox",
      label = setting.label,
      value = setting.value,
      on_change = setting.on_change,
      padding = padding
    } )
  end
end

---@class OptionsFrameDropdownOption
---@field value any
---@field label string

---@class OptionsFrameDropdownSetting
---@field key string
---@field label string
---@field value any
---@field options OptionsFrameDropdownOption[]
---@field on_change fun( value: any )

---@param content table
---@param dropdowns OptionsFrameDropdownSetting[]
local function add_dropdowns( content, dropdowns )
  for i, setting in ipairs( dropdowns or {} ) do
    local padding = i == 1 and 10 or 4

    table.insert( content, {
      type = "dropdown",
      label = setting.label,
      value = setting.value,
      options = setting.options,
      on_change = setting.on_change,
      padding = padding
    } )
  end
end

---@class OptionsFrameData
---@field title string?
---@field settings OptionsFrameBooleanSetting[]
---@field sliders OptionsFrameSliderSetting[]
---@field editboxes OptionsFrameEditboxSetting[]
---@field dropdowns OptionsFrameDropdownSetting[]
---@field buttons OptionsFrameButtonWithCallback[]

---@param data OptionsFrameData
local function transform( data )
  local content = {}
  add_title( content, data.title )
  add_settings( content, data.settings )
  add_editboxes( content, data.editboxes )
  add_sliders( content, data.sliders )
  add_dropdowns( content, data.dropdowns )
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
