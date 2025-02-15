RollFor = RollFor or {}
local m = RollFor

if m.LootAwardPopup then return end

local M = m.Module.new( "LootAwardPopup" )

local RS = m.Types.RollingStrategy
local RT = m.Types.RollType
local LAE = m.Types.LootAwardError
local red = m.colors.red
local blue = m.colors.blue
local c = m.colorize_player_by_class
local r = m.roll_type_color
local possesive_case = m.possesive_case
local article = m.article

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

---@class LootAwardPopup
---@field show fun( data: MasterLootConfirmationData )
---@field hide fun()

---@param popup_builder table
---@param db table
---@param center_point table
function M.new( popup_builder, db, center_point )
  local popup
  local top_padding = 14
  local on_hide ---@type fun()?

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
        :on_hide( function()
          if on_hide then
            on_hide()
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

  ---@param content table
  ---@param winners Winner[]
  ---@param receiver ItemCandidate
  ---@diagnostic disable-next-line: unused-local
  local function add_raid_roll_winners( content, winners, receiver ) -- TODO: To fix the popup display.
    for i, winner in ipairs( winners ) do
      local padding = i > 1 and 2 or 8
      local player = c( winner.name, winner.class )
      table.insert( content, { type = "text", value = string.format( "%s wins the %s.", player, blue( "raid-roll" ) ), padding = padding } )
    end
  end

  ---@param winner Winner
  ---@param padding number?
  local function sr_content( winner, padding )
    M.debug.add( "sr_content" )
    local player = c( winner.name, winner.class )
    local soft_ressed = r( RT.MainSpec, "soft-ressed" )
    return { type = "text", value = string.format( "%s %s this item.", player, soft_ressed ), padding = padding or top_padding }
  end

  ---@param content table
  ---@param winners Winner[]
  ---@param strategy_type RollingStrategyType
  local function add_roll_winners( content, winners, strategy_type )
    local last_award_button_visible = false

    for i, winner in ipairs( winners ) do
      local player = c( winner.name, winner.class )
      local roll_type = winner.roll_type and r( winner.roll_type )
      local roll = winner.winning_roll and blue( winner.winning_roll )
      local padding = last_award_button_visible and 8 or i == 1 and top_padding or (top_padding - 6)

      if roll then
        table.insert( content,
          { type = "text", value = string.format( "%s wins the %s roll with %s %s.", player, roll_type, article( winner.winning_roll ), roll ), padding = padding } )
      elseif strategy_type == RS.SoftResRoll then
        table.insert( content, sr_content( winner, padding ) )
      else
        table.insert( content, { type = "text", value = string.format( "%s %s win the roll.", player, red( "did not" ) ), padding = padding } )
      end
    end
  end

  ---@param content table
  ---@param data MasterLootConfirmationData
  local function add_winners( content, data )
    if data.strategy_type == RS.InstaRaidRoll or data.strategy_type == RS.RaidRoll then
      add_raid_roll_winners( content, data.winners, data.receiver )
    else
      add_roll_winners( content, data.winners, data.strategy_type )
    end
  end

  ---@param data MasterLootConfirmationData
  local function make_content( data )
    local content = { { type = "item_link_with_icon", link = data.item.link, texture = data.item.texture } }
    local winner_count = #data.winners

    if winner_count > 0 then
      add_winners( content, data )
    end

    local name = c( data.receiver.name, data.receiver.class )
    -- TODO: check if receiver is a winner and add a warning if not.
    table.insert( content, { type = "text", value = string.format( "Award this item to %s?", name ), padding = 6 } )

    if data.error then
      local message = data.error == LAE.FullBags and string.format( "%s%s %s", name, red( possesive_case( data.receiver.name ) ), red( "bags are full." ) ) or
          data.error == LAE.AlreadyOwnsUniqueItem and string.format( "%s %s", name, red( "already owns this unique item." ) ) or
          data.error == LAE.PlayerNotFound and string.format( "%s %s", name, red( "cannot be found." ) ) or
          data.error == LAE.CantAssignItemToThatPlayer and string.format( "%s %s.", red( "Can't assign this item to" ), name ) or nil

      if message then
        table.insert( content, { type = "text", value = message, padding = 7 } )
      end
    end

    table.insert( content, { type = "button", label = "Yes", width = 80, on_click = data.confirm_fn } )
    table.insert( content, {
      type = "button",
      label = "No",
      width = 80,
      on_click = function()
        on_hide = nil
        data.abort_fn()
      end
    } )

    return content
  end

  ---@param data MasterLootConfirmationData
  local function show( data )
    if not popup then popup = create_popup() end
    popup:clear()
    on_hide = data.abort_fn

    for _, v in ipairs( make_content( data ) ) do
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
          local count = #lines

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
    if popup then
      on_hide = nil
      popup:Hide()
    end
  end

  ---@type LootAwardPopup
  return {
    show = show,
    hide = hide
  }
end

m.LootAwardPopup = M
return M
