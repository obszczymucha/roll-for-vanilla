RollFor = RollFor or {}
local M = RollFor

---@diagnostic disable-next-line: deprecated
local getn = table.getn

---@class WowApi
---@field GetLootSlotLink fun( slot: number ): string
---@field GetLootSlotInfo fun( slot: number ):
---    string, -- texture
---    number, -- item
---    number, -- quantity
---    number  -- quality

M.api = getfenv()
M.lua = {
  ---@diagnostic disable-next-line: undefined-global
  format = format,
  ---@diagnostic disable-next-line: undefined-global
  time = time,
  strmatch = strmatch,
  ---@diagnostic disable-next-line: undefined-global
  random = random,
  math = math
}

M.colors = {
  highlight = function( text )
    return string.format( "|cffff9f69%s|r", text )
  end,
  blue = function( text )
    return string.format( "|cff209ff9%s|r", text )
  end,
  white = function( text )
    return string.format( "|cffffffff%s|r", text )
  end,
  red = function( text )
    return string.format( "|cffff2f2f%s|r", text )
  end,
  orange = function( text )
    return string.format( "|cffff8f2f%s|r", text )
  end,
  grey = function( text )
    return string.format( "|cff9f9f9f%s|r", text )
  end,
  green = function( text )
    return string.format( "|cff2fff5f%s|r", text )
  end,
  pink = function( text )
    return string.format( "|cffdf8eed%s|r", text )
  end
}

M.msg = {
  disabled = M.colors.red( "disabled" ),
  enabled = M.colors.green( "enabled" ),
  locked = M.colors.red( "locked" ),
  unlocked = M.colors.green( "unlocked" ),
  pfui = "|cff33ffccpf|cffffffffUI"
}

if M.api.RAID_CLASS_COLORS then
  M.api.RAID_CLASS_COLORS.HUNTER.colorStr = "ffabd473"
  M.api.RAID_CLASS_COLORS.WARLOCK.colorStr = "ff8788ee"
  M.api.RAID_CLASS_COLORS.PRIEST.colorStr = "ffffffff"
  M.api.RAID_CLASS_COLORS.PALADIN.colorStr = "fff58cba"
  M.api.RAID_CLASS_COLORS.MAGE.colorStr = "ff3fc7eb"
  M.api.RAID_CLASS_COLORS.ROGUE.colorStr = "fffff569"
  M.api.RAID_CLASS_COLORS.DRUID.colorStr = "ffff7d0a"
  M.api.RAID_CLASS_COLORS.SHAMAN.colorStr = "ff0070de"
  M.api.RAID_CLASS_COLORS.WARRIOR.colorStr = "ffc79c6e"
end

M.colors.softres = M.colors.blue
M.colors.name_matcher = M.colors.blue
M.colors.hl = M.colors.highlight

function M.print( message )
  if not message then return end
  M.api.DEFAULT_CHAT_FRAME:AddMessage( message )
end

function M.pretty_print( message, color_fn, module_name )
  if not message then return end

  local c = color_fn and type( color_fn ) == "function" and color_fn or color_fn and type( color_fn ) == "string" and M.colors[ color_fn ] or M.colors.blue
  local module_str = module_name and string.format( "%s%s%s", c( "[ " ), M.colors.white( module_name ), c( " ]" ) ) or ""
  M.api.DEFAULT_CHAT_FRAME:AddMessage( string.format( "%s%s: %s", c( "RollFor" ), module_str, message ) )
end

function M.print_header( text, color_fn )
  local c = color_fn or M.colors.blue
  M.api.DEFAULT_CHAT_FRAME:AddMessage( c( text ) )
end

function M.info( message )
  M.pretty_print( message )
end

function M.dbg( message )
  M.pretty_print( message, M.colors.grey )
end

function M.count_elements( t, f )
  local result = 0

  for _, v in pairs( t ) do
    if f and f( v ) or not f then
      result = result + 1
    end
  end

  return result
end

function M.clone( t )
  local result = {}

  if not t then return result end

  for k, v in pairs( t ) do
    result[ k ] = v
  end

  return result
end

function M.is_player_master_looter()
  if not M.api.IsInGroup() then return false end

  local loot_method, id = M.api.GetLootMethod()
  if loot_method ~= "master" or not id then return false end
  if id == 0 then return true end

  if M.api.IsInRaid() then
    local name = M.api.GetRaidRosterInfo( id )
    return name == M.my_name()
  end

  return M.api.UnitName( "party" .. id ) == M.my_name()
end

function M.is_master_loot()
  return M.api.GetLootMethod() == "master"
end

function M.is_player_a_leader()
  return M.api.UnitIsPartyLeader( "player" )
end

function M.my_name()
  return M.api.UnitName( "player" )
end

function M.target_name()
  return M.api.UnitName( "target" )
end

function M.target_dead()
  return M.api.UnitIsDead( "target" )
end

function M.get_group_chat_type()
  return M.api.IsInRaid() and "RAID" or "PARTY"
end

function M.decolorize( input )
  return input and string.gsub( input, "|c%x%x%x%x%x%x%x%x([^|]+)|r", "%1" )
