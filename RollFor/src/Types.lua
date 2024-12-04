---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.Types then return end

local M = {}

M.RollSlashCommand = {
  NormalRoll = "/rf",
  NoSoftResRoll = "/arf",
  RaidRoll = "/rr"
}

--- Roll type constants
---@alias RollType
---| '"MainSpec"'
---| '"OffSpec"'
---| '"Transmog"'
---| '"SoftRes"'
M.RollType = {
  MainSpec = "MainSpec",
  OffSpec = "OffSpec",
  Transmog = "Transmog",
  SoftRes = "SoftRes"
}

--- Rolling strategy constants
--- @alias RollingStrategy
---| '"NormalRoll"'
---| '"SoftResRoll"'
---| '"TieRoll"'
---| '"RaidRoll"'
local RollingStrategy = {
  NormalRoll = "NormalRoll",
  SoftResRoll = "SoftResRoll",
  TieRoll = "TieRoll",
  RaidRoll = "RaidRoll"
}

M.RollingStrategy = RollingStrategy

--- Player type constants
--- @alias PlayerType
--- | '"Player"'
--- | '"Winner"'
local PlayerType = {
  Player = "Player",
  Winner = "Winner",
}

M.PlayerType = PlayerType

--- Player class constants
---@alias PlayerClass
---| '"Druid"'
---| '"Hunter"'
---| '"Mage"'
---| '"Paladin"'
---| '"Priest"'
---| '"Rogue"'
---| '"Shaman"'
---| '"Warlock"'
---| '"Warrior"'
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

---@alias Player { name: string, class: string }

--- Represents a player.
--- @param name string The name of the player.
--- @param class PlayerClass The class of the player.
--- @return Player
M.player = function( name, class )
  return {
    name = name,
    class = class,
    type = PlayerType.Player
  }
end

--- Represents a player that won a roll.
---@param name string The name of the player.
---@param class PlayerClass The class of the player.
---@param roll_type RollType The type of the roll.
---@param roll number The roll value.
M.winner = function( name, class, roll_type, roll )
  return {
    name = name,
    class = class,
    roll_type = roll_type,
    roll = roll,
    type = PlayerType.Winner
  }
end

---@alias RollingStatus
---| '"InProgress"'
---| '"TieFound"'
---| '"Waiting"'
---| '"Finished"'
---| '"Canceled"'
local RollingStatus = {
  InProgress = "InProgress",
  TieFound = "TieFound",
  Waiting = "Waiting",
  Finished = "Finished",
  Canceled = "Canceled"
}

M.RollingStatus = RollingStatus

---@alias LootAwardError
---| '"FullBags"'
---| '"AlreadyOwnsUniqueItem"'
---| '"PlayerNotFound"'
local LootAwardError = {
  FullBags = "FullBags",
  AlreadyOwnsUniqueItem = "AlreadyOwnsUniqueItem",
  PlayerNotFound = "PlayerNotFound"
}

M.LootAwardError = LootAwardError

modules.Types = M
return M
