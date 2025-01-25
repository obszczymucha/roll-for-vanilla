local M = {}

-- Mocking for now until LootFrame is properly refactored.
function M.new()
  ---@type LootFrame
  return {
    show = function() end,
    hide = function() end,
    update = function() end
  }
end

return M
