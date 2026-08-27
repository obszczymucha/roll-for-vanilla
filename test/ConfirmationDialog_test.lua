---@diagnostic disable: inject-field
package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
require( "src/modules" )
local ConfirmationDialog = require( "src/ConfirmationDialog" )

u.mock_wow_api()

-- A popup that actually runs the modify functions it's handed, unlike mocks/PopupBuilder
-- which drops them. The buttons are the whole point here: what this file is about is what
-- clicking one -- or not clicking either -- does.
local function popup_builder( recorder )
  local popup

  local function frame()
    return {
      SetText = function( self, text ) self.text = text end,
      SetWidth = function() end,
      SetHeight = function() end,
      SetScale = function() end,
      SetFrameLevel = function() end,
      ClearAllPoints = function() end,
      SetPoint = function() end,
      SetScript = function( self, script, handler ) self[ script ] = handler end
    }
  end

  popup = {
    lines = {},
    visible = false,
    add_line = function( line_type, modify_fn, padding )
      local line = { line_type = line_type, padding = padding or 0, frame = frame() }
      modify_fn( line_type, line.frame, popup.lines )
      table.insert( popup.lines, line )

      return line
    end,
    clear = function() popup.lines = {} end,
    Show = function() popup.visible = true end,
    Hide = function()
      -- Hiding is what runs OnHide in the client, and this file's whole dismissal story
      -- rides on that, so the stub does it too.
      popup.visible = false
      if recorder.on_hide then recorder.on_hide() end
    end,
    IsVisible = function() return popup.visible end,
    GetFrameLevel = function() return 1 end,
    GetName = function() return "RollForConfirmationDialog" end
  }

  local builder = {}

  setmetatable( builder, {
    __index = function()
      return function( self, arg )
        -- The one call whose argument matters to these tests.
        if type( arg ) == "function" then recorder.on_hide = arg end

        return self
      end
    end
  } )

  builder.build = function() return popup end

  return builder, popup
end

local function dialog()
  local recorder = {}
  local builder, popup = popup_builder( recorder )
  local sut = ConfirmationDialog.new( builder, { classic_look = function() return false end } )

  sut.popup = popup
  sut.is_visible = function() return popup.visible end

  -- Escape, or the close button: the client hides the frame and OnHide is all the module
  -- ever hears about it.
  sut.dismiss = function() popup.Hide() end

  sut.texts = function()
    local result = {}

    for _, line in ipairs( popup.lines ) do
      if line.line_type == "text" then table.insert( result, u.decolorize( line.frame.text ) or line.frame.text ) end
    end

    return result
  end

  -- A line's padding is the gap above it, which is the only spacing lever the popup
  -- gives a line. Text lines only -- buttons are placed along the bottom by the popup
  -- itself and ignore theirs.
  sut.gaps = function()
    local result = {}

    for _, line in ipairs( popup.lines ) do
      if line.line_type == "text" then table.insert( result, line.padding ) end
    end

    return result
  end

  sut.buttons = function()
    local result = {}

    for _, line in ipairs( popup.lines ) do
      if line.line_type == "button" then table.insert( result, line.frame ) end
    end

    return result
  end

  sut.click = function( label )
    for _, button in ipairs( sut.buttons() ) do
      if button.text == label then return button.OnClick() end
    end

    error( string.format( "No %s button.", label ), 2 )
  end

  return sut
end

---@param answers table
local function request( answers )
  return {
    title = "Roll the raid lockout over?",
    lines = { "This will forget 9 boss kills." },
    question = "Continue?",
    on_yes = function() table.insert( answers, "yes" ) end,
    on_no = function() table.insert( answers, "no" ) end
  }
end

ConfirmationDialogSpec = {}

function ConfirmationDialogSpec:should_show_the_title_the_lines_and_the_question_in_that_order()
  -- Given
  local sut = dialog()

  -- When
  sut.show( request( {} ) )

  -- Then
  eq( sut.texts(), { "Roll the raid lockout over?", "This will forget 9 boss kills.", "Continue?" } )
  eq( sut.is_visible(), true )
end

