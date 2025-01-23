local M = {}

local u = require( "test/utils" )
local RollingPopup = require( "src/RollingPopup" )

local function strip_functions( t )
  for _, line in ipairs( t ) do
    for k, v in pairs( line ) do
      if type( v ) == "function" then
        line[ k ] = nil
      end
    end
  end

  return t
end

local function cleanse( t )
  return u.map( strip_functions( t ), function( v )
    if (v.type == "text" or v.type == "info") and v.value then
      v.value = u.decolorize( v.value ) or v.value
    end

    return v
  end )
end

---@class RollingPopupMock : RollingPopup
---@field get fun(): table
---@field is_visible fun(): boolean
---@field click fun( button_type: RollingPopupButtonType )

---@param config Config
---@param controller RollController
function M.new( popup_builder, db, config, controller )
  local content
  local m_data ---@type RollingPopupPreviewData?

  local popup = RollingPopup.new( popup_builder, db, config, controller )
  ---@diagnostic disable-next-line: inject-field
  popup.get = function() return content and cleanse( content ) or {} end

  local old_refresh = popup.refresh
  popup.refresh = function( _, new_content )
    content = new_content
    old_refresh( _, new_content )
  end

  ---@diagnostic disable-next-line: inject-field
  popup.is_visible = function()
    return popup.get_frame():IsVisible()
  end

  ---@param data RollingPopupPreviewData
  local function show_preview( data )
    m_data = data
  end

  ---@diagnostic disable-next-line: inject-field
  popup.click = function( button_type )
    if not m_data then return end

    for _, button in ipairs( m_data.buttons ) do
      if button.type == button_type then button.callback() end
    end
  end

  controller.subscribe( "ShowRollingPopupPreview", show_preview )

  ---@type RollingPopupMock
  return popup
end

return M
