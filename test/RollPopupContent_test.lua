package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local tu = require( "test/utils" )
local lu, eq = tu.luaunit( "assertEquals" )
local api = tu.mock_wow_api()
local m = require( "src/modules" )
local types = require( "src/Types" )
require( "src/DebugBuffer" )
require( "src/Module" )
local ItemUtils = require( "src/ItemUtils" )
require( "src/Types" )
require( "src/SoftResDataTransformer" )
require( "src/RollingLogicUtils" )
require( "src/SoftResRollingLogic" )
require( "src/NonSoftResRollingLogic" )
require( "src/RaidRollRollingLogic" )
require( "src/InstaRaidRollRollingLogic" )
local softres_decorator = require( "src/SoftResPresentPlayersDecorator" )
local softres_mod = require( "src/SoftRes" )
local db_mod = require( "src/Db" )
local rolling_popup_mod = require( "src/RollingPopup" )
local rolling_logic_mod = require( "src/RollingLogic" )
local make_dropped_item = ItemUtils.make_dropped_item
local make_softres_dropped_item = ItemUtils.make_softres_dropped_item
local make_hardres_dropped_item = ItemUtils.make_hardres_dropped_item
local get_tooltip_link = ItemUtils.get_tooltip_link
local item_link = tu.item_link
local sr = tu.soft_res_item
local make_data = tu.create_softres_data

local db = db_mod.new( {} )

local C = types.PlayerClass
local winner = types.make_winner
local RT = types.RollType
local RS = types.RollingStrategy

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
    is_player_in_my_group = function( player_name ) return find_player( player_name ) and true or false end,
    get_all_players_in_my_group = function() return players end
  }
end

---@return Config
local function mock_config( configuration )
  local c = configuration

  return {
    auto_raid_roll = function() return c and c.auto_raid_roll end,
    raid_roll_again = function() return c and c.raid_roll_again end,
    rolling_popup_lock = function() return c and c.rolling_popup_lock end,
    subscribe = function() end,
    rolling_popup = function() return true end,
    ms_roll_threshold = function() return 100 end,
    os_roll_threshold = function() return 99 end,
    tmog_roll_threshold = function() return 98 end,
    tmog_rolling_enabled = function() return true end,
    insta_raid_roll = function() return true end
  }
end

local function mock_popup( config, controller )
  local content

  local popup_builder = require( "mocks/PopupBuilder" )
  local popup = rolling_popup_mod.new( popup_builder.new(), db( "dummy" ), config or mock_config(), controller )
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

---@param group_roster GroupRoster
---@param data table?
---@return GroupedSoftRes
local function softres( group_roster, data )
  local raw_softres = softres_mod.new()
  local result = softres_decorator.new( group_roster, raw_softres )

  if data then
    result.import( data )
  end

  return result
end

local function new( dependencies, raid_roll, roll_item, insta_raid_roll, select_player )
  local deps = dependencies or {}

  local config = deps[ "Config" ] or mock_config()
  deps[ "Config" ] = config

  local player_info = require( "mocks/PlayerInfo" ).new( "PrincessKenny", "Warrior", true, true )
  deps[ "PlayerInfo" ] = player_info

  local chat = require( "mocks/Chat" ).new()
  deps[ "Chat" ] = chat

  local group_roster = deps[ "GroupRoster" ] or mock_group_roster( p( "PrincessKenny", C.Warrior ) )
  deps[ "GroupRoster" ] = group_roster

  local loot_list = require( "mocks/LootList" ).new()
  deps[ "SoftResLootList" ] = loot_list

  local ml_candidates = require( "src/MasterLootCandidates" ).new( group_roster )
  deps[ "MasterLootCandidates" ] = ml_candidates

  local ace_timer = tu.mock_ace_timer()
  deps[ "AceTimer" ] = ace_timer

  local winner_tracker = require( "src/WinnerTracker" ).new( db( "winner_tracker" ) )
  deps[ "WinnerTracker" ] = winner_tracker

  local roll_tracker = require( "src/RollTracker" ).new()
  deps[ "RollTracker" ] = roll_tracker

  local roll_controller = require( "src/RollController" ).new(
    roll_tracker,
    player_info
  )

  local softres_dep = deps[ "SoftRes" ] or softres( group_roster )

  local strategy_factory = require( "src/RollingStrategyFactory" ).new(
    group_roster,
    loot_list,
    ml_candidates,
    chat,
    ace_timer,
    winner_tracker,
    config,
    softres_dep,
    player_info
  )
  deps[ "RollingStrategyFactory" ] = strategy_factory

  local rolling_logic = rolling_logic_mod.new(
    chat,
    ace_timer,
    roll_controller,
    strategy_factory,
    ml_candidates,
    winner_tracker,
    config
  )
  deps[ "RollingLogic" ] = rolling_logic

  local popup = mock_popup( config, roll_controller )
  local noop = function() end

  local rolling_popup_content = require( "src/RollingPopupContent" ).new(
    popup,
    roll_controller,
    roll_tracker,
    loot_list,
    config,
    raid_roll or noop,
    roll_item or noop,
    insta_raid_roll or noop,
    select_player or noop
  )
  deps[ "RollingPopupContent" ] = rolling_popup_content

  if m.RollController.debug.is_enabled() then m.RollController.debug.disable() end
  return popup, roll_controller, deps
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
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.RaidRoll, item, 1, nil, seconds_left )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,          count = 1 },
      { type = "text",                value = "Raid rolling...", padding = 8 },
      { type = "empty_line",          height = 5 },
    } )
