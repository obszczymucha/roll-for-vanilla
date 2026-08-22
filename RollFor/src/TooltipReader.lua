RollFor = RollFor or {}
local m = RollFor

if m.TooltipReader then return end


local M = {}
local _G = getfenv( 0 ) ---@diagnostic disable-line: deprecated
local BindType = m.ItemUtils.BindType

local function create_tooltip_frame()
  local frame = m.api.CreateFrame( "GameTooltip", "RollForTooltipFrame", nil, "GameTooltipTemplate" )
  frame:SetOwner( m.api.WorldFrame, "ANCHOR_NONE" );

  return frame
end

---@class TooltipReader
---@field get_slot_bind_type fun( slot: number ): BindType
---@field get_inventory_item_lines fun( unit: string, slot: number ): string[]?
---@field get_unit_buff_lines fun( unit: string, index: number ): string[]?

---@param api table
function M.new( api )
  local m_frame

  local function ensure_frame()
    if m_frame then return end
    m_frame = create_tooltip_frame()
  end

  ---@param slot number?
  local function set_loot_slot( slot )
    ensure_frame()

    m_frame:ClearLines()
    m_frame:SetLootItem( slot )
  end

  ---@return BindType
  local function get_item_type_from_tooltip()
    local num_lines = m_frame:NumLines()

    if num_lines < 2 then
      return BindType.None
    end

    local line = _G[ "RollForTooltipFrameTextLeft2" ]:GetText()

    if line == api.ITEM_BIND_ON_PICKUP or line == api.ITEM_SOULBOUND then
      return BindType.BindOnPickup
    elseif line == api.ITEM_BIND_ON_EQUIP then
      return BindType.BindOnEquip
    elseif line == api.ITEM_BIND_QUEST then
      return BindType.Quest
    else
      return BindType.None
    end
  end

  local function get_slot_bind_type( slot )
    set_loot_slot( slot )

    return get_item_type_from_tooltip()
  end

  -- Whatever is currently in the tooltip frame.
  ---@return string[]? -- left-hand lines, nil if the tooltip is empty
  local function read_lines()
    local line_count = m_frame:NumLines()
    if not line_count or line_count == 0 then return nil end

    local result = {}

    for i = 1, line_count do
      local line = _G[ "RollForTooltipFrameTextLeft" .. i ]
      local text = line and line:GetText()

      if text then table.insert( result, text ) end
    end

    return result
  end

  -- Reads the tooltip of an item equipped by a unit. Works for inspected units,
  -- too, as long as their inspect data has arrived (see Inspector).
  ---@param unit string
  ---@param slot number
  ---@return string[]? -- nil if the slot is empty
  local function get_inventory_item_lines( unit, slot )
    ensure_frame()

    m_frame:ClearLines()
    m_frame:SetOwner( m.api.WorldFrame, "ANCHOR_NONE" )
    m_frame:SetInventoryItem( unit, slot )

    return read_lines()
  end

  -- Same trick as the item tooltips above, for an aura the unit is carrying.
  -- Auras are already on the client, so unlike gear this needs no inspect.
  ---@param unit string
  ---@param index number -- the UnitBuff index the name came from
  ---@return string[]? -- nil if there's no buff in that slot
  local function get_unit_buff_lines( unit, index )
    ensure_frame()

    m_frame:ClearLines()
    m_frame:SetOwner( m.api.WorldFrame, "ANCHOR_NONE" )
    m_frame:SetUnitBuff( unit, index )

    return read_lines()
  end

  ---@type TooltipReader
  return {
    get_slot_bind_type = get_slot_bind_type,
    get_inventory_item_lines = get_inventory_item_lines,
    get_unit_buff_lines = get_unit_buff_lines
  }
end

m.TooltipReader = M
return M
