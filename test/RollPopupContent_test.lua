package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local tu = require( "test/utils" )
local lu, eq = tu.luaunit( "assertEquals" )
tu.mock_wow_api()
require( "src/modules" )
local types = require( "src/Types" )
require( "src/DebugBuffer" )
require( "src/Module" )
local ItemUtils = require( "src/ItemUtils" )
local tracker_mod = require( "src/RollTracker" )
local controller_mod = require( "src/RollController" )
require( "src/Types" )
require( "src/SoftResDataTransformer" )
local softres_decorator = require( "src/SoftResPresentPlayersDecorator" )
local softres_mod = require( "src/SoftRes" )
local loot_list_mod = require( "mocks/LootList" )
local db_mod = require( "src/Db" )
local rolling_popup_mod = require( "src/RollingPopup" )
local master_looter_mock = require( "mocks/MasterLooter" )
local new = require( "src/RollingPopupContent" ).new
local make_dropped_item = ItemUtils.make_dropped_item
local make_softres_dropped_item = ItemUtils.make_softres_dropped_item
local make_hardres_dropped_item = ItemUtils.make_hardres_dropped_item
local get_tooltip_link = ItemUtils.get_tooltip_link
local item_link = tu.item_link
local sr = tu.soft_res_item
local make_data = tu.create_softres_data

local C = types.PlayerClass
local winner = types.make_winner
local RT = types.RollType
local RS = types.RollingStrategy
local tracker = tracker_mod.new()
local controller = controller_mod.new( tracker, master_looter_mock.new( true ) )
local loot_list = loot_list_mod.new()

local getn = table.getn

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

local function mock_config( configuration )
  local c = configuration

  return {
    auto_raid_roll = function() return c and c.auto_raid_roll end,
    raid_roll_again = function() return c and c.raid_roll_again end,
    rolling_popup_lock = function() return c and c.rolling_popup_lock end,
    subscribe = function() end,
    rolling_popup = function() return true end
  }
end

local function mock_popup( config )
  local content


  local popup_builder = require( "mocks/PopupBuilder" )
  local popup = rolling_popup_mod.new( popup_builder.new(), db_mod.new( {} )( "dummy" ), config or mock_config(), controller )
  popup.get = function() return content end

  local old_refresh = popup.refresh
  popup.refresh = function( _, new_content )
    content = new_content
    old_refresh( _, new_content )
  end

  popup.is_visible = function()
    return popup.get_frame():IsVisible()
  end

  return popup
end

local function new_softres( group_roster, data )
  local raw_softres = softres_mod.new()
  local result = softres_decorator.new( group_roster, raw_softres )
  result.import( data )

  return result
end

local function new_mod( config, finish_early, cancel_roll, raid_roll, roll_item, insta_raid_roll, select_player )
  local popup = mock_popup( config )
  local noop = function() end
  local mod = new(
    popup,
    controller,
    tracker,
    loot_list,
    config or mock_config(),
    finish_early or noop,
    cancel_roll or noop,
    raid_roll or noop,
    roll_item or noop,
    insta_raid_roll or noop,
    select_player or noop
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

---@param name string
---@param id number
---@param sr_players string[]?
---@param hr boolean?
local function i( name, id, sr_players, hr )
  local link = item_link( name, id )
  local tooltip_link = get_tooltip_link( link )
  local item = make_dropped_item( id, name, link, tooltip_link )

  if hr then
    return make_hardres_dropped_item( item )
  end

  if getn( sr_players or {} ) > 0 then
    return make_softres_dropped_item( item, sr_players or {} )
  end

  return item
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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,          count = 1 },
      { type = "text",                value = "Raid rolling...", padding = 8 },
      { type = "empty_line",          height = 5 },
    } )
end

function RaidRollPopupContentSpec:should_return_initial_content_with_multiple_items_to_roll()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.RaidRoll, item, 2, nil, seconds_left )

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,          count = 2 },
      { type = "text",                value = "Raid rolling...", padding = 8 },
      { type = "empty_line",          height = 5 },
    } )
end

