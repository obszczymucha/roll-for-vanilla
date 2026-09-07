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

---@alias OptionsSection "general"|"extension"

---@class OptionsFrame
---@field show fun()
---@field refresh fun( _, data: OptionsFrameData )
---@field get_frame fun(): Popup?

---@param popup_builder PopupBuilder
---@param content_transformer OptionsFrameContentTransformer
---@param config Config
---@param parent Frame -- the settings panel canvas this renders into
---@param section OptionsSection? -- which subcategory's page this is; general by default
---@param extension_name string? -- which extension, when section is "extension"
function M.new( popup_builder, content_transformer, config, parent, section, extension_name )
  ---@type Popup?
  local popup
  -- How far the page sits in from the settings panel's own edges, and the only top margin
  -- there is. It used to be three stacked offsets -- this inset, a popup top padding, and
  -- an extra gap the transformer gave the first line -- but the latter two were both
  -- there to clear the window title, and the settings window draws that itself now.
  local side_inset, top_inset = 16, 16

  -- The options live in the game's own settings window now, so this is no longer a
  -- popup: no dragging, no remembered position, no Esc handling, no strata of its own.
  -- What's left of the popup machinery is the part that earns its keep -- `resize`,
  -- which sizes the frame to whatever content_transformer produced, so the panel doesn't
  -- have to be laid out by hand every time a setting is added.
  --
  -- Anchored top-left inside the canvas, with no border and no backdrop, so it reads as
  -- part of the settings page rather than a window sitting on top of one.
  local function create_popup()
    local result = popup_builder
        :name( "RollForOptionsFrame" )
        :parent( parent )
        :point( { point = "TOPLEFT", relative_frame = parent, relative_point = "TOPLEFT",
          x = side_inset, y = -top_inset } )
        :gui_elements( m.GuiElements )
        :backdrop_color( 0, 0, 0, 0 )
        :no_border()
        :build()

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
        elseif type == "text" or type == "section_header" or type == "paragraph" then
          frame:SetText( v.value )
        end

        if type ~= "button" then
          local count = getn( lines )

          -- Left-aligned, not centred. Every option widget is a container that sizes
          -- itself to its own content, so centring them lined up their *middles* and left
          -- the labels ragged down the page. Anchoring on the left edge puts every label
          -- at the same x, which is what a settings page is expected to look like.
          if count == 0 then
            frame:ClearAllPoints()
            frame:SetPoint( "TOPLEFT", popup, "TOPLEFT", 0, -(v.padding or 0) )
          else
            local line_anchor = lines[ count ].frame
            frame:ClearAllPoints()
            frame:SetPoint( "TOPLEFT", line_anchor, "BOTTOMLEFT", 0, v.padding and -v.padding or 0 )
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

  ---@param settings OptionsSetting[]
  local function general_settings( settings )
    add_toggle( settings, "auto_loot" )
    add_toggle( settings, "auto_loot_announce" )
    add_toggle( settings, "auto_loot_messages" )
    add_toggle( settings, "auto_group_loot" )
    add_toggle( settings, "auto_master_loot" )
    add_toggle( settings, "auto_raid_roll" )
    add_toggle( settings, "show_ml_warning" )
    add_toggle( settings, "rolling_popup_lock" )
    add_toggle( settings, "raid_roll_again" )
    add_toggle( settings, "classic_look" )
    add_number( settings, "ms_roll_threshold", "MS roll threshold", 0 )
    add_number( settings, "os_roll_threshold", "OS roll threshold", 0 )
    add_slider( settings, "default_rolling_time_seconds", "Default rolling time (seconds)", 4, 15, 0 )
    add_slider( settings, "master_loot_frame_rows", "Master loot frame rows", 5, 20, 0 )
    add_slider( settings, "sr_roll_spacing", "SR roll spacing", 16, 28, 1 )
    add_choice( settings, "master_loot_threshold", "Master loot threshold", master_loot_threshold_choices )
  end

  -- The page core draws for an extension that supplies none of its own: the switch, and
  -- nothing else. Anything worth saying about what the extension does is the extension's
  -- to say, on the page it builds itself -- core does not keep a copy.
  ---@param settings OptionsSetting[]
  local function extension_settings( settings )
    local extension = m.Extensions.get( extension_name )
    if not extension then return end

    if extension.incompatible then
      table.insert( settings, {
        type = "paragraph",
        value = string.format( "This extension was built for a newer version of RollFor (extension API %s, this is %s), so it cannot be enabled.",
          tostring( extension.api_version ), m.Extensions.API_VERSION )
      } )

      return
    end

    ---@type BooleanSetting
    local enabled = {
      type = "boolean",
      label = "Enabled",
      value = m.Extensions.is_enabled( extension.name ),
      on_change = function( value ) m.Extensions.set_enabled( extension.name, value ) end
    }

    table.insert( settings, enabled )
  end

  -- General and each extension are separate subcategories, so each one is a page of its
  -- own and this renders whichever it was built for.
  --
  -- No title and no Close button: the settings window supplies both. A Close button
  -- inside a settings page would close nothing anyone expects.
  ---@return OptionsFrameData
  local function default_content()
    local settings = {}

    if section == "extension" then
      extension_settings( settings )
    else
      general_settings( settings )
    end

    return {
      settings = settings
    }
  end

  -- Called when the settings panel is shown, so what's on screen is read from the
  -- config at that moment rather than from whenever the page was last built.
  local function show()
    if not popup then popup = create_popup() end
    refresh( nil, default_content() )

    popup:Show()
  end

  ---@type OptionsFrame
  return {
    show = show,
    refresh = refresh,
    get_frame = function() return popup end
  }
end

m.OptionsFrame = M
return M
