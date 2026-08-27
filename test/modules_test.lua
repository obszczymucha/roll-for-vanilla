package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local lu = require( "luaunit" )
require( "test/utils" ) -- Need to load this before modules to load lua50 stuff.
local mod = require( "src/modules" )
local eq = lu.assertEquals

MapSpec = {}

function MapSpec:should_map_simple_array()
  -- Given
  local map = mod.map
  local f = string.upper

  -- Expect
  eq( map( { "abc", "def" }, f ), { "ABC", "DEF" } )
  eq( map( {}, f ), {} )
end

function MapSpec:should_map_an_array_of_objects()
  -- Given
  local map = mod.map
  local f = string.upper

  -- Expect
  eq( map( {
    { name = "abc", roll = 69 },
    { name = "def", roll = 100 }
  }, f, "name" ), {
    { name = "ABC", roll = 69 },
    { name = "DEF", roll = 100 }
  } )
end

FilterSpec = {}

function FilterSpec:should_filter_simple_array()
  -- Given
  local filter = mod.filter
  local f = function( x ) return x > 3 end

  -- Expect
  eq( filter( { 1, 2, 3, 4, 5, 6 }, f ), { 4, 5, 6 } )
  eq( filter( {}, f ), {} )
end

function FilterSpec:should_filter_an_array_of_objects()
  -- Given
  local filter = mod.filter
  local f = function( x ) return x > 70 end

  -- Expect
  eq( filter( {
    { name = "abc", roll = 69 },
    { name = "def", roll = 100 },
    { name = "ghi", roll = 88 }
  }, f, "roll" ), {
    { name = "def", roll = 100 },
    { name = "ghi", roll = 88 }
  } )
end

MergeSpec = {}

function MergeSpec:should_merge_tables()
  eq( mod.merge( {}, {} ), {} )
  eq( mod.merge( {}, {}, {} ), {} )
  eq( mod.merge( {}, { "a" }, {} ), { "a" } )
  eq( mod.merge( {}, {}, { "a" } ), { "a" } )
  eq( mod.merge( {}, { "a" }, { "b" } ), { "a", "b" } )
  eq( mod.merge( { "a" }, { "b" }, { "c" } ), { "a", "b", "c" } )
end

TakeSpec = {}

function TakeSpec:should_take_n_elements_from_a_table()
  eq( mod.take( { "a", "b", "c" }, 0 ), {} )
  eq( mod.take( { "a", "b", "c" }, 1 ), { "a" } )
  eq( mod.take( { "a", "b", "c" }, 2 ), { "a", "b" } )
  eq( mod.take( { "a", "b", "c" }, 3 ), { "a", "b", "c" } )
  eq( mod.take( { "a", "b", "c" }, 4 ), { "a", "b", "c" } )
  eq( mod.take( { "a", "b", "c" }, -1 ), {} )
end

Base64Spec = {}

function Base64Spec:should_decode_and_encode()
  local encoded = mod.encode_base64( "Princess Kenny" )
  local decoded = mod.decode_base64( encoded )

  eq( decoded, "Princess Kenny" )
end

CoinSpec = {}

function CoinSpec:should_one_line_coin_name()
  eq( mod.one_line_coin_name( nil ), "" )
  eq( mod.one_line_coin_name( "5 gold\n37 silver\n69 copper" ), "5 gold, 37 silver, 69 copper" )
  eq( mod.one_line_coin_name( "37 silver\n69 copper" ), "37 silver, 69 copper" )
  eq( mod.one_line_coin_name( "69 copper" ), "69 copper" )
end

ChunkTextSpec = {}

local getn = mod.getn
local item_link = "|cffa335ee|Hitem:32235:0:0:0:0:0:0:0:70:0:0:0:0:0:0|h[Cursed Vision of Sargeras]|h|r"

-- A string is valid UTF-8 if every continuation byte follows a lead byte that asked for
-- it. Chunking that cuts a multi-byte character in half is what this catches.
local function is_valid_utf8( text )
  local i, length = 1, string.len( text )

  while i <= length do
    local byte = string.byte( text, i )
    local continuations =
        byte < 128 and 0 or
        byte >= 240 and 3 or
        byte >= 224 and 2 or
        byte >= 192 and 1 or
        -1 -- a continuation byte with no lead byte in front of it

    if continuations == -1 then return false end

    for j = 1, continuations do
      local continuation = string.byte( text, i + j )
      if not continuation or continuation < 128 or continuation >= 192 then return false end
    end

    i = i + continuations + 1
  end

  return true