function RaidRollPopupContentSpec:should_display_the_winner()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = true } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.RaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                       count = 1 },
      { type = "text",                value = "Psikutas wins the raid-roll.", padding = 8 },
      { type = "button",              label = "Close",                        width = 70 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_winner_and_the_award_button()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = true } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.RaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, true, RT.MainSpec ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                       count = 1 },
      { type = "text",                value = "Psikutas wins the raid-roll.", padding = 8 },
      { type = "button",              label = "Award winner",                 width = 130 },
      { type = "button",              label = "Close",                        width = 70 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_winner_with_raid_roll_again_button()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = true, raid_roll_again = true } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.RaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                       count = 1 },
      { type = "text",                value = "Psikutas wins the raid-roll.", padding = 8 },
      { type = "button",              label = "Raid roll again",              width = 130 },
      { type = "button",              label = "Close",                        width = 70 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_winner_and_auto_raid_roll_info()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = false } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.RaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                           count = 1 },
      { type = "text",                value = "Psikutas wins the raid-roll.",                     padding = 8 },
      { type = "info",                value = "Use /rf config auto-rr to enable auto raid-roll.", anchor = "RollForRollingFrame" },
      { type = "button",              label = "Close",                                            width = 70 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_winners()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = true } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock )
  local strategy = RS.RaidRoll
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.winners_found( item, 1, {
    winner( p1.name, p1.class, item, true, RT.MainSpec ),
    winner( p2.name, p2.class, item, true, RT.MainSpec )
  }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                        count = 2 },
      { type = "text",                value = "Psikutas wins the raid-roll.",  padding = 8 },
      { type = "award_button",        label = "Award",                         padding = 6, width = 90 },
      { type = "text",                value = "Jogobobek wins the raid-roll.", padding = 8 },
      { type = "award_button",        label = "Award",                         padding = 6, width = 90 },
      { type = "button",              label = "Close",                         width = 70 }
    } )
end

InstaRaidRollPopupContentSpec = {}

function InstaRaidRollPopupContentSpec:should_return_initial_content()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.InstaRaidRoll, item, 1, nil, seconds_left )

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                count = 1 },
      { type = "text",                value = "Insta raid rolling...", padding = 8 },
    } )
end

function InstaRaidRollPopupContentSpec:should_return_initial_content_with_multiple_items_to_roll()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.InstaRaidRoll, item, 2, nil, seconds_left )

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                count = 2 },
      { type = "text",                value = "Insta raid rolling...", padding = 8 },
    } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = true } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.InstaRaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                             count = 1 },
      { type = "text",                value = "Psikutas wins the insta raid-roll.", padding = 8 },
      { type = "button",              label = "Close",                              width = 70 }
    } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner_and_the_award_button()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = true } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.InstaRaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, true, RT.MainSpec ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                             count = 1 },
      { type = "text",                value = "Psikutas wins the insta raid-roll.", padding = 8 },
      { type = "button",              label = "Award winner",                       width = 130 },
      { type = "button",              label = "Close",                              width = 70 }
    } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner_with_raid_roll_again_button()
  -- Given
  local popup = new_mod( mock_config( { auto_raid_roll = true, raid_roll_again = true } ) )
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.InstaRaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                             count = 1 },
      { type = "text",                value = "Psikutas wins the insta raid-roll.", padding = 8 },
      { type = "button",              label = "Raid roll again",                    width = 130 },
      { type = "button",              label = "Close",                              width = 70 }
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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                     count = 1 },
      { type = "text",                value = "Rolling ends in 7 seconds.", padding = 11 },
      { type = "button",              label = "Finish early",               width = 100 },
      { type = "button",              label = "Cancel",                     width = 100 }
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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                     count = 1 },
      { type = "text",                value = "Rolling ends in 7 seconds.", padding = 11 },
      { type = "text",                value = "Auto raid-roll is enabled." },
      { type = "button",              label = "Finish early",               width = 100 },
      { type = "button",              label = "Cancel",                     width = 100 }
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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                     count = 1 },
      { type = "text",                value = "Rolling ends in 5 seconds.", padding = 11 },
      { type = "button",              label = "Finish early",               width = 100 },
      { type = "button",              label = "Cancel",                     width = 100 }
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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                     count = 1 },
      { type = "text",                value = "Rolling has been canceled.", padding = 11 },
      { type = "button",              label = "Close",                      width = 70 }
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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                    count = 1 },
      { type = "text",                value = "Rolling ends in 1 second.", padding = 11 },
      { type = "button",              label = "Finish early",              width = 100 },
      { type = "button",              label = "Cancel",                    width = 100 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_winner()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 69 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec, 69 ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                      count = 1 },
      { type = "roll",                roll_type = RT.MainSpec,                               player_name = p1.name, player_class = p1.class, roll = 69, padding = 11 },
      { type = "text",                value = "Psikutas wins the main-spec roll with a 69.", padding = 11 },
      { type = "button",              label = "Raid roll",                                   width = 90 },
      { type = "button",              label = "Close",                                       width = 70 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_winner_with_proper_article_for_8()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 8 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec, 8 ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                      count = 1 },
      { type = "roll",                roll_type = RT.MainSpec,                               player_name = p1.name, player_class = p1.class, roll = 8, padding = 11 },
      { type = "text",                value = "Psikutas wins the main-spec roll with an 8.", padding = 11 },
      { type = "button",              label = "Raid roll",                                   width = 90 },
      { type = "button",              label = "Close",                                       width = 70 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_winner_with_proper_article_for_11()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 11 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec, 11 ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                       count = 1 },
      { type = "roll",                roll_type = RT.MainSpec,                                player_name = p1.name, player_class = p1.class, roll = 11, padding = 11 },
      { type = "text",                value = "Psikutas wins the main-spec roll with an 11.", padding = 11 },
      { type = "button",              label = "Raid roll",                                    width = 90 },
      { type = "button",              label = "Close",                                        width = 70 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_winner_with_proper_article_for_18()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 18 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec, 18 ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                       count = 1 },
      { type = "roll",                roll_type = RT.MainSpec,                                player_name = p1.name, player_class = p1.class, roll = 18, padding = 11 },
      { type = "text",                value = "Psikutas wins the main-spec roll with an 18.", padding = 11 },
      { type = "button",              label = "Raid roll",                                    width = 90 },
      { type = "button",              label = "Close",                                        width = 70 }
    } )
