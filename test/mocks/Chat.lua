local M = {}

---@param api ChatApi
---@param chat_type ChatType
function M.new( api, chat_type )
  ---@type Chat
  return {
    announce = function( message ) api.SendChatMessage( message, chat_type ) end,
    info = function( message ) api.DEFAULT_CHAT_FRAME:AddMessage( message ) end
  }
end

return M
