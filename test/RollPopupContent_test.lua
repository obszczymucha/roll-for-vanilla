package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua;../RollFor/libs/LibStub/?.lua"

local lu = require( "luaunit" )
local tu = require( "test/utils" )
tu.mock_wow_api()
tu.load_libstub()
require( "src/modules" )
local types = require( "src/Types" )
local tracker_mod = require( "src/RollTracker" )
local controller_mod = require( "src/RollController" )
require( "src/SoftResDataTransformer" )
local ml_correlation_data = require( "src/MasterLootCorrelationData" )
local softres_decorator = require( "src/SoftResPresentPlayersDecorator" )
local softres_mod = require( "src/SoftRes" )
local new = require( "src/RollingPopupContent" ).new
local ItemUtils = require( "src/ItemUtils" )
local make_item = ItemUtils.make_item
local item_link = tu.item_link
local sr = tu.soft_res_item
local make_data = tu.create_softres_data

local C = types.PlayerClass
local winner = types.winner
local player = types.player
local RT = types.RollType
local RS = types.RollingStrategy
local tracker = tracker_mod.new()
local controller = controller_mod.new( tracker )

local function p( player_name, player_class )
  return {
    name = player_name,
    class = player_class
  }
end

local function mock_group_roster( ... )
  local players = { ... }

  local function find_player( player_name )
    for _, playa in ipairs( players ) do
      if playa.name == player_name then return playa end
    end
  end

  return {
    find_player = find_player,
    is_player_in_my_group = function( player_name ) return find_player( player_name ) and true or false end
  }
end

local function mock_popup()
  local content
  local is_visible = false

  local function refresh( _, new_content )
    content = new_content
  end

  return {
    refresh = refresh,
    get = function() return content end,
    show = function() is_visible = true end,
    is_visible = function() return is_visible end,
    border_color = function() end
  }
end

local function mock_config( configuration )
  local c = configuration

  return {
    auto_raid_roll = function() return c and c.auto_raid_roll end,
    raid_roll_again = function() return c and c.raid_roll_again end
  }
end

local function new_softres( group_roster, data )
  local raw_softres = softres_mod.new()
  local result = softres_decorator.new( group_roster, raw_softres )
  result.import( data )

  return result
end

local function new_mod( config, finish_early, cancel_roll, raid_roll )
  local popup = mock_popup()
  local noop = function() end
  local mod = new(
    popup,
    controller,
    tracker,
    config or mock_config(),
    finish_early or noop,
    cancel_roll or noop,
    raid_roll or noop,
    ml_correlation_data.new( ItemUtils )
  )

  return popup, mod
end

local function strip_functions( t )
  for _, line in ipairs( t ) do
    for k, v in pairs( line ) do
      if type( v ) == "function" then
        line[ k ] = nil
      end
    end
  end

  return t
end

local function i( name, id )
  local link = item_link( name, id )
  return make_item( id, name, link )
end

local function cleanse( t )
  return tu.map( strip_functions( t ), function( v )
    if (v.type == "text" or v.type == "info") and v.value then
      v.value = tu.decolorize( v.value ) or v.value
    end

    return v
  end )
end

RaidRollPopupContentSpec = {}

function RaidRollPopupContentSpec:should_return_initial_content()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.RaidRoll, item, 1, nil, seconds_left )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",      link = item.link },
      { type = "icon_text", value = "Raid rolling...", padding = 10 },
    } )
end

function RaidRollPopupContentSpec:should_display_the_winner()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = true } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  controller.start( RS.RaidRoll, item, 1, nil, seconds_left )
  controller.finish( player( p1.name, p1.class ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "text",   value = "Psikutas wins the raid-roll.", padding = 7 },
      { type = "button", label = "Close",                        width = 90 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_winner_with_raid_roll_again_button()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = true, raid_roll_again = true } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  controller.start( RS.RaidRoll, item, 1, nil, seconds_left )
  controller.finish( player( p1.name, p1.class ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "text",   value = "Psikutas wins the raid-roll.", padding = 7 },
      { type = "button", label = "Raid roll again",              width = 130 },
      { type = "button", label = "Close",                        width = 90 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_winner_and_auto_raid_roll_info()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = false } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  controller.start( RS.RaidRoll, item, 1, nil, seconds_left )
  controller.finish( player( p1.name, p1.class ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "text",   value = "Psikutas wins the raid-roll.",                     padding = 7 },
      { type = "info",   value = "Use /rf config auto-rr to enable auto raid-roll.", anchor = "RollForRollingFrame" },
      { type = "button", label = "Close",                                            width = 90 }
    } )
end

NormalRollPopupContentSpec = {}

function NormalRollPopupContentSpec:should_return_initial_content()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "text",   value = "Rolling ends in 7 seconds.", padding = 10 },
      { type = "button", label = "Finish early",               width = 100 },
      { type = "button", label = "Cancel",                     width = 100 }
    } )
