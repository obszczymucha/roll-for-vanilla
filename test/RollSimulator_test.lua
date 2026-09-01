package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/libs/?.lua"

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" )
local player, leader, is_in_raid = u.player, u.raid_leader, u.is_in_raid

local function mock_config()
  return {
    new = function()
      return {
        auto_raid_roll = function() return false end,
        auto_round_robin = function() return false end,
        minimap_button_hidden = function() return false end,
        minimap_button_locked = function() return false end,
        subscribe = function() end,
        rolling_popup_lock = function() return true end,
        ms_roll_threshold = function() return 100 end,
        os_roll_threshold = function() return 99 end,
        roll_threshold = function()
          return {
            value = 100,
            str = "/roll"
          }
        end,
        auto_loot = function() return true end,
        rolling_popup = function() return true end,
        raid_roll_again = function() return false end,
        default_rolling_time_seconds = function() return 8 end,
        classic_look = function() return true end,
        sr_roll_spacing = function() return 24 end,
        resistance_bonus_rolls_enabled = function() return true end
      }
    end
  }
end

---@type ModuleRegistry
local module_registry = {
  { module_name = "Config",  mock = mock_config },
  { module_name = "ChatApi", mock = "mocks/ChatApi", variable_name = "chat" }
}

local m = {}

local SHAHRAZ = "Mother Shahraz"
local COUNCIL = "The Illidari Council"
local PENDANT = 32370 -- Nadina's Pendant of Purity, Mother Shahraz
local CLOAK = 32331   -- Cloak of the Illidari Council

RollSimulatorSpec = {}

-- /rfsetup replaces softres.get in place to get around SoftResPresentPlayersDecorator
-- capturing the roster as an upvalue. That replacement has to keep every layer *above*
-- present-players running -- it used to hardcode the layer beneath it, which silently
-- dropped bonus rolls out of the simulator the moment a decorator went on top.
function RollSimulatorSpec:should_offer_bonus_rolls_in_the_simulator()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Drutree", "Mendunia" )
  local rf = u.load_roll_for()
  rf.resistance_bonus_roll_registry.reset()
  rf.resistance_bonus_roll_registry.grant( "Drutree", SHAHRAZ, "Warrior" )

  -- When
  u.run_command( "RFSETUP", string.format( "%s Drutree,Mendunia", u.item_link( "Nadina's Pendant of Purity", PENDANT ) ) )

  -- Then
  local rollers = rf.softres.get( { item_id = PENDANT, item_quantity = 1 } )
  eq( u.map( rollers, function( p ) return { p.name, p.bonus_rolls } end ), {
    { "Drutree", 1 },
    { "Mendunia", 0 }
  } )
end

-- The rank rule has to survive the simulator too: a Mother item is worth only the roll
-- that existed when Mother died.
function RollSimulatorSpec:should_apply_the_boss_rank_rule_in_the_simulator()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Drutree", "Mendunia" )
  local rf = u.load_roll_for()
  rf.resistance_bonus_roll_registry.reset()
  rf.resistance_bonus_roll_registry.grant( "Drutree", SHAHRAZ, "Warrior" )
  rf.resistance_bonus_roll_registry.grant( "Drutree", COUNCIL, "Warrior" )

  -- When
  u.run_command( "RFSETUP", string.format( "%s Drutree,Mendunia", u.item_link( "Nadina's Pendant of Purity", PENDANT ) ) )

  -- Then (the Council roll is worth nothing on Mother loot)
  local mother_rollers = rf.softres.get( { item_id = PENDANT, item_quantity = 1 } )
  eq( mother_rollers[ 1 ].bonus_rolls, 1 )

  -- Then (both count on Council loot)
  local council_rollers = rf.softres.get( { item_id = CLOAK, item_quantity = 1 } )
  eq( council_rollers[ 1 ] and council_rollers[ 1 ].bonus_rolls or 0, 0 ) -- nobody soft-ressed the cloak
  eq( rf.resistance_bonus_roll_registry.count_for_item( "Drutree", CLOAK ), 2 )
end

-- The simulator still has to filter out anyone who isn't in the fake raid, which is the
-- job the replaced layer was doing in the first place.
function RollSimulatorSpec:should_still_drop_soft_ressers_outside_the_fake_raid()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Drutree", "Mendunia" )
  local rf = u.load_roll_for()
  rf.resistance_bonus_roll_registry.reset()

  -- When (only Drutree is named, so Mendunia is not in the simulated group)
  u.run_command( "RFSETUP", string.format( "%s Drutree", u.item_link( "Nadina's Pendant of Purity", PENDANT ) ) )

  -- Then
  local rollers = rf.softres.get( { item_id = PENDANT, item_quantity = 1 } )
  eq( u.map( rollers, function( p ) return p.name end ), { "Drutree" } )
end

u.mock_libraries()
u.load_real_stuff_and_inject( module_registry, m )

os.exit( lu.LuaUnit.run( "-v", "-T", "Spec", "-m", "should", "-o", "text" ) )
