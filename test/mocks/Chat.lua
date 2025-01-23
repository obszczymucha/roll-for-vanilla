local M = {}

local u = require( "test/utils" )
local _, eq = u.luaunit( "assertEquals" )

---@class ChatMock
---@field assert fun( ...: ChatMessage[] )

---@alias ChatType
---| "PARTY"
---| "RAID"
---| "RAID_WARNING"
---| "CONSOLE"

---@class ChatMessage
---@field message string
---@field type ChatType

function M.new()
  ---@type ChatMessage[]
  local messages = {}

  local function announce( message, use_raid_warning )
    local parsed_message = u.parse_item_link( message )
    table.insert( messages, u.chat_message( parsed_message, use_raid_warning and "RAID_WARNING" or "RAID" ) )
  end

  local function assert( ... )
    local args = { ... }
    local expected = {}
    u.flatten( expected, args )
    eq( messages, expected )
  end

  ---@type Chat
  return {
    announce = announce,
    assert = assert
  }
end

return M
