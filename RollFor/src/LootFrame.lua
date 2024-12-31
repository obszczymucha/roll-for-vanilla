RollFor = RollFor or {}
local m = RollFor
if m.LootFrame then return end

local M = {}

local S = m.Types.RollingStatus

function M.new( frame_builder, loot_list, db, roll_controller, roll_tracker )
  local scale = 1.0
  ---@class Frame
  local boss_name_frame
  ---@class Frame
  local loot_frame
  local boss_name_width = 0
  local max_frame_width
  local selected_item

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
      local center_point = { point = "CENTER", relative_point = "CENTER", x = -260, y = 220 }
      db.point = center_point
      frame:position( center_point )

      return
    end

    db.point = { point = point, relative_point = relative_point, x = x, y = y }
  end

  local function create_boss_name_frame()
    boss_name_frame = frame_builder.new()
        :name( "RollForBossNameFrame" )
        :width( 380 )
        :height( 22 )
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
      ---@diagnostic disable-next-line: undefined-global
      boss_name_frame:SetPoint( "TOPLEFT", LootFrame, "TOPLEFT", 22, -54 )
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
  end

  local function hide()
    if boss_name_frame then boss_name_frame:Hide() end
  end

  local function on_click( button, item )
    if m.api.IsControlKeyDown() then
      m.api.DressUpItemLink( item.link )
      return
    elseif m.api.IsShiftKeyDown() and m.api.ChatFrameEditBox:IsVisible() then
      m.api.ChatFrameEditBox:Insert( item.link )
      return
    end

    local loot_method = m.api.GetLootMethod()

    if m.is_player_master_looter() and not item.coin then
      roll_controller.preview( item )
      return
    end

    local threshold = m.api.GetLootThreshold()

    if loot_method == "freeforall" or (item.quality or 0) < threshold then
      -- Fucking hell this took forever to figure out. Fuck you Blizzard.
      -- For looting to work in vanilla, the frame must be of a "LootButton" type and
      -- then it comes with the SetSlot function that we need to use to set the slot.
      -- This will probably be a pain in the ass when porting.
      button:SetSlot( item.slot )
    end
  end

  local function update()
    loot_frame.clear()

    local content = {}
    for _, item in ipairs( loot_list.get_items() ) do
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
          local item = v.item
          frame:SetItem( item )
          frame:SetHeight( height )
          frame:SetOnClick( on_click )
          frame:ClearAllPoints()
          frame:SetSelectedItem( selected_item )

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

    loot_frame:SetHeight( item_count * height + 2 )

    return max_width, frames
  end

  local function show()
    if not boss_name_frame then create_boss_name_frame() end
    if not loot_frame then create_frame() end

    local roll_data = roll_tracker.get()
    selected_item = roll_data and roll_data.status and roll_data.status ~= S.Preview and roll_data.item

    max_frame_width = nil

    boss_name_frame:Show()
    boss_name_frame.clear()
    boss_name_frame.add_line( "text", function( type, frame )
      if type == "text" then
        frame:ClearAllPoints()
        frame:SetHeight( 16 )
        frame:SetPoint( "CENTER", 0, 0 )
        frame:SetTextColor( 0.125, 0.624, 0.976 )

        local name = m.api.UnitName( "target" )
        frame:SetText( string.format( "%s%s Loot", name, m.possesive_case( name ) ) )

        boss_name_width = frame:GetStringWidth() + 30
      end
    end, 0 )

    loot_frame:ClearAllPoints()
    loot_frame:SetPoint( "TOP", boss_name_frame, "BOTTOM", 0, 1 )

    local max_width, frames = update()
    max_frame_width = m.lua.math.max( boss_name_width, max_width )

    boss_name_frame:SetWidth( max_frame_width )
    loot_frame:SetWidth( max_frame_width )

    for _, frame in ipairs( frames ) do
      frame:SetWidth( max_frame_width - 2 )
    end
  end

  local function select( data )
    selected_item = data and data.item or nil
    update()
  end

  local function deselect()
    selected_item = nil
    update()
  end

  roll_controller.subscribe( "preview", select )
  roll_controller.subscribe( "award_loot", select )
  roll_controller.subscribe( "award_aborted", select )
  roll_controller.subscribe( "rolling_popup_closed", deselect )
  roll_controller.subscribe( "loot_awarded", deselect )

  return {
    show = show,
    update = update,
    hide = hide
  }
end

m.LootFrame = M
return M
