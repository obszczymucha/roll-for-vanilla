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
---@param confirm_popup ConfirmPopup
---@param config Config
function M.new( popup_builder, frame_builder, db, awarded_loot, roll_controller, confirm_popup, config )
  ---@type Popup
  local popup
  local refresh
  local headers
  local sort
  local sort_order = "asc"
  local scroll_frame
  local is_resizing
  local award_filters = config.award_filter()
  local winners_data

  db.point = db.point or M.center_point
  --[[
  awarded_loot.award( "Zombiehunter", 16939, { roll_type = "SoftRes", roll = 112, player_name = "", player_class = "" }, "SoftResRoll", nil, "Hunter", 30 )
  awarded_loot.award( "Kevieboipro", 16939, { roll_type = "SoftRes", roll = 98, player_name = "", player_class = "" }, "SoftResRoll", nil, "Warrior", 20 )
  awarded_loot.award( "Kevieboipro", 19019, { roll_type = "Transmog", roll = 89, player_name = "", player_class = "" }, "NormalRoll", nil, "Warrior" )
  awarded_loot.award( "Dayknight", 5504, { roll_type = "MainSpec", roll = 53, player_name = "", player_class = "" }, "NormalRoll", nil, "Paladin" )
  awarded_loot.award( "Celilae", 5504, { roll_type = "MainSpec", roll = 78, player_name = "", player_class = "" }, "NormalRoll", nil, "Paladin" )
  awarded_loot.award( "Borazor", 16939, { roll_type = "SoftRes", roll = 112, player_name = "", player_class = "" }, "SoftResRoll", nil, "Hunter", 30 )
  awarded_loot.award( "Ryiana", 16939, { roll_type = "SoftRes", roll = 98, player_name = "", player_class = "" }, "SoftResRoll", nil, "Warrior", 20 )
  awarded_loot.award( "Tornapart", 19019, { roll_type = "Transmog", roll = 89, player_name = "", player_class = "" }, "NormalRoll", nil, "Warrior" )
  awarded_loot.award( "Dayknight", 5504, { roll_type = "MainSpec", roll = 53, player_name = "", player_class = "" }, "NormalRoll", nil, "Paladin" )
  awarded_loot.award( "Celilae", 5504, { roll_type = "MainSpec", roll = 78, player_name = "", player_class = "" }, "NormalRoll", nil, "Paladin" )
  awarded_loot.award( "Borazor", 16936, { roll_type = "SoftRes", roll = 112, player_name = "", player_class = "" }, "SoftResRoll", nil, "Hunter", 30 )
  ]]

  local function create_popup()
    M.debug.add( "create popup" )
    local function on_drag_stop( self )
      if not self then return end
      if m.is_frame_out_of_bounds( self ) then
        self:position( db.point or M.center_point )
        return
      end

      local anchor = self:get_anchor_point()
      db.point = { point = anchor.point, relative_point = anchor.relative_point, x = anchor.x, y = anchor.y }
    end

    local old_width
    local function on_resize( self )
      if not self or not is_resizing then return end
      local min_width, max_width, min_height, max_height = 225, 500, 173, 600

      local width = math.max( min_width, math.min( max_width, self:GetWidth() ) )
      if width ~= self:GetWidth() then
        self:SetWidth( width )
      end

      local height = math.max( min_height, math.min( max_height, self:GetHeight() ) )
      if height ~= self:GetHeight() then
        self:SetHeight( height )
      end

      if not old_width then old_width = self:GetWidth() end
      if (math.abs( (width) - old_width ) > 7) or (width <= min_width) then
        old_width = self:GetWidth()
        refresh()
      end
      scroll_frame:update_scroll_state()
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
        :name( "RollForWinnersFrame" )
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
    M.debug.add( "make content" )
    local function set_sort( self )
      if sort == self.sort then
        sort_order = (sort_order == "asc") and "desc" or "asc"
      else
        sort = self.sort
      end
      refresh( true )
    end

    local function cb_on_change( cb_filter, cb_setting, value )
      if cb_filter and cb_setting then
        award_filters[ cb_filter ][ cb_setting ] = value
        refresh( true )
      end
    end

    m.GuiElements.titlebar( popup, "Winners" )

    local btn_reset = m.GuiElements.tiny_button( popup, "R", "Reset Sorting", { r = .125, g = .976, b = .624 } )
    btn_reset:SetPoint( "TOPRIGHT", m.classic and -29 or -23, m.classic and -5 or -5 )
    btn_reset:SetScript( "OnClick", function()
      sort = nil
      refresh( true )
    end )

    local btn_clear = m.GuiElements.tiny_button( popup, "C", "Clear data", "#209ff9" )
    btn_clear:SetPoint( "TOPRIGHT", btn_reset, "TOPLEFT", m.classic and 0 or -5, 0 )
    btn_clear:SetScript( "OnClick", function()
      if confirm_popup.is_visible() then
        confirm_popup.hide()
        return
      end

      confirm_popup.show( { "This will clear the current winners data.", "Are you sure?" }, function( value )
        if value then
          awarded_loot.clear( true )
        end
      end )
    end )

    local btn_resize = m.GuiElements.resize_grip( popup,
      function()
        is_resizing = true
      end,
      function( frame )
        is_resizing = false
        db.width = frame:GetWidth()
        db.height = frame:GetHeight()
      end
    )
    btn_resize:SetPoint( "BOTTOMRIGHT", m.classic and -4 or 0, m.classic and 4 or 0 )

    local padding_top = m.classic and -20 or -10

    headers = m.WinnersPopupGui.headers( popup, set_sort )
    headers:SetPoint( "TOPLEFT", 20, padding_top - 20 )
    headers:SetPoint( "RIGHT", -20, 0 )

    m.WinnersPopupGui.create_dropdown( headers.item_id_header, award_filters, function( self )
      m.WinnersPopupGui.create_checkbox_entry( self, "Poor", "item_quality.Poor", cb_on_change )
      m.WinnersPopupGui.create_checkbox_entry( self, "Common", "item_quality.Common", cb_on_change )
      m.WinnersPopupGui.create_checkbox_entry( self, "Uncommon", "item_quality.Uncommon", cb_on_change )
      m.WinnersPopupGui.create_checkbox_entry( self, "Rare", "item_quality.Rare", cb_on_change )
      m.WinnersPopupGui.create_checkbox_entry( self, "Epic", "item_quality.Epic", cb_on_change )
      m.WinnersPopupGui.create_checkbox_entry( self, "Legendary", "item_quality.Legendary", cb_on_change )
    end )

    m.WinnersPopupGui.create_dropdown( headers.winning_roll_header, award_filters, function( self )
      m.WinnersPopupGui.create_checkbox_entry( self, "Show SR+", "winning_roll.show_sr_plus", cb_on_change )
    end )

    m.WinnersPopupGui.create_dropdown( headers.roll_type_header, award_filters, function( self )
      m.WinnersPopupGui.create_checkbox_entry( self, "MainSpec", "roll_type.MainSpec", cb_on_change )
      m.WinnersPopupGui.create_checkbox_entry( self, "OffSpec", "roll_type.OffSpec", cb_on_change )
      m.WinnersPopupGui.create_checkbox_entry( self, "Transmog", "roll_type.Transmog", cb_on_change )
      m.WinnersPopupGui.create_checkbox_entry( self, "Soft reserve", "roll_type.SoftRes", cb_on_change )
      m.WinnersPopupGui.create_checkbox_entry( self, "Raid roll", "roll_type.RR", cb_on_change )
      m.WinnersPopupGui.create_checkbox_entry( self, "Other", "roll_type.NA", cb_on_change )
    end )

    scroll_frame = m.WinnersPopupGui.create_scroll_frame( popup )
    scroll_frame:SetPoint( "TOPLEFT", 20, padding_top - 35 )
    scroll_frame:SetPoint( "BOTTOMRIGHT", -6, m.classic and 20 or 15 )

    local inner_builder = frame_builder.new()
        :parent( scroll_frame )
        :name( "RollForWinnersFrameInner" )
        :width( 250 )
        :height( 100 )
        :point( { point = "TOPLEFT", relative_point = "TOPLEFT", relative_frame = "RollForWinnersFrame", x = 0, y = 0 } )
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :gui_elements( m.WinnersPopupGui )
        :frame_style( "None" )

    scroll_frame.content = inner_builder:build()
    scroll_frame:SetScrollChild( scroll_frame.content )
    scroll_frame.content:SetAllPoints( scroll_frame )
    scroll_frame.content:Show()

    return popup
  end

  local function get_data()
    local function filter_winners()
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

      winners_data = filter( winners_data, function( item )
        local quality = item.quality or 0
        return m.table_contains_value( quality_filter, quality ) and m.table_contains_value( rolltype_filter, item.roll_type )
      end )
    end

    local function sort_winners( a, b )
      if sort == "winning_roll" then
        local roll_a = tonumber( a[ sort ] ) or 0
        local roll_b = tonumber( b[ sort ] ) or 0

        if sort_order == "asc" then
          return roll_a > roll_b
        else
          return roll_a < roll_b
        end
      end

      local val_a = a[ sort ] or ""
      local val_b = b[ sort ] or ""

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

    M.debug.add( "Get data" )
    local db_data = awarded_loot.get_winners()
    winners_data = {}
    for _, v in ipairs( db_data ) do
      if v.item_link then
        table.insert( winners_data, {
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
      end
    end

    if getn( winners_data ) == 0 then
      scroll_frame:UpdateScrollChildRect()
      return
    end

    filter_winners()
    if (sort) then table.sort( winners_data, sort_winners ) end
  end

  function refresh( refresh_data )
    if not popup then
      popup = create_popup()
      make_content()
    end

    if not winners_data or refresh_data then get_data() end

    local show_sr_plus = award_filters[ "winning_roll" ][ "show_sr_plus" ]
    local got_sr_plus = false
    local content = {}
    for _, item in pairs( winners_data ) do
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

    scroll_frame.content:clear()
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
    local tick = 0
    scroll_frame:SetScript( "OnUpdate", function()
      scroll_frame:update_scroll_state()
      tick = tick + 1
      if tick > 1 then
        scroll_frame:SetScript( "OnUpdate", nil )
      end
    end )
  end

  local function show()
    M.debug.add( "show" )
    if not popup then
      popup = create_popup()
      make_content()
    end
    popup:Show()
    refresh( true )
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
      refresh( true )
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
      refresh( true )
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
