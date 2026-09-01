RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobinAddPlayerFrame then return end

local M = {}
local getn = m.getn

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

-- Puts a player into a queue by hand. A name and a class, because those are the two things a
-- queue row is: anybody can be added, in the group or not, since a queue outlives the raid it was
-- built in and somebody offline right now is exactly who you want to keep a place for.
--
-- One frame, reused, in the same shape as ConfirmationDialog: only one of these can be on screen
-- at a time, and the caller supplies what to do with the answer.
--
-- The class is only ever used to colour the name. It defaults to whatever the group roster says
-- about that name as you type, so adding somebody standing next to you is one field, not two.

---@class AutoRoundRobinAddPlayerFrame
---@field show fun( category: string )
---@field hide fun()
---@field get_frame fun(): Popup?

-- The two fields are sized independently, and in different units, because the widgets measure
-- themselves differently: an editbox is exactly as wide as it is told, while
-- UIDropDownMenu_SetWidth is given the width of the box's *text area* and makes the frame 50
-- wider than that. So the dropdown below is 62 + 50 = 112 pixels on screen against the name
-- field's 95 -- the two numbers are not comparable as written.
local name_field_width = 85
local class_dropdown_width = 65

-- The longest a character name can be, so the longest this field ever needs to hold.
local max_name_length = 12

-- Alphabetical, which is what a dropdown of nine equals should be.
---@return ValueLabel[]
local function class_options()
  local names = {}

  for _, class in pairs( m.Types.PlayerClass ) do table.insert( names, class ) end

  table.sort( names )

  local options = {}

  for _, class in ipairs( names ) do
    table.insert( options, { value = class, label = m.colorize_player_by_class( class, class ) } )
  end

  return options
end

---@param popup_builder PopupBuilder
---@param round_robin AutoRoundRobin
---@param group_roster GroupRoster
---@param on_added fun() -- lets the queue window redraw
---@return AutoRoundRobinAddPlayerFrame
function M.new( popup_builder, round_robin, group_roster, on_added )
  local popup
  local top_padding = 16

  local category
  local name = ""
  local class = m.Types.PlayerClass.Warrior
  local error_message

  -- Forward declared: the fields call it to redraw the error line and the class the roster
  -- guessed, and the buttons call it after a failed add.
  local refresh

  local function create_popup()
    local frame = popup_builder
        :name( "RollForAutoRoundRobinAddPlayerFrame" )
        :point( { point = "CENTER", relative_point = "CENTER", x = 0, y = 100 } )
        :gui_elements( m.GuiElements )
        :esc()
        :backdrop_color( 0, 0, 0, 0.8 )
        :border_color( 0.125, 0.624, 0.976, 0.3 )
        :strata( "FULLSCREEN_DIALOG" )
        :movable()
        :hidden()
        :build()

    m.api.tinsert( m.api.UISpecialFrames, frame:GetName() )

    return frame
  end

  local function hide()
    if popup then popup:Hide() end
  end

  -- Typing a name that is standing in the group fills the class in, because the roster already
  -- knows it and making somebody pick it again from a dropdown is asking them to retype a fact.
  -- A name nobody recognises leaves whatever was last chosen alone.
  ---@param typed string
  local function guess_class( typed )
    local player = group_roster.find_player( typed )
    if player and player.class then class = player.class end
  end

  local function submit()
    local added, why = round_robin.add_player( category, name, class )

    if not added then
      error_message = why
      refresh()

      return
    end

    hide()
    on_added()
  end

  ---@return table
  local function content()
    local lines = {
      -- Built in three pieces rather than as one format string: |r resets to the default colour
      -- rather than to the enclosing one, so a highlighted category nested inside a blue line
      -- would leave everything after it white.
      { type = "text", value = string.format( "%s%s%s",
        m.colors.blue( "Add a player to the " ), m.colors.hl( category ), m.colors.blue( " queue" ) ) },
      { type = "text_field", label = "Name", value = name, width = name_field_width,
        max_letters = max_name_length, padding = 14 },
      { type = "dropdown", label = "Class", value = class, options = class_options(),
        width = class_dropdown_width, padding = 10 }
    }

    if error_message then
      table.insert( lines, { type = "text", value = m.colors.red( error_message ), padding = 10 } )
    end

    table.insert( lines, { type = "button", label = "Add", width = 80, on_click = submit } )
    table.insert( lines, { type = "button", label = "Cancel", width = 80, on_click = hide } )

    return lines
  end

  refresh = function()
    if not popup then popup = create_popup() end
    popup:clear()

    for _, v in ipairs( content() ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:ClearAllPoints() -- This fixes a strange visual bug in BCC. Frame is either without label or misaligned without this.
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )
          frame:SetFrameLevel( popup:GetFrameLevel() + 1 )
        elseif type == "text_field" then
          frame:SetText( v.label or "" )
          frame:SetFieldWidth( v.width )
          frame:SetMaxLetters( v.max_letters )
          frame:SetValue( v.value )

          frame.on_change = function( typed )
            name = typed
            guess_class( typed )
          end

          -- Enter submits: it is a two-field form and the second field has a sensible default,
          -- so reaching for the mouse to confirm a name you just typed is the odd path.
          frame.on_enter = submit
          frame.on_escape = hide
        elseif type == "dropdown" then
          frame:SetText( v.label or "" )
          frame:SetDropdownWidth( v.width )
          frame:SetOptions( v.options )
          frame:SetValue( v.value )
          frame.on_change = function( selected ) class = selected end
        elseif type == "text" then
          frame:SetText( v.value )
        end

        if type ~= "button" then
          local count = getn( lines )

          frame:ClearAllPoints()

          if count == 0 then
            frame:SetPoint( "TOP", popup, "TOP", 0, -top_padding - (v.padding or 0) )
          else
            frame:SetPoint( "TOP", lines[ count ].frame, "BOTTOM", 0, v.padding and -v.padding or 0 )
          end
        end
      end, v.padding )
    end
  end

  ---@param queue_category string
  local function show( queue_category )
    category = queue_category
    -- A fresh form every time: the last name added is never the next one, and a stale error
    -- about it would be about nothing.
    name = ""
    error_message = nil

    refresh()
    popup:Show()
  end

  ---@type AutoRoundRobinAddPlayerFrame
  return {
    show = show,
    hide = hide,
    get_frame = function() return popup end
  }
end

m.AutoRoundRobinAddPlayerFrame = M
return M
