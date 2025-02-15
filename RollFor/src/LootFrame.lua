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

---@param frame_builder table
---@param db table
---@param config Config
function M.new( frame_builder, db, config )
  local scale = 1.0
  ---@class Frame
  local boss_name_frame
  ---@class Frame
  local loot_frame
  local boss_name_width = 0
  local max_frame_width

  local function is_out_of_bounds( x, y, frame_width, frame_height, screen_width, screen_height )
    local left = x
    local right = x + frame_width
    local top = y
    local bottom = y - frame_height

    return left < 0 or
        right > screen_width or
        top > 0 or
        bottom < -screen_height
  end

  local function on_drag_stop( frame )
    local width, height = frame:GetWidth(), frame:GetHeight()
    local screen_width, screen_height = m.api.GetScreenWidth(), m.api.GetScreenHeight()
    local point, _, relative_point, x, y = frame:GetPoint()

    if is_out_of_bounds( x, y, width, height, screen_width, screen_height ) then
      db.point = M.center_point
      frame:position( M.center_point )

      return
    end

    db.point = { point = point, relative_point = relative_point, x = x, y = y }
  end

  local function create_boss_name_frame()
    boss_name_frame = frame_builder.new()
        :name( "RollForBossNameFrame" )
        :width( 380 )
        :height( 24 )
        :border_size( 16 )
        :sound()
        :gui_elements( m.GuiElements )
        :frame_style( "PrincessKenny" )
        :backdrop_color( 0, 0.501, 1, 0.3 )
        :border_color( 0, 0, 0, 0.9 )
        :movable()
        :gui_elements( m.GuiElements )
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :on_show( function()
          loot_frame:Show()
        end )
        :on_hide( function()
          loot_frame:Hide()
        end )
        :on_drag_stop( on_drag_stop )
        :scale( scale )
        :build()

    boss_name_frame:ClearAllPoints()

    if db.point then
      local p = db.point
      ---@diagnostic disable-next-line: undefined-global
      boss_name_frame:SetPoint( p.point, UIParent, p.relative_point, p.x, p.y )
    else
      boss_name_frame:position( M.center_point )
    end
  end

  local function create_frame()
    loot_frame = frame_builder.new()
        :name( "RollForLootFrame" )
        :width( 280 )
        :height( 100 )
        :border_size( 16 )
        :gui_elements( m.GuiElements )
        :frame_style( "PrincessKenny" )
        :backdrop_color( 0, 0, 0, 0.5 )
        :border_color( 0, 0, 0, 0.9 )
        :movable()
        :gui_elements( m.GuiElements )
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :scale( scale )
        :build()

    loot_frame:ClearAllPoints()
    loot_frame:SetPoint( "TOP", boss_name_frame, "BOTTOM", 0, 1 )
  end

  local function update_boss_name_frame()
    boss_name_frame.clear()
    boss_name_frame.add_line( "text", function( type, frame )
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
    boss_name_frame:Show()
  end

  local function hide()
    if boss_name_frame then
      M.debug.add( "hide" )
      boss_name_frame:Hide()
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
    loot_frame.clear()

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
    local height = 25
    local frames = {}

    for _, v in ipairs( content ) do
      loot_frame.add_line( v.type, function( type, frame )
        if type == "dropped_item" then
          local item = v.item ---@type LootFrameItem
          frame:SetItem( item )
          frame:SetHeight( height )
          frame:ClearAllPoints()

          if max_frame_width then
            frame:SetWidth( max_frame_width - 2 )
          end

          if not anchor then
            frame:SetPoint( "TOPLEFT", loot_frame, "TOPLEFT", 1, -1 )
          else
            frame:SetPoint( "TOPLEFT", anchor, "BOTTOMLEFT", 0, 0 )
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

    boss_name_frame:SetWidth( max_frame_width )
    loot_frame:SetWidth( max_frame_width )
    loot_frame:SetHeight( item_count * height + 2 )

    for _, frame in ipairs( frames ) do
      frame:SetWidth( max_frame_width - 2 )
    end
  end

  config.subscribe( "reset_loot_frame", function()
    db.point = nil
    if boss_name_frame then boss_name_frame:position( M.center_point ) end
  end )

  create_boss_name_frame()
  create_frame()

  ---@type LootFrame
  return {
    show = show,
    update = update,
    hide = hide,
    get_frame = function() return boss_name_frame end
  }
end

m.LootFrame = M
return M
