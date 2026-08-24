RollFor = RollFor or {}
local m = RollFor

if m.ConfirmationDialog then return end

local M = {}
local getn = m.getn

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

-- A line's padding is the space *above* it: the popup chains each one under the last, so
-- that's the only gap a line gets to ask for.
--
-- The headline gets a wide one under it so it reads as a heading rather than as the first
-- of several sentences, and the question gets one of its own so what the buttons answer
-- isn't run together with the detail above it.
local title_gap = 14
local line_gap = 4
local question_gap = 8

-- Room under the last line for the buttons, handed to the popup builder by whoever
-- constructs one of these -- it's fixed at build time, so it can't be decided in here.
-- Wider than the popup default on purpose: an answer crowded up against the question it
-- answers is one that gets clicked before it's read.
M.bottom_margin = { classic = 44, modern = 33 }

-- A yes/no popup for anything that's about to do something the user can't take back.
-- The caller supplies the words and what to do with the answer; everything about the
-- window itself lives here.
--
-- One frame, reused: only one question can be on screen at a time, and a dialog asking
-- two things at once is a dialog nobody reads.
--
-- Dismissing counts as No. Escape, the close button and clicking Yes all end up in the
-- same OnHide, so the answer is cleared before the popup is hidden deliberately -- what
-- reaches OnHide with an answer still pending is a dismissal, and a confirmation that
-- treated that as silence would leave the caller waiting forever.

---@class ConfirmationRequest
---@field title string? -- headline; colored by this file, not the caller
---@field lines string[]? -- body lines, already colored by the caller
---@field question string -- the line the buttons answer
---@field yes_label string? -- defaults to "Yes"
---@field no_label string? -- defaults to "No"
---@field on_yes fun()
---@field on_no fun()?

---@class ConfirmationDialog
---@field show fun( request: ConfirmationRequest )
---@field hide fun()

---@param popup_builder PopupBuilder
---@param config Config
---@return ConfirmationDialog
function M.new( popup_builder, config )
  local popup
  local top_padding = config.classic_look() and 18 or 14

  -- What a dismissal means, while a question is on screen. Nil the rest of the time,
  -- which is what tells a deliberate hide from a dismissed one.
  local pending_no ---@type fun()?

  local function create_popup()
    local frame = popup_builder
        :name( "RollForConfirmationDialog" )
        :point( { point = "CENTER", relative_point = "CENTER", x = 0, y = 100 } )
        :sound()
        :esc()
        :gui_elements( m.GuiElements )
        :on_hide( function()
          local dismissed = pending_no
          pending_no = nil
          if dismissed then dismissed() end
        end )
        :backdrop_color( 0, 0, 0, 0.8 )
        :border_color( 0.125, 0.624, 0.976, 0.3 )
        :strata( "FULLSCREEN_DIALOG" )
        :movable()
        :build()

    m.api.tinsert( m.api.UISpecialFrames, frame:GetName() )

    return frame
  end

  -- Answering clears the pending dismissal before hiding, so the OnHide the hide itself
  -- causes doesn't come back around as a second answer.
  ---@param answer fun()?
  ---@return fun()
  local function answered_with( answer )
    return function()
      pending_no = nil
      popup:Hide()
      if answer then answer() end
    end
  end

  ---@param request ConfirmationRequest
  ---@return table
  local function make_content( request )
    local content = {}

    if request.title then
      table.insert( content, { type = "text", value = m.colors.blue( request.title ) } )
    end

    -- Whatever comes first under the headline takes the wide gap, body line or question
    -- alike: what wants the air is the break after the title, not any particular line.
    local first_gap = request.title and title_gap or 0
    local lines = request.lines or {}

    for i, line in ipairs( lines ) do
      table.insert( content, { type = "text", value = line, padding = i == 1 and first_gap or line_gap } )
    end

    table.insert( content, {
      type = "text",
      value = request.question,
      padding = getn( lines ) == 0 and first_gap or question_gap
    } )

    table.insert( content, {
      type = "button",
      label = request.yes_label or "Yes",
      width = 80,
      on_click = answered_with( request.on_yes )
    } )

    table.insert( content, {
      type = "button",
      label = request.no_label or "No",
      width = 80,
      on_click = answered_with( request.on_no )
    } )

    return content
  end

  ---@param request ConfirmationRequest
  local function show( request )
    if not popup then popup = create_popup() end

    -- Before clear(), because clearing and rebuilding must not read as a dismissal of
    -- whatever was being asked a moment ago.
    pending_no = nil
    popup:clear()

    for _, v in ipairs( make_content( request ) ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "text" then
          frame:SetText( v.value )
        elseif type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:ClearAllPoints() -- This fixes a strange visual bug in BCC. Frame is either without label or misaligned without this.
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )
          frame:SetFrameLevel( popup:GetFrameLevel() + 1 )
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

    pending_no = request.on_no
    popup:Show()
  end

  -- Closing it from code, which is not the user saying no to anything.
  local function hide()
    if not popup then return end

    pending_no = nil
    popup:Hide()
  end

  ---@type ConfirmationDialog
  return {
    show = show,
    hide = hide
  }
end

m.ConfirmationDialog = M
return M
