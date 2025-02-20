RollFor = RollFor or {}
local m = RollFor

if m.LootController then return end

local getn = table.getn
local red, orange, blue, hl = m.colors.red, m.colors.orange, m.colors.blue, m.colors.hl
local item_utils = m.ItemUtils

local M = m.Module.new( "LootController" )

---@alias SelectedItem { item_id: number, comment: string? }

---@param player_info PlayerInfo
---@param loot_facade LootFacade
---@param loot_list LootList
---@param loot_frame LootFrame
---@param roll_controller RollController
---@param softres GroupAwareSoftRes
---@param rolling_logic RollingLogic
---@param chat Chat
function M.new( player_info, loot_facade, loot_list, loot_frame, roll_controller, softres, rolling_logic, chat )
  -- This will store which items were selected, because we'll lost that info when the loot is closed.
  -- Upon loot opening, we'll check it here and reselect if appropriate.
  local item_selection_cache = {}
  local selected_item = nil ---@type SelectedItem?

  local function show()
    M.debug.add( "show" )
    loot_frame.show()
  end

  ---@param item SelectedItem
  local function make_cache_key( item )
    return string.format( "%s|%s", item.item_id, item.comment or "" )
  end

  ---@param entries LootListEntry[]
  ---@param item_id number
  ---@param comment string?
  local function count_selected_items( entries, item_id, comment )
    local result = 0

    for _, entry in ipairs( entries ) do
      if entry.item.id == item_id and entry.comment == comment then
        result = result + 1
      end
    end

    return result
  end

  ---@param item_id number
  ---@param entries LootListEntry[]
  local function find_top_priority_comment( item_id, entries ) -- HR > SR > none
    for _, entry in ipairs( entries ) do
      if entry.item.id == item_id and entry.hard_ressed then
        return entry.comment
      end

      if entry.item.id == item_id and entry.soft_ressed then
        return entry.comment
      end
    end
  end

  ---@param entries LootListEntry[]
  ---@param item DroppedItem
  ---@param hard_ressed boolean?
  ---@param soft_ressed boolean?
  local function select_item( entries, item, hard_ressed, soft_ressed )
    M.debug.add( string.format( "select_item( %s, %s )", item.id, hard_ressed and "hr" or soft_ressed and "sr" or "free roll" ) )
    local c = find_top_priority_comment( item.id, entries )
    local count = count_selected_items( entries, item.id, c )

    selected_item = { item_id = item.id, comment = c }
    local key = make_cache_key( selected_item )
    item_selection_cache[ key ] = selected_item

    roll_controller.preview( item, count )
  end

  ---@param items (DroppedItem|Coin)[]
  local function make_sr_player_map( items )
    local result = {}

    for _, item in ipairs( items ) do
      if item.type ~= "Coin" then
        result[ item.id ] = softres.get( item.id )
      end
    end

    return result
  end

  ---@return RollingPlayer?
  local function pop_first_item_from_a_table( t )
    if getn( t ) == 0 then return nil end

    local result = t[ 1 ]
    table.remove( t, 1 )

    return result
  end

  ---@param sr_players RollingPlayer[]
  local function make_comment_tooltip( sr_players )
    local result = { blue( "Soft-ressed by:" ) }

    if getn( sr_players ) == 1 then
      local player = sr_players[ 1 ]
      table.insert( result, m.colorize_player_by_class( player.name, player.class ) )

      return result
    end

    for _, player in ipairs( sr_players ) do
      local rolls = player.rolls and player.rolls > 1 and hl( string.format( " [%s rolls]", player.rolls ) ) or ""
      table.insert( result, string.format( "%s%s", m.colorize_player_by_class( player.name, player.class ), rolls ) )
    end

    return result
  end

  ---@alias LootListEntry {
  ---  item: DroppedItem|Coin,
  ---  comment: string?,
  ---  comment_tooltip: string?,
  ---  hard_ressed: boolean?,
  ---  soft_ressed: boolean? }

  ---@param item_id number
  ---@param entries LootListEntry[]
  local function is_already_hr( item_id, entries )
    for _, entry in ipairs( entries ) do
      if entry.item.id == item_id and entry.hard_ressed then return true end
    end

    return false
  end

  ---@param items (DroppedItem|Coin)[]
  ---@return LootListEntry[]
  local function get_entries( items )
    local result = {}
    local sr_player_map = make_sr_player_map( items )

    for _, item in ipairs( items ) do
      if item.type == "Coin" then
        table.insert( result, { item = item } )
      elseif softres.is_item_hardressed( item.id ) and not is_already_hr( item.id, result ) then
        table.insert( result, { item = item, comment = red( "HR" ), hard_ressed = true } )
      else
        local sr_players = softres.get( item.id )
        local sr_player_count = getn( sr_players )
        local item_count = loot_list.count( item.id )

        if is_already_hr( item.id, result ) then item_count = item_count - 1 end

        if item_count > 0 then
          if sr_player_count > 0 then
            if sr_player_count > item_count then
              table.insert( result, { item = item, comment = orange( "SR" ), comment_tooltip = make_comment_tooltip( sr_players ), soft_ressed = true } )
            else
              local sr_player = pop_first_item_from_a_table( sr_player_map[ item.id ] )

              if sr_player then
                table.insert( result, { item = item, comment = orange( "SR" ), comment_tooltip = make_comment_tooltip( { sr_player } ), soft_ressed = true } )
              else
                table.insert( result, { item = item } )
              end
            end
          else
            table.insert( result, { item = item } )
          end
        end
      end
    end

    return result
  end

  ---@param item_id number
  ---@param comment string?
  local function should_be_selected( item_id, comment )
    if selected_item and selected_item.item_id == item_id and selected_item.comment == comment then
      return true
    end

    return false
  end

  ---@param entries LootListEntry[]
  local function find_selected_item( entries )
    for _, entry in ipairs( entries ) do
      if entry.item.type ~= "Coin" then
        local key = make_cache_key( { item_id = entry.item.id, comment = entry.comment } )

        if item_selection_cache[ key ] then
          return item_selection_cache[ key ]
        end
      end
    end
  end

  local function update()
    M.debug.add( "update" )

    local items = loot_list.get_items() ---@type (DroppedItem|Coin)[]
    local entries = get_entries( items )

    selected_item = find_selected_item( entries )

    ---@type LootFrameItem[]
    local result = {}

    for index, entry in ipairs( entries ) do
      local item = entry.item
      local is_coin = item.type == "Coin"
      local selected = should_be_selected( item.id, entry.comment )
      local selected_entry = entry -- Fucking lua50 and its broken closures.

      ---@type LootFrameItem
      table.insert( result, {
        index = index,
        texture = item.texture,
        name = is_coin and m.one_line_coin_name( item.amount_text ) or item.name,
        quality = item.quality or 0,
        quantity = item.quantity,
        link = item.link,
        click_fn = function()
          if m.is_ctrl_key_down() then
            m.api.DressUpItemLink( item.link )
            return
          end

          if m.is_shift_key_down() then
            m.link_item_in_chat( item.link )
            return
          end

          if rolling_logic.is_rolling() then
            chat.info( "Cannot select item while rolling is in progress.", m.colors.red )
            return
          end

          if is_coin or selected or not player_info.is_master_looter() then return end
          select_item( entries, selected_entry.item --[[@as DroppedItem]], selected_entry.hard_ressed, selected_entry.soft_ressed ); update()
        end,
        is_selected = selected or false,
        is_enabled = selected or not selected_item or false,
        slot = loot_list.get_slot( is_coin and "Coin" or item.id ),
        tooltip_link = item.tooltip_link,
        comment = entry.comment,
        comment_tooltip = entry.comment_tooltip,
        bind = item_utils.bind_abbrev( item.bind )
      } )
    end

    loot_frame.update( result )
  end

  local function hide()
    M.debug.add( "hide" )
    loot_frame.hide()
  end

  ---@class LootFrameDeselectData
  ---@field item_id number?

  ---@param data LootFrameDeselectData
  local function deselect( data )
    if data.item_id then
      local key = string.format( "^%s", data.item_id )

      for k, _ in pairs( item_selection_cache ) do
        if string.find( k, key ) then item_selection_cache[ k ] = nil end
      end

      update()
      return
    end

    if not selected_item then return end

    M.debug.add( "deselect" )
    local key = make_cache_key( selected_item )
    item_selection_cache[ key ] = nil
    selected_item = nil

    update()
  end

  local function on_loot_opened()
    M.debug.add( "loot_opened" )
    show()
    update()

    if selected_item then
      roll_controller.update( selected_item.item_id )
    end
  end

  local function on_loot_slot_cleared( slot )
    M.debug.add( string.format( "loot_slot_cleared( %s )", slot ) )
    update()
  end

  local function on_loot_closed()
    M.debug.add( "loot_closed" )
    hide()
  end

  ---@param item_id number
  local function clear_selection_cache( item_id )
    for k, v in pairs( item_selection_cache ) do
      if v.item_id == item_id then item_selection_cache[ k ] = nil end
    end
  end

  loot_facade.subscribe( "LootOpened", on_loot_opened )
  loot_facade.subscribe( "LootClosed", on_loot_closed )
  loot_facade.subscribe( "LootSlotCleared", on_loot_slot_cleared )
  roll_controller.subscribe( "LootFrameDeselect", deselect )
  roll_controller.subscribe( "LootFrameClearSelectionCache", clear_selection_cache )
  roll_controller.subscribe( "LootFrameUpdate", update )
end

m.LootController = M
return M
