---@diagnostic disable-next-line: undefined-global
local modules = LibStub( "RollFor-Modules" )
if modules.SoftRes then return end

local M = {}

---@diagnostic disable-next-line: undefined-global
local libStub = LibStub

---@diagnostic disable-next-line: deprecated
local getn = table.getn

--function M:new()
--local o = {}
--setmetatable( o, self )
--self.__index = self

--return o
--end

-- Taragaman the Hungerer all SR by Jogobobek:
-- eyJtZXRhZGF0YSI6eyJpZCI6IjNRUzg1OCIsImluc3RhbmNlIjoxMDEsImluc3RhbmNlcyI6WyJLYXJhemhhbiJdLCJvcmlnaW4iOiJyYWlkcmVzIn0sInNvZnRyZXNlcnZlcyI6W3sibmFtZSI6IkpvZ29ib2JlayIsIml0ZW1zIjpbeyJpZCI6MTQxNDUsInF1YWxpdHkiOjN9LHsiaWQiOjE0MTQ4LCJxdWFsaXR5IjozfSx7ImlkIjoxNDE0OSwicXVhbGl0eSI6M31dfV0sImhhcmRyZXNlcnZlcyI6W119

-- Taragaman the Hungerer all SR by Jogobobek and Guildhamster:
-- eyJtZXRhZGF0YSI6eyJpZCI6Ilg4SEZSSiIsImluc3RhbmNlIjo5NiwiaW5zdGFuY2VzIjpbIk5heHhyYW1hcyJdLCJvcmlnaW4iOiJyYWlkcmVzIn0sInNvZnRyZXNlcnZlcyI6W3sibmFtZSI6IkpvZ29ib2JlayIsIml0ZW1zIjpbeyJpZCI6MTQxNDUsInF1YWxpdHkiOjJ9LHsiaWQiOjE0MTQ4LCJxdWFsaXR5IjoyfSx7ImlkIjoxNDE0OSwicXVhbGl0eSI6Mn1dfSx7Im5hbWUiOiJPYnN6Y3p5bXVjaGEiLCJpdGVtcyI6W3siaWQiOjE0MTQ1LCJxdWFsaXR5IjoyfSx7ImlkIjoxNDE0OCwicXVhbGl0eSI6Mn0seyJpZCI6MTQxNDksInF1YWxpdHkiOjJ9XX1dLCJoYXJkcmVzZXJ2ZXMiOltdfQ==

function M.new( db )
  local softres_items = {}
  local hardres_items = {}
  local item_quality = {}

  local function persist( data )
    if data ~= nil then
      db.import_timestamp = modules.lua.time()
    else
      db.import_timestamp = nil
    end

    db.data = data
  end

  function M.decode( encoded_softres_data )
    if not encoded_softres_data then return nil end

    local data = modules.decode_base64( encoded_softres_data )

    if not data then
      modules.pretty_print( "Couldn't decode softres data!", modules.colors.red )
      return nil
    end

    -- data = libStub( "LibDeflate" ):DecompressZlib( data )
    --
    -- if not data then
    --   modules.pretty_print( "Couldn't decompress softres data!", modules.colors.red )
    --   return nil
    -- end

    local json = libStub( "Json-0.1.2" )
    local success, result = pcall( function() return json.decode( data ) end )
    return success and result
  end

  local function clear( report )
    if modules.count_elements( softres_items ) == 0 and modules.count_elements( hardres_items ) == 0 then return end
    softres_items = {}
    hardres_items = {}
    item_quality = {}
    persist( nil )
    if report then modules.pretty_print( "Cleared soft-res data." ) end
  end

  local function add( item_id, quality, player_name )
    softres_items[ item_id ] = softres_items[ item_id ] or {}
    item_quality[ item_id ] = quality
    local items = softres_items[ item_id ]

    for _, value in pairs( items ) do
      if value.name == player_name then
        value.rolls = value.rolls + 1
        return
      end
    end

    table.insert( items, { name = player_name, rolls = 1 } )
  end

  local function add_hr( item_id, quality )
    hardres_items[ item_id ] = hardres_items[ item_id ] or 1
    item_quality[ item_id ] = quality
  end

  local function get( item_id )
    return softres_items[ item_id ] or {}
  end

  local function is_player_softressing( player_name, item_id )
    if item_id and not softres_items[ item_id ] then return false end

    if item_id then
      for _, player in pairs( softres_items[ item_id ] ) do
        if player.name == player_name then return true end
      end
    else
      for _, players in pairs( softres_items ) do
        for _, player in pairs( players ) do
          if player.name == player_name then return true end
        end
      end
    end

    return false
  end

  local function sort_softres_items()
    for _, players in pairs( softres_items ) do
      table.sort( players, function( left, right ) return left.name < right.name end )
    end
  end

  local function process_softres_items( entries )
    if not entries then return end

    for i = 1, getn( entries ) do
      local entry = entries[ i ]
      local items = entry.items

      for j = 1, getn( items ) do
        local item_id = items[ j ].id
        local quality = items[ j ].quality

        add( item_id, quality, entry.name )
      end
    end

    sort_softres_items()
  end

  local function process_hardres_items( entries )
    if not entries then return end

    for i = 1, getn( entries ) do
      local item_id = entries[ i ].id
      local quality = entries[ i ].quality

      add_hr( item_id, quality )
    end
  end

  local function import( softres_data )
    clear()
    if not softres_data then return end
    process_softres_items( softres_data.softreserves )
    process_hardres_items( softres_data.hardreserves )
  end

  local function get_item_ids()
    local result = {}

    for k, _ in pairs( softres_items ) do
      table.insert( result, k )
    end

    return result
  end

  local function get_hr_item_ids()
    local result = {}

    for k, _ in pairs( hardres_items ) do
      table.insert( result, k )
    end

    return result
  end

  local function is_item_hardressed( item_id )
    return hardres_items[ item_id ] and hardres_items[ item_id ] == 1 or false
  end

  local function dump( o )
    local entries = 0

    if type( o ) == 'table' then
      local s = '{'
      for k, v in pairs( o ) do
        if (entries == 0) then s = s .. " " end
        if type( k ) ~= 'number' then k = '"' .. k .. '"' end
        if (entries > 0) then s = s .. ", " end
        s = s .. '[' .. k .. '] = ' .. dump( v )
        entries = entries + 1
      end

      if (entries > 0) then s = s .. " " end
      return s .. '}'
    else
      return tostring( o )
    end
  end

  local function show()
    print( dump( softres_items ) )
  end

  local function get_all_softres_player_names()
    local softres_player_names = {}

    for _, softres_players in pairs( softres_items ) do
      for _, player in pairs( softres_players ) do
        softres_player_names[ player.name ] = 1
      end
    end

    local result = {}

    for player_name, _ in pairs( softres_player_names ) do
      table.insert( result, player_name )
    end

    return result
  end

  local function get_item_quality( item_id )
    return item_quality[ item_id ]
  end

  return {
    get = get,
    is_player_softressing = is_player_softressing,
    get_item_ids = get_item_ids,
    get_item_quality = get_item_quality,
    get_hr_item_ids = get_hr_item_ids,
    is_item_hardressed = is_item_hardressed,
    show = show,
    get_all_softres_player_names = get_all_softres_player_names,
    import = import,
    clear = clear,
    persist = persist
  }
end

modules.SoftRes = M
return M
