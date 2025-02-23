RollFor = RollFor or {}
local m = RollFor

if m.Sandbox then return end

local M = {}

---@class Sandbox
---@field run fun()

function M.new()
  local fb = m.FrameBuilder ---@type FrameBuilderFactory

  local function run()
    local point = {
      point = "CENTER",
      -- anchor = m.api.LootFrame,
      relative_point = "CENTER",
      x = 0,
      y = 0
    }

    local texture_size = 512
    local right_side_width = 32
    local item_height = 41
    local texture_dimensions = {
      total = { width = texture_size, height = texture_size },
      topleft = { width = texture_size - right_side_width, height = 73 },
      topright = { width = right_side_width, height = 73 },
      middleleft = { width = texture_size - right_side_width, height = item_height },
      middleright = { width = right_side_width, height = item_height },
      bottomleft = { width = texture_size - right_side_width, height = 11 },
      bottomright = { width = right_side_width, height = 11 }
    }

    local td = texture_dimensions

    local frame = fb.new() ---@type Frame
        :name( "TestFrame" )
        :point( point )
        :width( 150 )
        :height( 1 )
        :frame_style( "Classic" )
        :backdrop_color( 0, 0.501, 1, 0.3 )
        -- :border_color( 0, 0, 0, 0.9 )
        :movable()
        :gui_elements( m.GuiElements )
        :bg_file( "" )
        :edge_file( "" )
        :build()

    local function create_close_button()
      local button = fb.button():parent( frame ):width( 32 ):height( 32 ):build()

      button:SetNormalTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Up" )
      button:SetPushedTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Down" )

      button:Show()

      local highlight_texture = button:CreateTexture( nil, "HIGHLIGHT" )
      highlight_texture:SetTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight" )
      highlight_texture:SetBlendMode( "ADD" )
      highlight_texture:SetAllPoints( button )

      ---@diagnostic disable-next-line: undefined-field
      button:SetScript( "OnClick", function()
        frame:Hide()
      end )

      return button
    end

    local function texture()
      local result = frame:CreateTexture( nil, "BACKGROUND" )
      result:SetTexture( "Interface\\AddOns\\RollFor\\assets\\og-loot-frame.tga" )
      return result
    end

    local function create_portrait()
      local overlay = frame:CreateTexture( nil, "OVERLAY" )
      overlay:SetTexture( "Interface\\TargetingFrame\\TargetDead" )
      overlay:SetWidth( 55 )
      overlay:SetHeight( 56 )
      overlay:SetPoint( "TOPLEFT", frame, "TOPLEFT", 9, -5 )
    end

    local function create_title()
      local font_string = frame:CreateFontString( nil, "ARTWORK", "GameFontNormal" )
      font_string:SetText( "Items" )
      font_string:SetJustifyH( "CENTER" )
      font_string:SetWidth( 90 )
      font_string:SetHeight( 30 )
      font_string:SetPoint( "TOP", frame, "TOP", 20, -6 )
    end

    local textures = {
      topleft = texture(),
      topright = texture(),
      middleleft = {},
      middleright = {},
      bottomleft = texture(),
      bottomright = texture(),
      portrait = create_portrait()
    }

    local close_button = create_close_button()
    create_title()

    for _ = 1, 15 do
      table.insert( textures.middleleft, texture() )
      table.insert( textures.middleright, texture() )
    end

    local item_count = 4
    local width = 300

    local function update( w, count )
      if w then width = w end
      if count then item_count = count end

      local height = td.topleft.height + (td.middleleft.height * item_count) + td.bottomleft.height
      frame:SetWidth( width )
      frame:SetHeight( height )
      local left_side_width = width - right_side_width
      local topleft = textures.topleft
      local topoffset = td.topleft.height / td.total.height
      topleft:SetTexCoord( 0, left_side_width / td.total.width, 0, topoffset )
      topleft:SetWidth( left_side_width )
      topleft:SetHeight( td.topleft.height )
      topleft:SetPoint( "TOPLEFT", frame, "TOPLEFT", 0, 0 )

      local topright = textures.topright
      topright:SetTexCoord( (td.total.width - td.topright.width) / td.total.width, 1, 0, topoffset )
      topright:SetWidth( td.topright.width )
      topright:SetHeight( td.topright.height )
      topright:SetPoint( "TOPLEFT", frame, "TOPLEFT", left_side_width, 0 )

      local left_anchor = topleft
      local right_anchor = topright

      for i = 1, item_count do
        local middleleft = textures.middleleft[ i ]
        local height_offset = 0.498 + ((td.middleleft.height + 1) / 512)
        middleleft:SetTexCoord( 0, left_side_width / td.total.width, 0.511, height_offset )
        middleleft:SetWidth( left_side_width )
        middleleft:SetHeight( td.middleleft.height )
        middleleft:SetPoint( "TOPLEFT", left_anchor, "BOTTOMLEFT", 0, 0 ) -- Just use 0 here
        middleleft:Show()

        local middleright = textures.middleright[ i ]
        middleright:SetTexCoord( (td.total.width - td.middleright.width) / td.total.width, 1, 0.511, height_offset )
        middleright:SetWidth( td.middleright.width )
        middleright:SetHeight( td.middleright.height )
        middleright:SetPoint( "TOPRIGHT", right_anchor, "BOTTOMRIGHT", 0, 0 ) -- And 0 here
        middleright:Show()

        left_anchor, right_anchor = middleleft, middleright
      end

      for i = item_count + 1, 15 do
        textures.middleleft[ i ]:Hide()
        textures.middleright[ i ]:Hide()
      end

      local bottomleft = textures.bottomleft
      bottomleft:SetTexCoord( 0, left_side_width / td.total.width, 1.001 - (td.bottomleft.height / td.total.height), 0.999 )
      bottomleft:SetWidth( left_side_width )
      bottomleft:SetHeight( td.bottomleft.height )
      bottomleft:SetPoint( "TOPLEFT", left_anchor, "BOTTOMLEFT", 0, 1.8 )

      local bottomright = textures.bottomright
      bottomright:SetTexCoord( 1 - (td.bottomright.width / td.total.width), 1, 1.001 - (td.bottomright.height / td.total.height), 0.999 )
      bottomright:SetWidth( td.bottomright.width )
      bottomright:SetHeight( td.bottomright.height )
      bottomright:SetPoint( "TOPRIGHT", right_anchor, "BOTTOMRIGHT", 0, 1.8 )

      close_button:SetPoint( "TOPRIGHT", frame, "TOPRIGHT", 5, -6 )
    end

    ---@diagnostic disable-next-line: inject-field
    frame.width = function( w )
      width = w <= 512 and w or 512
      update()
    end

    ---@diagnostic disable-next-line: inject-field
    frame.item_count = function( i )
      item_count = i <= 15 and i or 15
      update()
    end

    update( 183, 4 )
    frame:Show()
  end

  ---@type Sandbox
  return {
    run = run
  }
end

m.Sandbox = M
return M
