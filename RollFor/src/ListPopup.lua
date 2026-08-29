RollFor = RollFor or {}
local m = RollFor

if m.ListPopup then return end

local M = {}
local getn = m.getn

-- The shell the resistance-style list windows are all built out of: a draggable popup
-- that remembers where it was left, a refresh that rebuilds itself from a content
-- transformer, and show/hide/toggle on a slash command.
--
-- What actually differs between those windows is small -- the frame's name, the slash
-- command, which row widget it lists, and where its rows and buttons come from -- so
-- that is all the caller supplies. Everything below this line was previously copied
-- once per window, which is how three of them ended up with three chances to fix the
-- same layout bug.
--
-- Rows are laid out by chaining each line under the one before it, centered. Every row
-- widget reports the same fixed width for the reason GuiElements documents: the popup
-- sizes itself from the widest line, so self-measuring rows would let the columns
-- drift between windows.

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

local top_padding = 16

---@class ListPopup
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field refresh_if_visible fun()
---@field get_frame fun(): Popup?

---@class ListPopupConfig
---@field name string -- the global frame name
---@field slash_command string -- without the leading slash
---@field db table -- where the window position is remembered
---@field popup_builder PopupBuilder
---@field content_transformer table -- anything with transform( data ): table
---@field content fun(): table -- the model handed to the transformer, read fresh per refresh
---@field row_type string -- the line type its rows use, e.g. "resistance_row"
---@field row_callback string? -- the field a row carries that its widget calls back on

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 0 }

---@param config ListPopupConfig
---@return ListPopup
function M.new( config )
  ---@type Popup?
  local popup

  local function on_drag_stop()
    if not popup then return end

    if m.is_frame_out_of_bounds( popup ) then
      config.db.point = M.center_point
      popup:position( M.center_point )

      return
    end

    local anchor = popup:get_anchor_point()
    config.db.point = { point = anchor.point, relative_point = anchor.relative_point, x = anchor.x, y = anchor.y }
  end

  local function get_point()
    if popup and m.is_frame_out_of_bounds( popup ) then
      return M.center_point
    elseif config.db.point then
      return config.db.point
    else
      return M.center_point
    end
  end

  local function create_popup()
    local result = config.popup_builder
        :name( config.name )
        :point( get_point() )
        :gui_elements( m.GuiElements )
        :movable()
        :on_drag_stop( on_drag_stop )
        :strata( "DIALOG" )
        :self_centered_anchor()
        :anchor_point( "TOPLEFT" )
        :hidden()
        :build()

    result:border_color( 0.65, 0.22, 0.22, 0.22 )

    return result
  end

  ---@param frame table
  ---@param v table
  local function draw_button( frame, v )
    frame:SetWidth( v.width or button_defaults.width )
    frame:SetHeight( v.height or button_defaults.height )
    frame:SetText( v.label or "" )
    frame:ClearAllPoints() -- This fixes a strange visual bug in BCC. Frame is either without label or misaligned without this.
    frame:SetScale( v.scale or button_defaults.scale )
    frame:SetScript( "OnClick", v.on_click or function() end )

    if v.disabled then frame:Disable() else frame:Enable() end
  end

  -- SetRow writes every column on every call because FrameBuilder recycles line frames
  -- across refreshes; the same reason is why the callback is reassigned unconditionally
  -- rather than only when the row carries one -- a frame left holding the previous
  -- occupant's closure would act on the wrong player.
  ---@param frame table
  ---@param v table
  local function draw_row( frame, v )
    frame:SetHeader( v.header and true or false )
    frame:SetRow( v )

    if config.row_callback then
      frame[ config.row_callback ] = v[ config.row_callback ] or function() end
    end
  end

  ---@param frame table
  ---@param v table
  ---@param lines table[]
  local function place( frame, v, lines )
    local count = getn( lines )

    frame:ClearAllPoints()

    if count == 0 then
      frame:SetPoint( "TOP", popup, "TOP", 0, -top_padding - (v.padding or 0) )
    else
      frame:SetPoint( "TOP", lines[ count ].frame, "BOTTOM", 0, v.padding and -v.padding or 0 )
    end
  end

  local function refresh()
    if not popup then popup = create_popup() end
    popup:clear()

    for _, v in ipairs( config.content_transformer.transform( config.content() ) ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "button" then
          draw_button( frame, v )
        elseif type == config.row_type then
          draw_row( frame, v )
        elseif type == "checkbox_row" then
          frame:SetRow( v )
        elseif type == "text" then
          frame:SetText( v.value )
        end

        -- Buttons are laid out by the popup itself; everything else chains downwards.
        if type ~= "button" then place( frame, v, lines ) end
      end, v.padding )
    end
  end

  local function show()
    if not popup then popup = create_popup() end
    refresh()

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

  -- Nothing to redraw while it's hidden, and every caller that subscribes to a model
  -- wants exactly this, so it's the one they get rather than raw refresh.
  local function refresh_if_visible()
    if popup and popup:IsVisible() then refresh() end
  end

  m.slash_cmd( config.slash_command, toggle )

  ---@type ListPopup
  return {
    show = show,
    hide = hide,
    toggle = toggle,
    refresh_if_visible = refresh_if_visible,
    get_frame = function() return popup end
  }
end

m.ListPopup = M
return M
