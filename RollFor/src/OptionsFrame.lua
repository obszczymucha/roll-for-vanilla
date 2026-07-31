RollFor = RollFor or {}
local m = RollFor

if m.OptionsFrame then return end

local M = {}
local getn = m.getn

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

---@class OptionsFrame
---@field show fun()
---@field refresh fun( _, data: OptionsFrameData )
---@field hide fun()
---@field toggle fun()
---@field get_frame fun(): Popup?

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 0 }

---@param popup_builder PopupBuilder
---@param content_transformer OptionsFrameContentTransformer
---@param config Config
---@param db table
function M.new( popup_builder, content_transformer, config, db )
  ---@type Popup?
  local popup
  local top_padding = config.classic_look() and 14 or 8

  local function on_drag_stop()
    if not popup then return end

    if m.is_frame_out_of_bounds( popup ) then
      db.point = M.center_point
      popup:position( M.center_point )

      return
    end

    local anchor = popup:get_anchor_point()
    db.point = { point = anchor.point, relative_point = anchor.relative_point, x = anchor.x, y = anchor.y }
  end

  local function get_point()
    if popup and m.is_frame_out_of_bounds( popup ) then
      return M.center_point
    elseif db.point then
      return db.point
    else
      return M.center_point
    end
  end

  local function create_popup()
    local result = popup_builder
        :name( "RollForOptionsFrame" )
        :point( get_point() )
        :gui_elements( m.GuiElements )
        :movable()
        :on_drag_stop( on_drag_stop )
        :strata( "DIALOG" )
        :self_centered_anchor()
        :hidden()
        :build()

    result:border_color( 0.351, 0.553, 1.0, 0.3 )

    return result
  end

  ---@param data OptionsFrameData
  local function refresh( _, data )
    if not popup then popup = create_popup() end
    popup:clear()

    for _, v in ipairs( content_transformer.transform( data ) ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:ClearAllPoints() -- This fixes a strange visual bug in BCC. Frame is either without label or misaligned without this.
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )
        elseif type == "checkbox" then
          frame:SetText( v.label or "" )
          frame:SetChecked( v.value )
          frame.on_click = v.on_click or function() end
        elseif type == "text" then
          frame:SetText( v.value )
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
  end

  local excluded_settings = {
    superwow_auto_loot_coins = true
  }

  ---@return OptionsFrameBooleanSetting[]
  local function boolean_settings()
    local result = {}

    for toggle_key, setting in pairs( config.toggles or {} ) do
      if not setting.hidden and not excluded_settings[ toggle_key ] then
        table.insert( result, {
          key = toggle_key,
          label = setting.display,
          value = config[ toggle_key ](),
          on_toggle = config[ "toggle_" .. toggle_key ]
        } )
      end
    end

    table.sort( result, function( a, b ) return a.label < b.label end )

    return result
  end

  ---@return OptionsFrameData
  local function default_content()
    return {
      title = "RollFor Options",
      settings = boolean_settings(),
      buttons = {
        { type = "Close", callback = function() if popup then popup:Hide() end end }
      }
    }
  end

  local function show()
    if not popup then popup = create_popup() end
    refresh( nil, default_content() )

    popup:Show()
  end

  local function hide()
    if popup then popup:Hide() end
  end

  local function toggle()
    if not popup then popup = create_popup() end

    if popup:IsVisible() then
      popup:Hide()
    else
      show()
    end
  end

  ---@type OptionsFrame
  return {
    show = show,
    refresh = refresh,
    hide = hide,
    toggle = toggle,
    get_frame = function() return popup end
  }
end

m.OptionsFrame = M
return M
