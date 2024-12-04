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

M.RollType = {
  MainSpec = "main-spec",
  OffSpec = "off-spec",
  Transmog = "transmog",
  SoftRes = "soft-res",
  RaidRoll = "raid-roll"
}

M.RollingStrategy = {
  NormalRoll = "normal",
  SoftResRoll = "soft-res",
  TieRoll = "tie-roll",
  RaidRoll = "raid-roll"
}

modules.Types = M
return M
