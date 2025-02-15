RollFor = RollFor or {}
local m = RollFor

if m.PopupBuilder then return end

local M = {}

---@class Popup : Frame
---@field resize fun( self: Popup, lines: table )

---@class PopupBuilder
---@field name fun( self: PopupBuilder, name: string ): PopupBuilder
---@field height fun( self: PopupBuilder, height: number ): PopupBuilder
---@field width fun( self: PopupBuilder, width: number ): PopupBuilder
---@field point fun( self: PopupBuilder, p: table ): PopupBuilder
---@field sound fun( self: PopupBuilder ): PopupBuilder
---@field frame_level fun( self: PopupBuilder, frame_level: number ): PopupBuilder
---@field backdrop_color fun( self: PopupBuilder, r: number, g: number, b: number, a: number ): PopupBuilder
---@field bg_file fun( self: PopupBuilder, bg_file: string ): PopupBuilder
---@field esc fun( self: PopupBuilder ): PopupBuilder
---@field gui_elements fun( self: PopupBuilder, gui_elements: table ): PopupBuilder
---@field frame_style fun( self: PopupBuilder, frame_style: string ): PopupBuilder
---@field on_drag_stop fun( self: PopupBuilder, callback: function ): PopupBuilder
---@field movable fun( self: PopupBuilder ): PopupBuilder
---@field border_size fun( self: PopupBuilder, border_size: number ): PopupBuilder
---@field on_show fun( self: PopupBuilder, on_show: function ): PopupBuilder
---@field on_hide fun( self: PopupBuilder, on_hide: function ): PopupBuilder
---@field border_color fun( self: PopupBuilder, r: number, g: number, b: number, a: number ): PopupBuilder
---@field self_centered_anchor fun( self: PopupBuilder ): PopupBuilder
---@field scale fun( self: PopupBuilder, scale: number ): PopupBuilder
---@field build fun( self: PopupBuilder ): Popup

---@param frame_builder FrameBuilderFactory
function M.new( frame_builder )
  local button_padding = 10
  local bottom_margin = 30

  local function align_buttons( popup, lines )
    if not popup.buttons_frame then
      local frame = m.api.CreateFrame( "Frame", nil, popup )
      frame:SetPoint( "BOTTOM", 0, 8 )
      popup.buttons_frame = frame
    end

    local total_width = 0
    local max_height = 0
    local last_anchor = nil

    local buttons = m.filter( lines, function( line ) return line.line_type == "button" end )

    for _, button in ipairs( buttons ) do
      local frame = button.frame
      local height = frame:GetHeight()
      local width = frame:GetWidth()
      local scale = frame:GetScale()

      if height > max_height then max_height = height end

      if not last_anchor then
        frame:SetPoint( "LEFT", popup.buttons_frame, "LEFT", 0, 0 )
      else
        frame:SetPoint( "LEFT", last_anchor, "RIGHT", button_padding, 0 )
        total_width = total_width + (button_padding * scale)
      end

      total_width = total_width + (width * scale)
      last_anchor = frame
    end

    popup.buttons_frame:SetWidth( total_width )
    popup.buttons_frame:SetHeight( max_height )
  end

  local function get_total_width( buttons )
    local result = 0

    for _, button in ipairs( buttons ) do
      local frame = button.frame
      result = result + frame:GetWidth() * frame:GetScale()
    end

    return result
  end

  local function resize( popup, lines )
    local max_width = 0
    local height = 0

    for _, line in ipairs( lines ) do
      if line.line_type ~= "button" and line.line_type ~= "info" then
        local frame = line.frame
        local scale = frame.GetScale and frame:GetScale() or 1
        local width = frame:GetWidth() * scale

        height = height + frame:GetHeight() * scale
        height = height + line.padding
        if width > max_width then max_width = width end
      end
    end


    local buttons = m.filter( lines, function( line ) return line.line_type == "button" end )
    local button_count = #buttons
    local button_width = get_total_width( buttons ) + (button_count - 1) * button_padding

    if button_width > max_width then max_width = button_width end

    if button_count > 0 then
      height = height + 23
    end

    popup:SetWidth( max_width + 35 )
    popup:SetHeight( height + (button_count > 0 and bottom_margin or 23) )

    align_buttons( popup, lines )
  end

  local decoratee = frame_builder.new()
  local build = decoratee.build

  decoratee.build = function()
    ---@class Popup
    local result = build( decoratee )
    result.resize = resize

    return result
  end

  return decoratee
end

m.PopupBuilder = M
return M
