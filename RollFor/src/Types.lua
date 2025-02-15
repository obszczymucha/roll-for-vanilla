RollFor = RollFor or {}
local m = RollFor

if m.Types then return end

local M = {}

---@class CreateFrameApi
---@field CreateFrame fun( frame_type: string, name: string?, parent: Frame?, template: string? ): Frame

---@alias PlayerName string
---@alias ItemId number

---@class RollSlashCommand
---@field NormalRoll "/rf"
---@field NoSoftResRoll "/arf"
---@field RaidRoll "/rr"
---@field InstaRaidRoll "/irr"

---@type RollSlashCommand
M.RollSlashCommand = {
  NormalRoll = "/rf",
  NoSoftResRoll = "/arf",
  RaidRoll = "/rr",
  InstaRaidRoll = "/irr"
}

function M.slash_command_to_strategy_type( slash_command )
  if slash_command == M.RollSlashCommand.NormalRoll then
    return M.RollingStrategy.SoftResRoll
  elseif slash_command == M.RollSlashCommand.NoSoftResRoll then
    return M.RollingStrategy.NormalRoll
  elseif slash_command == M.RollSlashCommand.RaidRoll then
    return M.RollingStrategy.RaidRoll
  elseif slash_command == M.RollSlashCommand.InstaRaidRoll then
    return M.RollingStrategy.InstaRaidRoll
  end
end

---@alias RollType
---| "MainSpec"
---| "OffSpec"
---| "Transmog"
---| "SoftRes"

---@class RT
---@field MainSpec "MainSpec"
---@field OffSpec "OffSpec"
---@field Transmog "Transmog"
---@field SoftRes "SoftRes"

---@type RT
M.RollType = {
  MainSpec = "MainSpec",
  OffSpec = "OffSpec",
  Transmog = "Transmog",
  SoftRes = "SoftRes"
}

--- @alias RollingStrategyType
---| "NormalRoll"
---| "SoftResRoll"
---| "TieRoll"
---| "RaidRoll"
---| "InstaRaidRoll"

---@class RS
---@field NormalRoll "NormalRoll"
---@field SoftResRoll "SoftResRoll"
---@field TieRoll "TieRoll"
---@field RaidRoll "RaidRoll"
---@field InstaRaidRoll "InstaRaidRoll"

local RollingStrategy = {
  NormalRoll = "NormalRoll",
  SoftResRoll = "SoftResRoll",
  TieRoll = "TieRoll",
  RaidRoll = "RaidRoll",
  InstaRaidRoll = "InstaRaidRoll"
}

---@type RS
M.RollingStrategy = RollingStrategy

---@class PT
---@field Player "Player"
---@field Roller "Roller"
---@field RollingPlayer "RollingPlayer"
---@field ItemCandidate "ItemCandidate"
---@field Winner "Winner"

---@alias PlayerType
---| "Player"
---| "Roller"
---| "RollingPlayer"
---| "ItemCandidate"
---| "Winner"

---@type PT
local PlayerType = {
  Player = "Player",
  Roller = "Roller",
  RollingPlayer = "RollingPlayer",
  ItemCandidate = "ItemCandidate",
  Winner = "Winner",
}

M.PlayerType = PlayerType

--- Player class constants
---@alias PlayerClass
---| "Druid"
---| "Hunter"
---| "Mage"
---| "Paladin"
---| "Priest"
---| "Rogue"
---| "Shaman"
---| "Warlock"
---| "Warrior"
local PlayerClass = {
  Druid = "Druid",
  Hunter = "Hunter",
  Mage = "Mage",
  Paladin = "Paladin",
  Priest = "Priest",
  Rogue = "Rogue",
  Shaman = "Shaman",
  Warlock = "Warlock",
  Warrior = "Warrior"
}

M.PlayerClass = PlayerClass


---@class Player
---@field name string
---@field class string
---@field online boolean
---@field type "Player"

---@alias MakePlayerFn fun(
---  name: string,
---  class: PlayerClass,
---  online: boolean ): Player

---@type MakePlayerFn
function M.make_player( name, class, online )
  ---@type Player
  return {
    name = name,
    class = class,
    online = online,
    type = PlayerType.Player
  }
end

--- Roller is a RollingPlayer that's not in the group (so we don't know their class).
---@class Roller
---@field name string
---@field rolls number
---@field type "Roller"

---@alias MakeRollerFn fun(
---  name: string,
---  rolls: number ): Roller

---@type MakeRollerFn
---@param name string
---@param rolls number
---@return Roller
function M.make_roller( name, rolls )
  return {
    name = name,
    rolls = rolls,
    type = PlayerType.Roller
  }
end

