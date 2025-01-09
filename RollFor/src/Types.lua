RollFor = RollFor or {}
local m = RollFor

if m.Types then return end

local M = {}

---@alias PlayerName string
---@alias ItemId number

M.RollSlashCommand = {
  NormalRoll = "/rf",
  NoSoftResRoll = "/arf",
  RaidRoll = "/rr",
  InstaRaidRoll = "/irr"
}

---@alias RollType
---| "MainSpec"
---| "OffSpec"
---| "Transmog"
---| "SoftRes"
M.RollType = {
  MainSpec = "MainSpec",
  OffSpec = "OffSpec",
  Transmog = "Transmog",
  SoftRes = "SoftRes"
}

--- @alias RollingStrategy
---| "NormalRoll"
---| "SoftResRoll"
---| "TieRoll"
---| "RaidRoll"
---| "InstaRaidRoll"
local RollingStrategy = {
  NormalRoll = "NormalRoll",
  SoftResRoll = "SoftResRoll",
  TieRoll = "TieRoll",
  RaidRoll = "RaidRoll",
  InstaRaidRoll = "InstaRaidRoll"
}

M.RollingStrategy = RollingStrategy

---@alias PlayerType
---| "Player"
---| "Roller"
---| "RollingPlayer"
---| "Winner"
local PlayerType = {
  Player = "Player",
  Roller = "Roller",
  RollingPlayer = "RollingPlayer",
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
---@field type PlayerType

--- Roller is a RollingPlayer that's not in the group (so we don't know their class).
---@class Roller
---@field name string
---@field rolls number
---@field type PlayerType

---@class RollingPlayer
---@field name string
---@field class string
---@field rolls number
---@field type PlayerType

---@class Winner
---@field name string
---@field class string
---@field roll_type RollType
---@field roll number
---@field type PlayerType

---@param name string
---@param class PlayerClass
---@return Player
function M.make_player( name, class )
  return {
    name = name,
    class = class,
    type = PlayerType.Player
  }
end

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

---@param name string
---@param class PlayerClass
---@param rolls number
---@return RollingPlayer
function M.make_rolling_player( name, class, rolls )
  return {
    name = name,
    class = class,
    rolls = rolls,
    type = PlayerType.RollingPlayer
  }
end

--- Represents a player that won a roll.
---@param name string The name of the player.
---@param class PlayerClass The class of the player.
---@param roll_type RollType The type of the roll.
---@param roll number The roll value.
---@return Winner
function M.make_winner( name, class, roll_type, roll )
  return {
    name = name,
    class = class,
    roll_type = roll_type,
    roll = roll,
    type = PlayerType.Winner
  }
end

---@alias RollingStatus
---| "InProgress"
---| "TieFound"
---| "Waiting"
---| "Finished"
---| "Canceled"
local RollingStatus = {
  Preview = "Preview",
  InProgress = "InProgress",
  TieFound = "TieFound",
  Waiting = "Waiting",
  Finished = "Finished",
  Canceled = "Canceled"
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

---@class WinningRoll
---@field player RollingPlayer
---@field roll_type RollType
---@field roll number
---@field value number | nil -- Master Loot candidate value

---@param player RollingPlayer
---@param roll_type RollType
---@param roll number
---@return WinningRoll
function M.make_winning_roll( player, roll_type, roll )
  return { player = player, roll_type = roll_type, roll = roll }
end

m.Types = M
return M
