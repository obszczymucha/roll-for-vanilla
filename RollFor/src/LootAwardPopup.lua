RollFor = RollFor or {}
local m = RollFor

if m.LootAwardPopup then return end

local M = {}

local RS = m.Types.RollingStrategy
local LAE = m.Types.LootAwardError
local red = m.colors.red
local c = m.colorize_player_by_class
local possesive_case = m.possesive_case
---@diagnostic disable-next-line: deprecated
local getn = table.getn

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

function M.new( popup_builder, roll_controller, confirm_award, RollingPopupContent, db, center_point, master_loot_candidates, roll_tracker )
  local popup
  local data_for_error
  local top_padding = 14

  local function create_popup()
    local frame = popup_builder
        :name( "RollForLootAssignmentFrame" )
        :width( 280 )
        :height( 100 )
        :sound()
        :border_size( 16 )
        :esc()
        :gui_elements( m.GuiElements )
        :frame_style( "PrincessKenny" )
        :on_show( function()
          ---@diagnostic disable-next-line: undefined-global
          local rolling_frame = RollForRollingFrame
          if rolling_frame then
            rolling_frame:Hide()
          end
        end )
        :self_centered_anchor()
        :build()

    frame:SetFrameStrata( "DIALOG" )

    return frame
  end

  local function border_color( item_id )
    local _, _, quality = m.api.GetItemInfo( string.format( "item:%s:0:0:0", item_id ) )
    local color = m.api.ITEM_QUALITY_COLORS[ quality ] or { r = 0, g = 0, b = 0, a = 1 }

    local multiplier = 0.5
    local alpha = 0.6

    popup:border_color( color.r * multiplier, color.g * multiplier, color.b * multiplier, alpha )
  end

  local function abort()
    if not popup then return end
    if popup then popup:Hide() end

    if data_for_error then
      roll_controller.award_aborted( data_for_error.item )
    end

    data_for_error = nil
  end

  local function make_content( item, player, rolling_strategy, error )
    local content                 = { { type = "item_link_with_icon", link = item.link, texture = item.texture } }
    local data, current_iteration = roll_tracker.get()

    local winner                  = data and data.status and data.winners and getn( data.winners ) > 0 and
        data.item and data.winners[ 1 ].name == player.name and
        data.item.link == item.link and data.winners[ 1 ]

    local winning_player          = winner or player

    if rolling_strategy == RS.RaidRoll or not rolling_strategy and current_iteration and current_iteration.rolling_strategy == RS.RaidRoll and winner then
      m.map( RollingPopupContent.raid_roll_winners_content( { winning_player } ), function( w ) table.insert( content, w ) end )
    elseif rolling_strategy == RS.InstaRaidRoll or not rolling_strategy and current_iteration and current_iteration.rolling_strategy == RS.InstaRaidRoll and winner then
      for _, w in ipairs( RollingPopupContent.insta_raid_roll_winners_content( { winning_player } ) ) do
        table.insert( content, w )
      end
    else
      m.map(
        RollingPopupContent.roll_winner_content( { winning_player }, winner and (rolling_strategy or current_iteration and current_iteration.rolling_strategy) ),
        function( w ) table.insert( content, w ) end )
    end

    table.insert( content, { type = "text", value = "Would you like to award this item?" } )

    if error then
      local name = c( winning_player.name, winning_player.class )
      local message = error == LAE.FullBags and string.format( "%s%s %s", name, red( possesive_case( winning_player.name ) ), red( "bags are full." ) ) or
          error == LAE.AlreadyOwnsUniqueItem and string.format( "%s %s", name, red( "already owns this unique item." ) ) or
          error == LAE.PlayerNotFound and string.format( "%s %s", name, red( "cannot be found." ) ) or
          error == LAE.CantAssignItemToThatPlayer and string.format( "%s %s.", red( "Can't assign this item to" ), name ) or nil

      if message then
        table.insert( content, { type = "text", value = message, padding = 7 } )
      end
    end

    table.insert( content, {
      type = "button",
      label = "Yes",
      width = 80,
      on_click = function()
        if not winning_player.value then
          local p = master_loot_candidates.find( winning_player.name )
          winning_player.value = p and p.value
        end

        if confirm_award then confirm_award( winning_player, item ) end
      end
    } )

    table.insert( content, {
      type = "button",
      label = "No",
      width = 80,
      on_click = abort
    } )

    return content
  end

  local function show( data, error )
    data_for_error = data

    if not popup then popup = create_popup() end
    popup:clear()

    for _, v in ipairs( make_content( data.item, data.player, data.rolling_strategy, error ) ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "item_link_with_icon" then
          frame:SetItem( v, v.link and m.ItemUtils.get_tooltip_link( v.link ) )
        elseif type == "text" then
          frame:SetText( v.value )
        elseif type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )
          frame:SetFrameLevel( popup:GetFrameLevel() + 1 )
        end

        if type ~= "button" then
          local count = getn( lines )

          if count == 0 then
            local y = -top_padding - (v.padding or 0)
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", popup, "TOP", 0, y )
          else
            local line_anchor = lines[ count ].frame
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", line_anchor, "BOTTOM", 0, v.padding and -v.padding or 0 )
          end
        end
      end, v.padding )
    end

    border_color( data.item.id )

    local point = db.point or center_point
    ---@diagnostic disable-next-line: undefined-global
    local anchor = UIParent
    if point.point == "CENTER" and point.relative_point == "CENTER" then
      popup:SetPoint( point.point, anchor, point.relative_point, point.x, point.y )
    else
      popup:SetPoint( point.point, anchor, point.relative_point, point.x - popup:GetWidth() / 2, point.y + popup:GetHeight() / 2 )
    end

    popup:Show()
  end

  local function hide()
    data_for_error = nil
    if popup then popup:Hide() end
  end

  local function player_already_has_unique_item()
    if data_for_error and popup:IsVisible() then
      show( data_for_error, LAE.AlreadyOwnsUniqueItem )
    end
  end

  local function player_has_full_bags()
    if data_for_error and popup:IsVisible() then
      show( data_for_error, LAE.FullBags )
    end
  end

  local function player_not_found()
    if data_for_error and popup:IsVisible() then
      show( data_for_error, LAE.PlayerNotFound )
    end
  end

  local function cant_assign_item_to_that_player()
    if data_for_error and popup:IsVisible() then
      show( data_for_error, LAE.CantAssignItemToThatPlayer )
    end
  end

  roll_controller.subscribe( "start", hide )
  roll_controller.subscribe( "loot_awarded", hide )
  roll_controller.subscribe( "award_loot", show )
  roll_controller.subscribe( "loot_closed", abort )
  roll_controller.subscribe( "player_already_has_unique_item", player_already_has_unique_item )
  roll_controller.subscribe( "player_has_full_bags", player_has_full_bags )
  roll_controller.subscribe( "player_not_found", player_not_found )
  roll_controller.subscribe( "cant_assign_item_to_that_player", cant_assign_item_to_that_player )

  return {
    show = show,
    hide = hide,
  }
end

m.LootAwardPopup = M
return M
