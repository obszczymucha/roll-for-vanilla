RollFor = RollFor or {}
local m = RollFor

if m.OptionsFrame then return end

local M = {}
local getn = m.getn
local ItemQuality = m.Types.ItemQuality

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
        :esc()
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
          frame.on_click = v.on_click and v.on_click or function() end
        elseif type == "slider" then
          frame:SetText( v.label or "" )
          frame:SetMinMaxValues( v.min, v.max )
          frame:SetPrecision( v.precision )
          frame:SetValue( v.value )
          frame.on_change = v.on_change or function() end
        elseif type == "dropdown" then
          frame:SetText( v.label or "" )
          frame:SetOptions( v.options )
          frame:SetValue( v.value )
          frame.on_change = v.on_change or function() end
        elseif type == "editbox" then
          frame:SetText( v.label or "" )
          frame:SetPrecision( v.precision )
          frame:SetValue( v.value )
          frame.on_change = v.on_change or function() end
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

  local master_loot_threshold_choices = {
    { value = ItemQuality.Uncommon, label = m.colorize_item_by_quality( "Uncommon", ItemQuality.Uncommon ) },
    { value = ItemQuality.Rare,     label = m.colorize_item_by_quality( "Rare", ItemQuality.Rare ) },
    { value = ItemQuality.Epic,     label = m.colorize_item_by_quality( "Epic", ItemQuality.Epic ) },
  }

  ---@param settings OptionsSetting[]
  ---@param toggle_key string
  local function add_toggle( settings, toggle_key )
    ---@type ConfigToggle
    local toggle = config.toggles[ toggle_key ]
    if not toggle then return end

    ---@type BooleanSetting
    local setting = {
      type = "boolean",
      label = toggle.display,
      value = config[ toggle_key ](),
      on_change = config[ "set_" .. toggle_key ]
    }

    table.insert( settings, setting )
  end

  ---@param settings OptionsSetting[]
  ---@param key string
  ---@param label string
  ---@param precision number
  local function add_number( settings, key, label, precision )
    local get_value = config[ key ]
    if not get_value then return end

    ---@type NumberSetting
    local setting = {
      type = "number",
      label = label,
      value = get_value(),
      precision = precision,
      on_change = config[ "set_" .. key ]
    }

    table.insert( settings, setting )
  end

  ---@param settings OptionsSetting[]
  ---@param key string
  ---@param label string
  ---@param min number
  ---@param max number
  ---@param precision number
  local function add_slider( settings, key, label, min, max, precision )
    local get_value = config[ key ]
    if not get_value then return end

    ---@type ConstrainedNumberSetting
    local setting = {
      type = "constrained_number",
      label = label,
      value = get_value(),
      precision = precision,
      min = min,
      max = max,
      on_change = config[ "set_" .. key ]
    }

    table.insert( settings, setting )
  end

  ---@param settings OptionsSetting[]
  ---@param key string
  ---@param label string
  ---@param choices ValueLabel[]
  local function add_choice( settings, key, label, choices )
    local get_value = config[ key ]
    if not get_value then return end

    ---@type StringChoiceSetting
    local setting = {
      type = "choice",
      label = label,
      value = get_value(),
      choices = choices,
      on_change = config[ "set_" .. key ]
    }

    table.insert( settings, setting )
  end

  ---@return OptionsFrameData
  local function default_content()
    local settings = {}

    add_toggle( settings, "auto_loot" )
    add_toggle( settings, "auto_loot_announce" )
    add_toggle( settings, "auto_loot_messages" )
    add_toggle( settings, "auto_group_loot" )
    add_toggle( settings, "auto_master_loot" )
    add_toggle( settings, "auto_raid_roll" )
    add_toggle( settings, "auto_round_robin" )
    add_toggle( settings, "show_ml_warning" )
    add_toggle( settings, "rolling_popup_lock" )
    add_toggle( settings, "raid_roll_again" )
    add_toggle( settings, "classic_look" )
    add_toggle( settings, "resistance_bonus_rolls_enabled" )
    add_number( settings, "ms_roll_threshold", "MS roll threshold", 0 )
    add_number( settings, "os_roll_threshold", "OS roll threshold", 0 )
    add_number( settings, "resistance_check_throttle", "Resistance check throttle", 1 )
    add_slider( settings, "default_rolling_time_seconds", "Default rolling time (seconds)", 4, 15, 0 )
    add_slider( settings, "master_loot_frame_rows", "Master loot frame rows", 5, 20, 0 )
    add_slider( settings, "sr_roll_spacing", "SR roll spacing", 16, 28, 1 )
    add_choice( settings, "master_loot_threshold", "Master loot threshold", master_loot_threshold_choices )

    return {
      title = "RollFor Options",
      settings = settings,
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
