local M = {}

local u = require( "test/utils" )
local _, eq = u.luaunit( "assertEquals" )

---@class ChatApiMock : ChatApi
---@field assert fun( ...: ChatMessage[] )
---@field assert_no_messages fun()
---@field party fun( expected_message: string )
---@field raid fun( expected_message: string )
---@field raid_warning fun( expected_message: string )
---@field console fun( expected_message: string )

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
  local last_message_assertion_index = 0

  local function send_chat_message( message, chat )
    local parsed_message = u.parse_item_link( message )
    table.insert( messages, u.chat_message( parsed_message, chat ) )
  end

  local function assert( ... )
    local args = { ... }
    local expected = {}
    u.flatten( expected, args )

    eq( messages, expected, nil, nil, 3 )
  end

  local function default_chat_frame( _, message )
    local message_without_colors = u.parse_item_link( u.decolorize( message ) )
    table.insert( messages, u.chat_message( message_without_colors, "CONSOLE" ) )
  end

  local function assert_no_messages()
    eq( messages, {}, nil, nil, 3 )
  end

  ---@param expected ChatMessage
  local function assert_message( expected )
    if #messages < last_message_assertion_index + 1 then
      error( "No chat message found.", 3 )
      return
    end

    local was = messages[ last_message_assertion_index + 1 ]

    if was.type ~= expected.type and was.message == expected.message then
      error( string.format( "Was: %s  Expected: %s", was.type, expected.type ), 3 )
      return
    end

    if was.type == expected.type and was.message ~= expected.message then
      error( string.format( "Was: \"%s\"  Expected: \"%s\"", was.message, expected.message ), 3 )
      return
    end

    if was.message ~= expected.message then
      error( string.format( "Was %s: \"%s\"  Expected %s: \"%s\"", was.type, was.message, expected.type, expected.message ), 3 )
      return
    end

    last_message_assertion_index = last_message_assertion_index + 1
  end

  ---@param expected_message string
  local function assert_party( expected_message )
    assert_message( u.chat_message( expected_message, "PARTY" ) )
  end

  ---@param expected_message string
  local function assert_raid( expected_message )
    assert_message( u.chat_message( expected_message, "RAID" ) )
  end

  ---@param expected_message string
  local function assert_raid_warning( expected_message )
    assert_message( u.chat_message( expected_message, "RAID_WARNING" ) )
  end

  ---@param expected_message string
  local function assert_console( expected_message )
    assert_message( u.chat_message( expected_message, "CONSOLE" ) )
  end

  ---@type ChatApiMock
  return {
    SendChatMessage = send_chat_message,
    DEFAULT_CHAT_FRAME = { AddMessage = default_chat_frame },
    assert = assert,
    assert_no_messages = assert_no_messages,
    party = assert_party,
    raid = assert_raid,
    raid_warning = assert_raid_warning,
    console = assert_console
  }
end

return M
