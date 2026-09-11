RollFor = RollFor or {}
local m = RollFor

if m.OptionsFrameContentTransformer then return end

local M = {}

local blue = m.colors.blue
local getn = m.getn

-- Rows of one list, so they sit closer together than two unrelated controls would.
local priority_row_padding = 3

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

---@alias OptionsSetting BooleanSetting|NumberSetting|ConstrainedNumberSetting|StringChoiceSetting|HeaderSetting|ParagraphSetting|PriorityListSetting

---@class HeaderSetting
---@field type "header"
---@field label string

---@class ParagraphSetting
---@field type "paragraph"
---@field value string

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

---@class PriorityEntry
---@field name string -- the id, for whoever is being ranked; not shown
---@field title string -- what the user reads

-- An ordered list the user rearranges, rather than a value they pick. Nothing about the list
-- is stored here: `value` is whatever the current order is at the moment the page is drawn,
-- and a move is reported straight back rather than collected and applied.
---@class PriorityListSetting
---@field type "priority_list"
---@field label string
---@field value PriorityEntry[]
---@field on_move fun( position: number, offset: number ) -- offset is -1 for up, 1 for down

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

-- One header and a row per entry, rather than one line holding the list: a line is a frame,
-- and the rows have to be frames of their own to be clicked. Nothing scrolls here, so the
-- list is however long it is.
--
-- The arrows come pre-answered rather than the row working out where it sits: the first row
-- cannot move up and the last cannot move down, and a button that does nothing when clicked
-- is worse than one that says it will not.
---@param content table
---@param setting PriorityListSetting
---@param padding number
local function add_priority_list( content, setting, padding )
  table.insert( content, { type = "section_header", value = blue( setting.label ), padding = padding } )

  local count = getn( setting.value )

  for position, entry in ipairs( setting.value ) do
    table.insert( content, {
      type = "priority_row",
      label = entry.title,
      can_move_up = position > 1,
      can_move_down = position < count,
      on_up = function() setting.on_move( position, -1 ) end,
      on_down = function() setting.on_move( position, 1 ) end,
      padding = priority_row_padding
    } )
  end
end

---@class OptionsFrameData
---@field title string?
---@field settings OptionsSetting[]
---@field buttons OptionsFrameButtonWithCallback[]

---@param data OptionsFrameData
local function transform( data )
  ---@param type "boolean"|"number"|"constrained_number"|"choice"|"header"|"paragraph"|"priority_list"
  local function get_padding( type )
    -- The list leads with its own heading, so it is spaced like one.
    if type == "header" or type == "priority_list" then
      return 13
    elseif type == "paragraph" then
      return 9
    elseif type == "boolean" then
      return 5
    elseif type == "number" then
      return 10
    elseif type == "constrained_number" then
      return 10
    else
      return 8
    end
  end

  local content = {}

  add_title( content, data.title )

  -- A paragraph is a block of prose, and whatever comes after it is a new thought -- so
  -- it gets more air than the ordinary gap between two controls, which would otherwise
  -- leave a checkbox looking like the last line of the paragraph.
  local after_paragraph_padding = 16

  for i, setting in ipairs( data.settings ) do
    local previous = data.settings[ i - 1 ]

    -- The first line starts at the top of the page. The gap it used to get was clearance
    -- for the window title, which the settings window supplies itself now.
    local padding = i == 1 and 0
        or previous and previous.type == "paragraph" and after_paragraph_padding
        or get_padding( setting.type )

    if setting.type == "boolean" then
      add_checkbox( content, setting, padding )
    elseif setting.type == "number" then
      add_editbox( content, setting, padding )
    elseif setting.type == "constrained_number" then
      add_slider( content, setting, padding )
    elseif setting.type == "choice" then
      add_dropdown( content, setting, padding )
    elseif setting.type == "header" then
      table.insert( content, { type = "section_header", value = blue( setting.label ), padding = padding } )
    elseif setting.type == "paragraph" then
      table.insert( content, { type = "paragraph", value = setting.value, padding = padding } )
    elseif setting.type == "priority_list" then
      add_priority_list( content, setting, padding )
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