end

function NormalRollPopupContentSpec:should_sort_the_rolls()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1, p2, p3 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid ), p( "Ponpon", C.Warlock )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 42 )
  controller.add( p1.name, p1.class, RT.OffSpec, 68 )
  controller.add( p2.name, p2.class, RT.MainSpec, 45 )
  controller.add( p1.name, p1.class, RT.Transmog, 69 )
  controller.add( p3.name, p3.class, RT.Transmog, 69 )
  controller.winners_found( item, 1, { winner( p2.name, p2.class, item, false, RT.MainSpec, 45 ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                          count = 1 },
      { type = "roll",                roll_type = RT.MainSpec,                                   player_name = p2.name, player_class = p2.class, roll = 45, padding = 11 },
      { type = "roll",                roll_type = RT.MainSpec,                                   player_name = p1.name, player_class = p1.class, roll = 42 },
      { type = "roll",                roll_type = RT.OffSpec,                                    player_name = p1.name, player_class = p1.class, roll = 68 },
      { type = "roll",                roll_type = RT.Transmog,                                   player_name = p3.name, player_class = p3.class, roll = 69 },
      { type = "roll",                roll_type = RT.Transmog,                                   player_name = p1.name, player_class = p1.class, roll = 69 },
      { type = "text",                value = "Obszczymucha wins the main-spec roll with a 45.", padding = 11 },
      { type = "button",              label = "Raid roll",                                       width = 90 },
      { type = "button",              label = "Close",                                           width = 70 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_off_spec_winner()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.OffSpec, 69 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.OffSpec, 69 ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                     count = 1 },
      { type = "roll",                roll_type = RT.OffSpec,                               player_name = p1.name, player_class = p1.class, roll = 69, padding = 11 },
      { type = "text",                value = "Psikutas wins the off-spec roll with a 69.", padding = 11 },
      { type = "button",              label = "Raid roll",                                  width = 90 },
      { type = "button",              label = "Close",                                      width = 70 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_transmog_winner()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.Transmog, 69 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.Transmog, 69 ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                     count = 1 },
      { type = "roll",                roll_type = RT.Transmog,                              player_name = p1.name, player_class = p1.class, roll = 69, padding = 11 },
      { type = "text",                value = "Psikutas wins the transmog roll with a 69.", padding = 11 },
      { type = "button",              label = "Raid roll",                                  width = 90 },
      { type = "button",              label = "Close",                                      width = 70 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_winners()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Hunter )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.tick( 1 )
  controller.winners_found( item, 1, {
    winner( p1.name, p1.class, item, false, RT.MainSpec, 54 ),
    winner( p2.name, p2.class, item, false, RT.OffSpec, 69 )
  }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                      count = 2 },
      { type = "text",                value = "Psikutas wins the main-spec roll with a 54.", padding = 11 },
      { type = "text",                value = "Jogobobek wins the off-spec roll with a 69.", padding = 5 },
      { type = "button",              label = "Raid roll",                                   width = 90 },
      { type = "button",              label = "Close",                                       width = 70 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_winners_and_the_award_buttons()
  -- Given
  local popup = new_mod()
  local item_id = 123
  local seconds_left = 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Hunter )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.tick( 1 )
  controller.winners_found( item, 1, {
    winner( p1.name, p1.class, item, true, RT.MainSpec, 54 ),
    winner( p2.name, p2.class, item, true, RT.OffSpec, 69 )
  }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                      count = 2 },
      { type = "text",                value = "Psikutas wins the main-spec roll with a 54.", padding = 11 },
      { type = "award_button",        label = "Award",                                       padding = 6, width = 90 },
      { type = "text",                value = "Jogobobek wins the off-spec roll with a 69.", padding = 8 },
      { type = "award_button",        label = "Award",                                       padding = 6, width = 90 },
      { type = "button",              label = "Raid roll",                                   width = 90 },
      { type = "button",              label = "Close",                                       width = 70 }
    } )
