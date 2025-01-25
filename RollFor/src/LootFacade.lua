RollFor = RollFor or {}
local m = RollFor

if m.LootFacade then return end

local M = {}
local interface = m.Interface

M.interface = {
  subscribe = "function",
  get_item_count = "function",
  get_source_guid = "function",
  get_link = "function",
  get_info = "function",
  is_item = "function",
  is_coin = "function"
}

---@class LootSlotInfo
---@field texture string
---@field name string
---@field quantity number
---@field quality number

---@class LootFacade
---@field subscribe fun( event_name: LootEventName, callback: fun( arg: any? ) )
---@field get_item_count fun(): number
---@field get_source_guid fun(): string
---@field get_link fun( slot: number ): ItemLink
---@field get_info fun( slot: number ): LootSlotInfo
---@field is_item fun( slot: number ): boolean
---@field is_coin fun( slot: number ): boolean

---@alias LootEventName
---| "LootOpened"
---| "LootClosed"
---| "LootSlotCleared"
---| "ChatMsgLoot"

function M.new( event_frame, api )
  interface.validate( api, m.WowApi.LootInterface )

  ---@param event_name LootEventName
  ---@param callback fun()
  local function subscribe( event_name, callback )
    local blizz_event =
        event_name == "LootOpened" and "LOOT_OPENED" or
        event_name == "LootClosed" and "LOOT_CLOSED" or
        event_name == "LootSlotCleared" and "LOOT_SLOT_CLEARED" or
        event_name == "ChatMsgLoot" and "CHAT_MSG_LOOT"

    if blizz_event then
      event_frame.subscribe( blizz_event, callback )
    end
  end

  ---@return number
  local function get_item_count()
    return api.GetNumLootItems()
  end

  ---@return string?
  local function get_source_guid()
    return api.UnitName( "target" )
  end

  ---@param slot number
  ---@return ItemLink?
  local function get_link( slot )
    return api.GetLootSlotLink( slot )
  end

  ---@param slot number
  ---@return LootSlotInfo?
  local function get_info( slot )
    local texture, name, quantity, quality = api.GetLootSlotInfo( slot )

    return texture and {
      texture = texture,
      name = name,
      quantity = quantity,
      quality = quality
    } or nil
  end

  ---@param slot number
  ---@return boolean
  local function is_item( slot )
    return api.LootSlotIsItem( slot ) == 1 or false
  end

  ---@param slot number
  ---@return boolean
  local function is_coin( slot )
    return api.LootSlotIsCoin( slot ) == 1 or false
  end

  ---@type LootFacade
  return {
    subscribe = subscribe,
    get_item_count = get_item_count,
    get_source_guid = get_source_guid,
    get_link = get_link,
    get_info = get_info,
    is_item = is_item,
    is_coin = is_coin
  }
end

m.LootFacade = M
return M
