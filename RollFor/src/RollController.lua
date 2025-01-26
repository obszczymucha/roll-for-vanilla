RollFor = RollFor or {}
local m = RollFor

if m.RollController then return end

local info = m.pretty_print
local M = m.Module.new( "RollController" )
local S = m.Types.RollingStatus
local RS = m.Types.RollingStrategy
local LAE = m.Types.LootAwardError
local IU = m.ItemUtils ---@type ItemUtils
local getn = table.getn

---@class RollControllerFacade
---@field roll_was_ignored fun( player_name: string, player_class: string?, roll_type: RollType, roll: number, reason: string )
---@field roll_was_accepted fun( player_name: string, player_class: string, roll_type: RollType, roll: number )
---@field tick fun( seconds_left: number )
---@field winners_found fun( item: Item, item_count: number, winners: Winner[], strategy: RollingStrategyType )
---@field finish fun()

---@class RollController
---@field preview fun( item: Item, count: number, seconds: number?, message: string? )
---@field start fun( rolling_strategy: RollingStrategyType, item: Item, count: number, seconds: number?, info: string? )
---@field winners_found fun( item: Item, item_count: number, winners: Winner[], strategy: RollingStrategyType )
---@field finish fun()
---@field tick fun( seconds_left: number )
---@field add fun( player_name: string, player_class: string, roll_type: RollType, roll: number )
---@field add_ignored fun( player_name: string, player_class: string?, roll_type: RollType, roll: number, reason: string )
---@field rolling_canceled fun()
---@field subscribe fun( event_type: string, callback: fun( data: any ) )
---@field tie fun( tied_players: RollingPlayer[], item: Item, item_count: number, roll_type: RollType, roll: number, rerolling: boolean?, top_roll: boolean? )
---@field tie_start fun()
---@field waiting_for_rolls fun()
---@field award_aborted fun( item: Item )
---@field loot_awarded fun( player_name: string, item_id: number, item_link: string )
---@field show_master_loot_confirmation fun( player: ItemCandidate|Winner, item: MasterLootDistributableItem, rolling_strategy: RollingStrategyType )
---@field loot_opened fun()
---@field loot_closed fun()
---@field player_already_has_unique_item fun()
---@field player_has_full_bags fun()
---@field player_not_found fun()
---@field cant_assign_item_to_that_player fun()
---@field rolling_popup_closed fun()
---@field loot_award_popup_closed fun()
---@field loot_list_item_selected fun()
---@field loot_list_item_deselected fun()
---@field finish_rolling_early fun()
---@field cancel_rolling fun()
---@field rolling_started fun( rolling_strategy: RollingStrategyType, item: Item, count: number, seconds: number?, message: string?, rolling_players: RollingPlayer[]? )
---@field award_confirmed fun( player: ItemCandidate|Winner, item: MasterLootDistributableItem )

