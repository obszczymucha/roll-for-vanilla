RollFor = RollFor or {}
local m = RollFor

if m.DroppedLootAnnounce then return end

local M = {}
local announce_limit = 6
local filter = m.filter

---@diagnostic disable-next-line: deprecated
local getn = table.getn

local function distinct( items )
  local result = {}

  local function exists( item )
    for i = 1, getn( result ) do
      if result[ i ].id == item.id then return true end
    end

    return false
  end

  for i = 1, getn( items ) do
    local item = items[ i ]

    if not exists( item ) then
      table.insert( result, item )
    end
  end

  return result
end

local function commify( t, f )
  local result = ""

  if getn( t ) == 0 then
    return result
  end

  if getn( t ) == 1 then
    return (f and f( t[ 1 ] ) or t[ 1 ])
  end

  for i = 1, getn( t ) - 1 do
    if result ~= "" then
      result = result .. ", "
    end

    result = result .. (f and f( t[ i ] ) or t[ i ])
  end

  result = result .. " and " .. (f and f( t[ getn( t ) ] ) or t[ getn( t ) ])
  return result
end

local function stringify( announcements )
  local result = {}

  local function print_player( show_rolls )
    return function( player )
      local rolls = show_rolls and player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
      local sr_plus = player.sr_plus and string.format( " (+%s)", player.sr_plus ) or ""
      return string.format( "%s%s%s", player.name, rolls, sr_plus )
    end
  end

  for i = 1, getn( announcements ) do
    local entry = announcements[ i ]

    if entry.is_hardressed then
      table.insert( result, {
        text = string.format( "%s. %s (HR)", i, entry.item_link ),
        entry = entry
      } )
    elseif entry.softres_count > 0 then
      local count = entry.how_many_dropped
      local prefix = count == 1 and "" or string.format( "%sx", count )
      local f = print_player( entry.softres_count > 1 )
      table.insert( result, {
        text = string.format( "%s. %s%s (SR by %s)", i, prefix, entry.item_link, commify( entry.softressers, f ) ),
        entry = entry
      } )
    else
      local count = entry.how_many_dropped
      local prefix = count == 1 and "" or string.format( "%sx", count )
      table.insert( result, {
        text = string.format( "%s. %s%s", i, prefix, entry.item_link ),
        entry = entry
      } )
    end
  end

  return result
end

local function sort( announcements )
  local hr = {}
  local sr = {}
  local free_roll = {}

  for _, v in pairs( announcements ) do
    if v.is_hardressed then
      table.insert( hr, v )
    elseif v.softres_count > 0 then
      table.insert( sr, v )
    else
      table.insert( free_roll, v )
    end
  end

  table.sort( free_roll, function( left, right )
    if left.item_quality ~= right.item_quality then
      return left.item_quality > right.item_quality
    else
      return left.item_name < right.item_name
    end
  end )

  table.sort( sr, function( left, right )
    if left.softres_count == 1 and left.softres_count == right.softres_count then
      if left.item_quality == right.item_quality then
        return left.softressers[ 1 ].name < right.softressers[ 1 ].name
      else
        return left.item_quality > right.item_quality
      end
    elseif left.softres_count ~= right.softres_count then
      return left.softres_count < right.softres_count
    else
      if left.item_quality == right.item_quality then
        return left.item_name < right.item_name
      else
        return left.item_quality > right.item_quality
      end
    end
  end )

  return m.merge( {}, hr, sr, free_roll )
end

function M.create_item_announcements( summary )
  local result = {}

  for i = 1, getn( summary ) do
    local entry = summary[ i ]
    local softres_count = getn( entry.softressers )

    if entry.is_hardressed then
      table.insert( result, {
        item_link = entry.item.link,
        item_name = entry.item.name,
        item_quality = entry.item.quality,
        is_hardressed = true,
        softres_count = 0
      } )
    elseif softres_count == 0 then
      table.insert( result, {
        item_link = entry.item.link,
        item_name = entry.item.name,
        item_quality = entry.item.quality,
        softres_count = 0,
        how_many_dropped = entry.how_many_dropped
      } )
    elseif entry.how_many_dropped == softres_count then
      for j = 1, softres_count do
        table.insert( result, {
          item_link = entry.item.link,
          item_name = entry.item.name,
          item_quality = entry.item.quality,
          softres_count = 1,
          how_many_dropped = 1,
          softressers = { entry.softressers[ j ] }
        } )
      end
    else
      table.insert( result, {
        item_link = entry.item.link,
        item_name = entry.item.name,
        item_quality = entry.item.quality,
        softres_count = getn( entry.softressers ),
        how_many_dropped = entry.how_many_dropped,
        softressers = entry.softressers
      } )
    end
  end

  return stringify( sort( result ) )
