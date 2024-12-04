---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.MasterLootFrame then return end

local M = {}

local _G = getfenv()
local icon_width = 16
local button_width = 85 + icon_width
local button_height = 16
local horizontal_padding = 3
local vertical_padding = 5
local rows = 5

---@diagnostic disable-next-line: undefined-field
local mod = math.mod
---@diagnostic disable-next-line: deprecated
local getn = table.getn

local OldLootFrame_OnEvent = LootFrame_OnEvent

function LootFrame_OnEvent( event )
  if event ~= "OPEN_MASTER_LOOT_LIST" then
    OldLootFrame_OnEvent( event )
  end
end

local function highlight( frame )
  frame:SetBackdropColor( frame.color.r, frame.color.g, frame.color.b, 0.3 )
end

local function dim( frame )
  frame:SetBackdropColor( 0.5, 0.5, 0.5, 0.1 )
end

local function press( frame )
  frame:SetBackdropColor( frame.color.r, frame.color.g, frame.color.b, 0.7 )
end

local function restore_loot_buttons()
  for i = 1, modules.api.LOOTFRAME_NUMBUTTONS do
    local name = "LootButton" .. i
    local button = _G[ name ]

    if button.OriginalOnClick then button:SetScript( "OnClick", button.OriginalOnClick ) end
  end
end

