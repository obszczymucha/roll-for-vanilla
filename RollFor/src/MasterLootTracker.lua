RollFor = RollFor or {}
local m = RollFor

if m.MasterLootTracker then return end

local M = {}
local count_elements = m.count_elements
local clear_table = m.clear_table

function M.new()
  local m_items = {}

  -- item -> ItemUtils.make_item()
  local function add( slot, item )
    m_items[ slot ] = item
  end

  local function remove( slot )
    m_items[ slot ] = nil
  end

  local function count()
    return count_elements( m_items )
  end

  local function clear()
    clear_table( m_items )
  end

  local function get( slot )
    return m_items[ slot ]
  end

  return {
    add = add,
    remove = remove,
    count = count,
    clear = clear,
    get = get
  }
end

m.MasterLootTracker = M
return M
