RollFor = RollFor or {}
local m = RollFor

if m.RollForAd then return end

local M = {}

local url = "https://github.com/obszczymucha/roll-for-vanilla/releases/download/latest/RollFor.zip"

---@param player_info PlayerInfo
function M.new( player_info )
  local function on_chat_msg( channel )
    return function( message, player_name )
      if message == "RollFor" and player_name == player_info.get_name() then
        m.api.SendChatMessage( url, channel )
      end
    end
  end

  local function on_chat_msg_whisper_inform( message, player_name )
    if message == "RollFor" then
      m.api.SendChatMessage( url, "WHISPER", nil, player_name )
    end
  end

  return {
    on_chat_msg_party = on_chat_msg( "PARTY" ),
    on_chat_msg_raid = on_chat_msg( "RAID" ),
    on_chat_msg_whisper_inform = on_chat_msg_whisper_inform
  }
end

m.RollForAd = M
return M
