RollFor = RollFor or {}
local m = RollFor

if m.AutoLoot then return end

local item_utils = m.ItemUtils ---@type ItemUtils
local hl = m.colors.hl
local grey = m.colors.grey

local M = {}

M.interface = {
  on_loot_opened = "function",
  loot_item = "function"
}

local button_visible = false
local _G = getfenv( 0 ) ---@diagnostic disable-line: deprecated

---@class AutoLoot
---@field is_auto_looted fun( item: DroppedItem ): boolean
---@field on_loot_opened fun()
---@field add fun( category_id: number, item_link: string )
---@field remove fun( item_link: string )
---@field clear fun()
---@field loot_item fun( slot: number )
---@field add_category fun( name: string ): number
---@field remove_category fun( id: number )
---@field enable_category fun( id: number )
---@field disable_category fun( id: number )
---@field list_categories fun()
---@field list fun()

---@class AutoLootItem
---@field name string
---@field link string

---@class AutoLootCategory
---@field name string
---@field enabled boolean
---@field items table< ItemId, AutoLootItem >

---@param loot_list LootList
---@param api function
---@param db table
---@param config Config
---@param player_info PlayerInfo
---@param chat Chat
function M.new( loot_list, api, db, config, player_info, chat )
  ---@type AutoLootCategory[]
  db.categories = db.categories or {}
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

  local function is_auto_looted( item )
    if not config.auto_loot() then
      return false
    end

    local threshold = api().GetLootThreshold()
    local quality = item.quality or 0

    for _, category in ipairs( db.categories ) do
      if category.enabled and category.items[ item.id ] then
        return true
      end
    end

    if item.bind == item_utils.BindType.BindOnPickup or item.bind == item_utils.BindType.Quest then
      return false
    end

    if quality < threshold then
      return true
    end

    return false
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
    for _, category in ipairs( db.categories ) do
      if category.enabled and next( category.items ) then
        return true
      end
    end

    return false
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

  local function show_usage()
    info( string.format( "Usage: %s <%s> <%s>", hl( "/rfal add" ), grey( "category_id" ), grey( "item_links" ) ) )
    info( string.format( "Usage: %s <%s>", hl( "/rfal remove" ), grey( "item_links" ) ) )
    info( string.format( "Usage: %s <%s||%s>", hl( "/rfal" ), hl( "list" ), hl( "list-categories" ) ) )
    info( string.format( "Usage: %s <%s>", hl( "/rfal add-category" ), grey( "category_name" ) ) )
    info( string.format( "Usage: %s <%s||%s||%s> <%s>", hl( "/rfal" ), hl( "remove-category" ), hl( "enable-category" ), hl( "disable-category" ),
      grey( "category_id" ) ) )
    info( string.format( "Usage: %s <%s> <%s>", hl( "/rfal rename-category" ), grey( "category_id" ), grey( "new_name" ) ) )
  end

  ---@param category_id number
  ---@param item_links string
  local function add( category_id, item_links )
    if #db.categories == 0 then
      info( "No categories exist. Add a category first." )
      return
    end

    local category = db.categories[ category_id ]

    if not category then
      info( string.format( "Category with ID %s does not exist.", hl( category_id ) ) )
      return
    end

    local details = item_utils.parse_items( item_links )

    if #details == 0 then
      show_usage()
      return
    end

    for _, i in ipairs( details ) do
      db.categories[ category_id ].items[ i.id ] = {
        name = i.name,
        link = i.link
      }

      info( string.format( "%s added to %s.", i.link, hl( category.name ) ) )
    end
  end

  local function remove( item_links )
    local details = item_utils.parse_items( item_links )

    if #details == 0 then
      show_usage()
      return
    end

    for _, i in ipairs( details ) do
      for _, category in ipairs( db.categories ) do
        if category.items[ i.id ] then category.items[ i.id ] = nil end
      end

      info( string.format( "%s removed.", i.link ) )
    end
  end

  local function clear()
  end

  local function count_items()
    local result = 0
    for _, category in ipairs( db.categories ) do
      result = result + m.count_elements( category.items )
    end

    return result
  end

  local function list()
    local count = count_items()

    if count == 0 then
      info( "No items are set to auto-loot." )
      return
    end

    info( "Auto-looted items:" )

    local i = 1

    for category_id, category in ipairs( db.categories ) do
      if m.count_elements( category.items ) > 0 then
        if i > 1 then print( "" ) end

        local status = category.enabled and m.msg.enabled or m.msg.disabled
        print( string.format( "%s: %s (%s)", hl( category_id ), hl( category.name ), status ) )

        local item_index = 1

        for _, item in pairs( category.items ) do
          print( string.format( "%s: %s", item_index, item.link ) )
          item_index = item_index + 1
        end

        i = i + 1
      end
    end
  end

  local function category_exists( name )
    for _, category in ipairs( db.categories ) do
      if category.name == name then
        return true
      end
    end

    return false
  end

  local function add_category( name )
    if category_exists( name ) then
      info( string.format( "Category %s already exists.", hl( name ) ) )
      return
    end

    local category = {
      name = name,
      enabled = true,
      items = {}
    }

    table.insert( db.categories, category )
    local id = #db.categories

    info( string.format( "Category %s added with ID %s.", hl( name ), hl( id ) ) )

    return id
  end

  ---@param id number
  local function remove_category( id )
    local category = db.categories[ id ]

    if not category then
      info( string.format( "Category with ID %s does not exist.", hl( id ) ) )
      return
    end

    table.remove( db.categories, id )
    info( string.format( "Category %s removed.", hl( category.name ) ) )
  end

  ---@param id number
  local function enable_category( id )
    local category = db.categories[ id ]

    if not category then
      info( string.format( "Category with ID %s does not exist.", hl( id ) ) )
      return
    end

    category.enabled = true
    info( string.format( "Category %s %s.", hl( category.name ), m.msg.enabled ) )
  end

  ---@param id number
  local function disable_category( id )
    local category = db.categories[ id ]
    if not category then
      info( string.format( "Category with ID %s does not exist.", hl( id ) ) )
      return
    end

    category.enabled = false
    info( string.format( "Category %s %s.", hl( category.name ), m.msg.disabled ) )
  end

  ---@param id number
  ---@param name string
  local function rename_category( id, name )
    local category = db.categories[ id ]
    if not category then
      info( string.format( "Category with ID %s does not exist.", hl( id ) ) )
      return
    end

    local old_name = category.name
    category.name = name
    info( string.format( "Renamed %s category to %s.", hl( old_name ), hl( name ) ) )
  end

  local function list_categories()
    if #db.categories == 0 then
      info( "No categories exist." )
      return
    end

    info( "Categories:" )

    for id, category in ipairs( db.categories ) do
      local status = category.enabled and m.msg.enabled or m.msg.disabled
      info( string.format( "%s: %s (%s)", hl( id ), hl( category.name ), hl( status ) ) )
    end
  end

  local function on_command( args )
    if args == "list" then
      list()
      return
    end

    if args == "list-categories" then
      list_categories()
      return
    end

    ---@param category string
    ---@param fn fun(category_id: number, params...)
    local function category_id_fn( category, fn, ... )
      local category_id = tonumber( category )

      if not category_id then
        info( string.format( "Invalid category ID: %s", hl( category ) ) )
        return
      end

      fn( category_id, ... )
    end

    for category, item_links in string.gmatch( args, "add (.-) (.*)" ) do
      category_id_fn( category, add, item_links )
      return
    end

    for item_links in string.gmatch( args, "remove (.*)" ) do
      remove( item_links )
      return
    end

    for category_name in string.gmatch( args, "add%-category (.*)" ) do
      add_category( category_name )
      return
    end

    for category in string.gmatch( args, "remove%-category (.*)" ) do
      category_id_fn( category, remove_category )
      return
    end

    for category in string.gmatch( args, "enable%-category (.*)" ) do
      category_id_fn( category, enable_category )
      return
    end

    for category in string.gmatch( args, "disable%-category (.*)" ) do
      category_id_fn( category, disable_category )
      return
    end

    for category, name in string.gmatch( args, "rename%-category (.-) (.*)" ) do
      category_id_fn( category, rename_category, name )
      return
    end

    show_usage()
  end

  local function loot_item( slot )
    local index = find_my_candidate_index()

    if index then
      api().GiveMasterLoot( slot, index )
    end
  end

  _G[ "SLASH_RFAL1" ] = "/rfal"
  _G[ "SlashCmdList" ][ "RFAL" ] = on_command

  ---@type AutoLoot
  return {
    is_auto_looted = is_auto_looted,
    on_loot_opened = on_loot_opened,
    add = add,
    add_category = add_category,
    remove_category = remove_category,
    enable_category = enable_category,
    disable_category = disable_category,
    rename_category = rename_category,
    list_categories = list_categories,
    remove = remove,
    clear = clear,
    loot_item = loot_item,
    list = list
  }
end

m.AutoLoot = M
return M