end

SoftResrollPopupContentSpec = {}

function SoftResrollPopupContentSpec:should_preview_rolls()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id, softressing_players )
  controller.preview( item, 1 )

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,             count = 1 },
      { type = "roll",                player_name = "Obszczymucha", player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",                player_name = "Psikutas",     player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",                player_name = "Psikutas",     player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "button",              label = "Roll",               width = 70 },
      { type = "button",              label = "Award...",           width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_preview_the_winner()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ) )
  local item_id = 123
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id, softressing_players )
  controller.preview( item, 1 )

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                          count = 1 },
      { type = "text",                value = "Psikutas soft-ressed this item.", padding = 11 },
      { type = "button",              label = "Close",                           width = 70 },
      { type = "button",              label = "Award...",                        width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_preview_the_winners()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p2.name, 123 ) )
  local item_id = 123
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id, softressing_players )
  controller.preview( item, 2 )

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                              count = 2 },
      { type = "text",                value = "Obszczymucha soft-ressed this item.", padding = 11 },
      { type = "text",                value = "Psikutas soft-ressed this item.",     padding = 4 },
      { type = "button",              label = "Close",                               width = 70 },
      { type = "button",              label = "Award...",                            width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_preview_the_winners_with_no_difference_if_one_has_many_rolls()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name ), sr( p2.name, 123 ) )
  local item_id = 123
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id, softressing_players )
  controller.preview( item, 2 )

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                              count = 2 },
      { type = "text",                value = "Obszczymucha soft-ressed this item.", padding = 11 },
      { type = "text",                value = "Psikutas soft-ressed this item.",     padding = 4 },
      { type = "button",              label = "Close",                               width = 70 },
      { type = "button",              label = "Award...",                            width = 90 }
    } )