end

function NormalRollPopupContentSpec:should_return_initial_content_and_auto_raid_roll_message()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = true } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "text",   value = "Rolling ends in 7 seconds.", padding = 10 },
      { type = "text",   value = "Auto raid-roll is enabled." },
      { type = "button", label = "Finish early",               width = 100 },
      { type = "button", label = "Cancel",                     width = 100 }
    } )
end

function NormalRollPopupContentSpec:should_update_rolling_ends_message()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 5 )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "text",   value = "Rolling ends in 5 seconds.", padding = 10 },
      { type = "button", label = "Finish early",               width = 100 },
      { type = "button", label = "Cancel",                     width = 100 }
    } )
end

function NormalRollPopupContentSpec:should_display_cancel_message()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 5 )
  controller.cancel()

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "text",   value = "Rolling has been canceled.", padding = 10 },
      { type = "button", label = "Close",                      width = 90 }
    } )
end

function NormalRollPopupContentSpec:should_update_rolling_ends_message_for_one_second_left()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "text",   value = "Rolling ends in 1 second.", padding = 10 },
      { type = "button", label = "Finish early",              width = 100 },
      { type = "button", label = "Cancel",                    width = 100 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_winner()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 69 )
  controller.finish( winner( p1.name, p1.class, RT.MainSpec, 69 ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   roll_type = RT.MainSpec,                               player_name = p1.name, player_class = p1.class, roll = 69, padding = 10 },
      { type = "text",   value = "Psikutas wins the main-spec roll with a 69.", padding = 10 },
      { type = "button", label = "Raid roll",                                   width = 90 },
      { type = "button", label = "Close",                                       width = 90 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_winner_with_proper_article_for_8()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 8 )
  controller.finish( winner( p1.name, p1.class, RT.MainSpec, 8 ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   roll_type = RT.MainSpec,                               player_name = p1.name, player_class = p1.class, roll = 8, padding = 10 },
      { type = "text",   value = "Psikutas wins the main-spec roll with an 8.", padding = 10 },
      { type = "button", label = "Raid roll",                                   width = 90 },
      { type = "button", label = "Close",                                       width = 90 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_winner_with_proper_article_for_11()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 11 )
  controller.finish( winner( p1.name, p1.class, RT.MainSpec, 11 ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   roll_type = RT.MainSpec,                                player_name = p1.name, player_class = p1.class, roll = 11, padding = 10 },
      { type = "text",   value = "Psikutas wins the main-spec roll with an 11.", padding = 10 },
      { type = "button", label = "Raid roll",                                    width = 90 },
      { type = "button", label = "Close",                                        width = 90 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_winner_with_proper_article_for_18()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 18 )
  controller.finish( winner( p1.name, p1.class, RT.MainSpec, 18 ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   roll_type = RT.MainSpec,                                player_name = p1.name, player_class = p1.class, roll = 18, padding = 10 },
      { type = "text",   value = "Psikutas wins the main-spec roll with an 18.", padding = 10 },
      { type = "button", label = "Raid roll",                                    width = 90 },
      { type = "button", label = "Close",                                        width = 90 }
    } )
end

function NormalRollPopupContentSpec:should_sort_the_rolls()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1, p2, p3 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid ), p( "Ponpon", C.Warlock )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 42 )
  controller.add( p1.name, p1.class, RT.OffSpec, 68 )
  controller.add( p2.name, p2.class, RT.MainSpec, 45 )
  controller.add( p1.name, p1.class, RT.Transmog, 69 )
  controller.add( p3.name, p3.class, RT.Transmog, 69 )
  controller.finish( winner( p2.name, p2.class, RT.MainSpec, 45 ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   roll_type = RT.MainSpec,                                   player_name = p2.name, player_class = p2.class, roll = 45, padding = 10 },
      { type = "roll",   roll_type = RT.MainSpec,                                   player_name = p1.name, player_class = p1.class, roll = 42 },
      { type = "roll",   roll_type = RT.OffSpec,                                    player_name = p1.name, player_class = p1.class, roll = 68 },
      { type = "roll",   roll_type = RT.Transmog,                                   player_name = p3.name, player_class = p3.class, roll = 69 },
      { type = "roll",   roll_type = RT.Transmog,                                   player_name = p1.name, player_class = p1.class, roll = 69 },
      { type = "text",   value = "Obszczymucha wins the main-spec roll with a 45.", padding = 10 },
      { type = "button", label = "Raid roll",                                       width = 90 },
      { type = "button", label = "Close",                                           width = 90 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_off_spec_winner()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.OffSpec, 69 )
  controller.finish( winner( p1.name, p1.class, RT.OffSpec, 69 ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   roll_type = RT.OffSpec,                               player_name = p1.name, player_class = p1.class, roll = 69, padding = 10 },
      { type = "text",   value = "Psikutas wins the off-spec roll with a 69.", padding = 10 },
      { type = "button", label = "Raid roll",                                  width = 90 },
      { type = "button", label = "Close",                                      width = 90 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_transmog_winner()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.Transmog, 69 )
  controller.finish( winner( p1.name, p1.class, RT.Transmog, 69 ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   roll_type = RT.Transmog,                              player_name = p1.name, player_class = p1.class, roll = 69, padding = 10 },
      { type = "text",   value = "Psikutas wins the transmog roll with a 69.", padding = 10 },
      { type = "button", label = "Raid roll",                                  width = 90 },
      { type = "button", label = "Close",                                      width = 90 }
    } )
end

SoftResrollPopupContentSpec = {}

function SoftResrollPopupContentSpec:should_return_initial_softres_content()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left, softressing_players )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   player_name = "Obszczymucha",         player_class = C.Druid,   roll_type = RT.SoftRes, padding = 10 },
      { type = "roll",   player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",   player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Rolling ends in 7 seconds.", padding = 10 },
      { type = "button", label = "Finish early",               width = 100 },
      { type = "button", label = "Cancel",                     width = 100 }
    } )
