RollFor = RollFor or {}
local m = RollFor

if m.ChatApi then return end

local _G = getfenv( 0 )
local M = {}

---@class ChatApi
---@field SendChatMessage fun( text: string, chat_type: string )
---@field DEFAULT_CHAT_FRAME table

function M.new()
  ---@type ChatApi
  return {
    SendChatMessage = _G.SendChatMessage or function() print( "PRINCESS KENI" ) end,
    DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME or { AddMessage = function() end }
  }
end

m.ChatApi = M
return M
