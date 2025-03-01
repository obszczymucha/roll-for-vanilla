RollFor = RollFor or {}
local m = RollFor

if m.WinnersPopup then return end

local c = m.colorize_player_by_class
local r = m.roll_type_color
local getn = m.getn
local filter = m.filter

---@class WinnersPopup
---@field show fun()
---@field hide fun()
---@field toggle fun()

local M = m.Module.new( "WinnersPopup" )
--M.debug.enable()

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 150 }

---@param popup_builder PopupBuilder
---@param frame_builder FrameBuilderFactory
---@param db table
---@param awarded_loot AwardedLoot
---@param roll_controller RollController
----@param options_popup_fn function
---@param config Config
function M.new( popup_builder, frame_builder, db, awarded_loot, roll_controller, config )
  ---@type Popup?
  local popup
  local refresh
  local headers
  local sort
  local sort_order = "asc"
  local scroll_frame
  local is_resizing
  local award_filters = config.award_filter()

  db.point = db.point or M.center_point
  --[[
  awarded_loot.award( 'Zombiehunter', 16939, { roll_type = 'SoftRes', roll = 112, player_name = "", player_class = "" }, 'SoftResRoll', nil, 'Hunter', 30 )
  awarded_loot.award( 'Kevieboipro', 16939, { roll_type = 'SoftRes', roll = 98, player_name = "", player_class = "" }, 'SoftResRoll', nil, 'Warrior', 20 )
  awarded_loot.award( 'Kevieboipro', 19019, { roll_type = 'Transmog', roll = 89, player_name = "", player_class = "" }, "NormalRoll", nil, 'Warrior' )
  awarded_loot.award( 'Dayknight', 5504, { roll_type = 'MainSpec', roll = 53, player_name = "", player_class = "" }, "NormalRoll", nil, 'Paladin' )
  awarded_loot.award( 'Celilae', 5504, { roll_type = 'MainSpec', roll = 78, player_name = "", player_class = "" }, "NormalRoll", nil, 'Paladin' )
  awarded_loot.award( 'Borazor', 16939, { roll_type = 'SoftRes', roll = 112, player_name = "", player_class = "" }, "SoftResRoll", nil, 'Hunter', 30 )
  awarded_loot.award( 'Ryiana', 16939, { roll_type = 'SoftRes', roll = 98, player_name = "", player_class = "" }, "SoftResRoll", nil, 'Warrior', 20 )
  awarded_loot.award( 'Tornapart', 19019, { roll_type = 'Transmog', roll = 89, player_name = "", player_class = "" }, "NormalRoll", nil, 'Warrior' )
  awarded_loot.award( 'Dayknight', 5504, { roll_type = 'MainSpec', roll = 53, player_name = "", player_class = "" }, "NormalRoll", nil, 'Paladin' )
  awarded_loot.award( 'Celilae', 5504, { roll_type = 'MainSpec', roll = 78, player_name = "", player_class = "" }, "NormalRoll", nil, 'Paladin' )
  awarded_loot.award( 'Borazor', 16936, { roll_type = 'SoftRes', roll = 112, player_name = "", player_class = "" }, "SoftResRoll", nil, 'Hunter', 30 )
  ]]

  local function create_popup()
    local function on_drag_stop()
      if not popup then return end
      if m.is_frame_out_of_bounds( popup ) then
        popup:position( db.point or M.center_point )
        return
      end

      local anchor = popup:get_anchor_point()
      db.point = { point = anchor.point, relative_point = anchor.relative_point, x = anchor.x, y = anchor.y }
    end

    local old_width
    local function on_resize()
      if not is_resizing then return end
      local min_width, max_width, min_height, max_height = 225, 500, 173, 600

      local width = math.max( min_width, math.min( max_width, this:GetWidth() ) )
      if width ~= this:GetWidth() then
        this:SetWidth( width )
      end

      local height = math.max( min_height, math.min( max_height, this:GetHeight() ) )
      if height ~= this:GetHeight() then
        this:SetHeight( height )
      end

      if not old_width then old_width = this:GetWidth() end
      if (math.abs( (width) - old_width ) > 7) or (width <= min_width) then
        old_width = this:GetWidth()
        refresh()
      end
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

    local frame = popup_builder
        :name( "rfWinnersFrame" )
        :width( db.width or 290 )
        :height( db.height or 200 )
        :point( get_point() )
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :sound()
        :movable()
        :on_drag_stop( on_drag_stop )
        :resizable()
        :on_resize( on_resize )
        :build()

    if not m.classic then
      frame:backdrop_color( 0, 0, 0, .8 )
      frame:border_color( .2, .2, .2, 1 )
    end

    return frame
  end

  local function make_content()
    local function set_sort()
      if sort == this.sort then
        sort_order = (sort_order == "asc") and "desc" or "asc"
      else
        sort = this.sort
      end
      refresh()
    end

    local function create_dropdown( parent, populate )
      if not parent:GetParent().dropdowns then parent:GetParent().dropdowns = {} end
      local dropdown = m.api.CreateFrame( "Frame", nil, parent )
      dropdown:SetFrameStrata( "TOOLTIP" )
      dropdown:SetPoint( "TOPLEFT", parent, "BOTTOMLEFT", 0, 0 )
      dropdown:SetBackdrop( {
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 0.5,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
      } )
      dropdown:SetBackdropColor( 0, 0, 0, 1 )
      dropdown:SetBackdropBorderColor( .2, .2, .2, 1 )
      dropdown:EnableMouse( true )
      dropdown:Hide()
      table.insert( parent:GetParent().dropdowns, dropdown )

      dropdown:SetScript( "OnLeave", function()
        if m.api.MouseIsOver( dropdown ) then
          return
        end
        dropdown:Hide()
      end )

      parent:SetScript( "OnMouseDown", function()
        if arg1 == "RightButton" then
          local visible = dropdown:IsVisible()
          for v in ipairs( parent:GetParent().dropdowns ) do
            parent:GetParent().dropdowns[ v ]:Hide()
          end
          if not visible then dropdown:Show() end
        end
      end )

      if populate then
        dropdown:SetScript( "OnShow", function()
          if not this.setup then
            this.setup = true
            populate()
          end
          for _, v in ipairs( this.checkboxes ) do
            v.checkbox:SetChecked( award_filters[ v.filter ][ v.setting ] )
          end
        end )
      end
    end

    local function create_checkbox_entry( text, setting )
      if not this.checkboxes then this.checkboxes = {} end
      local p = string.find( setting, ".", 1, true ) or 0
      local cb_filter = string.sub( setting, 1, p - 1 )
      local cb_setting = string.sub( setting, p + 1 )

      local cb = m.GuiElements.checkbox( this, text, function( value )
        award_filters[ cb_filter ][ cb_setting ] = value
        refresh()
      end )
      table.insert( this.checkboxes, cb )
      cb:SetPoint( "TOP", 0, -((getn( this.checkboxes ) - 1) * 17) - 7 )
      cb.filter = cb_filter
      cb.setting = cb_setting or setting

      if cb:GetWidth() > this:GetWidth() - 15 then
        this:SetWidth( cb:GetWidth() + 15 )
      end
      this:SetHeight( getn( this.checkboxes ) * 17 + 11 )
    end

    local main_frame = popup
    m.GuiElements.titlebar( main_frame, "Winners" )

    --[[
    local btn_options = m.GuiElements.tiny_button( main_frame, "o", "Open Settings", { r = .125, g = .624, b = .976 } )
    btn_options:SetPoint( "RIGHT", btn_close, "LEFT", m.classic and -2 or -5, 0 )
    btn_options:SetScript( "OnMouseUp", function()
      --options_popup_fn( "Awards popup" )
    end )
    ]]

    local btn_reset = m.GuiElements.tiny_button( main_frame, "R", "Reset Sorting", { r = .125, g = .976, b = .624 } )
    btn_reset:SetPoint( "TOPRIGHT", m.classic and -29 or -19, m.classic and -5 or -5 )
    btn_reset:SetScript( "OnClick", function()
      sort = nil
      refresh()
    end )

    local btn_resize = m.GuiElements.resize_grip( main_frame,
      function()
        is_resizing = true
      end,
      function()
        is_resizing = false
        db.width = this:GetParent():GetWidth()
        db.height = this:GetParent():GetHeight()
      end
    )
    btn_resize:SetPoint( "BOTTOMRIGHT", m.classic and -4 or 0, m.classic and 4 or 0 )

    local padding_top = m.classic and -20 or -10

    headers = m.GuiElements.winners_header( main_frame, set_sort )
    headers:SetPoint( "TOPLEFT", 20, padding_top - 20 )
    headers:SetPoint( "RIGHT", -20, 0 )

    create_dropdown( headers.item_id_header, function()
      create_checkbox_entry( "Poor", "item_quality.Poor" )
      create_checkbox_entry( "Common", "item_quality.Common" )
      create_checkbox_entry( "Uncommon", "item_quality.Uncommon" )
      create_checkbox_entry( "Rare", "item_quality.Rare" )
      create_checkbox_entry( "Epic", "item_quality.Epic" )
      create_checkbox_entry( "Legendary", "item_quality.Legendary" )
    end )

    create_dropdown( headers.winning_roll_header, function()
      create_checkbox_entry( "Show SR+", "winning_roll.show_sr_plus" )
    end )

    create_dropdown( headers.roll_type_header, function()
      create_checkbox_entry( "MainSpec", "roll_type.MainSpec" )
      create_checkbox_entry( "OffSpec", "roll_type.OffSpec" )
      create_checkbox_entry( "Transmog", "roll_type.Transmog" )
      create_checkbox_entry( "Soft reserve", "roll_type.SoftRes" )
      create_checkbox_entry( "Raid roll", "roll_type.RR" )
      create_checkbox_entry( "Other", "roll_type.NA" )
    end )

    scroll_frame = m.GuiElements.create_scroll_frame( main_frame )
    scroll_frame:SetPoint( "TOPLEFT", 20, padding_top - 35 )
    scroll_frame:SetPoint( "BOTTOMRIGHT", -6, m.classic and 20 or 15 )

    local inner_builder = frame_builder.new()
        :parent( scroll_frame )
        :name( "rfWinnersFrameInner" )
        :width( 250 )
        :height( 100 )
        :point( { point = "TOPLEFT", relative_point = "TOPLEFT", relative_frame = "rfWinnersFrame", x = 0, y = 0 } )
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :gui_elements( m.GuiElements )
        :frame_style( "None" )

    ---@class Frame
    scroll_frame.content = inner_builder:build()
    scroll_frame:SetScrollChild( scroll_frame.content )
    scroll_frame.content:SetAllPoints( scroll_frame )
    scroll_frame.content:SetScript( "OnUpdate", function()
      this:GetParent():update_scroll_state()
    end )

    scroll_frame.content:Show()
    return main_frame
  end

  function refresh()
    local function filter_winners( data )
      local quality_filter = {}
      for q, v in pairs( award_filters.item_quality ) do
        if v then
          table.insert( quality_filter, m.Types.ItemQuality[ q ] )
        end
      end

      local rolltype_filter = {}
      for t, v in pairs( award_filters.roll_type ) do
        if v then
          table.insert( rolltype_filter, t )
        end
      end

      data = filter( data, function( item )
        local quality = item.quality or 0
        return m.table_contains_value( quality_filter, quality ) and m.table_contains_value( rolltype_filter, item.roll_type )
      end )

      return data
    end

    local function sort_winners( a, b )
      local val_a, val_b
      if sort == "winning_roll" then
        val_a, val_b = a[ sort ] or 0, b[ sort ] or 0

        if sort_order == "asc" then
          return val_a > val_b
        else
          return val_a < val_b
        end
      else
        val_a, val_b = a[ sort ] or "", b[ sort ] or ""

        if sort == "player_name" then
          local class_a, class_b = a[ "player_class" ] or "", b[ "player_class" ] or ""
          if class_a ~= class_b then
            return (sort_order == "asc") == (class_a < class_b)
          end
          return a.player_name < b.player_name
        elseif sort == "item_id" then
          local quality_a, quality_b = a[ "quality" ] or 0, b[ "quality" ] or 0
          if quality_a ~= quality_b then
            return (sort_order == "asc") == (quality_a > quality_b)
          end
          return m.ItemUtils.get_item_name( a.item_link ) < m.ItemUtils.get_item_name( b.item_link )
        elseif sort == "roll_type" then
          local roll_order = { SoftRes = 1, MainSpec = 2, OffSpec = 3, Transmog = 4, RR = 5, NA = 6 }
          val_a, val_b = a[ sort ] or "NA", b[ sort ] or "NA"
          if val_a ~= val_b then
            return (sort_order == "asc") == (roll_order[ val_a ] < roll_order[ val_b ])
          end
          return a.item_id < b.item_id
        end
      end
    end

    if not popup then popup = create_popup() end
    scroll_frame.content:clear()
    local db_data = awarded_loot.get_winners()
    local data = {}

    local winners_count = 0
    for _, v in ipairs( db_data ) do
      if v.item_link then
        table.insert( data, {
          player_name = v.player_name,
          player_class = v.player_class,
          item_id = v.item_id,
          item_link = v.item_link,
          roll_type = (v.rolling_strategy == m.Types.RollingStrategy.RaidRoll or v.rolling_strategy == m.Types.RollingStrategy.InstaRaidRoll) and "RR"
              or v.roll_type or "NA",
          rolling_strategy = v.rolling_strategy,
          winning_roll = v.winning_roll,
          sr_plus = v.sr_plus,
          quality = v.quality
        } )
        winners_count = winners_count + 1
      end
    end

    if winners_count == 0 then
      scroll_frame:UpdateScrollChildRect()
      return
    end

    data = filter_winners( data )
    if (sort) then table.sort( data, sort_winners ) end

    local show_sr_plus = award_filters[ "winning_roll" ][ "show_sr_plus" ]
    local got_sr_plus = false
    local content = {}
    for _, item in pairs( data ) do
      table.insert( content, {
        type = "winner",
        player_name = item.player_name,
        player_class = item.player_class,
        item_link = item.item_link,
        roll_type = item.roll_type,
        rolling_strategy = item.rolling_strategy,
        winning_roll = item.winning_roll,
        sr_plus = item.sr_plus,
        quality = item.quality
      } )
      if item.sr_plus then got_sr_plus = true end
    end

    headers.winning_roll_header:SetWidth( (show_sr_plus and got_sr_plus) and 50 or 25 )

    for _, v in ipairs( content ) do
      scroll_frame.content.add_line( v.type, function( type, frame, lines )
        if type == "winner" then
          local roll_type_abbrev = v.roll_type == "RR" and "RR" or v.roll_type == "NA" and "NA" or m.roll_type_abbrev( v.roll_type )
          local sr_plus = ""

          if show_sr_plus and got_sr_plus then
            frame.winning_roll:GetParent():SetWidth( 50 )
            if v.sr_plus and v.rolling_strategy == m.Types.RollingStrategy.SoftResRoll and v.roll_type == m.Types.RollType.SoftRes then
              sr_plus = string.format( "+%s ", v.sr_plus )
            end
          else
            frame.winning_roll:GetParent():SetWidth( 25 )
          end

          frame:SetItem( v.item_link )
          frame.player_name:SetText( c( v.player_name, v.player_class ) )
          frame.winning_roll:SetText( string.format( "%s%s", sr_plus, v.winning_roll or "-" ) )
          frame.roll_type:SetText( r( v.roll_type, roll_type_abbrev ) )

          frame:SetPoint( "TOP", scroll_frame.content, "TOP", 0, -getn( lines ) * 14 )
        end
      end, 0 )
    end
    scroll_frame:UpdateScrollChildRect()
  end

  local function show()
    M.debug.add( "show" )
    if not popup then
      popup = create_popup()
      make_content()
    end
    popup:Show()
    refresh()
  end

  local function hide()
    M.debug.add( "hide" )
    if popup then
      popup:Hide()
    end
  end

  local function toggle()
    M.debug.add( "toggle" )
    if popup and popup:IsVisible() then
      hide()
    else
      show()
    end
  end

  local function loot_awarded()
    M.debug.add( "loot_awarded" )
    if popup and popup:IsVisible() then
      refresh()
      if not sort then
        local max = scroll_frame:GetVerticalScrollRange()
        local tick = 0
        scroll_frame:SetScript( "OnUpdate", function()
          local new_max = scroll_frame:GetVerticalScrollRange()
          tick = tick + 1
          if new_max > max or tick > 5 then
            scroll_frame:SetVerticalScroll( new_max )
            scroll_frame:SetScript( "OnUpdate", nil )
          end
        end )
      end
    end
  end

  local function award_data_updated()
    if popup and popup:IsVisible() then
      refresh()
    end
  end

  roll_controller.subscribe( "loot_awarded", loot_awarded )
  awarded_loot.subscribe( "award_data_updated", award_data_updated )

  ---@type WinnersPopup
  return {
    show = show,
    hide = hide,
    toggle = toggle
  }
end

m.WinnersPopup = M
return M
