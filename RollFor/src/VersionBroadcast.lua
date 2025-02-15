RollFor = RollFor or {}
local m = RollFor

if m.VersionBroadcast then return end

local M = {}

local pp = m.pretty_print
local ADDON_NAME = "RollFor"
local orange = m.colors.orange
local c = m.colorize_player_by_class

---@param db table
---@param player_info PlayerInfo
---@param my_version string
function M.new( db, player_info, my_version )
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
    m.api.C_ChatInfo.SendAddonMessage( ADDON_NAME, "VERSION::" .. my_version, channel )
  end

  local function broadcast_version_to_the_guild()
    if not m.api.IsInGuild() then return end
    broadcast_version( "GUILD" )
  end

  local function group_channel()
    return m.api.IsInRaid() and "RAID" or "PARTY"
  end

  local function broadcast_version_to_the_group()
    if not m.api.IsInGroup() and not m.api.IsInRaid() then return end
    broadcast_version( group_channel() )
  end

  local function on_group_changed()
    broadcast_version_to_the_group()
  end

  local function notify_about_new_version( ver )
    db.last_new_version_reminder_timestamp = m.lua.time()
    pp( string.format( "New version (%s) is available!", m.colors.highlight( string.format( "v%s", ver ) ) ) )
    pp( "https://github.com/obszczymucha/roll-for-vanilla/releases/download/latest/RollFor.zip" )
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

  local function on_version_request( channel, requesting_player_name )
    if not channel or not requesting_player_name then return end
    m.api.C_ChatInfo.SendAddonMessage( ADDON_NAME,
      string.format(
        "VERSION_RESPONSE::%s::%s::%s::%s::%s",
        requesting_player_name,
        channel,
        player_info.get_name(),
        player_info.get_class(),
        my_version
      ), channel )
  end

  local function on_version_response( requesting_player_name, channel, their_name, their_class, their_version )
    if requesting_player_name ~= player_info.get_name() then return end
    pp( string.format( "%s %s", c( their_name, their_class ), "v" .. (their_version or "unknown") ), orange, string.lower( channel ) )
  end

  local function version_request( channel )
    m.api.C_ChatInfo.SendAddonMessage( ADDON_NAME, string.format( "VERSION_REQUEST::%s::%s", channel, player_info.get_name() ), channel )
  end

  local function group_version_request()
    if not m.api.IsInGroup() and not m.api.IsInRaid() then
      pp( "Not in a group.", m.colors.red )
      return
    end

    version_request( group_channel() )
  end

  local function guild_version_request()
    if not m.api.IsInGuild() then
      pp( "Not in a guild.", m.colors.red )
      return
    end

    version_request( "GUILD" )
  end

  return {
    on_group_changed = on_group_changed,
    broadcast = broadcast,
    on_version = on_version,
    on_version_request = on_version_request,
    on_version_response = on_version_response,
    group_version_request = group_version_request,
    guild_version_request = guild_version_request,
  }
end

m.VersionBroadcast = M
return M
