---@diagnostic disable: inject-field
local M = {}

local u = require( "test/utils" )
local _, eq = u.luaunit( "assertEquals" )
local AutoRoundRobinAddPlayerFrame = require( "src/AutoRoundRobinAddPlayerFrame" )

-- The real frame over the mocked PopupBuilder, driven through the lines it hands add_line. That
-- is the only seam there is: unlike the list windows this one has no content transformer, because
-- there is nothing here worth transforming -- two fields and two buttons.

---@class AutoRoundRobinAddPlayerFrameMock : AutoRoundRobinAddPlayerFrame
---@field is_visible fun(): boolean
---@field should_be_visible fun()
---@field should_be_hidden fun()
---@field type_name fun( name: string )
---@field pick_class fun( class: string )
---@field press_enter fun()
---@field click fun( label: string )
---@field labels fun(): string[]
---@field field fun( label: string ): table?
---@field class_options fun(): string[]

---@param popup_builder PopupBuilder
---@param round_robin AutoRoundRobin
---@param group_roster GroupRoster
---@param on_added fun()
function M.new( popup_builder, round_robin, group_roster, on_added )
  -- Whatever the frame last drew. The mocked popup's add_line hands us the line's type and a
  -- stub frame, and the frame's own modify_fn writes the callbacks onto that stub -- so driving
  -- the form is a matter of calling them back.
  local lines = {}

  local builder = popup_builder.new()
  local real_build = builder.build

  builder.build = function( self )
    local popup = real_build( self )

    popup.clear = function() lines = {} end
    popup.GetFrameLevel = function() return 1 end

    popup.add_line = function( line_type, modify_fn )
      local frame = {
        SetWidth = function() end,
        SetHeight = function() end,
        SetScale = function() end,
        SetText = function( _, text ) end,
        SetValue = function( _, value ) end,
        SetOptions = function( _, options ) end,
        SetFieldWidth = function() end,
        SetMaxLetters = function() end,
        SetDropdownWidth = function() end,
        SetScript = function() end,
        ClearAllPoints = function() end,
        SetPoint = function() end,
        SetFrameLevel = function() end
      }

      local line = { type = line_type, frame = frame }

      -- Captured off the setters rather than guessed at, so a spec reads what the user would.
      frame.SetText = function( _, text ) line.text = text end
      frame.SetValue = function( _, value ) line.value = value end
      frame.SetOptions = function( _, options ) line.options = options end
      frame.SetScript = function( _, script, handler )
        if script == "OnClick" then line.on_click = handler end
      end

      table.insert( lines, line )
      modify_fn( line_type, frame, {} )

      return line
    end

    return popup
  end

  local frame = AutoRoundRobinAddPlayerFrame.new( builder, round_robin, group_roster, on_added )

  ---@param label string
  local function field( label )
    for _, line in ipairs( lines ) do
      if line.text == label then return line end
    end
  end

  frame.field = field

  frame.labels = function()
    local result = {}
    for _, line in ipairs( lines ) do table.insert( result, line.text ) end

    return result
  end

  frame.is_visible = function()
    local popup = frame.get_frame()
    return popup and popup:IsVisible() or false
  end

  frame.type_name = function( name )
    field( "Name" ).frame.on_change( name )
  end

  frame.pick_class = function( class )
    field( "Class" ).frame.on_change( class )
  end

  frame.press_enter = function()
    field( "Name" ).frame.on_enter()
  end

  frame.class_options = function()
    local result = {}

    for _, option in ipairs( field( "Class" ).options or {} ) do
      table.insert( result, option.value )
    end

    return result
  end

  frame.click = function( label )
    for _, line in ipairs( lines ) do
      if line.type == "button" and line.text == label then
        line.on_click()
        return
      end
    end

    error( string.format( "There is no %s button.", label ), 2 )
  end

  frame.should_be_visible = function()
    if not frame.is_visible() then error( "Add player frame is hidden.", 2 ) end
  end

  frame.should_be_hidden = function()
    if frame.is_visible() then error( "Add player frame is visible.", 2 ) end
  end

  ---@type AutoRoundRobinAddPlayerFrameMock
  return frame
end

return M
