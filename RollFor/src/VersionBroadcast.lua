RollFor = RollFor or {}
local m = RollFor

if m.VersionBroadcast then return end

local M = {}

function M.new( db, my_version )
  local function version_recently_reminded()
    if not db.last_new_version_reminder_timestamp then return false end

    local time = m.lua.time()

    -- Only remind once a day
    if time - db.last_new_version_reminder_timestamp > 3600 * 24 then
      return false
    else
      return true
    end
  end

  local function broadcast_version( channel )
    m.api.SendAddonMessage( "RollFor", "VERSION::" .. my_version, channel )
  end

  local function broadcast_version_to_the_guild()
    if not m.api.IsInGuild() then return end
    broadcast_version( "GUILD" )
  end

  local function broadcast_version_to_the_group()
    if not m.api.IsInGroup() and not m.api.IsInRaid() then return end
    broadcast_version( m.api.IsInRaid() and "RAID" or "PARTY" )
  end

  local function on_group_changed()
    broadcast_version_to_the_group()
  end

  local function notify_about_new_version( ver )
    db.last_new_version_reminder_timestamp = m.lua.time()
    m.pretty_print( string.format( "New version (%s) is available!", m.colors.highlight( string.format( "v%s", ver ) ) ) )
    m.pretty_print( "https://github.com/obszczymucha/roll-for-vanilla/releases/download/latest/RollFor.zip" )
  end

  local function on_version( their_version )
    if m.is_new_version( my_version, their_version ) and not version_recently_reminded() then
      notify_about_new_version( their_version )
    end
  end

  local function broadcast()
    broadcast_version_to_the_guild()
    broadcast_version_to_the_group()
  end

  return {
    on_group_changed = on_group_changed,
    broadcast = broadcast,
    on_version = on_version
  }
end

m.VersionBroadcast = M
return M
