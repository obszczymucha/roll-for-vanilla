local M = {}

---@class MasterLootCandidateSelectionFrameMock : MasterLootCandidateSelectionFrame
---@field is_visible fun(): boolean
---@field select fun( player_name: string )

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

  ---@type MasterLootCandidateSelectionFrameMock
  return {
    show = show,
    hide = hide,
    get_frame = real_frame.get_frame,
    is_visible = is_visible,
    select = select
  }
end

return M