end

function SoftResrollPopupContentSpec:should_update_rolling_ends_message()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left, softressing_players )
  controller.tick( 5 )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   player_name = "Obszczymucha",         player_class = C.Druid,   roll_type = RT.SoftRes, padding = 10 },
      { type = "roll",   player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",   player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Rolling ends in 5 seconds.", padding = 10 },
      { type = "button", label = "Finish early",               width = 100 },
      { type = "button", label = "Cancel",                     width = 100 }
    } )
end

function SoftResrollPopupContentSpec:should_update_rolling_ends_message_for_one_second_left()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left, softressing_players )
  controller.tick( 1 )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   player_name = "Obszczymucha",        player_class = C.Druid,   roll_type = RT.SoftRes, padding = 10 },
      { type = "roll",   player_name = "Psikutas",            player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",   player_name = "Psikutas",            player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Rolling ends in 1 second.", padding = 10 },
      { type = "button", label = "Finish early",              width = 100 },
      { type = "button", label = "Cancel",                    width = 100 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_winner()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.finish( winner( "Psikutas", C.Warrior, RT.SoftRes, 69 ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   player_name = "Obszczymucha",                         player_class = C.Druid,   roll_type = RT.SoftRes, padding = 10 },
      { type = "roll",   player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",   player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Psikutas wins the soft-res roll with a 69.", padding = 10 },
      { type = "button", label = "Close",                                      width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_say_nobody_rolled()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   player_name = "Obszczymucha",                   player_class = C.Druid,   roll_type = RT.SoftRes, padding = 10 },
      { type = "roll",   player_name = "Psikutas",                       player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",   player_name = "Psikutas",                       player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Rolling has finished. No one rolled.", padding = 10 },
      { type = "button", label = "Raid roll",                            width = 90 },
      { type = "button", label = "Close",                                width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_only_soft_resser()
  -- Given
  local popup = new_mod()
  local p1 = p( "Psikutas", C.Warrior )
  local group_roster = mock_group_roster( p1 )
  local data = make_data( sr( p1.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.finish( player( "Psikutas", C.Warrior ) )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "text",   value = "Psikutas is the only one soft-ressing.", padding = 10 },
      { type = "button", label = "Close",                                  width = 90 }
    } )
end

-- Note that this test demonstrates inconsistency - we display a roll and we also say that no one rolled.
-- This is fine, we're testing display and not the logic here.
-- The view is dumb, the controller should enforce any constraints.
function SoftResrollPopupContentSpec:should_display_the_rolls()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.SoftRes, 69 )
  controller.add( p2.name, p2.class, RT.SoftRes, 42 )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   player_name = "Psikutas",                       player_class = C.Warrior, roll_type = RT.SoftRes, roll = 69, padding = 10 },
      { type = "roll",   player_name = "Obszczymucha",                   player_class = C.Druid,   roll_type = RT.SoftRes, roll = 42 },
      { type = "roll",   player_name = "Psikutas",                       player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Rolling has finished. No one rolled.", padding = 10 },
      { type = "button", label = "Raid roll",                            width = 90 },
      { type = "button", label = "Close",                                width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_say_waiting_for_remaining_rolls()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.waiting_for_rolls()

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   player_name = "Obszczymucha",             player_class = C.Druid,   roll_type = RT.SoftRes, padding = 10 },
      { type = "roll",   player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",   player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",   value = "Waiting for remaining rolls...", padding = 10 },
      { type = "button", label = "Finish early",                   width = 100 },
      { type = "button", label = "Cancel",                         width = 100 }
    } )
