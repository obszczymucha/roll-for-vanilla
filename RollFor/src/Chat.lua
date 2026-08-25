RollFor = RollFor or {}
local m = RollFor

if m.Chat then return end

local M = m.Module.new( "Chat" )

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

  -- The last line of defence against the 255 byte chat limit. Callers that build a
  -- message out of a player list are expected to have split it on element boundaries
  -- already (m.split_message), because that reads better than anything that can be done
  -- from here -- but a message that arrives here too long still goes out in pieces
  -- rather than not going out at all.
  local function announce( text, use_raid_warning )
    local chat_type = get_roll_announcement_chat_type( use_raid_warning )

    for _, chunk in ipairs( m.chunk_text( text ) ) do
      api.SendChatMessage( chunk, chat_type )
    end
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
