RollFor = RollFor or {}
local m = RollFor

if m.AutoLoot then return end

local item_utils = m.ItemUtils ---@type ItemUtils
local auto_loot_db = m.AutoLootDb
local grey = m.colors.grey

local M = {}

M.interface = {
  on_loot_opened = "function",
  loot_item = "function"
}

local button_visible = false

---@class AutoLoot
---@field is_auto_looted fun( item: DroppedItem ): boolean
---@field is_on_predefined_list fun( item: DroppedItem ): boolean
---@field on_loot_opened fun()
---@field loot_item fun( slot: number )

---@param loot_list LootList
---@param api function
---@param autoloot_db table the persisted autoloot_db backing the auto-loot GUI's predefined list
--- (see AutoLootDb.ensure_seeded). The GUI owns every write to it; this module only ever reads.
---@param config Config
---@param player_info PlayerInfo
---@param chat Chat
function M.new( loot_list, api, autoloot_db, config, player_info, chat )
  local info = chat.info

  local frame

  local function find_my_candidate_index( slot )
    for i = 1, 40 do
      if m.vanilla then
        local name = m.api.GetMasterLootCandidate( i )

        if name == api().UnitName( "player" ) then
          return i
        end
      else
        local name = m.api.GetMasterLootCandidate( slot, i )

        if name == api().UnitName( "player" ) then
          return i
        end
      end
    end
  end

  -- Items the player ticked in the auto-loot GUI (/rf autoloot). A deliberate choice, so they're
  -- auto-looted regardless of quality or bind type, and they stay announced even when auto-loot
  -- announcements are otherwise off (see DroppedLootAnnounce).
  local function is_on_predefined_list( item )
    return auto_loot_db.is_enabled( autoloot_db, item.id )
  end

  local function is_auto_looted( item )
    if not config.auto_loot() then
      return false
    end

    if is_on_predefined_list( item ) then
      return true
    end

    if item.bind == item_utils.BindType.BindOnPickup or item.bind == item_utils.BindType.Quest then
      return false
    end

    return (item.quality or 0) < api().GetLootThreshold()
  end

  local function on_auto_loot()
    if not player_info.is_master_looter() or not config.auto_loot() then
      return
    end

    -- Iterate by slot so duplicates of the same item id stay distinguishable;
    -- get_slot() would collapse them onto the first matching slot and we'd only
    -- ever loot one of them.
    for slot, item in pairs( loot_list.get_items_by_slot() ) do
      -- Looting coins is hidden under a secure button and cannot be done
      -- through vanilla API. If the user has the SuperWoW mod, we can call an
      -- extra function instead.
      if config.superwow_auto_loot_coins() and api().SUPERWOW_VERSION and item.type == item_utils.LootType.Coin then
        api().LootSlot( slot, 1 )

        local coin = item --[[@as Coin]]
        local amount = string.gsub( string.gsub( coin.amount_text, "\n", " " ), " $", "" )

        if config.auto_loot_messages() then
          info( string.format( "Auto-looting %s.", grey( amount ) ) )
        end
      end

      if item.id then
        if is_auto_looted( item ) then
          local index = find_my_candidate_index( slot )

          if index then
            api().GiveMasterLoot( slot, index )

            if config.auto_loot_messages() then
              info( string.format( "Auto-looting %s.", item.link ) )
            end
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

  local function has_auto_loot_items()
    return auto_loot_db.has_enabled_items( autoloot_db )
  end

  local function on_loot_opened()
    if button_visible then
      if not frame then create_frame() end

      if has_auto_loot_items() then
        frame:Show()
      else
        frame:Hide()
      end
    end

    if not m.is_shift_key_down() then on_auto_loot() end
  end

  local function loot_item( slot )
    local index = find_my_candidate_index()

    if index then
      api().GiveMasterLoot( slot, index )
    end
  end

  ---@type AutoLoot
  return {
    is_auto_looted = is_auto_looted,
    is_on_predefined_list = is_on_predefined_list,
    on_loot_opened = on_loot_opened,
    loot_item = loot_item
  }
end

m.AutoLoot = M
return M
