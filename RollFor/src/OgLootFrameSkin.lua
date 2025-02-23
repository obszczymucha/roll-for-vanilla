RollFor = RollFor or {}
local m = RollFor

if m.OgLootFrameSkin then return end

local M = {}

local gui = m.GuiElements

local texture_size = 512
local right_side_width = 32
local item_height = 41
local header_height = 73
local footer_height = 11
local min_width = 183

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

---@param frame_builder FrameBuilderFactory
function M.new( frame_builder )
  ---@param og_set_width function
  ---@param update function?
  local function set_width( og_set_width, update )
    return function( self, width )
      local w = width < min_width and min_width or min_width
      og_set_width( self, w )
      if update then update( w ) end
    end
  end

  ---@param parent Frame
  local function create_close_button( parent )
    local button = frame_builder.button():parent( parent ):width( 32 ):height( 32 ):build()

    button:SetNormalTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Up" )
    button:SetPushedTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Down" )

    button:Show()

    local highlight_texture = button:CreateTexture( nil, "HIGHLIGHT" )
    highlight_texture:SetTexture( "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight" )
    highlight_texture:SetBlendMode( "ADD" )
    highlight_texture:SetAllPoints( button )

    ---@diagnostic disable-next-line: undefined-field
    button:SetScript( "OnClick", function()
      parent:Hide()
      m.api.CloseLoot()
    end )

    return button
  end

  ---@param parent Frame
  local function texture( parent )
    local result = parent:CreateTexture( nil, "BACKGROUND" )
    result:SetTexture( "Interface\\AddOns\\RollFor\\assets\\og-loot-frame.tga" )
    return result
  end

  ---@param parent Frame
  local function create_portrait( parent )
    local overlay = parent:CreateTexture( nil, "OVERLAY" )
    overlay:SetTexture( "Interface\\TargetingFrame\\TargetDead" )
    overlay:SetWidth( 55 )
    overlay:SetHeight( 56 )
    overlay:SetPoint( "TOPLEFT", parent, "TOPLEFT", 9, -5 )
  end

  ---@param parent Frame
  local function create_title( parent )
    local font_string = parent:CreateFontString( nil, "ARTWORK", "GameFontNormal" )
    font_string:SetText( "Items" )
    font_string:SetJustifyH( "CENTER" )
    font_string:SetWidth( 90 )
    font_string:SetHeight( 30 )
    font_string:SetPoint( "TOP", parent, "TOP", 20, -6 )
  end

  ---@param parent Frame
  local function dropped_item( parent )
    local container = m.create_backdrop_frame( m.api, "Frame", nil, parent )

    local w = 38
    local h = 38
    local spacing = 6
    local mouse_down = false
    local icon_zoom = 0

    local item

    container:SetHeight( item_height )
    container.name = gui.create_text_in_container( "Button", container, 20, "LEFT", nil, "text", "GameFontNormal" )
    container.name.text:SetJustifyH( "LEFT" )
    container.name.text:SetTextColor( 1, 1, 1 )
    container.name.text:SetWidth( 86 )
    container.name:SetHeight( h )
    container.name:SetWidth( 102 )
    local name_texture = container.name:CreateTexture( nil, "BACKGROUND" )
    name_texture:SetTexture( "Interface\\QuestFrame\\UI-QuestItemNameFrame" )
    name_texture:SetWidth( 133 )
    name_texture:SetHeight( 62 )
    name_texture:SetPoint( "LEFT", -15, 0 )
    container.icon = gui.create_icon_in_container( m.vanilla and "LootButton" or "Button", container, w, h, icon_zoom )
    container.icon:SetPoint( "LEFT", container, "LEFT", 20, 0 )
    local pushed_texture = container.icon:CreateTexture( nil, "OVERLAY" )
    pushed_texture:SetAllPoints( container.icon )
    pushed_texture:SetTexture( "Interface\\Buttons\\UI-Quickslot-Depress" )
    pushed_texture:Hide()
    container.icon.pushed_texture = pushed_texture
    local highlight_texture = container.icon:CreateTexture( nil, "OVERLAY" )
    highlight_texture:SetAllPoints( container.icon )
    highlight_texture:SetTexture( "Interface\\Buttons\\ButtonHilight-Square" )
    highlight_texture:SetBlendMode( "ADD" )
    highlight_texture:Hide()
    container.icon.highlight_texture = highlight_texture
    container.comment = m.create_backdrop_frame( m.api, "Frame", nil, container )
    container.comment:SetPoint( "CENTER", container.icon, "CENTER", 0, 0 )
    container.comment:SetWidth( 16 )
    container.comment:SetHeight( 15 )
    container.comment:SetFrameLevel( container.icon:GetFrameLevel() + 1 )
    container.comment.inner = gui.create_text_in_container( "Frame", container, 12, "CENTER", nil, "text", "GameFontNormalSmall" )
    container.comment.inner:ClearAllPoints()
    container.comment.inner:SetAllPoints( container.comment )
    container.comment.inner.text:ClearAllPoints()

    -- Small differences in rendering between OG and modern clients.
    if m.vanilla then
      container.comment.inner.text:SetPoint( "CENTER", container.comment.inner, "CENTER", 0, 1 )
    else
      container.comment.inner.text:SetPoint( "CENTER", container.comment.inner, "CENTER", 1, 0 )
    end

    container.comment.inner:SetScale( 0.7 )
    container.comment.inner:SetFrameLevel( container.comment:GetFrameLevel() + 1 )
    container.comment:SetBackdrop( {
      bgFile = "Interface/Buttons/WHITE8x8",
      edgeFile = "Interface/Buttons/WHITE8x8",
      tile = false,
      tileSize = 0,
      edgeSize = 0.8
    } )
    container.comment:SetBackdropColor( 0, 0, 0, 0.7 )
    container.comment:SetBackdropBorderColor( 1, 0.561, 0.184, 1 )

    container.quantity = gui.create_text_in_container( "Frame", container.icon, 20, "CENTER", nil, "text", "NumberFontNormal" )
    container.quantity:SetPoint( "BOTTOMRIGHT", -4, 1 )
    container.quantity:SetHeight( 16 )

    local middleleft = texture( container )
    local middleright = texture( container )

    local function resize()
      container.icon:Show()

      local icon_width = container.icon:GetWidth() + spacing
      local text_width = container.name.text:GetStringWidth() + spacing + 1
      local total_width = icon_width + text_width

      container:SetWidth( total_width )
      container:SetPoint( "LEFT", 0, 0 )
      container:SetPoint( "RIGHT", 0, 0 )
    end

    local function not_hovered_color()
      container:SetBackdropColor( 0, 0, 0, 0 )
    end

    local function update()
      if not item then return end

      if not item.is_enabled then
        container.icon:SetAlpha( 0.35 )
        container.name:SetAlpha( 0.35 )
        return
      end

      container.icon:SetAlpha( 1 )
      container.name:SetAlpha( 1 )
    end

    ---@param v LootFrameItem
    container.SetItem = function( _, v )
      item = v
      container.icon.texture:SetTexture( v.texture )
      container.name.text:SetText( m.colorize_item_by_quality( v.name, v.quality ) )
      container.name:SetPoint( "LEFT", container.icon, "RIGHT", spacing + 1, 0 )

      if v.quantity and v.quantity > 1 then
        container.quantity:Show()
        container.quantity.text:SetText( v.quantity )
        container.quantity:SetWidth( container.quantity.text:GetStringWidth() )
      else
        container.quantity:Hide()
      end

      if v.comment then
        container.comment.inner.text:SetText( v.comment )
        container.comment:Show()
      else
        container.comment:Hide()
      end

      local function modifier_fn()
        if m.is_ctrl_key_down() then
          m.api.DressUpItemLink( v.link )
          return
        end

        if m.is_shift_key_down() then
          m.link_item_in_chat( v.link )
          return
        end
      end

      container.icon:SetScript( "OnClick", v.is_enabled and not v.is_selected and v.click_fn or modifier_fn )

      if m.vanilla then
        -- Fucking hell this took forever to figure out. Fuck you Blizzard.
        -- For looting to work in vanilla, the frame must be of a "LootButton" type and
        -- then it comes with the SetSlot function that we need to use to set the slot.
        -- This will probably be a pain in the ass when porting.
        container.icon:SetSlot( v.slot or 0 )
      end

      update()
      resize()
    end

    local function on_enter( self )
      if m.vanilla then self = this end

      if not item or item.is_enabled then container.icon.highlight_texture:Show() end
      if not item then return end

      if item.tooltip_link then
        m.api.GameTooltip:SetOwner( self, "ANCHOR_RIGHT" )
        m.api.GameTooltip:SetHyperlink( item.tooltip_link )
        m.api.GameTooltip:Show()
      end

      if not item.is_enabled then return end
    end

    container:SetBackdrop( {
      bgFile = "Interface/Buttons/WHITE8x8",
      tile = false,
      tileSize = 0,
    } )

    not_hovered_color()

    local function on_leave()
      container.icon.highlight_texture:Hide()
      m.api.GameTooltip:Hide()
      mouse_down = false
    end

    container.name:SetScript( "OnEnter", function( self )
      if not item then return end
      if item.comment_tooltip then
        if m.vanilla then self = this end

        self.tooltip_scale = m.api.GameTooltip:GetScale()
        m.api.GameTooltip:SetOwner( self, "ANCHOR_RIGHT" )

        local result = ""

        for _, line in ipairs( item.comment_tooltip ) do
          if result ~= "" then result = result .. "\n" end
          result = result .. line
        end

        m.api.GameTooltip:AddLine( result, 1, 1, 1 )
        m.api.GameTooltip:SetScale( 0.9 )
        m.api.GameTooltip:Show()
      end
    end )

    container.name:SetScript( "OnLeave", function( self )
      if m.vanilla then self = this end

      m.api.GameTooltip:Hide()
      m.api.GameTooltip:SetScale( self.tooltip_scale or 1 )
      mouse_down = false

      not_hovered_color()
    end )

    container.icon:SetScript( "OnEnter", on_enter )
    container.icon:SetScript( "OnLeave", on_leave )

    local function on_mouse_down()
      if not item or item.is_enabled then container.icon.pushed_texture:Show() end
      if not item then return end
      if not item.is_enabled or item.is_selected then return end

      mouse_down = true
    end

    local function on_mouse_up()
      container.icon.pushed_texture:Hide()

      if not item then return end
      if not item.is_enabled or item.is_selected then return end

      if not mouse_down then return end
    end

    container.icon:SetScript( "OnMouseUp", on_mouse_up )
    container.icon:SetScript( "OnMouseDown", on_mouse_down )

    container:SetScript( "OnShow", function()
      mouse_down = false
    end )

    local function update_textures( width )
      local left_side_width = width - right_side_width
      local height_offset = 0.498 + ((td.middleleft.height + 1) / 512)

      middleleft:SetTexCoord( 0, (left_side_width + 2) / td.total.width, 0.511, height_offset )
      middleleft:SetWidth( left_side_width + 2 )
      middleleft:SetHeight( td.middleleft.height )
      middleleft:SetPoint( "TOPLEFT", container, "TOPLEFT", 0, 0 )

      middleright:SetTexCoord( (td.total.width - td.middleright.width) / td.total.width, 1, 0.511, height_offset )
      middleright:SetWidth( td.middleright.width )
      middleright:SetHeight( td.middleright.height )
      middleright:SetPoint( "TOPRIGHT", container, "TOPRIGHT", 0, 0 )
    end

    local og_set_width = container.SetWidth
    container.SetWidth = set_width( og_set_width, update_textures )
    return container
  end

  ---@param on_drag_stop function
  ---@param on_show function
  ---@param on_hide function
  local function header( on_drag_stop, on_show, on_hide )
    local frame = frame_builder.new() ---@type Frame
        :name( "RollForLootFrameHeader" )
        :width( min_width )
        :height( header_height )
        :sound()
        :gui_elements( {} )
        :movable()
        :on_show( on_show )
        :on_hide( on_hide )
        :on_drag_stop( on_drag_stop )
        :hidden()
        :build()

    local topleft = texture( frame )
    local topright = texture( frame )
    create_portrait( frame )
    create_title( frame )
    local close_button = create_close_button( frame )
    close_button:ClearAllPoints()
    close_button:SetPoint( "TOPRIGHT", frame, "TOPRIGHT", 5, -6 )

    local function update( width )
      local topoffset = td.topleft.height / td.total.height

      local left_side_width = width - right_side_width
      topleft:SetTexCoord( 0, left_side_width / td.total.width, 0, topoffset )
      topleft:SetWidth( left_side_width )
      topleft:SetHeight( td.topleft.height )
      topleft:SetPoint( "TOPLEFT", frame, "TOPLEFT", 0, 0 )

      topright:SetTexCoord( (td.total.width - td.topright.width) / td.total.width, 1, 0, topoffset )
      topright:SetWidth( td.topright.width )
      topright:SetHeight( td.topright.height )
      topright:SetPoint( "TOPLEFT", frame, "TOPLEFT", left_side_width, 0 )
    end

    local og_set_width = frame.SetWidth
    frame.SetWidth = set_width( og_set_width, update )

    return frame
  end

  ---@param parent Frame
  local function body( parent )
    local frame = frame_builder.new()
        :name( "RollForLootFrame" )
        :parent( parent )
        :width( 280 )
        :height( 100 )
        :gui_elements( { dropped_item = dropped_item } )
        :build()

    frame:ClearAllPoints()
    frame:SetPoint( "TOP", parent, "BOTTOM", 0, 1 )

    local og_set_width = frame.SetWidth
    frame.SetWidth = set_width( og_set_width )
    return frame
  end

  ---@param parent Frame
  local function footer( parent )
    local frame = frame_builder.new() ---@type Frame
        :name( "RollForLootFrameFooter" )
        :parent( parent )
        :width( min_width )
        :height( footer_height )
        :gui_elements( {} )
        :movable()
        :build()

    local bottomleft = texture( frame )
    local bottomright = texture( frame )

    local function update( width )
      local left_side_width = width - right_side_width
      bottomleft:SetTexCoord( 0, left_side_width / td.total.width, 1.001 - (td.bottomleft.height / td.total.height), 0.999 )
      bottomleft:SetWidth( left_side_width )
      bottomleft:SetHeight( td.bottomleft.height )
      bottomleft:SetPoint( "TOPLEFT", frame, "TOPLEFT", 0, 0 )

      bottomright:SetTexCoord( 1 - (td.bottomright.width / td.total.width), 1, 1.001 - (td.bottomright.height / td.total.height), 0.999 )
      bottomright:SetWidth( td.bottomright.width )
      bottomright:SetHeight( td.bottomright.height )
      bottomright:SetPoint( "TOPRIGHT", frame, "TOPRIGHT", 0, 0 )
    end

    local og_set_width = frame.SetWidth
    frame.SetWidth = set_width( og_set_width, update )

    return frame
  end

  local function get_item_height()
    return item_height
  end

  local function get_footer_height()
    return footer_height
  end

  ---@type LootFrameSkin
  return {
    header = header,
    body = body,
    dropped_item = dropped_item,
    footer = footer,
    get_item_height = get_item_height,
    get_footer_height = get_footer_height
  }
end

m.OgLootFrameSkin = M
return M
