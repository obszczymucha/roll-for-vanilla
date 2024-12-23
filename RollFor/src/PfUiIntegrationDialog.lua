RollFor = RollFor or {}
local m = RollFor

if m.PfUiIntegrationDialog then return end

local M = {}

local confirmation_dialog_key = "ROLLFOR_PFUI_INTEGRATION_CONFIRMATION_DIALOG"
local blue = m.colors.blue
local hl = m.colors.hl
local info = m.pretty_print
local pfui = m.msg.pfui

function M.new( config )
  local function create_custom_dialog()
    m.api.StaticPopupDialogs[ confirmation_dialog_key ] = {
      text = string.format(
        "Would your like to integrate %s with %s?\n" ..
        "This will add %s and %s click support for roll and raid-rolling items.\n" ..
        "It will also replace master loot frame with roll winner tracking.\n" ..
        "You can always enable/disable the integration using %s.",
        blue( "RollFor" ),
        pfui,
        hl( "shift" ),
        hl( "alt" ),
        hl( "/rf config pfui" )
      ),
      button1 = m.api.YES,
      button2 = m.api.NO,
      OnAccept = function()
        config.enable_pfui_integration()
        info( string.format( "%s integration is now %s. Disable using %s.", pfui, m.msg.enabled, hl( "/rf config pfui" ) ) )
      end,
      OnCancel = function()
        config.disable_pfui_integration()
        info( string.format( "%s integration is now %s. Enable using %s.", pfui, m.msg.disabled, hl( "/rf config pfui" ) ) )
      end,
      timeout = 0,
    }
  end

  local function on_master_loot()
    if not m.uses_pfui() or config.pfui_integration_enabled() then return end
    create_custom_dialog()
    m.api.StaticPopup_Show( confirmation_dialog_key )
  end

  return {
    on_master_loot = on_master_loot
  }
end

m.PfUiIntegrationDialog = M
return M
