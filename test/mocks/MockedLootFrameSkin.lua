RollFor = RollFor or {}
local m = RollFor

if m.MockedLootFrameSkin then return end

local M = {}

---@param frame_builder FrameBuilderFactory
function M.new( frame_builder )
  local function header()
    return frame_builder.new():build()
  end

  local function dropped_item()
    return frame_builder.new():build()
  end

  local function body()
    return frame_builder.new():build()
  end

  local function footer()
    return frame_builder.new():build()
  end

  local function get_item_height()
    return 25
  end

  ---@type LootFrameSkin
  return {
    header = header,
    body = body,
    dropped_item = dropped_item,
    footer = footer,
    get_item_height = get_item_height
  }
end

m.MockedLootFrameSkin = M
return M