end

function M.dump( o )
  if not o then return "nil" end
  if type( o ) ~= 'table' then return tostring( o ) end

  local entries = 0
  local s = "{"

  for k, v in pairs( o ) do
    if (entries == 0) then s = s .. " " end

    local key = type( k ) ~= "number" and '"' .. k .. '"' or k

    if (entries > 0) then s = s .. ", " end

    s = s .. "[" .. key .. "] = " .. M.dump( v )
    entries = entries + 1
  end

  if (entries > 0) then s = s .. " " end
  return s .. "}"
end

function M.fetch_item_link( item_id, quality )
  if not item_id then return end

  local id = tonumber( item_id )
  if not id or id == 0 then return end

  local name, details = M.api.GetItemInfo( tonumber( item_id ) )

  if not name or not details then
    return
  end

  return string.format( "%s|H%s|h[%s]|h|r", M.api.ITEM_QUALITY_COLORS[ quality or 0 ].hex, details, name )
end

function M.set_game_tooltip_with_item_id( item_id )
  M.api.GameTooltip:SetHyperlink( string.format( "item:%s:0:0:0:0:0:0:0", item_id ) )
end

-- TODO: This should split the string into two if the length exceeds 255 so we don't blow up.
-- The function should return a table instead that we could then iterate on.
function M.prettify_table( t, f )
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

function M.filter( t, f, extract_field )
  if not t then return nil end
  if type( f ) ~= "function" then return t end

  local result = {}

  for i = 1, getn( t ) do
    local v = t[ i ]
    local value = type( v ) == "table" and extract_field and v[ extract_field ] or v
    if f( value ) then table.insert( result, v ) end
  end

  return result
end

function M.take( t, n )
  if n == 0 then return {} end

  local result = {}

  for i = 1, getn( t ) do
    if i > n then return result end
    table.insert( result, t[ i ] )
  end

  return result
end

function M.my_raid_rank()
  for i = 1, 40 do
    local name, rank = M.api.GetRaidRosterInfo( i )

    if name and name == M.my_name() then
      return rank
    end
  end

  return 0
end

function M.table_contains_value( t, value, f )
  if not t then return false end

  for _, v in pairs( t ) do
    local val = type( f ) == "function" and f( v ) or v
    if val == value then return true end
  end

  return false
end

function M.find_value_in_table( t, value, f )
  if not t then return false end

  for _, v in pairs( t ) do
    local val = type( f ) == "function" and f( v ) or v
    if val == value then return v end
  end
end

function M.reindex_table( t )
  local result = {}

  for _, v in pairs( t ) do
    table.insert( result, v )
  end

  return result
end

function M.map( t, f, extract_field )
  if type( f ) ~= "function" then return t end

  local result = {}

  for k, v in pairs( t ) do
    local is_table = type( v ) == "table"

    if is_table and extract_field then
      local mapped_result = f( v[ extract_field ] )
      local value = M.clone( v )
      value[ extract_field ] = mapped_result
      result[ k ] = value
    elseif is_table then
      result[ k ] = f( M.clone( v ) )
    else
      result[ k ] = f( v )
    end
  end

  return result
end

function M.negate( f )
  return function( v )
    return not f( v )
  end
end

function M.no_nil( f )
  return function( v )
    return f( v ) or v
  end
end

---@diagnostic disable-next-line: unused-vararg
function M.merge( result, next, p3, p4 )
  if type( result ) ~= "table" then return {} end
  if type( next ) ~= "table" then return result end

  for i = 1, getn( next ) do
    table.insert( result, next[ i ] )
  end

  if p3 then
    return M.merge( result, p3, p4 )
  end

  return result
end

function M.keys( t )
  if type( t ) ~= "table" then return {} end

  local result = {}

  for k, _ in pairs( t ) do
    table.insert( result, k )
  end

  return result
end

function M.find( value, t, extract_field )
  if type( t ) ~= "table" or getn( t ) == 0 then return nil end

  for _, v in pairs( t ) do
    local val = extract_field and v[ extract_field ] or v
    if val == value then return v end
  end

  return nil
end

function M.idempotent_hookscript( frame, event, callback )
  if not frame.RollForHookScript then
    frame.RollForHookScript = frame.HookScript

    frame.HookScript = function( self, _event, f )
      if string.find( _event, "RollForIdempotent", 1, true ) == 1 then
        if not frame[ _event ] then
          local real_event = string.gsub( _event, "RollForIdempotent", "" )
          frame.RollForHookScript( self, real_event, f )
          frame[ _event ] = true
        end
      else
        frame.RollForHookScript( self, _event, f )
      end
    end
  end

  frame:HookScript( "RollForIdempotent" .. event, callback )
end

function M.colorize_item_by_quality( item_name, quality )
  local color = M.api.ITEM_QUALITY_COLORS[ quality ].hex
  return color .. item_name .. M.api.FONT_COLOR_CODE_CLOSE
end

function M.colorize_player_by_class( name, class )
  if not class then return name end
  local color = M.api.RAID_CLASS_COLORS[ string.upper( class ) ].colorStr
  return "|c" .. color .. name .. M.api.FONT_COLOR_CODE_CLOSE
