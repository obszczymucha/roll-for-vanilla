RollFor = RollFor or {}
local m = RollFor

if m.NameManualMatcher then return end

local M = {}

local clone = m.clone
local negate = m.negate
local filter = m.filter
local keys = m.keys
local merge = m.merge
local colors = m.colors
local p = m.pretty_print
local map = m.map

function M.new( db, api, absent_unfiltered_softres, name_matcher, softres_status_changed )
  db.manual_matches = db.manual_matches or {}
  local manual_match_options = nil

  local function show_manual_matches( matches, absent_players )
    if #matches == 0 and #absent_players == 0 then
      p( "There are no players that can be manually matched." )
      return
    end

    local index = 1

    if #matches > 0 then
      p( string.format( "To unmatch, clear your target and type: %s", colors.hl( "/sro <number>" ) ) )

      for i = 1, #matches do
        p( string.format( "[%s]: %s (manually matched with %s)", colors.green( index ), colors.hl( matches[ i ] ), colors.hl( db.manual_matches[ matches[ i ] ] ) ) )
        index = index + 1
      end
    end

    if #absent_players > 0 then
      p( string.format( "To match, target a player and type: %s", colors.hl( "/sro <number>" ) ) )

      for i = 1, #absent_players do
        p( string.format( "[%s]: %s", colors.green( index ), colors.red( absent_players[ i ] ) ) )
        index = index + 1
      end
    end
  end

  local parse_number = function( args )
    for i in string.gmatch( args, "(%d+)" ) do
      return tonumber( i )
    end

    return nil
  end

  local function is_matched( player )
    return db.manual_matches[ player.name ] or name_matcher.is_matched( player.name )
  end

  local function create_matches_and_show()
    local absent_players = map( filter( absent_unfiltered_softres.get_all_rollers(), negate( is_matched ) ), function( v ) return v.name end )
    local manually_matched = keys( db.manual_matches )
    manual_match_options = merge( {}, manually_matched, absent_players )
    show_manual_matches( manually_matched, absent_players )
  end

  local function manual_match( args )
    if not manual_match_options or not args or args == "" then
      create_matches_and_show()
      return
    end

    local count = #manual_match_options
    local target = api().UnitName( "target" )
    local index = parse_number( args )

    if not index or index < 0 or index > count then
      p( "Invalid player number." )
      create_matches_and_show()

      return
    end

    local softres_name = manual_match_options[ index ]
    local already_matched_name = db.manual_matches[ softres_name ]

    if target and already_matched_name then
      p( string.format( "%s is already matched to %s.", colors.hl( softres_name ), colors.hl( already_matched_name ) ) )
      create_matches_and_show()
    elseif target and not already_matched_name then
      manual_match_options = nil
      db.manual_matches[ softres_name ] = target
      p( string.format( "%s is now soft-ressing as %s.", colors.hl( target ), colors.hl( softres_name ) ) )
      softres_status_changed()
    elseif not target and already_matched_name then
      manual_match_options = nil
      db.manual_matches[ softres_name ] = nil
      p( string.format( "Unmatched %s.", colors.hl( softres_name ) ) )
      softres_status_changed()
    else
      p( string.format( "To match a player, target them first." ) )
      create_matches_and_show()
    end
  end

  local function get_matched_name( softres_name )
    return db.manual_matches[ softres_name ] or name_matcher.get_matched_name( softres_name )
  end

  local function get_softres_name( matched_name )
    for softres_name, name in pairs( db.manual_matches ) do
      if name == matched_name then return softres_name end
    end

    return name_matcher.get_softres_name( matched_name )
  end

  local function clear( report )
    if not db.manual_matches or m.count_elements( db.manual_matches ) == 0 then return end
    m.clear_table( db.manual_matches )
    if report then p( "Cleared manual matches." ) end
  end

  local function remove_duplicates( source, duplicates )
    local result = {}

    for _, v in pairs( source ) do
      if not m.find( v.softres_name, duplicates, "softres_name" ) then
        table.insert( result, v )
      end
    end

    return result
  end

  local function get_matches()
    local matches = {}

    for softres_name, match in pairs( db.manual_matches ) do
      table.insert( matches, { softres_name = softres_name, matched_name = match } )
    end

    local auto_matches, auto_not_matches = name_matcher.get_matches()
    return remove_duplicates( auto_matches, matches ), remove_duplicates( remove_duplicates( auto_not_matches, matches ), auto_matches ), matches
  end

  local decorator = clone( name_matcher )
  decorator.manual_match = manual_match
  decorator.is_matched = is_matched
  decorator.get_matched_name = get_matched_name
  decorator.get_softres_name = get_softres_name
  decorator.clear = clear
  decorator.get_matches = get_matches

  return decorator
end

m.NameManualMatcher = M
return M
