RollFor = RollFor or {}
local m = RollFor

if m.LootAwardPopup then return end

local M = {}

---@class AwardPopupMock
---@field show fun( data: MasterLootConfirmationData )
---@field hide fun()
---@field is_visible fun(): boolean
---@field confirm fun()
---@field abort fun()
---@field should_be_visible fun()
---@field should_be_hidden fun()

function M.new( _ )
  local visible = false
  ---@type MasterLootConfirmationData?
  local m_data

  ---@param data MasterLootConfirmationData
  local function show( data )
    m_data = data
    visible = true
  end

  local function hide()
    visible = false
  end

  local function confirm()
    if not m_data then return end
    m_data.confirm_fn()
  end

  local function abort()
    if not m_data then return end
    m_data.abort_fn()
  end

  local function should_be_visible()
    if not visible then
      error( "Loot confirmation popup is hidden.", 2 )
    end
  end

  local function should_be_hidden()
    if visible then
      error( "Loot confirmation popup is visible.", 2 )
    end
  end

  ---@type AwardPopupMock
  return {
    show = show,
    hide = hide,
    is_visible = function() return visible end,
    confirm = confirm,
    abort = abort,
    should_be_visible = should_be_visible,
    should_be_hidden = should_be_hidden
  }
end

m.LootAwardPopup = M
return M
