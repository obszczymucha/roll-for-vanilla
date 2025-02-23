local M = {}

local m = require( "src/modules" )

---@class MasterLootCandidateSelectionFrameMock : MasterLootCandidateSelectionFrame
---@field is_visible fun(): boolean
---@field select fun( player_name: string )
---@field should_be_visible fun()
---@field should_be_hidden fun()
---@field should_display fun( ...: string )

---@param frame_builder FrameBuilderFactory
---@param config Config
function M.new( frame_builder, config )
  local m_candidates = nil ---@type MasterLootCandidate[]?

  local real_frame = require( "src/MasterLootCandidateSelectionFrame" ).new( frame_builder, config )

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

  local function should_be_visible( level )
    if not is_visible() then
      error( "Player selection is hidden.", level )
    end
  end

  local function should_be_hidden()
    if is_visible() then
      error( "Player selection is visible.", 2 )
    end
  end

  local function prettify_table( t )
    local result = ""

    for _, v in ipairs( t ) do
      if result ~= "" then
        result = result .. ", "
      end

      result = result .. v
    end

    return string.format( "[%s]", result )
  end

  ---@param ... string
  local function should_display( ... )
    should_be_visible( 3 )

    local was = { ... }
    table.sort( was )

    local expected = m.map( m_candidates or {},
      ---@param candidate MasterLootCandidate
      function( candidate )
        return candidate.name
      end )

    local was_str = prettify_table( was )
    local expected_str = prettify_table( expected )

    if was_str ~= expected_str then
      error( string.format( "Was: %s  Expected: %s", was_str, expected_str ), 2 )
      return
    end
  end

  ---@type MasterLootCandidateSelectionFrameMock
  return {
    show = show,
    hide = hide,
    get_frame = real_frame.get_frame,
    is_visible = is_visible,
    select = select,
    should_be_visible = function() should_be_visible( 2 ) end,
    should_be_hidden = should_be_hidden,
    should_display = should_display
  }
end

return M
