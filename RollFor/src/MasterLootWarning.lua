RollFor = RollFor or {}
local m = RollFor

if m.MasterLootWarning then return end

local M                    = {}
local red                  = m.colors.red
local blue                 = m.colors.blue
local grey                 = m.colors.grey
local table_contains_value = m.table_contains_value

---@diagnostic disable-next-line: undefined-global
local UIParent             = UIParent

local function create_frame( api )
  local frame = api().CreateFrame( "FRAME", "RollForMasterLootWarning", UIParent )
  frame:Hide()

  local label = frame:CreateFontString( nil, "OVERLAY" )
  label:SetFont( "FONTS\\FRIZQT__.TTF", 24, "OUTLINE" )
  label:SetPoint( "CENTER", 0, 0 )
  label:SetText( string.format( "No %s!", red( "Master Loot" ) ) )

  local label2 = frame:CreateFontString( nil, "OVERLAY" )
  label2:SetFont( "FONTS\\FRIZQT__.TTF", 16, "OUTLINE" )
  label2:SetPoint( "CENTER", 0, -20 )
  label2:SetText( string.format( "Enable %s or type %s to disable this message.", grey( "Master Loot" ), blue( "/rf ml" ) ) )

  frame:SetWidth( label:GetWidth() )
  frame:SetHeight( label:GetHeight() )
  frame:SetPoint( "CENTER", UIParent, "CENTER", 0, 140 )

  return frame
end

---@param api table
---@param config Config
---@param boss_list BossList
---@param player_info PlayerInfo
function M.new( api, config, boss_list, player_info )
  local frame
  local is_visible = false

  local function show()
    if not frame or is_visible or not config.show_ml_warning() then return end

    api().UIFrameFadeRemoveFrame( frame )
    frame:SetAlpha( 1 )
    frame:Show()
    is_visible = true
    frame.fading_out = nil
  end

  local function hide()
    if not frame or frame.fading_out or not frame:IsVisible() then return end

    frame.fading_out = true
    is_visible = false
    api().UIFrameFadeOut( frame, 2, 1, 0 )
    frame.fadeInfo.finishedFunc = function()
      frame.fading_out = nil
      frame:Hide()
    end
  end

  local function toggle()
    if not player_info.is_master_looter() and not player_info.is_leader() or config.auto_master_loot() then
      if is_visible then hide() end
      return
    end

    local master_loot = m.is_master_loot()
    local zone_name = api().GetRealZoneText()
    local target_name = api().UnitName( "target" )
    local zone = boss_list[ zone_name ] or {}
    local dead = api().UnitIsDead( "target" )

    if not zone or master_loot or not table_contains_value( zone, target_name ) or dead then
      if is_visible then hide() end
      return
    end

    if not frame then frame = create_frame( api ) end
    show()
  end

  return {
    on_player_target_changed = toggle,
    on_party_loot_method_changed = toggle,
    hide = hide
  }
end

m.MasterLootWarning = M
return M
