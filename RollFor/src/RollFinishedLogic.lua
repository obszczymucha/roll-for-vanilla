---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.RollFinishedLogic then return end

local white = modules.colors.white
local blue = modules.colors.blue
local red = modules.colors.red
local RollType = modules.Types.RollType

local M = {}

function M.new( master_loot_correlation_data, winner_tracker, loot_award_popup )
  -- player -> MasterLootCandidates
  local function show_popup( player, item_link )
    local slot = master_loot_correlation_data.get( item_link )
    print("chuj1")
    if not slot then return end
    print("chuj2")

    local colored_player_name = modules.colorize_player_by_class( player.name, player.class )
    local winners = winner_tracker.find_winners( item_link )
    local winner = modules.find_value_in_table( winners, player.name, function( v ) return v.winner_name end )

    if not winner then
      local text1 = string.format( "%s%s%s", colored_player_name, red( " did not " ), white( "roll." ) )
      local text2 = white( "Would you like to award this item?" )

      loot_award_popup.show( item_link, player, text1, text2 )
      return
    end

    local color = modules.roll_type_color
    local roll_type = winner.roll_type

    if roll_type == RollType.RaidRoll then
      local text1 = string.format( "%s%s%s%s", colored_player_name, white( " wins the " ), color( roll_type ), white( "." ) )
      local text2 = white( "Would you like to award this item?" )

      loot_award_popup.show( item_link, player, text1, text2 )
      return
    end

    if roll_type == RollType.SoftRes and not winner.winning_roll then
      local text1 = string.format( "%s%s%s%s", colored_player_name, white( " is the only one " ), color( roll_type, "soft-ressing" ), white( "." ) )
      local text2 = white( "Would you like to award this item?" )

      loot_award_popup.show( item_link, player, text1, text2 )
      return
    end

    local text1 = string.format( "%s%s%s%s%s%s",
      colored_player_name,
      white( " wins the " ),
      color( roll_type ),
      white( " roll with a " ),
      blue( winner.winning_roll ),
      white( "." )
    )

    local text2 = white( "Would you like to award this item?" )

    loot_award_popup.show( item_link, player, text1, text2 )
  end

  return {
    show_popup = show_popup
  }
end

modules.RollFinishedLogic = M
return M
