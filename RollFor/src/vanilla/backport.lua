---@diagnostic disable: undefined-global
function IsInParty() return GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 end

function IsInRaid() return GetNumRaidMembers() > 0 end

function IsInGroup() return IsInParty() or IsInRaid() end

---@diagnostic disable-next-line: undefined-field
if not string.gmatch then string.gmatch = string.gfind end

---@diagnostic disable-next-line: duplicate-set-field
string.match = string.match or function( str, pattern )
  if not str then return nil end

  local _, _, r1, r2, r3, r4, r5, r6, r7, r8, r9 = string.find( str, pattern )
  return r1, r2, r3, r4, r5, r6, r7, r8, r9
end

LOOT_SLOT_NONE = 0
LOOT_SLOT_ITEM = 1
LOOT_SLOT_MONEY = 2

---@param slot number
---@return number
function GetLootSlotType( slot )
  if LootSlotIsItem( slot ) == 1 then
    return LOOT_SLOT_ITEM
  elseif LootSlotIsCoin( slot ) == 1 then
    return LOOT_SLOT_MONEY
  else
    return LOOT_SLOT_NONE
  end
end

---@param unit_type string
---@return boolean
function UnitIsGroupLeader( unit_type )
  return UnitIsPartyLeader( unit_type )
end
