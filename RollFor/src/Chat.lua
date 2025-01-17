RollFor = RollFor or {}
local m = RollFor

if m.chat then return end

local M = {}

---@alias AnnounceFn fun( text: string, use_raid_warning: boolean? )

---@class Chat
---@field announce AnnounceFn

---@param api table
---@param player_info PlayerInfo
function M.new( api, player_info )
  local function get_group_chat_type()
    return api.IsInRaid() and "RAID" or "PARTY"
  end

  local function my_raid_rank()
    for i = 1, 40 do
      local name, rank = api.GetRaidRosterInfo( i )

      if name and name == player_info.get_name() then
        return rank
      end
    end

    return 0
  end

  local function get_roll_announcement_chat_type( use_raid_warning )
    local chat_type = get_group_chat_type()
    if not use_raid_warning then return chat_type end

    local rank = my_raid_rank()

    if chat_type == "RAID" and rank > 0 then
      return "RAID_WARNING"
    else
      return chat_type
    end
  end

  ---@type AnnounceFn
  local function announce( text, use_raid_warning )
    api.SendChatMessage( text, get_roll_announcement_chat_type( use_raid_warning ) )
  end

  ---@type Chat
  return {
    announce = announce
  }
end

m.Chat = M
return M