end

TieRollPopupContentSpec = {}

function TieRollPopupContentSpec:should_display_tied_rolls()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.add( p1.name, p1.class, RT.MainSpec, 69 )
  controller.tick( 1 )
  controller.add( p2.name, p2.class, RT.MainSpec, 69 )
  controller.tie( { p1, p2 }, RT.MainSpec, 69 )

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item", link = item.link },
      { type = "roll", player_name = "Obszczymucha",    player_class = C.Druid,   roll_type = RT.MainSpec, roll = 69,   padding = 10 },
      { type = "roll", player_name = "Psikutas",        player_class = C.Warrior, roll_type = RT.MainSpec, roll = 69 },
      { type = "text", value = "There was a tie (69):", padding = 10 },
      { type = "roll", player_name = "Obszczymucha",    player_class = C.Druid,   roll_type = RT.MainSpec, padding = 10 },
      { type = "roll", player_name = "Psikutas",        player_class = C.Warrior, roll_type = RT.MainSpec }
    } )
end

function TieRollPopupContentSpec:should_display_tied_rolls_with_waiting_message()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.add( p1.name, p1.class, RT.MainSpec, 69 )
  controller.tick( 1 )
  controller.add( p2.name, p2.class, RT.MainSpec, 69 )
  controller.tie( { p1, p2 }, RT.MainSpec, 69 )
  controller.tie_start()

  -- When
  local result = popup.get()

  -- Then
  lu.assertEquals( cleanse( result ),
    {
      { type = "item",   link = item.link },
      { type = "roll",   player_name = "Obszczymucha",             player_class = C.Druid,   roll_type = RT.MainSpec, roll = 69,   padding = 10 },
      { type = "roll",   player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.MainSpec, roll = 69 },
      { type = "text",   value = "There was a tie (69):",          padding = 10 },
      { type = "roll",   player_name = "Obszczymucha",             player_class = C.Druid,   roll_type = RT.MainSpec, padding = 10 },
      { type = "roll",   player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.MainSpec },
      { type = "text",   value = "Waiting for remaining rolls...", padding = 10 },
      { type = "button", label = "Finish early",                   width = 100 },
      { type = "button", label = "Cancel",                         width = 100 }
    } )
end

os.exit( lu.LuaUnit.run() )