end

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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                     count = 1 },
      { type = "roll",                player_name = "Obszczymucha",         player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",                player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",                player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",                value = "Rolling ends in 7 seconds.", padding = 11 },
      { type = "button",              label = "Finish early",               width = 100 },
      { type = "button",              label = "Cancel",                     width = 100 }
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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                     count = 1 },
      { type = "roll",                player_name = "Obszczymucha",         player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",                player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",                player_name = "Psikutas",             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",                value = "Rolling ends in 5 seconds.", padding = 11 },
      { type = "button",              label = "Finish early",               width = 100 },
      { type = "button",              label = "Cancel",                     width = 100 }
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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                    count = 1 },
      { type = "roll",                player_name = "Obszczymucha",        player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",                player_name = "Psikutas",            player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",                player_name = "Psikutas",            player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",                value = "Rolling ends in 1 second.", padding = 11 },
      { type = "button",              label = "Finish early",              width = 100 },
      { type = "button",              label = "Cancel",                    width = 100 }
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
  local strategy = RS.SoftResRoll
  controller.start( strategy, item, 1, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.winners_found( item, 1, { winner( "Psikutas", C.Warrior, item, false, RT.SoftRes, 69 ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                     count = 1 },
      { type = "roll",                player_name = "Obszczymucha",                         player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",                player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",                player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",                value = "Psikutas wins the soft-res roll with a 69.", padding = 11 },
      { type = "button",              label = "Close",                                      width = 70 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_winner_and_the_award_button()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  controller.start( strategy, item, 1, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.winners_found( item, 1, { winner( "Psikutas", C.Warrior, item, true, RT.SoftRes, 69 ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                                     count = 1 },
      { type = "roll",                player_name = "Obszczymucha",                         player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",                player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",                player_name = "Psikutas",                             player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",                value = "Psikutas wins the soft-res roll with a 69.", padding = 11 },
      { type = "button",              label = "Award winner",                               width = 130 },
      { type = "button",              label = "Close",                                      width = 70 }
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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                               count = 1 },
      { type = "roll",                player_name = "Obszczymucha",                   player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",                player_name = "Psikutas",                       player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",                player_name = "Psikutas",                       player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",                value = "Rolling has finished. No one rolled.", padding = 11 },
      { type = "button",              label = "Raid roll",                            width = 90 },
      { type = "button",              label = "Close",                                width = 70 }
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
  local strategy = RS.SoftResRoll
  controller.start( strategy, item, 1, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.winners_found( item, 1, { winner( "Psikutas", C.Warrior, item, false, RT.SoftRes ) }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                          count = 1 },
      { type = "text",                value = "Psikutas soft-ressed this item.", padding = 11 },
      { type = "button",              label = "Close",                           width = 70 },
      { type = "button",              label = "Award...",                        width = 90 }
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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                               count = 1 },
      { type = "roll",                player_name = "Psikutas",                       player_class = C.Warrior, roll_type = RT.SoftRes, roll = 69, padding = 11 },
      { type = "roll",                player_name = "Obszczymucha",                   player_class = C.Druid,   roll_type = RT.SoftRes, roll = 42 },
      { type = "roll",                player_name = "Psikutas",                       player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",                value = "Rolling has finished. No one rolled.", padding = 11 },
      { type = "button",              label = "Raid roll",                            width = 90 },
      { type = "button",              label = "Close",                                width = 70 }
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
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                         count = 1 },
      { type = "roll",                player_name = "Obszczymucha",             player_class = C.Druid,   roll_type = RT.SoftRes, padding = 11 },
      { type = "roll",                player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "roll",                player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.SoftRes },
      { type = "text",                value = "Waiting for remaining rolls...", padding = 11 },
      { type = "button",              label = "Finish early",                   width = 100 },
      { type = "button",              label = "Cancel",                         width = 100 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_winners()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  controller.start( strategy, item, 2, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.winners_found( item, 2, {
    winner( "Psikutas", C.Warrior, item, false, RT.SoftRes ),
    winner( "Obszczymucha", C.Druid, item, false, RT.SoftRes )
  }, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                              count = 2 },
      { type = "text",                value = "Psikutas soft-ressed this item.",     padding = 11 },
      { type = "text",                value = "Obszczymucha soft-ressed this item.", padding = 4 },
      { type = "button",              label = "Close",                               width = 70 },
      { type = "button",              label = "Award...",                            width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_winners_and_the_award_buttons()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  local winners = {
    winner( "Psikutas", C.Warrior, item, true, RT.SoftRes ),
    winner( "Obszczymucha", C.Druid, item, true, RT.SoftRes )
  }
  controller.start( strategy, item, 2, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.winners_found( item, 2, winners, strategy )
  controller.finish()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                              count = 2 },
      { type = "text",                value = "Psikutas soft-ressed this item.",     padding = 11 },
      { type = "award_button",        label = "Award",                               padding = 6, width = 90 },
      { type = "text",                value = "Obszczymucha soft-ressed this item.", padding = 8 },
      { type = "award_button",        label = "Award",                               padding = 6, width = 90 },
      { type = "button",              label = "Close",                               width = 70 },
      { type = "button",              label = "Award...",                            width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_properly_hide_and_show_the_popup_with_content_unchanged_after_aborting_the_award()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  local winners = {
    winner( "Psikutas", C.Warrior, item, true, RT.SoftRes ),
    winner( "Obszczymucha", C.Druid, item, true, RT.SoftRes )
  }
  controller.start( strategy, item, 2, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.winners_found( item, 2, winners, strategy )
  controller.finish()
  eq( popup.is_visible(), true )
  controller.show_master_loot_confirmation( winners[ 1 ], item, strategy )
  eq( popup.is_visible(), false )
  controller.award_aborted( item )
  eq( popup.is_visible(), true )

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                              count = 2 },
      { type = "text",                value = "Psikutas soft-ressed this item.",     padding = 11 },
      { type = "award_button",        label = "Award",                               padding = 6, width = 90 },
      { type = "text",                value = "Obszczymucha soft-ressed this item.", padding = 8 },
      { type = "award_button",        label = "Award",                               padding = 6, width = 90 },
      { type = "button",              label = "Close",                               width = 70 },
      { type = "button",              label = "Award...",                            width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_display_the_remaining_winner_after_awarding_one()
  -- Given
  local popup = new_mod()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local seconds_left = 7
  local softressing_players = new_softres( group_roster, data ).get( item_id )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  local winners = {
    winner( "Psikutas", C.Warrior, item, true, RT.SoftRes ),
    winner( "Obszczymucha", C.Druid, item, true, RT.SoftRes )
  }
  controller.start( strategy, item, 2, nil, seconds_left, softressing_players )
  controller.tick( 1 )
  controller.winners_found( item, 2, winners, strategy )
  controller.finish()
  eq( popup.is_visible(), true )
  controller.show_master_loot_confirmation( winners[ 1 ], item, strategy )
  eq( popup.is_visible(), false )
  controller.loot_awarded( "Psikutas", item.id, item.link )
  eq( popup.is_visible(), true )

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                              count = 2 },
      { type = "text",                value = "Psikutas soft-ressed this item.",     padding = 11 },
      { type = "award_button",        label = "Award",                               padding = 6, width = 90 },
      { type = "text",                value = "Obszczymucha soft-ressed this item.", padding = 8 },
      { type = "award_button",        label = "Award",                               padding = 6, width = 90 },
      { type = "button",              label = "Close",                               width = 70 },
      { type = "button",              label = "Award...",                            width = 90 }
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
  controller.tie( { p1, p2 }, item, 1, RT.MainSpec, 69 )

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                count = 1 },
      { type = "roll",                player_name = "Obszczymucha",    player_class = C.Druid,   roll_type = RT.MainSpec, roll = 69,   padding = 11 },
      { type = "roll",                player_name = "Psikutas",        player_class = C.Warrior, roll_type = RT.MainSpec, roll = 69 },
      { type = "text",                value = "There was a tie (69):", padding = 11 },
      { type = "roll",                player_name = "Obszczymucha",    player_class = C.Druid,   roll_type = RT.MainSpec, padding = 11 },
      { type = "roll",                player_name = "Psikutas",        player_class = C.Warrior, roll_type = RT.MainSpec }
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
  controller.tie( { p1, p2 }, item, 1, RT.MainSpec, 69 )
  controller.tie_start()

  -- When
  local result = popup.get()

  -- Then
  eq( cleanse( result ),
    {
      { type = "item_link_with_icon", link = item.link,                         count = 1 },
      { type = "roll",                player_name = "Obszczymucha",             player_class = C.Druid,   roll_type = RT.MainSpec, roll = 69,   padding = 11 },
      { type = "roll",                player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.MainSpec, roll = 69 },
      { type = "text",                value = "There was a tie (69):",          padding = 11 },
      { type = "roll",                player_name = "Obszczymucha",             player_class = C.Druid,   roll_type = RT.MainSpec, padding = 11 },
      { type = "roll",                player_name = "Psikutas",                 player_class = C.Warrior, roll_type = RT.MainSpec },
      { type = "text",                value = "Waiting for remaining rolls...", padding = 11 },
      { type = "button",              label = "Finish early",                   width = 100 },
      { type = "button",              label = "Cancel",                         width = 100 }
    } )
end

os.exit( lu.LuaUnit.run() )
