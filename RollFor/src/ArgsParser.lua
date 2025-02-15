RollFor = RollFor or {}
local m = RollFor

if m.ArgsParser then return end

local M = {}

---@type MakeItemFn
local make_item = m.ItemUtils.make_item

---@alias ParseArgsFn fun( args: string ):
---  Item,
---  number, -- item count
---  number, -- seconds
---  string  -- message

---@class ArgsParser
---@field parse ParseArgsFn

---@return ArgsParser
function M.new( item_utils, config )
  local function parse( args )
    for item_count, link, seconds, message in string.gmatch( args, "(%d*)[xX]?%s*(|%w+|Hitem.+|r)%s*(%d*)%s*(.*)" ) do
      local count = (not item_count or item_count == "") and 1 or tonumber( item_count )
      local id = item_utils.get_item_id( link )
      local name = item_utils.get_item_name( link )
      local quality, texture = m.get_item_quality_and_texture( m.api, id )

      local item = make_item( id, name, link, quality, texture )
      local secs = seconds and seconds ~= "" and seconds ~= " " and tonumber( seconds ) or config.default_rolling_time_seconds()

      return item, count, secs < 4 and 4 or secs > 15 and 15 or secs, message
    end
  end

  return {
    parse = parse
  }
end

m.ArgsParser = M
return M
