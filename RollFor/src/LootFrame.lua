RollFor = RollFor or {}
local m = RollFor
if m.LootFrame then return end

local M = m.Module.new( "LootFrame" )

---@class LootFrame
---@field show fun()
---@field update fun( items: LootFrameItem[] )
---@field hide fun()
---@field get_frame fun(): Frame

M.center_point = { point = "CENTER", relative_point = "CENTER", x = -260, y = 220 }

---@class LootFrameSkin
---@field header fun( on_drag_stop: function, on_show: function, on_hide: function ): Frame
---@field body fun( parent: Frame ): Frame
---@field dropped_item fun(): Frame
---@field footer fun( parent: Frame ): Frame?
---@field get_item_height fun(): number

---@param loot_frame_skin LootFrameSkin
---@param db table
---@param config Config
function M.new( loot_frame_skin, db, config )
  ---@type Frame
  local header_frame
  ---@type Frame
  local body_frame
  ---@type Frame?
  local footer_frame

  local boss_name_width = 0
  local max_frame_width

  local function on_drag_stop( frame )
    local point, _, relative_point, x, y = frame:GetPoint()

    if m.is_frame_out_of_bounds( frame ) then
      db.point = M.center_point
      frame:position( M.center_point )

      return
    end

    db.point = { point = point, relative_point = relative_point, x = x, y = y }
  end

  local function create_header_frame()
    local function on_show()
      body_frame:Show()
      if footer_frame then footer_frame:Show() end
    end

    local function on_hide()
      body_frame:Hide()
      if footer_frame then footer_frame:Hide() end
    end

    local frame = loot_frame_skin.header( on_drag_stop, on_show, on_hide )
    frame:ClearAllPoints()

    if db.point then
      local p = db.point
      ---@diagnostic disable-next-line: undefined-global
      frame:SetPoint( p.point, UIParent, p.relative_point, p.x, p.y )
    else
      frame:position( M.center_point )
    end

    return frame
  end

  local function update_boss_name_frame()
    header_frame.clear()
    header_frame.add_line( "text", function( type, frame )
      if type == "text" then
        frame:ClearAllPoints()
        frame:SetHeight( 16 )
        frame:SetPoint( "CENTER", 1, 0 )
        frame:SetTextColor( 0.125, 0.624, 0.976 )

        local name = m.api.UnitName( "target" )

        if not name then
          frame:SetText( "Loot" )
        else
          frame:SetText( string.format( "%s%s Loot", name, m.possesive_case( name ) ) )
        end

        boss_name_width = frame:GetStringWidth() + 30
      end
    end, 0 )
  end

  local function show()
    M.debug.add( "show" )
    update_boss_name_frame()
    max_frame_width = nil
    header_frame:Show()
  end

  local function hide()
    if header_frame then
      M.debug.add( "hide" )
      header_frame:Hide()
    end
  end

  ---@class LootFrameItem
  ---@field index number
  ---@field texture ItemTexture
  ---@field name string
  ---@field quality ItemQuality
  ---@field quantity number
  ---@field link ItemLink
  ---@field click_fn fun()
  ---@field is_selected boolean
  ---@field is_enabled boolean
  ---@field slot number?
  ---@field tooltip_link TooltipItemLink?
  ---@field comment string?
  ---@field comment_tooltip string[]?
  ---@field bind string?

  ---@param items LootFrameItem[]
  local function update( items )
    M.debug.add( "update" )
    body_frame.clear()

    local content = {}

    for _, item in ipairs( items ) do
      table.insert( content, {
        type = "dropped_item",
        item = item
      } )
    end

    local max_width = 0
    local anchor
    local item_count = 0
    local frames = {}

    for _, v in ipairs( content ) do
      body_frame.add_line( v.type, function( type, frame )
        if type == "dropped_item" then
          local item = v.item ---@type LootFrameItem
          frame:SetItem( item )
          frame:ClearAllPoints()

          if max_frame_width then
            frame:SetWidth( max_frame_width - 2 )
          end

          if not anchor then
            frame:SetPoint( "TOPLEFT", body_frame, "TOPLEFT", 0, 0 )
            frame:SetPoint( "TOPRIGHT", body_frame, "TOPRIGHT", 0, 0 )
          else
            frame:SetPoint( "TOPLEFT", anchor, "BOTTOMLEFT", 0, 0 )
            frame:SetPoint( "TOPRIGHT", anchor, "BOTTOMRIGHT", 0, 0 )
          end

          anchor = frame

          local w = frame:GetWidth() + 2
          if w > max_width then max_width = w end
          item_count = item_count + 1

          table.insert( frames, frame )
        end
      end, 0 )
    end

    max_frame_width = m.lua.math.max( boss_name_width, max_width )

    header_frame:SetWidth( max_frame_width )
    body_frame:SetWidth( max_frame_width )
    body_frame:SetHeight( item_count * loot_frame_skin.get_item_height() + 1 )

    if footer_frame then
      footer_frame:ClearAllPoints()
      footer_frame:SetWidth( max_frame_width )
      footer_frame:SetPoint( "TOP", body_frame, "BOTTOM", 0, 2 )
    end

    for _, frame in ipairs( frames ) do
      frame:SetWidth( max_frame_width - 2 )
    end
  end

  config.subscribe( "reset_loot_frame", function()
    db.point = nil
    if header_frame then header_frame:position( M.center_point ) end
  end )

  header_frame = create_header_frame()
  body_frame   = loot_frame_skin.body( header_frame )
  footer_frame = loot_frame_skin.footer( header_frame )

  ---@type LootFrame
  return {
    show = show,
    update = update,
    hide = hide,
    get_frame = function() return header_frame end
  }
end

m.LootFrame = M
return M
