local M = {}

local u = require( "test/utils" )
local _, eq = u.luaunit( "assertEquals" )

---@class ChatMock
---@field assert fun( ...: ChatMessage[] )
---@field assert_no_messages fun()

---@alias ChatType
---| "PARTY"
---| "RAID"
---| "RAID_WARNING"

---@class ChatMessage
---@field message string
---@field type ChatType|"CONSOLE"

function M.new()
  ---@type ChatMessage[]
  local messages = {}

  local function send_chat_message( message, chat )
    local parsed_message = u.parse_item_link( message )
    table.insert( messages, u.chat_message( parsed_message, chat ) )
  end

  local function assert( ... )
    local args = { ... }
    local expected = {}
    u.flatten( expected, args )
    eq( messages, expected )
  end

  local function default_chat_frame( _, message )
    local message_without_colors = u.parse_item_link( u.decolorize( message ) )
    table.insert( messages, u.chat_message( message_without_colors, "CONSOLE" ) )
  end

  local function assert_no_messages()
    eq( messages, {} )
  end

  ---@type ChatApi
  return {
    SendChatMessage = send_chat_message,
    DEFAULT_CHAT_FRAME = { AddMessage = default_chat_frame },
    assert = assert,
    assert_no_messages = assert_no_messages
  }
end

return M