local function create_main_frame()
  local frame = modules.api.CreateFrame( "Frame", "RollForLootFrame" )
  frame:Hide()
  frame:SetBackdrop( {
    bgFile = "Interface\\Tooltips\\UI-tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  } )
  frame:SetBackdropColor( 0, 0, 0, 1 )
  frame:SetFrameStrata( "DIALOG" )

  if modules.uses_pfui() then
    ---@diagnostic disable-next-line: undefined-global
    local button = pfLootButton1
    if button then
      frame:SetFrameLevel( button:GetFrameLevel() + 1 )
    end
  end

  frame:SetWidth( 100 )
  frame:SetHeight( 100 )
  frame:SetPoint( "CENTER", modules.api.UIParent, "Center" )
  frame:EnableMouse( true )
  frame:SetScript( "OnLeave",
    function()
      ---@diagnostic disable-next-line: undefined-global
      local self = this
      local mouse_x, mouse_y = modules.api.GetCursorPosition()
      local x, y = self:GetCenter()
      local width = self:GetWidth()
      local height = self:GetHeight()

      local is_over = mouse_x >= x - width / 2 and mouse_x <= x + width / 2 and mouse_y >= y - height / 2 and
          mouse_y <= y + height / 2

      if not is_over then self:Hide() end
    end )

  return frame
end

local function create_button( parent, index )
  local frame = modules.api.CreateFrame( "Button", "RollForLootFrameButton" .. index, parent )
  local width = 5 + horizontal_padding + modules.api.math.floor( (index - 1) / rows ) * (button_width + horizontal_padding)
  local height = -5 - vertical_padding - (mod( index - 1, rows ) * (button_height + vertical_padding))
  frame:SetWidth( button_width )
  frame:SetHeight( button_height )
  frame:SetPoint( "TOPLEFT", parent, "TOPLEFT", width, height )
  frame:SetBackdrop( { bgFile = "Interface\\Buttons\\WHITE8x8" } )
  frame:SetNormalTexture( "" )
  frame.parent = parent

  local text = frame:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
  text:SetPoint( "CENTER", frame, "CENTER" )
  text:SetText( "" )
  frame.text = text

  local icon = frame:CreateTexture( nil, "ARTWORK" )
  icon:SetPoint( "LEFT", text, "RIGHT", 2, 0 )
  icon:SetWidth( 13 )
  icon:SetHeight( 12 )
  icon:SetTexture( string.format( "Interface\\AddOns\\RollFor\\assets\\star-%s.tga", "gold" ) )
  icon:Hide()
  frame.icon = icon

  frame:SetScript( "OnEnter", function()
    ---@diagnostic disable-next-line: undefined-global
    local self = this
    highlight( self )
  end )

  frame:SetScript( "OnLeave", function()
    ---@diagnostic disable-next-line: undefined-global
    local self = this
    dim( self )
  end )

  frame:SetScript( "OnMouseDown", function()
    ---@diagnostic disable-next-line: undefined-global
    local self = this
    ---@diagnostic disable-next-line: undefined-global
    local button = arg1
    if button == "LeftButton" then press( self ) end
  end )

  frame:SetScript( "OnMouseUp", function()
    ---@diagnostic disable-next-line: undefined-global
    local self = this
    ---@diagnostic disable-next-line: undefined-global
    local button = arg1
    if button == "LeftButton" then
      if modules.api.MouseIsOver( self ) then
        highlight( self )
      else
        dim( self )
      end
    end
  end )

  return frame
end

function M.new( winner_tracker, master_loot_correlation_data, roll_controller )
  local m_frame
  local m_buttons = {}

  local function create()
    if m_frame then return end
    m_frame = create_main_frame()
  end

  local function create_candidate_frames( candidates, item_link )
    local total = getn( candidates )

    local columns = modules.api.math.ceil( total / rows )
    local total_rows = total < 5 and total or rows

    m_frame:SetWidth( (button_width + horizontal_padding) * columns + horizontal_padding + 11 )
    m_frame:SetHeight( (button_height + vertical_padding) * total_rows + vertical_padding + 11 )

    local function loop( i )
      if i > total then
        if m_buttons[ i ] then m_buttons[ i ]:Hide() end
        return
      end

      local candidate = candidates[ i ]

      if not m_buttons[ i ] then
        m_buttons[ i ] = create_button( m_frame, i )
      end

      local button = m_buttons[ i ]
      button.text:SetText( candidate.name )
      local color = modules.api.RAID_CLASS_COLORS[ string.upper( candidate.class ) ]
      button.color = color
      button.player = candidate

      if color then
        button.text:SetTextColor( color.r, color.g, color.b )
        dim( button )
      else
        button.text:SetTextColor( 1, 1, 1 )
      end

      button:SetScript( "OnClick", function()
        ---@diagnostic disable-next-line: undefined-global
        local self = button
        roll_controller.award_loot( self.player, item_link )
      end )

      button:Show()
    end

    for i = 1, 40 do
      loop( i )
    end
  end

  local function clear_winners()
    for i = 1, 40 do
      local button = m_buttons[ i ]
      if button then
        button.text:SetPoint( "CENTER", button, "CENTER" )
        button.icon:Hide()
        button.winner = nil
        button.winning_roll = nil
      end
    end
  end

  local function mark_winner( winner_name, item_link )
    if item_link ~= modules.api.LootFrame.selectedItemLink then return end

    for i = 1, 40 do
      local button = m_buttons[ i ]

      if button and button:IsVisible() and button.text:GetText() == winner_name then
        button.text:SetPoint( "CENTER", button, "CENTER", 2 - icon_width / 2, 0 )
        button.icon:Show()
      end
    end
  end

  local function show( item_link )
    if not m_frame then return end

    clear_winners()
    m_frame:Show()

    for _, winner in ipairs( winner_tracker.find_winners( item_link ) ) do
      mark_winner( winner.winner_name, item_link )
    end
  end

  local function hide()
    if m_frame then m_frame:Hide() end
  end

  local function anchor( frame )
    m_frame:SetPoint( "TOPLEFT", frame, "BOTTOMLEFT", 0, 0 )
  end

  local function prepare_rolling_slash_command( slot, slash_command )
    local item_link = modules.api.GetLootSlotLink( slot )
    master_loot_correlation_data.set( item_link, slot )
    modules.api.ChatFrameEditBox:Show()
    modules.api.ChatFrameEditBox:SetText( string.format( "%s %s", slash_command, item_link ) )
  end

  local function hook_loot_buttons( reset_confirmation, normal_loot, show_loot_candidates_frame, hide_fn )
    for i = 1, modules.api.LOOTFRAME_NUMBUTTONS do
      local name = "LootButton" .. i
      local button = _G[ name ]

      if not button.OriginalOnClick then button.OriginalOnClick = button:GetScript( "OnClick" ) end

      button:SetScript( "OnClick", function()
        ---@diagnostic disable-next-line: undefined-global
        local self = button
        local slot = self.slot
        reset_confirmation()

        local alt, ctrl, shift = modules.get_all_key_modifiers()

        if shift and not alt and not ctrl then
          prepare_rolling_slash_command( slot, modules.Types.RollSlashCommand.NormalRoll )
          return
        end

        if alt and not ctrl and not shift then
          prepare_rolling_slash_command( slot, modules.Types.RollSlashCommand.RaidRoll )
          return
        end

        if ctrl and not alt and not shift then
          local item_link = modules.api.GetLootSlotLink( slot )
          modules.api.DressUpItemLink( item_link )
          return
        end

        if modules.api.LootSlotIsItem( slot ) then
          local item_link = modules.api.GetLootSlotLink( slot )
          show_loot_candidates_frame( slot, item_link, button )
          return
        end

        hide_fn()
        normal_loot( self )
      end )
    end
  end

  local function hook_pfui_loot_buttons( reset_confirmation, normal_loot, show_loot_candidates_frame, hide_fn )
    for i = 1, modules.api.LOOTFRAME_NUMBUTTONS do
      local name = "pfLootButton" .. i
      local button = _G[ name ]

      if button then
        if not button.OriginalOnClick then button.OriginalOnClick = button:GetScript( "OnClick" ) end

        button:SetScript( "OnClick", function()
          ---@diagnostic disable-next-line: undefined-global
          local self = button
          local slot = self:GetID()
          reset_confirmation()

          local alt, ctrl, shift = modules.get_all_key_modifiers()

          if shift and not alt and not ctrl then
            prepare_rolling_slash_command( slot, modules.Types.RollSlashCommand.NormalRoll )
            return
          end

          if alt and not ctrl and not shift then
            prepare_rolling_slash_command( slot, modules.Types.RollSlashCommand.RaidRoll )
            return
          end

          if ctrl and not alt and not shift then
            local item_link = modules.api.GetLootSlotLink( slot )
            modules.api.DressUpItemLink( item_link )
            return
          end

          if alt or ctrl or shift then
            button.OriginalOnClick()
            return
          end

          if modules.api.LootSlotIsItem( slot ) then
            local item_link = modules.api.GetLootSlotLink( slot )
            show_loot_candidates_frame( slot, item_link, button )
            return
          end

          hide_fn()
          normal_loot( self )
        end )
      end
    end
  end

  winner_tracker.subscribe_for_rolling_started( clear_winners )
  winner_tracker.subscribe_for_winner_found( mark_winner )

  return {
    hook_loot_buttons = hook_loot_buttons,
    hook_pfui_loot_buttons = hook_pfui_loot_buttons,
    restore_loot_buttons = restore_loot_buttons,
    create = create,
    create_candidate_frames = create_candidate_frames,
    show = show,
    hide = hide,
    anchor = anchor,
  }
end

modules.MasterLootFrame = M
return M
