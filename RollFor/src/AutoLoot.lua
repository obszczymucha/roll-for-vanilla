---@diagnostic disable-next-line: undefined-global
local modules = LibStub( "RollFor-Modules" )
if modules.AutoLoot then return end

local item_utils = modules.ItemUtils
local info = modules.pretty_print
local hl = modules.colors.hl
local grey = modules.colors.grey
---@diagnostic disable-next-line: deprecated
local getn = table.getn

local M = {}
local button_visible = false
local _G = getfenv( 0 )

function M.new( api, db, config )
  db.items = db.items or {}

  local frame
  local items = db.items

  local function find_my_candidate_index()
    for i = 1, 40 do
      local name = modules.api.GetMasterLootCandidate( i )
      if name == api().UnitName( "player" ) then
        return i
      end
    end
  end

  local function on_auto_loot()
    local item_count = api().GetNumLootItems()
    local zone_name = api().GetRealZoneText()
    local item_ids = items[ zone_name ] or {}
    local threshold = modules.api.GetLootThreshold()

    for slot = 1, item_count do
      local link = modules.api.GetLootSlotLink( slot )
      local _, _, _, quality = modules.api.GetLootSlotInfo( slot )
      if not quality then quality = 0 end

      if link then
        local item_id = item_utils.get_item_id( link )

        if quality < threshold or config.auto_loot() and item_ids[ item_id ] then
          local index = find_my_candidate_index()

          if index then
            api().GiveMasterLoot( slot, index )
          end
        end
      end
    end
  end

  local function create_frame()
    frame = api().CreateFrame( "BUTTON", nil, api().LootFrame, "UIPanelButtonTemplate" )
    frame:SetWidth( 90 )
    frame:SetHeight( 23 )
    frame:SetText( "Auto Loot" )
    frame:SetPoint( "TOPRIGHT", api().LootFrame, "TOPRIGHT", -75, -44 )
    frame:SetScript( "OnClick", on_auto_loot )
    frame:Show()
  end

  local function on_loot_opened()
    if button_visible then
      if not frame then create_frame() end

      local zone_name = api().GetRealZoneText()
      local item_ids = items[ zone_name ]

      if not item_ids or getn( item_ids ) == 0 then
        frame:Hide()
      else
        frame:Show()
      end
    end

    if not modules.is_shift_key_down() then on_auto_loot() end
  end

  local function show_usage()
    info( string.format( "Usage: %s %s", hl( "/rfal <add||remove>" ), grey( "<item_link>" ) ) )
  end

  local function add( item_link )
    local item_id = item_utils.get_item_id( item_link )

    if not item_id then
      show_usage()
      return
    end

    local zone_name = api().GetRealZoneText()

    if not items[ zone_name ] then
      items[ zone_name ] = {}
    end

    items[ zone_name ][ item_id ] = {
      item_name = item_utils.get_item_name( item_link ),
      item_link = item_link
    }

    info( string.format( "%s added.", item_link ), "auto-loot" )
  end

  local function remove( item_link )
    local item_id = item_utils.get_item_id( item_link )

    if not item_id then
      show_usage()
      return
    end

    local zone_name = api().GetRealZoneText()

    if not items[ zone_name ] or not items[ zone_name ][ item_id ] then
      return
    end

    items[ zone_name ][ item_id ] = nil
    info( string.format( "%s removed.", item_link ), "auto-loot" )
  end

  local function clear()
  end

  local function on_command( args )
    for item_link in string.gmatch( args, "add (.*)" ) do
      add( item_link )
      return
    end

    for item_link in string.gmatch( args, "remove (.*)" ) do
      remove( item_link )
      return
    end

    show_usage()
  end

  _G[ "SLASH_RFAL1" ] = "/rfal"
  _G[ "SlashCmdList" ][ "RFAL" ] = on_command

  return {
    on_loot_opened = on_loot_opened,
    add = add,
    remove = remove,
    clear = clear
  }
end

modules.AutoLoot = M
return M