end

function ChunkTextSpec:should_leave_a_message_that_fits_alone()
  eq( mod.chunk_text( "Roll for Thunderfury.", 255 ), { "Roll for Thunderfury." } )
end

function ChunkTextSpec:should_split_on_a_space_rather_than_mid_word()
  eq( mod.chunk_text( "Psikutas Obszczymucha Ponpon", 25 ), { "Psikutas Obszczymucha ...", "... Ponpon" } )
end

function ChunkTextSpec:should_mark_a_broken_line_as_continuing()
  local chunks = mod.chunk_text( string.rep( "Obszczymucha ", 60 ), 255 )

  for i, chunk in ipairs( chunks ) do
    eq( string.sub( chunk, 1, 4 ) == "... ", i > 1 )
    eq( string.sub( chunk, -4 ) == " ...", i < getn( chunks ) )
  end
end

function ChunkTextSpec:should_not_promise_a_continuation_that_never_comes()
  -- An atom wider than the whole limit takes the rest of the text with it, so there is
  -- nothing left to continue into.
  eq( mod.chunk_text( item_link, 10 ), { item_link } )
end

-- A continuation marker is only ever the first or the last thing in a message. One in the
-- middle would read as part of the list rather than as the seam between two messages.
local function markers_are_at_the_edges( chunk )
  local at = 1

  while true do
    local from, to = string.find( chunk, "...", at, true )
    if not from then return true end
    if from ~= 1 and to ~= string.len( chunk ) then return false end
    at = to + 1
  end
end

function ChunkTextSpec:should_never_place_a_marker_away_from_the_edges()
  for _, chunk in ipairs( mod.chunk_text( string.rep( "Obszczymucha ", 60 ), 255 ) ) do
    lu.assertTrue( markers_are_at_the_edges( chunk ) )
  end
end

function ChunkTextSpec:should_keep_every_chunk_within_the_limit()
  for _, chunk in ipairs( mod.chunk_text( string.rep( "Obszczymucha ", 60 ), 255 ) ) do
    lu.assertTrue( string.len( chunk ) <= 255 )
  end
end

function ChunkTextSpec:should_never_cut_an_item_link_in_half()
  local text = string.format( "1. %s and %s and %s dropped.", item_link, item_link, item_link )
  local chunks = mod.chunk_text( text, 255 )

  lu.assertTrue( getn( chunks ) > 1 )

  for _, chunk in ipairs( chunks ) do
    local _, opened = string.gsub( chunk, "|Hitem:", "" )
    local _, closed = string.gsub( chunk, "|h|r", "" )
    eq( opened, closed )
  end
end

function ChunkTextSpec:should_never_cut_a_multibyte_character_in_half()
  local text = "Zo\195\171, \195\133smund, Bj\195\182rn, Ren\195\169e, M\195\188ller, Dvo\197\153\195\161k"

  for _, chunk in ipairs( mod.chunk_text( text, 12 ) ) do
    lu.assertTrue( is_valid_utf8( chunk ) )
  end
end

function ChunkTextSpec:should_lose_nothing_but_the_spaces_it_breaks_on()
  local text = string.rep( "Obszczymucha ", 40 ) .. "Ponpon"

  local stripped = mod.map( mod.chunk_text( text, 100 ), function( chunk )
    chunk = string.gsub( chunk, "^%.%.%. ", "" )
    return (string.gsub( chunk, " %.%.%.$", "" ))
  end )

  eq( table.concat( stripped, " " ), text )
end

SplitMessageSpec = {}

function SplitMessageSpec:should_produce_one_message_when_everything_fits()
  eq( mod.split_message( "SR by ", { "Psikutas", "Ponpon", "Obszczymucha" }, nil, "." ),
    { "SR by Psikutas, Ponpon and Obszczymucha." } )
end

function SplitMessageSpec:should_match_prettify_table_when_everything_fits()
  local players = { "Psikutas", "Ponpon", "Obszczymucha" }

  eq( mod.split_message( "SR by ", players, nil, "." )[ 1 ],
    string.format( "SR by %s.", mod.prettify_table( players ) ) )
end

function SplitMessageSpec:should_format_a_single_element_without_separators()
  eq( mod.split_message( nil, { "Psikutas" }, nil, " soft-ressed it." ), { "Psikutas soft-ressed it." } )
end

function SplitMessageSpec:should_behave_like_prettify_table_on_an_empty_list()
  eq( mod.split_message( "SR rolls remaining: ", {} ), { "SR rolls remaining: " } )
