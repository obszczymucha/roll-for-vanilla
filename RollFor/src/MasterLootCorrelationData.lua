---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.MasterLootCorrelationData then return end

-- This module holds temporary data to correlate a shift/alt click on a loot frame button
-- and the loot award popup. The reason for this correlation is, when we shift/alt click,
-- we populate the edit box with either /rf <item> or /rr <item> and we wait for the user
-- to acknowledge it by pressing Enter. In other words the process is not continuous.
-- So upon the click, we store the slot id and the link (and other stuff) so we can then grab it and validate it when
-- we show the popup.
-- We can only award the loot if the item being /rf or /rr has its correlation data
-- available.
-- Additionally, the data must be completely reset when the loot window closes, because
-- the loot slots may change if items are given and loot window is reopened.
-- If the loot window closes while the popup is visible, the popup must also close
-- (or at least the award loot button must be disabled).
local M = {}

function M.new( item_utils )
  local cache = {}

  local function set( item_link, slot )
    if cache[ item_link ] then return end

    cache[ item_link ] = {
      slot = slot,
      item_id = item_utils.get_item_id( item_link ),
      item_name = item_utils.get_item_name( item_link )
    }
  end

  local function remove( item_link )
    cache[ item_link ] = nil
  end

  local function get( item_link )
    return cache[ item_link ]
  end

  local function reset()
    modules.clear_table( cache )
  end

  return {
    set = set,
    remove = remove,
    get = get,
    reset = reset
  }
end

modules.MasterLootCorrelationData = M
return M
