RollFor = RollFor or {}
local m = RollFor

if m.AwardedLoot then return end

local M = m.Module.new( "AwardedLoot" )

local getn = m.getn
local hl = m.colors.hl
local grey = m.colors.grey
local item_utils = m.ItemUtils ---@type ItemUtils

---@class AwardedLootItemData
---@field item_id ItemId
---@field item_quantity number
---@field link string?

---@param item_id ItemId
---@param item_quantity number?
---@return AwardedLootItemData
function M.awarded_loot_item_data( item_id, item_quantity )
  return {
    item_id = item_id,
    item_quantity = item_quantity or 1
  }
end

---@class AwardedLoot
---@field award fun( player_name: string, item_data: AwardedLootItemData, verbose: boolean? )
---@field unaward fun( player_name: string, item_data: AwardedLootItemData, verbose: boolean? )
---@field has_item_been_awarded fun( player_name: string, item_data: AwardedLootItemData ): boolean
---@field has_item_been_awarded_to_any_player fun( item_data: AwardedLootItemData ): boolean
---@field clear fun()

---@param db table
---@param chat Chat
function M.new( db, chat )
  db.awarded_items = db.awarded_items or {}

  ---@param player_name string
  ---@param item_data AwardedLootItemData
  ---@param verbose boolean? -- when true, announce the award in the console
  local function award( player_name, item_data, verbose )
    M.debug.add( "award" )
    table.insert( db.awarded_items, { player_name = player_name, item_id = item_data.item_id } )

    if verbose then
      chat.info( string.format( "%s was awarded %s.", hl( player_name ), item_data.link or hl( item_data.item_id ) ) )
    end
  end

  ---@param player_name string
  ---@param item_data AwardedLootItemData
  ---@return boolean
  local function has_item_been_awarded( player_name, item_data )
    local item_id = item_data.item_id
    for _, item in pairs( db.awarded_items ) do
      if item.player_name == player_name and item.item_id == item_id then return true end
    end

    return false
  end

  ---@param item_data AwardedLootItemData
  ---@return boolean
  local function has_item_been_awarded_to_any_player( item_data )
    local item_id = item_data.item_id
    for _, item in pairs( db.awarded_items ) do
      if item.item_id == item_id then return true end
    end

    return false
  end

  local function clear()
    M.debug.add( "clear" )
    m.clear_table( db.awarded_items )
  end

  ---@param player_name string
  ---@param item_data AwardedLootItemData
  ---@param verbose boolean? -- when true, announce the unaward in the console
  local function unaward( player_name, item_data, verbose )
    M.debug.add( "unaward" )
    local item_id = item_data.item_id
    for i = getn( db.awarded_items ), 1, -1 do
      local awarded_item = db.awarded_items[ i ]

      if awarded_item.player_name == player_name and awarded_item.item_id == item_id then
        table.remove( db.awarded_items, i )

        if verbose then
          chat.info( string.format( "%s was unawarded %s.", hl( player_name ), item_data.link or hl( item_data.item_id ) ) )
        end

        return
      end
    end
  end

  ---@param slash string -- the slash command, e.g. "/award"
  ---@param action fun( player_name: string, item_data: AwardedLootItemData, verbose: boolean? )
  local function make_command( slash, action )
    local function show_usage()
      chat.info( string.format( "Usage: %s <%s> <%s>", hl( slash ), grey( "player" ), grey( "item_link" ) ) )
    end

    ---@param args string
    return function( args )
      if not args or args == "" then
        show_usage()
        return
      end

      for player_name, item_links in string.gmatch( args, "(%S+)%s+(.+)" ) do
        local items = item_utils.parse_items( item_links )

        if getn( items ) == 0 then
          show_usage()
          return
        end

        for _, parsed in ipairs( items ) do
          action( player_name, { item_id = parsed.id, item_quantity = 1, link = parsed.link }, true )
        end

        return
      end

      show_usage()
    end
  end

  m.slash_cmd( "award", make_command( "/award", award ) )
  m.slash_cmd( "unaward", make_command( "/unaward", unaward ) )

  ---@type AwardedLoot
  return {
    award = award,
    unaward = unaward,
    has_item_been_awarded = has_item_been_awarded,
    has_item_been_awarded_to_any_player = has_item_been_awarded_to_any_player,
    clear = clear
  }
end

m.AwardedLoot = M
return M
