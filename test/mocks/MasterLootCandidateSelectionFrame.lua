local M = {}

---@class MasterLootCandidateSelectionFrameMock : MasterLootCandidateSelectionFrame
---@field is_visible fun(): boolean
---@field select fun( player_name: string )
---@field should_be_visible fun()
---@field should_be_hidden fun()

function M.new( config )
  local m_candidates = nil ---@type MasterLootCandidate[]?

  local real_frame = require( "src/MasterLootCandidateSelectionFrame" ).new( config )

  ---@param candidates MasterLootCandidate[]
  local function show( candidates )
    m_candidates = candidates
    real_frame.show( candidates )
  end

  local function hide()
    real_frame.hide()
  end

  local function is_visible()
    local frame = real_frame.get_frame()
    return frame and frame:IsVisible() or false
  end

  local function select( player_name )
    for _, candidate in ipairs( m_candidates or {} ) do
      if candidate.name == player_name then
        candidate.confirm_fn()
        break
      end
    end
  end

  local function should_be_visible()
    if not is_visible() then
      error( "Player selection is hidden.", 2 )
    end
  end

  local function should_be_hidden()
    if is_visible() then
      error( "Player selection is visible.", 2 )
    end
  end

  ---@type MasterLootCandidateSelectionFrameMock
  return {
    show = show,
    hide = hide,
    get_frame = real_frame.get_frame,
    is_visible = is_visible,
    select = select,
    should_be_visible = should_be_visible,
    should_be_hidden = should_be_hidden
  }
end

return M
