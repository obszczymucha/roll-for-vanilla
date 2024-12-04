---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.RollingTipPopup then return end

local M = {}

local m = modules
local blue = m.colors.blue
local green = m.colors.green
local white = m.colors.white

function M.new( popup_builder, config )
  local popup

  local function create_popup()
    local builder = popup_builder()
        :with_name( "RollForTipFrame" )
        ---@diagnostic disable-next-line: undefined-global
        :with_frame_level( LootFrame:GetFrameLevel() )
        :with_bg_file( "Interface/Buttons/WHITE8x8" )
        :with_backdrop_color( 0, 0, 0, 0.6 )

    if modules.uses_pfui() then
      builder = builder
          :with_width( 110 )
          :with_height( 39 )
          :with_frame_style( "PrincessKenny" )
          :with_border_color( 0.5, 0.5, 0.5, 0.5 )
    else
      builder = builder
          :with_width( 130 )
          :with_height( 49 )
    end

    local frame = builder:build()

    local function create_font_string( parent, text, anchor )
      local font_string = parent:CreateFontString( nil, "ARTWORK", "GameFontNormalSmall" )

      if not anchor then
        font_string:SetPoint( "TOP", parent, "TOP", 0, 0 )
      else
        font_string:SetPoint( "TOP", anchor, "BOTTOM", 0, -2 )
      end

      font_string:SetText( text )

      return font_string
    end

    local inner_frame = m.api.CreateFrame( "Button", nil, frame )
    inner_frame:SetPoint( "CENTER", 0, 0 )
    local text1 = create_font_string( inner_frame, string.format( "%s %s", blue( "Shift" ), white( "click to roll." ) ) )
    create_font_string( inner_frame, string.format( "%s %s", green( "Alt" ), white( "click to raid-roll." ) ), text1 )

    inner_frame:SetWidth( frame:GetWidth() - 2 )
    inner_frame:SetHeight( text1:GetHeight() * 2 + 2 )

    inner_frame:SetScript( "OnEnter", function()
      ---@diagnostic disable-next-line: undefined-global
      local self = this
      self.tooltip_scale = m.api.GameTooltip:GetScale()
      m.api.GameTooltip:SetOwner( self, "ANCHOR_CURSOR" )
      m.api.GameTooltip:AddLine( string.format( "Use %s to hide this info.", blue( "/rf config rolling-tip" ) ), 1, 1, 1 )
      m.api.GameTooltip:SetScale( 0.75 )
      m.api.GameTooltip:Show()
    end )

    inner_frame:SetScript( "OnLeave", function()
      ---@diagnostic disable-next-line: undefined-global
      local self = this
      m.api.GameTooltip:Hide()
      m.api.GameTooltip:SetScale( self.tooltip_scale or 1 )
    end )

    return frame
  end

  local function show()
    if not config.show_rolling_tip() then return end
    if not popup then popup = create_popup() end

    if modules.uses_pfui() and config.pfui_integration_enabled() then
      ---@diagnostic disable-next-line: undefined-global
      popup:SetPoint( "TOPRIGHT", pfLootFrame, "TOPLEFT", -2, 1 )
    else
      ---@diagnostic disable-next-line: undefined-global
      popup:SetPoint( "BOTTOMLEFT", LootFrame, "TOPLEFT", 60, -15 )
      ---@diagnostic disable-next-line: undefined-global
      popup:SetFrameLevel( LootFrame:GetFrameLevel() - 1 )
    end

    popup:Show()
  end

  local function on_loot_opened()
    if modules.is_player_master_looter() then
      local count_items_to_loot = modules.count_items_to_master_loot()
      if count_items_to_loot == 0 then return end

      show()
    end
  end

  local function on_loot_closed()
    if popup then popup:Hide() end
  end

  config.subscribe( "rolling_tip", function( enabled )
    if enabled then
      show()
    else
      if popup then popup:Hide() end
    end
  end )

  return {
    show = show,
    on_loot_opened = on_loot_opened,
    on_loot_closed = on_loot_closed
  }
end

modules.RollingTipPopup = M
return M
