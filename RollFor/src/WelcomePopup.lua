RollFor = RollFor or {}
local m = RollFor

if m.WelcomePopup then return end

local M = {}

local getn = m.getn
local hl = m.colors.hl
local white = m.colors.white
local blue = m.colors.blue

function M.new( frame_builder, ace_timer, db )
  local popup
  local messages = {
    { text = "Welcome to version 4.",                    color = white },
    { text = "Check the minimap icon for new commands.", color = white },
    { text = "  ",                                       color = white },
    { text = "Be a responsible Master Looter.",          color = white },
    { text = "  ",                                       color = white },
    { text = "Happy rolling! o7",                        color = hl }
  }

  local message
  local line = 1
  local letters = 0
  local anchor
  local current_label

  local function fade( frame, mode, time, on_finish )
    local fade_info = {}

    fade_info.mode = mode
    fade_info.timeToFade = time
    fade_info.finishedFunc = on_finish

    if mode == "IN" then
      fade_info.startAlpha = 0
      fade_info.endAlpha = 1
      frame:SetAlpha( 0 )
      frame:Show()
    elseif mode == "OUT" then
      fade_info.startAlpha = 1
      fade_info.endAlpha = 0
    end

    m.api.UIFrameFade( frame, fade_info )
  end

  local function create_popup()
    local builder = frame_builder.new()
        :name( "RollForWelcomePopup" )
        :width( 260 )
        :height( 28 )
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :frame_style( "PrincessKenny" )
        :border_color( 0.125, 0.623, 0.976, 0.2 )
        :backdrop_color( 0, 0, 0, 0.7 )

    local frame = builder:build()

    local function create_label( parent, text, justify )
      local label = parent:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )
      label:SetTextColor( 1, 1, 1 )
      label:SetWidth( frame:GetWidth() - 2 )
      if justify then label:SetJustifyH( justify ) end

      label:SetText( text )

      return label
    end

    local header = create_label( frame, string.format( "%s", blue( "RollFor" ) ) )
    header:SetPoint( "TOP", 0, -9 )

    frame.new_line = function()
      frame:SetHeight( 35 + header:GetHeight() * line )
      current_label = create_label( frame, "" )

      if not anchor then
        current_label:SetPoint( "TOP", 0, -26 )
      else
        current_label:SetPoint( "TOP", anchor, "BOTTOM", 0, 0 )
      end

      anchor = current_label
    end

    frame.update_text = function( _, text )
      current_label:SetText( text )
    end

    return frame
  end

  local function animate()
    if not message then
      popup:new_line()
      message = messages[ line ]
    end

    if letters < string.len( message.text ) then
      ace_timer.ScheduleTimer( M, function()
        letters = letters + 1
        popup:update_text( message.color( string.sub( message.text, 1, letters ) ) )
        animate()
      end, 0.05 + m.api.random( 10 ) * 0.01 )
    else
      line = line + 1
      message = messages[ line ]
      letters = 0

      if line <= getn( messages ) then
        popup:new_line()
      else
        ace_timer.ScheduleTimer( M, function()
          fade( popup, "OUT", 5, function()
            db.showed = true
            popup:Hide()
          end )
        end, 3 )

        return
      end

      animate()
    end
  end

  local function show()
    if not popup then popup = create_popup() end

    popup:SetPoint( "CENTER", 0, 150 )

    ace_timer.ScheduleTimer( M, function()
      fade( popup, "IN", 2, function() ace_timer.ScheduleTimer( M, animate, 2 ) end )
    end, 3 )
  end

  return {
    should_show = function() return not db.showed end,
    show = show,
  }
end

m.WelcomePopup = M
return M