---@param roll_tracker RollTracker
---@param player_info PlayerInfo
---@param ml_candidates MasterLootCandidates
---@param softres GroupAwareSoftRes
---@param loot_list SoftResLootList
---@param rolling_popup RollingPopup
---@param player_selection_frame MasterLootCandidateSelectionFrame
function M.new( roll_tracker, player_info, ml_candidates, softres, loot_list, config, rolling_popup, player_selection_frame )
  local callbacks = {}
  local ml_confirmation_data = nil ---@type MasterLootConfirmationData?
  local preview_data = nil ---@type RollingPopupPreviewData

  local function notify_subscribers( event_type, data )
    M.debug.add( event_type )

    for _, callback in ipairs( callbacks[ event_type ] or {} ) do
      callback( data )
    end
  end

  local function get_color( quality )
    local color = m.api.ITEM_QUALITY_COLORS[ quality ] or { r = 0, g = 0, b = 0, a = 1 }

    local multiplier = 0.5
    local alpha = 0.6
    local c = { r = color.r * multiplier, g = color.g * multiplier, b = color.b * multiplier, a = alpha }

    return c
  end

  ---@class AwardConfirmedData
  ---@field player ItemCandidate|Winner
  ---@field item MasterLootDistributableItem

  ---@param player ItemCandidate|Winner
  ---@param item MasterLootDistributableItem
  local function award_confirmed( player, item )
    notify_subscribers( "award_confirmed", { player = player, item = item } )
  end

  ---@class WinnerWithAwardCallback
  ---@field name string
  ---@field class PlayerClass
  ---@field roll_type RollType
  ---@field roll number?
  ---@field award_callback fun()?

  ---@class RollingPopupButtonWithCallback
  ---@field type RollingPopupButtonType
  ---@field callback fun()

  ---@class RollingPopupPreviewData
  ---@field item_link ItemLink
  ---@field item_tooltip_link TooltipItemLink
  ---@field item_texture ItemTexture
  ---@field item_count number
  ---@field winners WinnerWithAwardCallback[]
  ---@field rolls RollData[]
  ---@field strategy_type RollingStrategyType
  ---@field buttons RollingPopupButtonWithCallback[]

  ---@param type RollingPopupButtonType
  ---@param callback fun()
  local function button( type, callback )
    return { type = type, callback = callback } ---@type RollingPopupButtonWithCallback
  end

  ---@class RollControllerStartData
  ---@field strategy_type RollingStrategyType
  ---@field item Item
  ---@field item_count number
  ---@field message string?
  ---@field seconds number?

  ---@param strategy_type RollingStrategyType
  ---@param item Item
  ---@param item_count number
  ---@param seconds number?
  ---@param message string?
  local function start( strategy_type, item, item_count, seconds, message )
    if ml_confirmation_data then
      info( "Item award confirmation is in progress. Can't start rolling now." )
      return
    end

    notify_subscribers( "start", { strategy_type = strategy_type, item = item, item_count = item_count, message = message, seconds = seconds } )
  end

  ---@param buttons RollingPopupButtonWithCallback[]
  local function add_close_button( buttons )
    table.insert( buttons, button( "Close", function() rolling_popup.hide() end ) )
  end

  local function process_next_item()
    if not player_info.is_master_looter() then return end
    notify_subscribers( "process_next_item" )
  end

  local function award_aborted( item )
    if ml_confirmation_data then
      notify_subscribers( "hide_master_loot_confirmation" )
      ml_confirmation_data = nil
    end

    notify_subscribers( "award_aborted", { item = item } )

    if preview_data then
      notify_subscribers( "ShowRollingPopupPreview", preview_data )
      return
    end

    local data, current_iteration = roll_tracker.get()

    if not data or not data.status or not data.item or not current_iteration then
      process_next_item()
      return
    end

    notify_subscribers( "TemporaryHack" ) -- TODO: So we don't break things until everything is aligned in RollingPopupContent.
  end

  ---@class MasterLootConfirmationData
  ---@field item MasterLootDistributableItem
  ---@field winners Winner[]
  ---@field receiver ItemCandidate
  ---@field strategy_type RollingStrategyType
  ---@field confirm_fn fun()
  ---@field abort_fn fun()
  ---@field error LootAwardError?

  ---@param player ItemCandidate|Winner
  ---@param item MasterLootDistributableItem
  ---@param strategy_type RollingStrategyType
  local function show_master_loot_confirmation( player, item, strategy_type )
    local candidate = ml_candidates.find( player.name )

    if not candidate then
      M.debug.add( "Candidate not found: %s", player.name )
      return
    end

    local winners = roll_tracker.get().winners

    ml_confirmation_data = {
      item = item,
      winners = winners,
      receiver = candidate,
      strategy_type = strategy_type,
      confirm_fn = function() award_confirmed( candidate, item ) end,
      abort_fn = function() award_aborted( item ) end
    }

    rolling_popup.hide()
    notify_subscribers( "show_master_loot_confirmation", ml_confirmation_data )
  end

  ---@param item Item
  ---@param item_count number
  ---@param seconds number?
  ---@param message string?
  ---@diagnostic disable-next-line: unused-local
  local function new_preview( item, item_count, seconds, message )
    M.debug.add( "new_preview" )
    if not item_count or item_count == 0 then
      m.trace( string.format( "item_count: %s", item_count or "nil" ) )
      return
    end

    local candidates = ml_candidates.get()
    local soft_ressers = softres.get( item.id )
    local hard_ressed = softres.is_item_hardressed( item.id )
    roll_tracker.preview( item, item_count, candidates, soft_ressers, hard_ressed )

    local color = get_color( item.quality )
    notify_subscribers( "border_color", { color = color } )

    local sr_count = getn( soft_ressers )
    local buttons = {}
    local dropped_item = loot_list.get_by_id( item.id )
    local candidate_count = getn( candidates )

    if sr_count == 0 then
      table.insert( buttons, button( "Roll", function() start( RS.NormalRoll, item, item_count, config.default_rolling_time_seconds() ) end ) )
      add_close_button( buttons )

      if dropped_item and candidate_count > 0 then
        table.insert( buttons,
          button( "AwardOther", function()
            ---@type MasterLootCandidate[]
            local players = m.map( candidates,
              ---@param candidate ItemCandidate
              function( candidate )
                ---@type MasterLootCandidate
                return {
                  name = candidate.name,
                  class = candidate.class,
                  is_winner = false,
                  confirm_fn = function()
                    player_selection_frame.hide()
                    show_master_loot_confirmation( candidate, dropped_item, RS.NormalRoll )
                  end
                }
              end )

            player_selection_frame.show( players )
            local frame = player_selection_frame.get_frame()
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", rolling_popup.get_frame(), "BOTTOM", 0, -5 )
          end ) )
      end

      preview_data = {
        item_link = item.link,
        item_tooltip_link = IU.get_tooltip_link( item.link ),
        item_texture = item.texture,
        item_count = item_count,
        winners = {},
        rolls = {},
        strategy_type = RS.NormalRoll,
        buttons = buttons
      }

      notify_subscribers( "ShowRollingPopupPreview", preview_data )
      return
    end

    if item_count == sr_count then
      ---@type WinnerWithAwardCallback[]
      local winners = m.map( soft_ressers,
        ---@param player RollingPlayer
        function( player )
          local candidate = ml_candidates.find( player.name )
          local award_callback = candidate and dropped_item and function()
            show_master_loot_confirmation( candidate, dropped_item, RS.SoftResRoll )
          end

          ---@type WinnerWithAwardCallback
          return { name = player.name, class = player.class, roll_type = "SoftRes", award_callback = award_callback }
        end
      )

      if getn( winners ) == 1 and winners[ 1 ].award_callback then
        table.insert( buttons, button( "AwardWinner", winners[ 1 ].award_callback ) )
        winners[ 1 ].award_callback = nil
      end

      add_close_button( buttons )

      if dropped_item and candidate_count > 0 then
        table.insert( buttons, button( "AwardOther", function() end ) )
      end

      preview_data = {
        item_link = item.link,
        item_tooltip_link = IU.get_tooltip_link( item.link ),
        item_texture = item.texture,
        item_count = item_count,
        winners = winners,
        rolls = {},
        strategy_type = RS.SoftResRoll,
        buttons = buttons
      }

      notify_subscribers( "ShowRollingPopupPreview", preview_data )
      return
    end

    table.insert( buttons, button( "Roll", function() start( RS.SoftResRoll, item, item_count, config.default_rolling_time_seconds() ) end ) )
    add_close_button( buttons )

    preview_data = {
      item_link = item.link,
      item_tooltip_link = IU.get_tooltip_link( item.link ),
      item_texture = item.texture,
      item_count = item_count,
      winners = {},
      rolls = roll_tracker.create_roll_data( soft_ressers ),
      strategy_type = RS.SoftResRoll,
      buttons = buttons
    }

    notify_subscribers( "ShowRollingPopupPreview", preview_data )
  end

  ---@param item Item|MasterLootDistributableItem
  ---@param count number
  ---@diagnostic disable-next-line: unused-function, unused-local
  local function preview( item, count )
    local candidates = ml_candidates.get()
    local soft_ressers = softres.get( item.id )
    local hard_ressed = softres.is_item_hardressed( item.id )
    roll_tracker.preview( item, count, candidates, soft_ressers, hard_ressed )
    local color = get_color( item.quality )

    notify_subscribers( "border_color", { color = color } )
    notify_subscribers( "preview", { item = item } )
  end

  local function add( player_name, player_class, roll_type, roll )
    roll_tracker.add( player_name, player_class, roll_type, roll )
    notify_subscribers( "roll" )
  end

  local function add_ignored( player_name, player_class, roll_type, roll, reason )
    roll_tracker.add_ignored( player_name, roll_type, roll, reason )
    notify_subscribers( "ignored_roll", {
      player_name = player_name,
      player_class = player_class,
      roll_type = roll_type,
      roll = roll,
      reason = reason
    } )
  end

  local function tick( seconds_left )
    roll_tracker.tick( seconds_left )
    notify_subscribers( "tick", { seconds_left = seconds_left } )
  end

  ---@class WinnersFoundData
  ---@field item Item
  ---@field item_count number
  ---@field winners Winner[]
  ---@field rolling_strategy RollingStrategyType

  ---@param item Item
  ---@param item_count number
  ---@param winners Winner[]
  ---@param strategy RollingStrategyType
  local function winners_found( item, item_count, winners, strategy )
    roll_tracker.add_winners( winners )
    notify_subscribers( "winners_found", { item = item, item_count = item_count, winners = winners, rolling_strategy = strategy } )
  end

  local function finish()
    local candidates = ml_candidates.get()
    roll_tracker.finish( candidates )
    notify_subscribers( "finish" )
  end

  ---@param strategy_type RollingStrategyType
  ---@param item Item
  ---@param item_count number
  ---@param seconds number?
  ---@param message string?
  ---@param rolling_players RollingPlayer[]?
  local function rolling_started( strategy_type, item, item_count, seconds, message, rolling_players )
    roll_tracker.start( strategy_type, item, item_count, seconds, message, rolling_players )

    local _, _, quality = m.api.GetItemInfo( string.format( "item:%s:0:0:0", item.id ) )
    local color = get_color( quality )

    notify_subscribers( "border_color", { color = color } )
    notify_subscribers( "rolling_started" )
  end

  local function tie( players, item, item_count, roll_type, roll, rerolling, top_roll )
    roll_tracker.tie( players, roll_type, roll )
    notify_subscribers( "tie", {
      players = players,
      item = item,
      item_count = item_count,
      roll_type = roll_type,
      roll = roll,
      rerolling = rerolling,
      top_roll = top_roll
    } )
  end

  local function tie_start()
    roll_tracker.tie_start()
    notify_subscribers( "tie_start" )
  end

  local function rolling_canceled()
    roll_tracker.rolling_canceled()
    notify_subscribers( "rolling_canceled" )
  end

  local function subscribe( event_type, callback )
    callbacks[ event_type ] = callbacks[ event_type ] or {}
    table.insert( callbacks[ event_type ], callback )
  end

  local function waiting_for_rolls()
    roll_tracker.waiting_for_rolls()
    notify_subscribers( "waiting_for_rolls" )
  end

  ---@class MasterLootCandidate
  ---@field name string
  ---@field class PlayerClass
  ---@field is_winner boolean
  ---@field confirm_fn fun()

  ---@class LootAwardedData
  ---@field player_name string
  ---@field item_id number
  ---@field item_link string

  ---@param player_name string
  ---@param item_id number
  ---@param item_link string
  local function loot_awarded( player_name, item_id, item_link )
    roll_tracker.loot_awarded( player_name, item_id )

    if ml_confirmation_data then
      ml_confirmation_data = nil
      notify_subscribers( "hide_master_loot_confirmation" )
    end

    notify_subscribers( "loot_awarded", { player_name = player_name, item_id = item_id, item_link = item_link } )
    process_next_item()

    local data = roll_tracker.get()

    if getn( data.winners ) == 0 then
      rolling_popup.hide()
      notify_subscribers( "all_items_awarded" )
    else
      notify_subscribers( "not_all_items_awarded" )
    end
  end
  local function loot_opened()
    notify_subscribers( "loot_opened" )
  end

  local function loot_closed()
    notify_subscribers( "loot_closed" )

    if ml_confirmation_data then
      award_aborted( ml_confirmation_data.item )
      ml_confirmation_data = nil
      notify_subscribers( "hide_master_loot_confirmation" )
      return
    end

    local status = roll_tracker.get().status

    if status and status.type == S.Preview then
      roll_tracker.clear()
      rolling_popup.hide()
    end
  end

  ---@param error LootAwardError
  local function update_loot_confirmation_with_error( error )
    if not ml_confirmation_data then return end
    ml_confirmation_data.error = error
    notify_subscribers( "show_master_loot_confirmation", ml_confirmation_data )
  end

  local function player_already_has_unique_item()
    update_loot_confirmation_with_error( LAE.AlreadyOwnsUniqueItem )
  end

  local function player_has_full_bags()
    update_loot_confirmation_with_error( LAE.FullBags )
  end

  local function player_not_found()
    update_loot_confirmation_with_error( LAE.PlayerNotFound )
  end

  local function cant_assign_item_to_that_player()
    update_loot_confirmation_with_error( LAE.CantAssignItemToThatPlayer )
  end

  local function rolling_popup_closed()
    notify_subscribers( "rolling_popup_closed" )

    -- local data = roll_tracker.get()
    --
    -- if data and data.status and data.status.type == S.Preview then
    --   roll_tracker.clear()
    -- end
  end

  local function loot_award_popup_closed()
    notify_subscribers( "loot_award_popup_closed" )
  end

  local function loot_list_item_selected()
    notify_subscribers( "loot_list_item_selected" )
  end

  local function loot_list_item_deselected()
    notify_subscribers( "loot_list_item_deselected" )
  end

  local function finish_rolling_early()
    notify_subscribers( "finish_rolling_early" )
  end

  local function cancel_rolling()
    notify_subscribers( "cancel_rolling" )
  end

  ---@type RollController
  return {
    preview = new_preview,
    start = start,
    winners_found = winners_found,
    finish = finish,
    tick = tick,
    add = add,
    add_ignored = add_ignored,
    rolling_canceled = rolling_canceled,
    subscribe = subscribe,
    waiting_for_rolls = waiting_for_rolls,
    tie = tie,
    tie_start = tie_start,
    award_aborted = award_aborted,
    loot_awarded = loot_awarded,
    show_master_loot_confirmation = show_master_loot_confirmation,
    loot_opened = loot_opened,
    loot_closed = loot_closed,
    player_already_has_unique_item = player_already_has_unique_item,
    player_has_full_bags = player_has_full_bags,
    player_not_found = player_not_found,
    cant_assign_item_to_that_player = cant_assign_item_to_that_player,
    rolling_popup_closed = rolling_popup_closed,
    loot_award_popup_closed = loot_award_popup_closed,
    loot_list_item_selected = loot_list_item_selected,
    loot_list_item_deselected = loot_list_item_deselected,
    finish_rolling_early = finish_rolling_early,
    cancel_rolling = cancel_rolling,
    rolling_started = rolling_started,
    award_confirmed = award_confirmed
  }
end

m.RollController = M
return M