end

function RaidRollPopupContentSpec:should_return_initial_content_with_multiple_items_to_roll()
  -- Given
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.RaidRoll, item, 2, nil, seconds_left )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,          count = 2 },
      { type = "text",                value = "Raid rolling...", padding = 8 },
      { type = "empty_line",          height = 5 },
    } )
end

function RaidRollPopupContentSpec:should_display_the_winner()
  -- Given
  local popup, controller = new( { [ "Config" ] = mock_config( { auto_raid_roll = true } ) } )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.RaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                       count = 1 },
      { type = "text",                value = "Psikutas wins the raid-roll.", padding = 8 },
      { type = "button",              label = "Close",                        width = 70 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_winner_and_the_award_button()
  -- Given
  local popup, controller = new( { [ "Config" ] = mock_config( { auto_raid_roll = true } ) } )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.RaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, true, RT.MainSpec ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                       count = 1 },
      { type = "text",                value = "Psikutas wins the raid-roll.", padding = 8 },
      { type = "button",              label = "Award winner",                 width = 130 },
      { type = "button",              label = "Close",                        width = 70 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_winner_with_raid_roll_again_button()
  -- Given
  local popup, controller = new( { [ "Config" ] = mock_config( { auto_raid_roll = true, raid_roll_again = true } ) } )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.RaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                       count = 1 },
      { type = "text",                value = "Psikutas wins the raid-roll.", padding = 8 },
      { type = "button",              label = "Raid roll again",              width = 130 },
      { type = "button",              label = "Close",                        width = 70 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_winner_and_auto_raid_roll_info()
  -- Given
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.RaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                                           count = 1 },
      { type = "text",                value = "Psikutas wins the raid-roll.",                     padding = 8 },
      { type = "info",                value = "Use /rf config auto-rr to enable auto raid-roll.", anchor = "RollForRollingFrame" },
      { type = "button",              label = "Close",                                            width = 70 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_winners()
  -- Given
  local popup, controller = new( { [ "Config" ] = mock_config( { auto_raid_roll = true } ) } )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock )
  local strategy = RS.RaidRoll
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.winners_found( item, 1, {
    winner( p1.name, p1.class, item, false, RT.MainSpec ),
    winner( p2.name, p2.class, item, false, RT.MainSpec )
  }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                        count = 2 },
      { type = "text",                value = "Psikutas wins the raid-roll.",  padding = 8 },
      { type = "text",                value = "Jogobobek wins the raid-roll.", padding = 2 },
      { type = "button",              label = "Close",                         width = 70 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_winners_and_the_award_buttons()
  -- Given
  local popup, controller = new( { [ "Config" ] = mock_config( { auto_raid_roll = true } ) } )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock )
  local strategy = RS.RaidRoll
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.winners_found( item, 1, {
    winner( p1.name, p1.class, item, true, RT.MainSpec ),
    winner( p2.name, p2.class, item, true, RT.MainSpec )
  }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                        count = 2 },
      { type = "text",                value = "Psikutas wins the raid-roll.",  padding = 8 },
      { type = "award_button",        label = "Award",                         padding = 6, width = 90 },
      { type = "text",                value = "Jogobobek wins the raid-roll.", padding = 8 },
      { type = "award_button",        label = "Award",                         padding = 6, width = 90 },
      { type = "button",              label = "Close",                         width = 70 }
    } )
end

