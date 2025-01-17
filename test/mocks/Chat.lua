local M = {}

function M.new()
  local function announce()
  end

  ---@type Chat
  return {
    announce = announce
  }
end

return M
