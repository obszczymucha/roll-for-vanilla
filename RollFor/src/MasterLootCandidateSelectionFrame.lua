RollFor = RollFor or {}
local m = RollFor

if m.MasterLootCandidateSelectionFrame then return end

local M = {}

local icon_width = 16
local button_width = 85 + icon_width
local button_height = 16
local vertical_margin = 5
local horizontal_margin = 5
local horizontal_padding = 3
local vertical_padding = 5

local mod, getn = m.mod, m.getn

local function highlight( frame )
  frame:SetBackdropColor( frame.color.r, frame.color.g, frame.color.b, 0.3 )
end

local function dim( frame )
  frame:SetBackdropColor( 0.5, 0.5, 0.5, 0.1 )
end

local function press( frame )
  frame:SetBackdropColor( frame.color.r, frame.color.g, frame.color.b, 0.7 )
end

---@param frame_builder FrameBuilderFactory
---@param config Config
local function create_main_frame( frame_builder, config )
  local builder = config.classic_look() and
      frame_builder.classic() or
      frame_builder.modern()
      :backdrop_color( 0, 0, 0, 0.8 )
      :border_color( 0.851, 0.553, 0.341, 0.3 )

  builder = builder
      :name( "RollForPlayerSelectionFrame" )
      :width( 100 )
      :height( 100 )
      :point( { point = "CENTER", relative_frame = m.api.UIParent, relative_point = "CENTER" } )
      :enable_mouse()
      :strata( "DIALOG" )
      :hidden()

  if config.classic_look() then
    vertical_margin = 9
    horizontal_margin = 10
  end

  local frame = builder:build()

  frame:SetScript( "OnLeave",
    function( self )
      if m.vanilla then self = this end

      local mouse_x, mouse_y = m.api.GetCursorPosition()
      local x, y = self:GetCenter()
      local width = self:GetWidth()
      local height = self:GetHeight()
      local half_width = width / 2
      local half_height = height / 2
      local left = x - half_width
      local right = x + half_width
      local top = y + half_height
      local bottom = y - half_height
      local is_over = mouse_x >= left and mouse_x <= right and mouse_y >= bottom and mouse_y <= top

      if not is_over then self:Hide() end
    end )

  return frame
end

local function position_button( button, parent, index, rows )
  local width = horizontal_margin + horizontal_padding + m.api.math.floor( (index - 1) / rows ) * (button_width + horizontal_padding)
  local height = (-vertical_margin) - vertical_padding - (mod( index - 1, rows ) * (button_height + vertical_padding))
  button:ClearAllPoints()
  button:SetPoint( "TOPLEFT", parent, "TOPLEFT", width, height )
end

local function create_button( parent, index, rows )
  local frame = m.create_backdrop_frame( m.api, "Button", nil, parent )

  frame:SetWidth( button_width )
  frame:SetHeight( button_height )
  position_button( frame, parent, index, rows )
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

  frame:SetScript( "OnEnter", function( self )
    if m.vanilla then self = this end

    highlight( self )
  end )

  frame:SetScript( "OnLeave", function( self )
    if m.vanilla then self = this end

    dim( self )
  end )

  frame:SetScript( "OnMouseDown", function( self, button )
    if m.vanilla then
      self = this
      button = arg1
    end

    if button == "LeftButton" then press( self ) end
  end )

  frame:SetScript( "OnMouseUp", function( self, button )
    if m.vanilla then
      self = this
      button = arg1
    end

    if button == "LeftButton" then
      if m.api.MouseIsOver( self ) then
        highlight( self )
      else
        dim( self )
      end
    end
  end )

  frame.unmark_winner = function()
    frame.text:SetPoint( "CENTER", frame, "CENTER" )
    frame.icon:Hide()
  end

  frame.mark_winner = function()
    frame.text:SetPoint( "CENTER", frame, "CENTER", 2 - icon_width / 2, 0 )
    frame.icon:Show()
  end

  return frame
end

---@class MasterLootCandidateSelectionFrame
---@field show fun( candidates: MasterLootCandidate[] )
---@field hide fun()
---@field get_frame fun(): Frame

---@param frame_builder FrameBuilderFactory
---@param config Config
function M.new( frame_builder, config )
  local m_frame
  local m_buttons = {}

  local function resize_frame( total, rows )
    local columns = m.api.math.ceil( total / rows )
    local total_rows = total < 5 and total or rows

    m_frame:SetWidth( (button_width + horizontal_padding) * columns + horizontal_padding + horizontal_margin * 2 )
    m_frame:SetHeight( (button_height + vertical_padding) * total_rows + vertical_padding + vertical_margin * 2 )
  end

  ---@param candidates MasterLootCandidate[]
  local function create_candidate_frames( candidates )
    local total = getn( candidates )
    local rows = config.master_loot_frame_rows()

    resize_frame( total, rows )

    local function loop( i )
      if i > total then
        if m_buttons[ i ] then m_buttons[ i ]:Hide() end
        return
      end

      local candidate = candidates[ i ]

      if not m_buttons[ i ] then
        m_buttons[ i ] = create_button( m_frame, i, rows )
      end

      local button = m_buttons[ i ]
      button.text:SetText( candidate.name )
      local color = m.api.RAID_CLASS_COLORS[ string.upper( candidate.class ) ]
      button.color = color
      button.player = candidate

      if color then
        button.text:SetTextColor( color.r, color.g, color.b )
        dim( button )
      else
        button.text:SetTextColor( 1, 1, 1 )
      end

      button:SetScript( "OnClick", candidate.confirm_fn )

      if candidate.is_winner then
        button.mark_winner()
      else
        button.unmark_winner()
      end

      button:Show()
    end

    for i = 1, 40 do
      loop( i )
    end
  end

  ---@param candidates MasterLootCandidate[]
  local function show( candidates )
    if not m_frame then m_frame = create_main_frame( frame_builder, config ) end

    create_candidate_frames( candidates )
    m_frame:Show()
  end

  local function hide()
    if m_frame then m_frame:Hide() end
  end

  config.subscribe( "master_loot_frame_rows", function()
    if not m_frame then return end

    local total = 0
    local rows = config.master_loot_frame_rows()

    for i = 1, 40 do
      if m_buttons[ i ] then
        total = total + 1
        position_button( m_buttons[ i ], m_frame, i, rows )
      end
    end

    resize_frame( total, rows )
  end )

  ---@type MasterLootCandidateSelectionFrame
  return {
    show = show,
    hide = hide,
    get_frame = function() return m_frame end
  }
end

m.MasterLootCandidateSelectionFrame = M
return M