function RaidRollPopupContentSpec:should_properly_hide_and_show_the_popup_with_content_unchanged_after_aborting_the_award()
  -- Given
  local popup, controller = new( { [ "Config" ] = mock_config( { auto_raid_roll = true } ) } )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock )
  local strategy = RS.RaidRoll
  local winners = {
    winner( p1.name, p1.class, item, true, RT.MainSpec ),
    winner( p2.name, p2.class, item, true, RT.MainSpec )
  }
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.winners_found( item, 1, winners, strategy )
  controller.finish()
  eq( popup.is_visible(), true )
  controller.show_master_loot_confirmation( winners[ 1 ], item, strategy )
  eq( popup.is_visible(), false )
  controller.award_aborted( item )
  eq( popup.is_visible(), true )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                        count = 2 },
      { type = "text",                value = "Psikutas wins the raid-roll.",  padding = 8 },
      { type = "award_button",        label = "Award",                         padding = 6, width = 90 },
      { type = "text",                value = "Jogobobek wins the raid-roll.", padding = 8 },
      { type = "award_button",        label = "Award",                         padding = 6, width = 90 },
      { type = "button",              label = "Close",                         width = 70 }
    } )
end

function RaidRollPopupContentSpec:should_display_the_remaining_winner_after_awarding_one()
  -- Given
  local popup, controller = new( { [ "Config" ] = mock_config( { auto_raid_roll = true } ) } )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock )
  local strategy = RS.RaidRoll
  local winners = {
    winner( p1.name, p1.class, item, true, RT.MainSpec ),
    winner( p2.name, p2.class, item, true, RT.MainSpec )
  }
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.winners_found( item, 1, winners, strategy )
  controller.finish()
  eq( popup.is_visible(), true )
  controller.show_master_loot_confirmation( winners[ 1 ], item, strategy )
  eq( popup.is_visible(), false )
  controller.loot_awarded( "Jogobobek", item.id, item.link )
  eq( popup.is_visible(), true )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                       count = 1 },
      { type = "text",                value = "Psikutas wins the raid-roll.", padding = 8 },
      { type = "button",              label = "Award winner",                 width = 130 },
      { type = "button",              label = "Close",                        width = 70 }
    } )
end

InstaRaidRollPopupContentSpec = {}

function InstaRaidRollPopupContentSpec:should_return_initial_content()
  -- Given
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.InstaRaidRoll, item, 1, nil, seconds_left )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                count = 1 },
      { type = "text",                value = "Insta raid rolling...", padding = 8 },
    } )
end

function InstaRaidRollPopupContentSpec:should_return_initial_content_with_multiple_items_to_roll()
  -- Given
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.InstaRaidRoll, item, 2, nil, seconds_left )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                count = 2 },
      { type = "text",                value = "Insta raid rolling...", padding = 8 },
    } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner()
  -- Given
  local popup, controller = new( mock_config( { auto_raid_roll = true } ) )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.InstaRaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                             count = 1 },
      { type = "text",                value = "Psikutas wins the insta raid-roll.", padding = 8 },
      { type = "button",              label = "Close",                              width = 70 }
    } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner_and_the_award_button()
  -- Given
  local popup, controller = new( mock_config( { auto_raid_roll = true } ) )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.InstaRaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, true, RT.MainSpec ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                             count = 1 },
      { type = "text",                value = "Psikutas wins the insta raid-roll.", padding = 8 },
      { type = "button",              label = "Award winner",                       width = 130 },
      { type = "button",              label = "Close",                              width = 70 }
    } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winner_with_raid_roll_again_button()
  -- Given
  local popup, controller = new( { [ "Config" ] = mock_config( { auto_raid_roll = true, raid_roll_again = true } ) } )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.InstaRaidRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                             count = 1 },
      { type = "text",                value = "Psikutas wins the insta raid-roll.", padding = 8 },
      { type = "button",              label = "Raid roll again",                    width = 130 },
      { type = "button",              label = "Close",                              width = 70 }
    } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winners()
  -- Given
  local popup, controller = new( mock_config( { auto_raid_roll = true } ) )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock )
  local strategy = RS.InstaRaidRoll
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.winners_found( item, 1, {
    winner( p1.name, p1.class, item, false, RT.MainSpec ),
    winner( p2.name, p2.class, item, false, RT.MainSpec )
  }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                              count = 2 },
      { type = "text",                value = "Psikutas wins the insta raid-roll.",  padding = 8 },
      { type = "text",                value = "Jogobobek wins the insta raid-roll.", padding = 2 },
      { type = "button",              label = "Close",                               width = 70 }
    } )
end