---@class RollingPlayer
---@field name string
---@field class string
---@field online boolean
---@field rolls number
---@field type "RollingPlayer"

---@alias MakeRollingPlayerFn fun(
---  name: string,
---  class: PlayerClass,
---  online: boolean,
---  rolls: number ): RollingPlayer

---@type MakeRollingPlayerFn
---@param name string
---@param class PlayerClass
---@param online boolean
---@param rolls number
---@return RollingPlayer
function M.make_rolling_player( name, class, online, rolls )
  return {
    name = name,
    class = class,
    online = online,
    rolls = rolls,
    type = PlayerType.RollingPlayer
  }
end

---@class ItemCandidate
---@field name string
---@field class string
---@field online boolean
---@field type "ItemCandidate"

---@alias MakeItemCandidateFn fun(
---  name: string,
---  class: PlayerClass,
---  online: boolean ): ItemCandidate

---@type MakeItemCandidateFn
---@param name string
---@param class PlayerClass
---@param online boolean
---@return ItemCandidate
function M.make_item_candidate( name, class, online )
  return {
    name = name,
    class = class,
    online = online,
    type = PlayerType.ItemCandidate
  }
end

---@class Winner
---@field name string
---@field class string
---@field item Item|MasterLootDistributableItem -- TODO: remove
---@field is_on_master_loot_candidate_list boolean -- TODO: remove
---@field roll_type RollType
---@field winning_roll number?
---@field rerolling boolean?
---@field type "Winner"

---@alias MakeWinnerFn fun(
---  name: string,
---  class: PlayerClass,
---  item: Item|MasterLootDistributableItem,
---  is_on_master_loot_candidate_list: boolean,
---  roll_type: RollType,
---  winning_roll: number?,
---  rerolling: boolean? ): Winner

---@type MakeWinnerFn
---@param name string
---@param class PlayerClass
---@param item Item|MasterLootDistributableItem
---@param is_on_master_loot_candidate_list boolean
---@param roll_type RollType
---@param winning_roll number?
---@param rerolling boolean?
---@return Winner
function M.make_winner( name, class, item, is_on_master_loot_candidate_list, roll_type, winning_roll, rerolling )
  return {
    name = name,
    class = class,
    item = item,
    is_on_master_loot_candidate_list = is_on_master_loot_candidate_list,
    roll_type = roll_type,
    winning_roll = winning_roll,
    rerolling = rerolling,
    type = PlayerType.Winner
  }
end

---@alias RollingStatus
---| "InProgress"
---| "TieFound"
---| "Waiting"
---| "Finished"
---| "Canceled"
---| "Awarded"
local RollingStatus = {
  Preview = "Preview",
  InProgress = "InProgress",
  TieFound = "TieFound",
  Waiting = "Waiting",
  Finished = "Finished",
  Canceled = "Canceled",
  Awarded = "Awarded"
}

M.RollingStatus = RollingStatus

---@alias LootAwardError
---| "FullBags"
---| "AlreadyOwnsUniqueItem"
---| "PlayerNotFound"
---| "CantAssignItemToThatPlayer"
local LootAwardError = {
  FullBags = "FullBags",
  AlreadyOwnsUniqueItem = "AlreadyOwnsUniqueItem",
  PlayerNotFound = "PlayerNotFound",
  CantAssignItemToThatPlayer = "CantAssignItemToThatPlayer"
}

M.LootAwardError = LootAwardError

---@class ItemQualityStr
---@field Poor number
---@field Common number
---@field Uncommon number
---@field Rare number
---@field Epic number
---@field Legendary number

---@type ItemQualityStr
local ItemQuality = {
  Poor = 0,
  Common = 1,
  Uncommon = 2,
  Rare = 3,
  Epic = 4,
  Legendary = 5
}

M.ItemQuality = ItemQuality

---@alias NotAceTimer any
---@alias TimerId number

---@class AceTimer
---@field ScheduleTimer fun( self: AceTimer, callback: function, delay: number, arg: any ): TimerId
---@field ScheduleRepeatingTimer fun( self: NotAceTimer, callback: function, delay: number, arg: any ): TimerId
---@field CancelTimer fun( self: AceTimer, timer_id: number )

---@class Roll
---@field player RollingPlayer
---@field roll_type RollType
---@field roll number

---@alias MakeRollFn fun(
---  player: RollingPlayer,
---  roll_type: RollType,
---  roll: number ): Roll

---@type MakeRollFn
---@param player RollingPlayer
---@param roll_type RollType
---@param roll number
---@return Roll
function M.make_roll( player, roll_type, roll )
  return { player = player, roll_type = roll_type, roll = roll }
end

m.Types = M
return M
