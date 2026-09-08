---@meta

-- The WoW API surface this project actually touches.
--
-- `m.api` is _G, so every api.Something read is a field read on the global table -- and
-- lua-language-server ships no definitions for the WoW client, so each one reads as an
-- undefined field. Declaring them here answers all of it in one place, for core and for
-- every extension addon that carries ../RollFor on its workspace library path.
--
-- Names come from actual api.* usage across core, its suite and the extension addons,
-- checked against WowApiDump_20260822.txt so a name cannot get in merely by being written
-- down twice. Four are not in that dump and are here on purpose:
--
--   SetLootMethod      -- guarded at modules.lua:271; absent on anniversary clients.
--   SUPERWOW_VERSION   -- from the SuperWoW client extension, so also guarded.
--   GetAddOnMetadata   -- only ever set as a harness mock; the real code reads it off
--   GetLootMethod         C_AddOns / C_PartyInfo, which are in the dump.
--
-- Everything is `any` except CreateFrame, which core already describes (see Types.lua's
-- CreateFrameApi) and which is worth keeping honest because every frame goes through it.
--
-- Annotations only, and deliberately absent from the TOC: read by the language server,
-- never loaded by the client.

---@type fun( frame_type: string, name: string?, parent: Frame?, template: string? ): Frame
CreateFrame = nil

---@type any
C_AddOns = nil
---@type any
C_ChatInfo = nil
---@type any
C_PartyInfo = nil
---@type any
ChatEdit_InsertLink = nil
---@type any
ChatFrame1EditBox = nil
---@type any
CloseLoot = nil
---@type any
DEFAULT_CHAT_FRAME = nil
---@type any
DressUpItemLink = nil
---@type any
FONT_COLOR_CODE_CLOSE = nil
---@type any
GameFontHighlight = nil
---@type any
GameFontHighlightSmall = nil
---@type any
GameTooltip = nil
---@type any
GetAddOnMetadata = nil
---@type any
GetCursorPosition = nil
---@type any
GetItemInfo = nil
---@type any
GetLootMethod = nil
---@type any
GetLootSlotInfo = nil
---@type any
GetLootSlotLink = nil
---@type any
GetLootSlotType = nil
---@type any
GetLootThreshold = nil
---@type any
GetMasterLootCandidate = nil
---@type any
GetMinimapShape = nil
---@type any
GetNumLootItems = nil
---@type any
GetNumSavedInstances = nil
---@type any
GetRaidRosterInfo = nil
---@type any
GetRealZoneText = nil
---@type any
GetRealmName = nil
---@type any
GetSavedInstanceInfo = nil
---@type any
GetScreenHeight = nil
---@type any
GetScreenWidth = nil
---@type any
GetTradePlayerItemInfo = nil
---@type any
GetTradePlayerItemLink = nil
---@type any
GetTradeTargetItemInfo = nil
---@type any
GetTradeTargetItemLink = nil
---@type any
GiveMasterLoot = nil
---@type any
ITEM_BIND_ON_EQUIP = nil
---@type any
ITEM_BIND_ON_PICKUP = nil
---@type any
ITEM_BIND_QUEST = nil
---@type any
ITEM_QUALITY_COLORS = nil
---@type any
ITEM_SOULBOUND = nil
---@type any
InCombatLockdown = nil
---@type any
IsAltKeyDown = nil
---@type any
IsControlKeyDown = nil
---@type any
IsInGroup = nil
---@type any
IsInGuild = nil
---@type any
IsInRaid = nil
---@type any
IsShiftKeyDown = nil
---@type any
LOOTFRAME_NUMBUTTONS = nil
---@type any
LOOT_SLOT_ITEM = nil
---@type any
LOOT_SLOT_MONEY = nil
---@type any
LootFrame = nil
---@type any
LootSlot = nil
---@type any
Minimap = nil
---@type any
MouseIsOver = nil
---@type any
PlaySound = nil
---@type any
RAID_CLASS_COLORS = nil
---@type any
RandomRoll = nil
---@type any
ReloadUI = nil
---@type any
RequestRaidInfo = nil
---@type any
SOUNDKIT = nil
---@type any
SUPERWOW_VERSION = nil
---@type any
SendChatMessage = nil
---@type any
SetLootMethod = nil
---@type any
SetLootThreshold = nil
---@type any
Settings = nil
---@type any
SlashCmdList = nil
---@type any
StaticPopup1Button2 = nil
---@type any
StaticPopupDialogs = nil
---@type any
ToggleDropDownMenu = nil
---@type any
TradeFrameRecipientNameText = nil
---@type any
UIDropDownMenu_AddButton = nil
---@type any
UIDropDownMenu_CreateInfo = nil
---@type any
UIDropDownMenu_Initialize = nil
---@type any
UIDropDownMenu_SetSelectedValue = nil
---@type any
UIDropDownMenu_SetText = nil
---@type any
UIDropDownMenu_SetWidth = nil
---@type any
UIFrameFade = nil
---@type any
UIFrameFadeOut = nil
---@type any
UIFrameFadeRemoveFrame = nil
---@type any
UIParent = nil
---@type any
UISpecialFrames = nil
---@type any
UnitClass = nil
---@type any
UnitExists = nil
---@type any
UnitGUID = nil
---@type any
UnitIsConnected = nil
---@type any
UnitIsDead = nil
---@type any
UnitIsFriend = nil
---@type any
UnitIsGroupLeader = nil
---@type any
UnitName = nil
---@type any
WeakAuras = nil
---@type any
WorldFrame = nil