function InstaRaidRollPopupContentSpec:should_display_the_winners_and_the_award_buttons()
  -- Given
  local popup, controller = new( mock_config( { auto_raid_roll = true } ) )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Jogobobek", C.Warlock )
  local strategy = RS.InstaRaidRoll
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.winners_found( item, 1, {
    winner( p1.name, p1.class, item, true, RT.MainSpec ),
    winner( p2.name, p2.class, item, true, RT.MainSpec )
  }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                              count = 2 },
      { type = "text",                value = "Psikutas wins the insta raid-roll.",  padding = 8 },
      { type = "award_button",        label = "Award",                               padding = 6, width = 90 },
      { type = "text",                value = "Jogobobek wins the insta raid-roll.", padding = 8 },
      { type = "award_button",        label = "Award",                               padding = 6, width = 90 },
      { type = "button",              label = "Close",                               width = 70 }
    } )
end

NormalRollPopupContentSpec = {}

function NormalRollPopupContentSpec:should_return_initial_content()
  -- Given
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                     count = 1 },
      { type = "text",                value = "Rolling ends in 7 seconds.", padding = 11 },
      { type = "button",              label = "Finish early",               width = 100 },
      { type = "button",              label = "Cancel",                     width = 100 }
    } )
end

function NormalRollPopupContentSpec:should_return_initial_content_and_auto_raid_roll_message()
  -- Given
  local popup, controller = new( { [ "Config" ] = mock_config( { auto_raid_roll = true } ) } )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 5 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                     count = 1 },
      { type = "text",                value = "Rolling ends in 5 seconds.", padding = 11 },
      { type = "button",              label = "Finish early",               width = 100 },
      { type = "button",              label = "Cancel",                     width = 100 }
    } )
end

function NormalRollPopupContentSpec:should_display_cancel_message()
  -- Given
  local popup, controller = new()
  m.RollController.debug.enable( true )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 5 )
  controller.cancel_rolling()

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                     count = 1 },
      { type = "text",                value = "Rolling has been canceled.", padding = 11 },
      { type = "button",              label = "Close",                      width = 70 }
    } )
end

function NormalRollPopupContentSpec:should_update_rolling_ends_message_for_one_second_left()
  -- Given
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                    count = 1 },
      { type = "text",                value = "Rolling ends in 1 second.", padding = 11 },
      { type = "button",              label = "Finish early",              width = 100 },
      { type = "button",              label = "Cancel",                    width = 100 }
    } )
end

function NormalRollPopupContentSpec:should_display_the_winner()
  -- Given
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 69 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec, 69 ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 8 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec, 8 ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 11 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec, 11 ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.MainSpec, 18 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.MainSpec, 18 ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
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

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.OffSpec, 69 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.OffSpec, 69 ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1 = p( "Psikutas", C.Warrior )
  local strategy = RS.NormalRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.Transmog, 69 )
  controller.winners_found( item, 1, { winner( p1.name, p1.class, item, false, RT.Transmog, 69 ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
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

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
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

  -- Then
  eq( cleanse( popup.get() ),
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

function NormalRollPopupContentSpec:should_auto_raid_roll_when_finishing_early_if_enabled()
  -- Given
  local popup, controller = new( { [ "Config" ] = mock_config( { auto_raid_roll = true } ) } )
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                     count = 1 },
      { type = "text",                value = "Rolling ends in 7 seconds.", padding = 11 },
      { type = "text",                value = "Auto raid-roll is enabled." },
      { type = "button",              label = "Finish early",               width = 100 },
      { type = "button",              label = "Cancel",                     width = 100 }
    } )

  -- Then
  controller.finish_rolling_early()
end

SoftResrollPopupContentSpec = {}

function SoftResrollPopupContentSpec:should_preview_rolls()
  -- Given
  local popup, controller = new()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id = 123
  local softressing_players = softres( group_roster, data )
  local item = i( "Hearthstone", item_id, softressing_players )
  controller.preview( item, 1 )

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ) )
  local item_id = 123
  local softressing_players = softres( group_roster, data )
  local item = i( "Hearthstone", item_id, softressing_players )
  controller.preview( item, 1 )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                          count = 1 },
      { type = "text",                value = "Psikutas soft-ressed this item.", padding = 11 },
      { type = "button",              label = "Close",                           width = 70 },
      { type = "button",              label = "Award...",                        width = 90 }
    } )
end