end

function M.process_dropped_items( loot_list, softres )
  local source_guid = loot_list.get_source_guid()
  local threshold = m.api.GetLootThreshold()
  local items = filter( loot_list.get_items(), function( item )
    local quality = item.quality or 0
    return quality >= threshold and item.id ~= 29434
  end )

  local summary = M.create_item_summary( items, softres )
  return source_guid or "unknown", items, M.create_item_announcements( summary )
end

-- SoftResLootListDecorator?
function M.create_item_summary( items, softres )
  local result = {}
  local distinct_items = distinct( items )

  local function count_items( item_id )
    ---@diagnostic disable-next-line: redefined-local
    local result = 0

    for i = 1, getn( items ) do
      if items[ i ].id == item_id then result = result + 1 end
    end

    return result
  end

  for i = 1, getn( distinct_items ) do
    local item = distinct_items[ i ]
    local item_count = count_items( item.id )
    local softressers = softres.get( item.id )
    local softres_count = getn( softressers )
    table.sort( softressers, function( l, r ) return l.name < r.name end )
    local hardressed = softres.is_item_hardressed( item.id )


    if hardressed then
      table.insert( result, { item = item, how_many_dropped = 1, softressers = {}, is_hardressed = hardressed } )
      item_count = item_count - 1
    end

    if item_count > 0 then
      if item_count > softres_count and softres_count > 0 then
        table.insert( result, { item = item, how_many_dropped = softres_count, softressers = softressers, is_hardressed = false } )
        table.insert( result, { item = item, how_many_dropped = item_count - softres_count, softressers = {}, is_hardressed = false } )
      else
        table.insert( result, { item = item, how_many_dropped = item_count, softressers = softressers, is_hardressed = false } )
      end
    end
  end

  return result
end

local function should_announce( i, item_count, announcement )
  if i < announce_limit then return true end
  if i == announce_limit and item_count == announce_limit then return true end

  if announcement.entry.softres_count and announcement.entry.softres_count > 0 then
    return true
  end

  if i == item_count then return true end

  return false
end

---@class DroppedLootAnnounce
---@field on_loot_opened fun()
---@field reset fun()

---@param loot_list LootList
---@param chat Chat
---@param dropped_loot DroppedLoot
---@param softres GroupAwareSoftRes
---@param winner_tracker WinnerTracker
---@param player_info PlayerInfo
function M.new( loot_list, chat, dropped_loot, softres, winner_tracker, player_info )
  local announcing = false
  local announced_source_ids = {}

  local function on_loot_opened()
    if not player_info.is_master_looter() or announcing then
      -- Wtf is this?
      if m.real_api then
        m.api = m.real_api
        m.real_api = nil
      end

      return
    end

    local source_guid, items, announcements = M.process_dropped_items( loot_list, softres )
    local was_announced = announced_source_ids[ source_guid ]
    if was_announced then return end

    announcing = true
    local item_count = getn( items )

    local target = m.api.UnitName( "target" )
    local target_msg = target and not m.api.UnitIsFriend( "player", "target" ) and string.format( "%s dropped ", target ) or ""

    if item_count > 0 then
      chat.announce(
        string.format( "%s%s item%s%s", target_msg, item_count, item_count > 1 and "s" or "", target_msg == "" and " dropped:" or ":" ) )

      for i = 1, item_count do
        local item = items[ i ]
        dropped_loot.add( item.id, item.name )
      end

      local trimmed = false

      for i, announcement in ipairs( announcements ) do
        if not trimmed and should_announce( i, item_count, announcement ) then
          chat.announce( announcement.text )

          if announcement.entry.softres_count == 1 then
            winner_tracker.track( announcement.entry.softressers[ 1 ].name, announcement.entry.item_link, m.Types.RollType.SoftRes,
              nil, m.Types.RollingStrategy.SoftResRoll )
          end
        elseif not trimmed then
          if i > (announce_limit - 1) and item_count > announce_limit then
            local count = item_count - i + 1
            chat.announce( string.format( "and %s more item%s...", count, count > 1 and "s" or "" ) )
            trimmed = true
          end
        end
      end

      announced_source_ids[ source_guid ] = true
    end

    announcing = false
  end

  local function reset()
    local former_size = m.count_elements( announced_source_ids )
    announced_source_ids = {}

    if former_size > 0 then
      m.pretty_print( "Loot announcement has been reset." )
    end
  end

  ---@type DroppedLootAnnounce
  return {
    on_loot_opened = on_loot_opened,
    reset = reset
  }
end

m.DroppedLootAnnounce = M
return M
