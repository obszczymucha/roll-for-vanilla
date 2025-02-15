RollFor = RollFor or {}
local m = RollFor

if m.Chat then return end

local M = {}

---@class Chat
---@field announce fun( text: string, use_raid_Warning: boolean? )
---@field info fun( text: string, color_fn: ColorFn?, module_name: string? )

---@param api ChatApi
---@param group_roster GroupRoster
---@param player_info PlayerInfo
function M.new( api, group_roster, player_info )
  local function get_group_chat_type()
    return group_roster.am_i_in_raid() and "RAID" or "PARTY"
  end

  local function get_roll_announcement_chat_type( use_raid_warning )
    local chat_type = get_group_chat_type()
    if not use_raid_warning then return chat_type end

    if chat_type == "RAID" and (player_info.is_leader() or player_info.is_assistant()) then
      return "RAID_WARNING"
    else
      return chat_type
    end
  end

  local function announce( text, use_raid_warning )
    api.SendChatMessage( text, get_roll_announcement_chat_type( use_raid_warning ) )
  end

  local function info( message, color_fn, module_name )
    if not message then return end

    local c = color_fn and type( color_fn ) == "function" and color_fn or color_fn and type( color_fn ) == "string" and m.colors[ color_fn ] or m.colors.blue
    local module_str = module_name and string.format( "%s%s%s", c( " [" ), m.colors.white( module_name ), c( "]" ) ) or ""

    local frame = api.DEFAULT_CHAT_FRAME
    if frame then frame:AddMessage( string.format( "%s%s: %s", c( "RollFor" ), module_str, message ) ) end
  end

  ---@type Chat
  return {
    announce = announce,
    info = info
  }
end

m.Chat = M
return M
