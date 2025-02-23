RollFor = RollFor or {}
local m = RollFor

if m.ModernLootFrameSkin then return end

local M = {}

local gui = m.GuiElements

local item_height = 22
local footer_height = 0

---@param frame_builder FrameBuilderFactory
function M.new( frame_builder )
  ---@param parent Frame
  local function dropped_item( parent )
    local container = m.create_loot_button( m.api, parent )

    local w = 22
    local h = 22
    local spacing = 6
    local bind_spacing = 3
    local mouse_down = false
    local icon_zoom = 2

    local item

    container:SetHeight( h )
    container.name = gui.create_text_in_container( "Frame", container, 20, "LEFT", nil, "text" )
    container.name.text:SetJustifyH( "LEFT" )
    container.name.text:SetTextColor( 1, 1, 1 )
    container.index = gui.create_text_in_container( "Frame", container, 20, "CENTER", nil, "text" )
    container.index:SetPoint( "LEFT", 1, 0 )
    container.index:SetWidth( 16 )
    container.index:SetHeight( h )
    container.icon = gui.create_icon_in_container( "Button", container, w, h, icon_zoom )
    container.icon:SetPoint( "LEFT", container.index, "RIGHT", 2, 0 )
    container.quantity = gui.create_text_in_container( "Frame", container.icon, 20, "CENTER", nil, "text", "NumberFontNormalSmall" )
    container.quantity:SetPoint( "BOTTOMRIGHT", 1, -2 )
    container.quantity:SetHeight( 16 )
    container.bind = gui.create_text_in_container( "Frame", container, 15, "LEFT", nil, "text" )
    container.bind:SetPoint( "LEFT", container.icon, "RIGHT", 5, 0 )
    container.comment = gui.create_text_in_container( "Button", container, 20, "CENTER", nil, "text" )
    container.comment:SetPoint( "RIGHT", -4, 0 )
    container.comment:SetHeight( 16 )

    local function resize()
      container.icon:Show()

      local index_width = container.index:GetWidth() + 1
      local icon_width = container.icon:GetWidth() + spacing
      local bind_width = item.bind and (container.bind:GetWidth() + bind_spacing) or 0
      local text_width = container.name.text:GetStringWidth() + spacing + 1
      local comment_width = container.comment:IsVisible() and container.comment:GetWidth() + spacing or 0

      local total_width = index_width + icon_width + bind_width + text_width + comment_width

      container:SetWidth( total_width )
      container:SetPoint( "LEFT", 0, 0 )
      container:SetPoint( "RIGHT", 0, 0 )
    end

    local function get_color( multiplier )
      local mult = multiplier or 1
      local color = m.api.ITEM_QUALITY_COLORS[ item.quality or 0 ]
      return color.r * mult, color.g * mult, color.b * mult
    end

    local function hovered_color()
      if not item then return end
      if item.is_selected then return end
      local r, g, b = get_color()
      container:SetBackdropColor( r, g, b, 0.3 )
    end

    local function clicked_color()
      local r, g, b = get_color()
      container:SetBackdropColor( r, g, b, 0.4 )
    end

    local function selected_color()
      if not item then return end
      local r, g, b = get_color()
      container:SetBackdropColor( r, g, b, 0.3 )
    end

    local function not_hovered_color()
      if not item or item.is_selected then return end
      container:SetBackdropColor( 0, 0, 0, 0.1 )
    end

    local function update()
      if not item then return end

      if not item.is_enabled then
        container:SetAlpha( 0.6 )
        return
      end

      if item.is_selected then
        selected_color()
      else
        not_hovered_color()
      end

      container:SetAlpha( 1 )
    end

    ---@param v LootFrameItem
    container.SetItem = function( _, v )
      item = v
      container.index.text:SetText( v.index )
      container.icon.texture:SetTexture( v.texture )
      container.name.text:SetText( m.colorize_item_by_quality( v.name, v.quality ) )

      if v.bind then
        container.bind.text:SetText( v.bind )
        container.bind:SetWidth( container.bind.text:GetStringWidth() )
        container.bind:Show()
        container.name:SetPoint( "LEFT", container.bind, "RIGHT", bind_spacing, 0 )
      else
        container.bind:Hide()
        container.name:SetPoint( "LEFT", container.icon, "RIGHT", spacing, 0 )
      end

      if v.comment then
        container.comment.text:SetText( v.comment )
        container.comment:Show()
        container.name:SetPoint( "RIGHT", container.comment, "LEFT", 0, 0 )
      else
        container.comment:Hide()
        container.name:SetPoint( "RIGHT", container, "RIGHT", 0, 0 )
      end

      if v.quantity and v.quantity > 1 then
        container.quantity:Show()
        container.quantity.text:SetText( v.quantity )
        container.quantity:SetWidth( container.quantity.text:GetStringWidth() )
      else
        container.quantity:Hide()
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

      container:SetScript( "OnClick", v.is_enabled and not v.is_selected and v.click_fn or modifier_fn )
      container.icon:SetScript( "OnClick", v.is_enabled and not v.is_selected and v.click_fn or modifier_fn )
      container.comment:SetScript( "OnClick", v.is_enabled and not v.is_selected and v.click_fn or modifier_fn )

      if m.vanilla then
        -- Fucking hell this took forever to figure out. Fuck you Blizzard.
        -- For looting to work in vanilla, the frame must be of a "LootButton" type and
        -- then it comes with the SetSlot function that we need to use to set the slot.
        -- This will probably be a pain in the ass when porting.
        container:SetSlot( v.slot or 0 )
      end

      update()
      resize()
    end

    local function on_enter( self )
      if m.vanilla then self = this end

      if not item then return end
      if item.tooltip_link then
        m.api.GameTooltip:SetOwner( self, "ANCHOR_RIGHT" )
        m.api.GameTooltip:SetHyperlink( item.tooltip_link )
        m.api.GameTooltip:Show()
      end

      if not item.is_enabled then return end
      hovered_color()
    end

    container:SetBackdrop( {
      bgFile = "Interface/Buttons/WHITE8x8",
      tile = false,
      tileSize = 0,
    } )

    not_hovered_color()

    local function on_leave()
      m.api.GameTooltip:Hide()
      mouse_down = false
      not_hovered_color()
    end

    container.comment:SetScript( "OnEnter", function( self )
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

      if not item.is_enabled then return end
      hovered_color()
    end )

    container.comment:SetScript( "OnLeave", function( self )
      if m.vanilla then self = this end

      m.api.GameTooltip:Hide()
      m.api.GameTooltip:SetScale( self.tooltip_scale or 1 )
      mouse_down = false

      not_hovered_color()
    end )

    container.icon:SetScript( "OnEnter", on_enter )
    container.icon:SetScript( "OnLeave", on_leave )

    container:SetScript( "OnEnter", on_enter )
    container:SetScript( "OnLeave", on_leave )

    local function on_mouse_down()
      if not item then return end
      if not item.is_enabled or item.is_selected then return end

      mouse_down = true
      clicked_color()
    end

    local function on_mouse_up()
      if not item then return end
      if not item.is_enabled or item.is_selected then return end

      if not mouse_down then return end
      hovered_color()
    end

    container:SetScript( "OnMouseUp", on_mouse_up )
    container:SetScript( "OnMouseDown", on_mouse_down )
    container.icon:SetScript( "OnMouseUp", on_mouse_up )
    container.icon:SetScript( "OnMouseDown", on_mouse_down )

    container:SetScript( "OnShow", function()
      mouse_down = false
    end )

    return container
  end

  ---@param on_drag_stop function
  ---@param on_show function
  ---@param on_hide function
  local function header( on_drag_stop, on_show, on_hide )
    return frame_builder.new()
        :name( "RollForLootFrameHeader" )
        :width( 380 )
        :height( 24 )
        :sound()
        :gui_elements( gui )
        :frame_style( "Modern" )
        :backdrop_color( 0, 0.501, 1, 0.3 )
        :border_color( 0, 0, 0, 0.9 )
        :movable()
        :gui_elements( m.GuiElements )
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :on_show( on_show )
        :on_hide( on_hide )
        :on_drag_stop( on_drag_stop )
        :hidden()
        :build()
  end

  ---@param parent Frame
  local function body( parent )
    local frame = frame_builder.new()
        :name( "RollForLootFrame" )
        :parent( parent )
        :width( 280 )
        :height( 100 )
        :gui_elements( { dropped_item = dropped_item } )
        :frame_style( "Modern" )
        :backdrop_color( 0, 0, 0, 0.5 )
        :border_color( 0, 0, 0, 0.9 )
        :movable()
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :build()

    frame:ClearAllPoints()
    frame:SetPoint( "TOP", parent, "BOTTOM", 0, 0 )

    return frame
  end

  local function footer()
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

m.ModernLootFrameSkin = M
return M