end

function SplitMessageSpec:should_apply_the_transform_to_every_element()
  eq( mod.split_message( nil, { { name = "Psikutas" }, { name = "Ponpon" } }, function( p ) return p.name end ),
    { "Psikutas and Ponpon" } )
end

function SplitMessageSpec:should_charge_the_prefix_and_suffix_against_the_budget()
  for _, message in ipairs( mod.split_message( "SR by ", { "Psikutas", "Ponpon" }, nil, " now.", 20 ) ) do
    lu.assertTrue( string.len( message ) <= 20 )
  end
end

function SplitMessageSpec:should_put_the_prefix_on_the_first_message_only()
  eq( mod.split_message( "SR by ", { "Psikutas", "Ponpon" }, nil, nil, 20 ), { "SR by Psikutas, ...", "...Ponpon" } )
end

function SplitMessageSpec:should_put_the_suffix_on_the_last_message_only()
  eq( mod.split_message( nil, { "Psikutas", "Ponpon" }, nil, " won.", 20 ), { "Psikutas, ...", "...Ponpon won." } )
end

function SplitMessageSpec:should_mark_a_broken_list_as_continuing()
  local players = {}
  for i = 1, 12 do players[ i ] = string.format( "Obszczymucha%s [2 rolls +1 bonus]", i ) end

  local messages = mod.split_message( string.format( "Roll for %s: SR by ", item_link ), players, nil, ". 2 top rolls win." )
  lu.assertTrue( getn( messages ) > 1 )

  for i, message in ipairs( messages ) do
    eq( string.sub( message, 1, 3 ) == "...", i > 1 )
    eq( string.sub( message, -5 ) == ", ...", i < getn( messages ) )
  end
end

function SplitMessageSpec:should_never_place_a_marker_away_from_the_edges()
  for player_count = 1, 30 do
    local players = {}
    for i = 1, player_count do players[ i ] = string.format( "Thundershock%s [2 rolls +2 bonus]", i ) end

    for _, message in ipairs( mod.split_message( string.format( "Roll for %s: SR by ", item_link ), players, nil, ". 2 top rolls win." ) ) do
      lu.assertTrue( markers_are_at_the_edges( message ) )
    end
  end
end

function SplitMessageSpec:should_charge_the_continuation_markers_against_the_budget()
  -- The markers are reserved before packing, not appended after: a splitter that adds
  -- them afterwards overflows by exactly their length on every message it breaks.
  for player_count = 1, 40 do
    local players = {}
    for i = 1, player_count do players[ i ] = string.format( "Thundershock%s [2 rolls +2 bonus]", i ) end

    for _, message in ipairs( mod.split_message( string.format( "Roll for %s: SR by ", item_link ), players, nil, ". 2 top rolls win." ) ) do
      lu.assertTrue( string.len( message ) <= 255 )
    end
  end
end

function SplitMessageSpec:should_break_between_elements_and_never_inside_one()
  local players = {}
  for i = 1, 12 do players[ i ] = string.format( "Obszczymucha%s [2 rolls +1 bonus]", i ) end

  local messages = mod.split_message( string.format( "Roll for %s: SR by ", item_link ), players, nil, ". 2 top rolls win." )
  lu.assertTrue( getn( messages ) > 1 )

  for _, message in ipairs( messages ) do
    lu.assertTrue( string.len( message ) <= 255 )
  end

  -- Every player is named exactly once, and nobody's name arrived in pieces. Matched
  -- plain, because the annotation itself is full of pattern magic characters.
  local all = table.concat( messages, " " )

  for _, player in ipairs( players ) do
    local occurrences, at = 0, 1

    while true do
      local from, to = string.find( all, player, at, true )
      if not from then break end
      occurrences = occurrences + 1
      at = to + 1
    end

    eq( occurrences, 1 )
  end
end

function SplitMessageSpec:should_keep_the_soft_res_roll_call_within_the_chat_limit()
  -- The regression that motivated all of this: bonus roll annotations roughly halved how
  -- many soft-ressers fit on one line.
  for player_count = 1, 40 do
    local players = {}
    for i = 1, player_count do players[ i ] = string.format( "Thundershock%s [2 rolls +2 bonus]", i ) end

    local messages = mod.split_message( string.format( "Roll for %s: SR by ", item_link ), players, nil, "" )

    for _, message in ipairs( messages ) do
      lu.assertTrue( string.len( message ) <= 255 )
    end
  end
end

os.exit( lu.LuaUnit.run() )
