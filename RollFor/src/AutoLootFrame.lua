RollFor = RollFor or {}
local m = RollFor

if m.AutoLootFrame then return end

local M = {}
local getn = m.getn
local ItemQuality = m.Types.ItemQuality
local IU = m.ItemUtils

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

-- Experiment: a 3-level tree (Dungeon -> Boss -> Item drops) GUI built on top of AutoLootTree's
-- pure data (tree contents, checked/desaturated/visibility already decided there). This file is
-- dumb rendering only -- it wires click/check callbacks that mutate a row's node and calls
-- refresh(), and translates rows into widget calls; it makes no decisions about the tree itself.

---@class AutoLootFrame
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field get_frame fun(): Popup?

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 0 }

---@param popup_builder PopupBuilder
---@param content_transformer AutoLootFrameContentTransformer
---@param db table
function M.new( popup_builder, content_transformer, db )
  ---@type Popup?
  local popup
  local top_padding = 16
  local side_padding = 20

  -- Tall enough to be worth opening, short enough to fit a 768px-tall screen at UI scale 1 --
  -- everything past it is reachable with the wheel (see the popup's `scrollable` below).
  local max_visible_rows = 20

  -- Forward declared: create_popup wires the scroll wheel to it.
  local refresh

  local function on_drag_stop()
    if not popup then return end

    if m.is_frame_out_of_bounds( popup ) then
      db.point = M.center_point
      popup:position( M.center_point )

      return
    end

    local anchor = popup:get_anchor_point()
    db.point = { point = anchor.point, relative_point = anchor.relative_point, x = anchor.x, y = anchor.y }
  end

  local function get_point()
    if popup and m.is_frame_out_of_bounds( popup ) then
      return M.center_point
    elseif db.point then
      return db.point
    else
      return M.center_point
    end
  end

  local function create_popup()
    local result = popup_builder
        :name( "RollForAutoLootFrame" )
        :point( get_point() )
        :gui_elements( m.GuiElements )
        :movable()
        :on_drag_stop( on_drag_stop )
        :strata( "DIALOG" )
        :self_centered_anchor()
        :anchor_point( "TOPLEFT" )
        :hidden()
        -- Only tree rows scroll; the title and the Close button stay where they are. Scrolling is
        -- just another reason to redraw, so it goes through the same refresh() everything else does.
        :scrollable( { line_types = "tree_node", max_lines = max_visible_rows, top_padding = top_padding } )
        :on_scroll( function() refresh() end )
        :build()

    result:border_color( 0.351, 0.553, 1.0, 0.3 )

    return result
  end

  -- Just relabels/wires callbacks onto AutoLootTree's already-decided rows -- no tree walking,
  -- no checked/desaturated computation here.
  ---@return AutoLootFrameTreeNode[]
  local function tree_rows()
    local rows = {}

    for _, row in ipairs( m.AutoLootTree.visible_rows( m.AutoLootTree.dungeons ) ) do
      local node = row.node

      -- Raw data (with its `type`) passed straight through -- the content transformer is where
      -- type -> presentation (label color, item vs label rendering) gets decided, not here.
      table.insert( rows, {
        depth = row.depth,
        data = row.data,
        expandable = row.expandable,
        expanded = row.expanded,
        checked = row.checked,
        desaturated = row.desaturated,
        on_click = row.expandable and function()
          node.data.expanded = not node.data.expanded
          refresh()
        end or nil,
        on_check = function( checked )
          m.AutoLootTree.set_checked( node, checked )
          refresh()
        end
      } )
    end

    return rows
  end

  ---@return AutoLootFrameData
  local function content()
    return {
      title = m.colorize_item_by_quality( "RollFor Auto Loot", ItemQuality.Legendary ),
      rows = tree_rows(),
      buttons = {
        { type = "Close", callback = function() if popup then popup:Hide() end end }
      }
    }
  end

  ---@param transformed table
  ---@return number -- how many of them are scrollable tree rows
  local function count_tree_nodes( transformed )
    local result = 0

    for _, v in ipairs( transformed ) do
      if v.type == "tree_node" then result = result + 1 end
    end

    return result
  end

  refresh = function()
    if not popup then popup = create_popup() end
    popup:clear()

    local transformed = content_transformer.transform( content() )

    -- The whole row list, not just the part that fits: the popup needs the real length to place
    -- the window and size the scrollbar, and to pull the window back up when a collapsed node
    -- leaves fewer rows than the offset it was scrolled to.
    popup:set_scroll_total( count_tree_nodes( transformed ) )

    for _, v in ipairs( transformed ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:ClearAllPoints() -- This fixes a strange visual bug in BCC. Frame is either without label or misaligned without this.
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )
        elseif type == "tree_node" then
          frame:SetDepth( v.depth or 0 )
          frame:SetExpandable( v.expandable, v.expanded )
          frame:SetChecked( v.checked )
          frame:SetDesaturated( v.desaturated )
          frame.on_click = v.on_click or function() end
          frame.on_check = v.on_check or function() end

          if v.item then
            local link = m.AutoLootDb.make_link( v.item_id, v.item.quality, v.item.name )
            frame:SetItem( { link = link, texture = v.item.icon, hover_background_color = v.hover_background_color, tooltip_position = v.tooltip_position }, IU.get_tooltip_link( link ) )
          else
            frame:SetText( v.label or "" )
            frame:SetLabelStyle( v.color, v.hover_text_color, v.hover_background_color )
          end
        elseif type == "text" then
          frame:SetText( v.value )
        end

        -- Title stays centered (the popup's usual look); tree rows chain vertically the same way
        -- but get a second, independent anchor pinning their left edge, so indentation is visible.
        if type ~= "button" then
          local count = getn( lines )

          frame:ClearAllPoints()

          if count == 0 then
            local y = -top_padding - (v.padding or 0)
            frame:SetPoint( "TOP", popup, "TOP", 0, y )
          else
            local line_anchor = lines[ count ].frame
            frame:SetPoint( "TOP", line_anchor, "BOTTOM", 0, v.padding and -v.padding or 0 )
          end

          if type == "tree_node" then
            frame:SetPoint( "LEFT", popup, "LEFT", side_padding, 0 )
          end
        end
      end, v.padding )
    end
  end

  local function show()
    if not popup then popup = create_popup() end
    refresh()

    popup:Show()
  end

  local function hide()
    if popup then popup:Hide() end
  end

  local function toggle()
    if not popup then popup = create_popup() end

    if popup:IsVisible() then
      popup:Hide()
    else
      show()
    end
  end

  ---@type AutoLootFrame
  return {
    show = show,
    hide = hide,
    toggle = toggle,
    get_frame = function() return popup end
  }
end

m.AutoLootFrame = M
return M
