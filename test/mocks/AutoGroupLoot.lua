local M = {}

function M.new()
  ---@type AutoGroupLoot
  return {
    on_loot_opened = function() end,
    on_loot_slot_cleared = function() end
  }
end

return M
