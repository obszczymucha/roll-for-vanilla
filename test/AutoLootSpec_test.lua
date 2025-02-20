package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

local u = require( "test/utils" )
local lu = u.luaunit()
local builder = require( "test/IntegrationTestBuilder" )
local ItemUtils = require( "src/ItemUtils" )
local new_roll_for = builder.new_roll_for
local qi = builder.qi
local boe, bop, quest = ItemUtils.BindType.BindOnEquip, ItemUtils.BindType.BindOnPickup, ItemUtils.BindType.Quest

AutoLootSpec = {}

function AutoLootSpec:should_autoloot_low_quality_items()
  local item = qi( "Pocket Lint", 123, 1, boe )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )
end

function AutoLootSpec:should_not_autoloot_high_quality_items()
  local item = qi( "Sword of Causing Damage", 123, 5, boe )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:should_not_autoloot_bop_items_of_any_quality()
  local item = qi( "Scythe of Healing", 123, 1, bop )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:should_not_autoloot_quest_items_of_any_quality()
  local item = qi( "Ancient Secret Text", 123, 1, quest )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:autoloot_should_depend_on_loot_threshold()
  local rf_builder = new_roll_for()
      :config( {
        auto_loot = true
      } )

  local item = qi( "Fire for Crafting", 123, 2, boe )

  local rf_low_threshold = rf_builder:threshold( 2 ):build()
  lu.assertEquals( rf_low_threshold.auto_loot.is_auto_looted( item ), true )

  local rf_high_threshold = rf_builder:threshold( 3 ):build()
  lu.assertEquals( rf_high_threshold.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:should_autoloot_any_explicitly_added_items()
  local item = qi( "Fire for Crafting", 123, 4, bop )

  local rf = new_roll_for()
      :config( {
        auto_loot = true
      } )
      :build()

  rf.auto_loot.add( item.link )

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), true )

  rf.auto_loot.remove( item.link )

  lu.assertEquals( rf.auto_loot.is_auto_looted( item ), false )
end

function AutoLootSpec:should_not_autoloot_if_config_option_is_false()
  local low_quality_item = qi( "Pocket Lint", 123, 1, boe )
  local explicitly_added_item = qi( "Fire for Crafting", 123, 4, bop )

  local rf = new_roll_for()
      :config( {
        auto_loot = false
      } )
      :build()

  rf.auto_loot.add( explicitly_added_item.link )

  lu.assertEquals( rf.auto_loot.is_auto_looted( low_quality_item ), false )
  lu.assertEquals( rf.auto_loot.is_auto_looted( explicitly_added_item ), false )
end

os.exit( lu.LuaUnit.run() )
