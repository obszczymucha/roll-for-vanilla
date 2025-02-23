RollFor = RollFor or {}
local m = RollFor

if m.UiReloadPopup then return end

local M = {}
local getn = m.getn

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

---@class UiReloadPopup
---@field show fun()
---@field hide fun()

---@param popup_builder PopupBuilder
---@param config Config
function M.new( popup_builder, config )
  local popup
  local classic = config.classic_look()
  local top_padding = classic and 18 or 14
  local on_hide ---@type fun()?

  local function create_popup()
    local frame = popup_builder
        :name( "RollForUiReloadPopup" )
        :point( { point = "CENTER", relative_point = "CENTER", x = 0, y = 100 } )
        :sound()
        :esc()
        :gui_elements( m.GuiElements )
        :on_hide( function()
          if on_hide then
            on_hide()
          end
        end )
        :backdrop_color( 0, 0, 0, 0.8 )
        :border_color( 0.125, 0.624, 0.976, 0.3 )
        :strata( "FULLSCREEN_DIALOG" )
        :movable()
        :build()

    m.api.tinsert( m.api.UISpecialFrames, frame:GetName() )

    return frame
  end

  ---@param on_yes function
  ---@param on_no function
  local function make_content( on_yes, on_no )
    local content = {
      { type = "text",   value = m.colors.blue( "This change requires a UI reload." ) },
      { type = "text",   value = "Reload the UI now?" },
      { type = "button", label = "Yes",                                               width = 80, on_click = on_yes },
      { type = "button", label = "No",                                                width = 80, on_click = on_no }
    }

    return content
  end

  local function show()
    if not popup then popup = create_popup() end
    popup:clear()

    local function on_yes()
      m.api.ReloadUI()
    end

    local function on_no()
      popup:Hide()
    end

    for _, v in ipairs( make_content( on_yes, on_no ) ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "text" then
          frame:SetText( v.value )
        elseif type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )
          frame:SetFrameLevel( popup:GetFrameLevel() + 1 )
        end

        if type ~= "button" then
          local count = getn( lines )

          if count == 0 then
            local y = -top_padding - (v.padding or 0)
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", popup, "TOP", 0, y )
          else
            local line_anchor = lines[ count ].frame
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", line_anchor, "BOTTOM", 0, v.padding and -v.padding or 0 )
          end
        end
      end, v.padding )
    end

    popup:Show()
  end

  local function hide()
    if popup then
      on_hide = nil
      popup:Hide()
    end
  end

  ---@type LootAwardPopup
  return {
    show = show,
    hide = hide
  }
end

m.UiReloadPopup = M
return M
