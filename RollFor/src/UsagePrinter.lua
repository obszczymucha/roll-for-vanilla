RollFor = RollFor or {}
local m = RollFor

if m.UsagePrinter then return end

local M = {}

local pretty_print = m.pretty_print
local hl = m.colors.hl
local RollSlashCommand = m.Types.RollSlashCommand

function M.new( config )
  local function print_usage( roll_type )
    if roll_type == RollSlashCommand.NormalRoll or roll_type == RollSlashCommand.NoSoftResRoll then
      pretty_print( string.format( "Usage: %s <%s> [%s]", roll_type, hl( "item" ), hl( "seconds" ) ) )
    elseif roll_type == RollSlashCommand.RaidRoll then
      pretty_print( string.format( "Usage: %s <%s>", roll_type, hl( "item" ) ), nil, "RaidRoll" )
    elseif roll_type == RollSlashCommand.InstaRaidRoll and config.insta_raid_roll() then
      pretty_print( string.format( "Usage: %s <%s>", roll_type, hl( "item" ) ), nil, "InstaRaidRoll" )
    elseif roll_type == RollSlashCommand.InstaRaidRoll and not config.insta_raid_roll() then
      pretty_print( string.format( "Insta raid-roll is %s.", m.msg.disabled ) )
    else
    end
  end

  return {
    print_usage = print_usage
  }
end

m.UsagePrinter = M
return M
