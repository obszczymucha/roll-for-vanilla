RollFor = RollFor or {}
local m = RollFor

if m.chat then return end

local M = {}

---@alias AnnounceFn fun( text: string, use_raid_warning: boolean? )
---@alias InfoFn fun( text: string )

---@class Chat
---@field announce AnnounceFn
---@field info fun( text: string )

---@class ChatApi
---@field SendChatMessage fun( text: string, chat_type: string )
---@field DEFAULT_CHAT_FRAME table

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

  ---@type AnnounceFn
  local function announce( text, use_raid_warning )
    api.SendChatMessage( text, get_roll_announcement_chat_type( use_raid_warning ) )
  end

  local function info( text )
    api.DEFAULT_CHAT_FRAME:AddMessage( text )
  end

  ---@type Chat
  return {
    announce = announce,
    info = info
  }
end

m.Chat = M
return M
