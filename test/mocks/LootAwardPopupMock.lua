---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.LootAwardPopup then return end

local utils = require( "test/utils" )

local M = {}

function M.new( _, _, callback )
  utils.register_loot_confirm_callback( callback )

  return {
    show = function() end,
    hide = function() end,
  }
end

modules.LootAwardPopup = M
return M
