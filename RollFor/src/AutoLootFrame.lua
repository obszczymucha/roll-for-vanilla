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

-- A 3-level tree (Dungeon -> Boss -> Item drops) selection GUI built on top of AutoLootTree's
-- pure data (tree contents, checked/desaturated/visibility already decided there). This file is
-- dumb rendering only -- it wires click/check callbacks that mutate a row's node and calls
-- refresh(), and translates rows into widget calls; it makes no decisions about the tree itself.
--
-- Auto-loot and auto round robin are the same window over two different catalogues, so what
-- differs between them -- the frame name, the title, which tree roots to render, how to build an
-- item link, and any buttons beyond Close -- is supplied by the caller. If the two are ever meant
-- to diverge visually, that's the moment to split them; not before.

---@class AutoLootFrame
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field refresh fun() -- redraw what's on screen, for when something outside the tree changed
---@field get_frame fun(): Popup?

---@class AutoLootFrameConfig
---@field popup_builder PopupBuilder
---@field content_transformer AutoLootFrameContentTransformer
---@field db table -- where the window position is remembered
---@field name string -- the global frame name
---@field title string -- plain text; this file decides how it's colored
---@field roots TreeNode[] -- the tree to render, as returned by AutoLootTree.build
---@field make_link fun( item_id: number, quality: number, name: string ): string
---@field extra_buttons AutoLootFrameButtonWithCallback[]? -- rendered before Close
---@field decorate_row fun( row: AutoLootFrameTreeNode )? -- last word on a row, called per refresh
---@field on_changed fun()? -- a row was ticked; the selection this window edits is now different

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 0 }

---@param config AutoLootFrameConfig
function M.new( config )
  local popup_builder = config.popup_builder
  local content_transformer = config.content_transformer
  local db = config.db

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
        :name( config.name )
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

    for _, row in ipairs( m.AutoLootTree.visible_rows( config.roots ) ) do
      local node = row.node

      -- Raw data (with its `type`) passed straight through -- the content transformer is where
      -- type -> presentation (label color, item vs label rendering) gets decided, not here.
      local result = {
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

          -- After the write and the redraw, so anyone listening sees the selection it landed on
          -- rather than the one it was leaving.
          if config.on_changed then config.on_changed() end
        end
      }

      -- The caller's chance to say something about a row that the tree can't know, because it
      -- depends on the client rather than on the selection -- see AutoRoundRobinFrame, which greys
      -- a quality row the loot threshold has made inert. Runs per refresh, on a table built fresh
      -- each time, so nothing it writes can go stale or leak into the tree.
      if config.decorate_row then config.decorate_row( result ) end

      table.insert( rows, result )
    end

    return rows
  end

  ---@return AutoLootFrameData
  local function content()
    local buttons = {}

    for _, button in ipairs( config.extra_buttons or {} ) do
      table.insert( buttons, button )
    end

    table.insert( buttons, { type = "Close", callback = function() if popup then popup:Hide() end end } )

    return {
      title = m.colorize_item_by_quality( config.title, ItemQuality.Legendary ),
      rows = tree_rows(),
      buttons = buttons
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
            local link = config.make_link( v.item_id, v.item.quality, v.item.name )
            frame:SetItem( { link = link, texture = v.item.icon, hover_background_color = v.hover_background_color, tooltip_position = v.tooltip_position }, IU.get_tooltip_link( link ) )
          else
            frame:SetText( v.label or "" )
            frame:SetLabelStyle( v.color, v.hover_text_color, v.hover_background_color )
            frame:SetLabelTooltip( v.tooltip_text )
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

  -- Redraws what's already on screen, and nothing else. A closed window has nothing to correct:
  -- show() refreshes on the way up, so the next opening is current either way. Callers use this
  -- when something the rows depend on changed outside the tree -- see AutoRoundRobinFrame, whose
  -- quality rows are drawn against the master loot threshold.
  local function refresh_if_visible()
    if popup and popup:IsVisible() then refresh() end
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
    refresh = refresh_if_visible,
    get_frame = function() return popup end
  }
end

m.AutoLootFrame = M
return M
