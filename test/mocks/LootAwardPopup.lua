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

function M.new( _, roll_controller )
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

  roll_controller.subscribe( "show_master_loot_confirmation", show )
  roll_controller.subscribe( "hide_master_loot_confirmation", hide )

  ---@type AwardPopupMock
  return {
    show = show,
    hide = hide,
    is_visible = function() return visible end,
    confirm = confirm,
    abort = abort
  }
end

m.LootAwardPopup = M
return M