end

local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
----@diagnostic disable-next-line: undefined-field
local mod = math.mod

function M.decode_base64( data )
  if not data then return nil end

  data = string.gsub( data, '[^' .. b .. '=]', '' )
  return string.gsub( string.gsub( data, '.', function( x )
    if (x == '=') then return '' end
    ---@diagnostic disable-next-line: undefined-field
    local r, f = '', (string.find( b, x ) - 1)
    for i = 6, 1, -1 do r = r .. (mod( f, 2 ^ i ) - mod( f, 2 ^ (i - 1) ) > 0 and '1' or '0') end
    return r;
  end ), '%d%d%d?%d?%d?%d?%d?%d?', function( x )
    if (string.len( x ) ~= 8) then return '' end
    local c = 0
    for i = 1, 8 do c = c + (string.sub( x, i, i ) == '1' and 2 ^ (8 - i) or 0) end
    return string.char( c )
  end )
end

function M.encode_base64( data )
  return (string.gsub( string.gsub( data, '.', function( x )
    local r, byte = '', string.byte( x )
    for i = 8, 1, -1 do r = r .. (mod( byte, 2 ^ i ) - mod( byte, 2 ^ (i - 1) ) > 0 and '1' or '0') end
    return r;
  end ) .. '0000', '%d%d%d?%d?%d?%d?', function( x )
    if (string.len( x ) < 6) then return '' end
    local c = 0
    for i = 1, 6 do c = c + (string.sub( x, i, i ) == '1' and 2 ^ (6 - i) or 0) end
    return string.sub( b, c + 1, c + 1 )
  end ) .. ({ '', '==', '=' })[ mod( string.len( data ), 3 ) + 1 ])
end

function M.get_addon_version()
  local version = M.api.GetAddOnMetadata( "RollFor", "Version" )
  local major, minor = string.match( version, "(%d+)%.(%d+)" )

  local result = {
    str = version,
    major = tonumber( major ),
    minor = tonumber( minor )
  }

  if not version or not result.major or not result.minor then
    error( "Invalid RollFor addon version!" )
    return
  end

  return result
end

function M.uses_pfui()
  ---@diagnostic disable-next-line: undefined-global
  return pfUI and pfUI.version and true or false
end

function M.clear_table( t )
  for k in pairs( t ) do
    t[ k ] = nil
  end
end

function M.is_shift_key_down()
  return M.api.IsShiftKeyDown()
end

function M.get_all_key_modifiers()
  local alt = M.api.IsAltKeyDown()
  local ctrl = M.api.IsControlKeyDown()
  local shift = M.api.IsShiftKeyDown()

  return alt, ctrl, shift
end

function M.roll_type_color( roll_type, text )
  if roll_type == M.Types.RollType.MainSpec then
    return M.colors.green( text or "main-spec" )
  elseif roll_type == M.Types.RollType.OffSpec then
    return M.colors.grey( text or "off-spec" )
  elseif roll_type == M.Types.RollType.Transmog then
    return M.colors.pink( text or "transmog" )
  elseif roll_type == M.Types.RollType.SoftRes then
    return M.colors.orange( text or "soft-res" )
  else
    return M.colors.white( text or "PrincessKenny" )
  end
end

function M.roll_type_abbrev_chat( roll_type )
  if roll_type == M.Types.RollType.MainSpec then
    return "MS"
  elseif roll_type == M.Types.RollType.OffSpec then
    return "OS"
  elseif roll_type == M.Types.RollType.Transmog then
    return "TMOG"
  elseif roll_type == M.Types.RollType.SoftRes then
    return "SR"
  elseif roll_type == M.Types.RollType.RaidRoll then
    return "RR"
  else
    error( string.format( "RollType %s not handled.", roll_type ) )
  end
end

function M.roll_type_abbrev( roll_type )
  if roll_type == M.Types.RollType.MainSpec then
    return "MS"
  elseif roll_type == M.Types.RollType.OffSpec then
    return "OS"
  elseif roll_type == M.Types.RollType.Transmog then
    return "TM"
  elseif roll_type == M.Types.RollType.SoftRes then
    return "SR"
  elseif roll_type == M.Types.RollType.RaidRoll then
    return "RR"
  else
    error( string.format( "RollType %s not handled.", roll_type ) )
    return M.colors.white( roll_type )
  end
end

function M.possesive_case( player_name )
  local last_letter = string.sub( player_name, -1 )
  return last_letter == "s" and "'" or "'s"
end

function M.is_new_version( mine, theirs )
  local function parse_version( v )
    local parts = {}

    for part in string.gmatch( v, "%d+" ) do
      table.insert( parts, tonumber( part ) )
    end

    return parts
  end

  local my_version = parse_version( mine )
  local their_version = parse_version( theirs )

  for i = 1, math.max( getn( my_version ), getn( their_version ) ) do
    local my_part = my_version[ i ] or 0
    local their_part = their_version[ i ] or 0

    if their_part > my_part then
      return true
    elseif their_part < my_part then
      return false
    end
  end

  return false
end

return M