function SoftResrollPopupContentSpec:should_preview_the_winners()
  -- Given
  local popup, controller = new()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p2.name, 123 ) )
  local item_id = 123
  local softressing_players = softres( group_roster, data )
  local item = i( "Hearthstone", item_id, softressing_players )
  controller.preview( item, 2 )

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name ), sr( p2.name, 123 ) )
  local item_id = 123
  local softressing_players = softres( group_roster, data )
  local item = i( "Hearthstone", item_id, softressing_players )
  controller.preview( item, 2 )

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left )

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left )
  controller.tick( 5 )

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.winners_found( item, 1, { winner( "Psikutas", C.Warrior, item, false, RT.SoftRes, 69 ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.winners_found( item, 1, { winner( "Psikutas", C.Warrior, item, true, RT.SoftRes, 69 ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1 = p( "Psikutas", C.Warrior )
  local group_roster = mock_group_roster( p1 )
  local data = make_data( sr( p1.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  controller.start( strategy, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.winners_found( item, 1, { winner( "Psikutas", C.Warrior, item, false, RT.SoftRes ) }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.add( p1.name, p1.class, RT.SoftRes, 69 )
  controller.add( p2.name, p2.class, RT.SoftRes, 42 )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  controller.start( RS.SoftResRoll, item, 1, nil, seconds_left )
  controller.tick( 1 )
  controller.waiting_for_rolls()

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.tick( 1 )
  controller.winners_found( item, 2, {
    winner( "Psikutas", C.Warrior, item, false, RT.SoftRes ),
    winner( "Obszczymucha", C.Druid, item, false, RT.SoftRes )
  }, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  local winners = {
    winner( "Psikutas", C.Warrior, item, true, RT.SoftRes ),
    winner( "Obszczymucha", C.Druid, item, true, RT.SoftRes )
  }
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.tick( 1 )
  controller.winners_found( item, 2, winners, strategy )
  controller.finish()

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  local winners = {
    winner( "Psikutas", C.Warrior, item, true, RT.SoftRes ),
    winner( "Obszczymucha", C.Druid, item, true, RT.SoftRes )
  }
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.tick( 1 )
  controller.winners_found( item, 2, winners, strategy )
  controller.finish()
  eq( popup.is_visible(), true )
  controller.show_master_loot_confirmation( winners[ 1 ], item, strategy )
  eq( popup.is_visible(), false )
  controller.award_aborted( item )
  eq( popup.is_visible(), true )

  -- Then
  eq( cleanse( popup.get() ),
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
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  local group_roster = mock_group_roster( p1, p2 )
  local data = make_data( sr( p1.name, 123 ), sr( p1.name, 123 ), sr( p2.name, 69, 2 ), sr( p2.name, 123 ) )
  local item_id, seconds_left = 123, 7
  local popup, controller = new( { [ "GroupRoster" ] = group_roster, [ "SoftRes" ] = softres( group_roster, data ) } )
  local item = i( "Hearthstone", item_id )
  local strategy = RS.SoftResRoll
  local winners = {
    winner( "Psikutas", C.Warrior, item, true, RT.SoftRes ),
    winner( "Obszczymucha", C.Druid, item, true, RT.SoftRes )
  }
  controller.start( strategy, item, 2, nil, seconds_left )
  controller.tick( 1 )
  controller.winners_found( item, 2, winners, strategy )
  controller.finish()
  eq( popup.is_visible(), true )
  controller.show_master_loot_confirmation( winners[ 1 ], item, strategy )
  eq( popup.is_visible(), false )
  controller.loot_awarded( "Psikutas", item.id, item.link )
  eq( popup.is_visible(), true )

  -- Then
  eq( cleanse( popup.get() ),
    {
      { type = "item_link_with_icon", link = item.link,                              count = 1 },
      { type = "text",                value = "Obszczymucha soft-ressed this item.", padding = 11 },
      { type = "button",              label = "Award winner",                        width = 130 },
      { type = "button",              label = "Close",                               width = 70 },
      { type = "button",              label = "Award...",                            width = 90 }
    } )
end

TieRollPopupContentSpec = {}

function TieRollPopupContentSpec:should_display_tied_rolls()
  -- Given
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.add( p1.name, p1.class, RT.MainSpec, 69 )
  controller.tick( 1 )
  controller.add( p2.name, p2.class, RT.MainSpec, 69 )
  controller.tie( { p1, p2 }, item, 1, RT.MainSpec, 69 )

  -- Then
  eq( cleanse( popup.get() ),
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
  local popup, controller = new()
  local item_id, seconds_left = 123, 7
  local item = i( "Hearthstone", item_id )
  local p1, p2 = p( "Psikutas", C.Warrior ), p( "Obszczymucha", C.Druid )
  controller.start( RS.NormalRoll, item, 1, nil, seconds_left )
  controller.add( p1.name, p1.class, RT.MainSpec, 69 )
  controller.tick( 1 )
  controller.add( p2.name, p2.class, RT.MainSpec, 69 )
  controller.tie( { p1, p2 }, item, 1, RT.MainSpec, 69 )
  controller.tie_start()

  -- Then
  eq( cleanse( popup.get() ),
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