function ConfirmationDialogSpec:should_label_the_buttons_yes_and_no_by_default()
  -- Given
  local sut = dialog()

  -- When
  sut.show( request( {} ) )

  -- Then
  local buttons = sut.buttons()
  eq( buttons[ 1 ].text, "Yes" )
  eq( buttons[ 2 ].text, "No" )
end

function ConfirmationDialogSpec:should_set_the_title_apart_from_what_follows_it()
  -- Given
  local sut = dialog()

  -- When
  sut.show( request( {} ) )

  -- Then
  local gaps = sut.gaps()
  -- The title itself takes the popup's own top padding, so it asks for nothing.
  eq( gaps[ 1 ], 0 )
  eq( gaps[ 2 ] > gaps[ 3 ], true )
end

function ConfirmationDialogSpec:should_give_the_question_the_wide_gap_when_there_are_no_body_lines()
  -- What wants the air is the break under the title, so whatever lands first takes it.
  -- Given
  local sut = dialog()
  local with_lines = dialog()

  -- When
  sut.show( { title = "Roll the raid lockout over?", question = "Continue?", on_yes = function() end } )
  with_lines.show( request( {} ) )

  -- Then
  eq( sut.gaps()[ 2 ], with_lines.gaps()[ 2 ] )
end

function ConfirmationDialogSpec:should_answer_yes_and_hide()
  -- Given
  local answers = {}
  local sut = dialog()
  sut.show( request( answers ) )

  -- When
  sut.click( "Yes" )

  -- Then
  eq( answers, { "yes" } )
  eq( sut.is_visible(), false )
end

function ConfirmationDialogSpec:should_answer_no_and_hide()
  -- Given
  local answers = {}
  local sut = dialog()
  sut.show( request( answers ) )

  -- When
  sut.click( "No" )

  -- Then
  eq( answers, { "no" } )
  eq( sut.is_visible(), false )
end

function ConfirmationDialogSpec:should_treat_a_dismissal_as_no()
  -- Escape and the close button don't reach a button, and a confirmation that read that
  -- as silence would leave whatever asked the question waiting forever.
  -- Given
  local answers = {}
  local sut = dialog()
  sut.show( request( answers ) )

  -- When
  sut.dismiss()

  -- Then
  eq( answers, { "no" } )
end

function ConfirmationDialogSpec:should_not_answer_twice_when_yes_hides_the_popup()
  -- Yes hides the dialog, which is the same OnHide a dismissal comes through.
  -- Given
  local answers = {}
  local sut = dialog()
  sut.show( request( answers ) )

  -- When
  sut.click( "Yes" )

  -- Then
  eq( answers, { "yes" } )
end

function ConfirmationDialogSpec:should_not_answer_twice_when_no_hides_the_popup()
  -- Given
  local answers = {}
  local sut = dialog()
  sut.show( request( answers ) )

  -- When
  sut.click( "No" )

  -- Then
  eq( answers, { "no" } )
end

function ConfirmationDialogSpec:should_not_answer_the_previous_question_when_asked_a_new_one()
  -- One frame is reused for every question, so rebuilding it must not read as the last
  -- one being dismissed.
  -- Given
  local answers = {}
  local sut = dialog()
  sut.show( request( answers ) )

  -- When
  sut.show( request( answers ) )

  -- Then
  eq( answers, {} )
end

function ConfirmationDialogSpec:should_not_answer_anything_when_hidden_from_code()
  -- Closing it from code is not the user saying no to anything.
  -- Given
  local answers = {}
  local sut = dialog()
  sut.show( request( answers ) )

  -- When
  sut.hide()

  -- Then
  eq( answers, {} )
  eq( sut.is_visible(), false )
end

function ConfirmationDialogSpec:should_cope_with_a_question_that_has_no_no_handler()
  -- Nothing to do on no is a perfectly good answer to have.
  -- Given
  local sut = dialog()
  sut.show( { question = "Continue?", on_yes = function() end } )

  -- When
  sut.dismiss()

  -- Then
  eq( sut.is_visible(), false )
end

os.exit( lu.LuaUnit.run() )
