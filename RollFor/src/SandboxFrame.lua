RollFor = RollFor or {}
local m = RollFor

if m.SandboxFrame then return end

local M = {}
local getn = m.getn
local ItemQuality = m.Types.ItemQuality

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

-- Experiment: a 3-level tree (Dungeon -> Boss -> Item drops) to try out an expandable tree
-- widget. Data is hardcoded sample data, not wired to anything real yet.
local dungeons = {
  {
    name = "Blackrock Depths",
    expanded = false,
    bosses = {
      { name = "Lord Incendius", expanded = false, items = { "Incendius' Cinch", "Flickering Cinderweb Cloak" } },
      { name = "Grizzle", expanded = false, items = { "Grizzly Claw", "Boarskin Gloves" } },
    }
  },
  {
    name = "Scholomance",
    expanded = false,
    bosses = {
      { name = "Darkmaster Gandling", expanded = false, items = { "Master's Burning Cape", "Gandling's Grimoire" } },
      { name = "Instructor Malicia", expanded = false, items = { "Malicia's Rejuvenating Charm" } },
    }
  }
}

---@class SandboxFrame
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field get_frame fun(): Popup?

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 0 }

---@param popup_builder PopupBuilder
---@param content_transformer SandboxFrameContentTransformer
---@param db table
function M.new( popup_builder, content_transformer, db )
  ---@type Popup?
  local popup
  local top_padding = 8
  local side_padding = 20

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
        :name( "RollForSandboxFrame" )
        :point( get_point() )
        :gui_elements( m.GuiElements )
        :movable()
        :on_drag_stop( on_drag_stop )
        :strata( "DIALOG" )
        :self_centered_anchor()
        :hidden()
        :build()

    result:border_color( 0.351, 0.553, 1.0, 0.3 )

    return result
  end

  local refresh

  ---@return SandboxFrameTreeNode[]
  local function tree_rows()
    local rows = {}

    for _, dungeon in ipairs( dungeons ) do
      table.insert( rows, {
        depth = 0,
        label = m.colors.blue( dungeon.name ),
        expandable = true,
        expanded = dungeon.expanded,
        on_click = function()
          dungeon.expanded = not dungeon.expanded
          refresh()
        end
      } )

      if dungeon.expanded then
        for _, boss in ipairs( dungeon.bosses ) do
          table.insert( rows, {
            depth = 1,
            label = boss.name,
            expandable = true,
            expanded = boss.expanded,
            on_click = function()
              boss.expanded = not boss.expanded
              refresh()
            end
          } )

          if boss.expanded then
            for _, item in ipairs( boss.items ) do
              table.insert( rows, { depth = 2, label = item } )
            end
          end
        end
      end
    end

    return rows
  end

  ---@return SandboxFrameData
  local function content()
    return {
      title = m.colorize_item_by_quality( "RollFor Sandbox", ItemQuality.Legendary ),
      rows = tree_rows(),
      buttons = {
        { type = "Close", callback = function() if popup then popup:Hide() end end }
      }
    }
  end

  refresh = function()
    if not popup then popup = create_popup() end
    popup:clear()

    for _, v in ipairs( content_transformer.transform( content() ) ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:ClearAllPoints() -- This fixes a strange visual bug in BCC. Frame is either without label or misaligned without this.
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )
        elseif type == "tree_node" then
          frame:SetText( v.label or "" )
          frame:SetDepth( v.depth or 0 )
          frame:SetExpandable( v.expandable, v.expanded )
          frame.on_click = v.on_click or function() end
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

  ---@type SandboxFrame
  return {
    show = show,
    hide = hide,
    toggle = toggle,
    get_frame = function() return popup end
  }
end

m.SandboxFrame = M
return M
