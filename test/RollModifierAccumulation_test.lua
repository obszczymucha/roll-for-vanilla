package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua"

-- Two modifiers, through the real thing, from the drop announcement to the award.
--
-- RollModifiers_test covers the seam as a unit. This is the case that proves it is a seam:
-- two extensions that have never heard of each other both change the same roll, the raid is
-- told one combined number before anybody rolls and the full decomposition afterwards, and
-- core is the only thing that knows both of them exist.
--
-- It is also where the tie bug is pinned down. A modifier that declares only the soft-res
-- round contributes nothing to a tie re-roll, so the re-roll announces the bare number --
-- which is what the old SR+ got wrong, by re-deriving the composition from the soft-res
-- store instead of reading what the roll recorded.

require( "src/compat" )
local u = require( "test/utils" )
local lu, eq = u.luaunit( "assertEquals" ) ---@diagnostic disable-line: unused-local
local sr = u.soft_res_item
local builder = require( "test/IntegrationTestBuilder" )
local mock_loot_facade, mock_chat, new_roll_for = builder.mock_loot_facade, builder.mock_chat, builder.new_roll_for
local i, p = builder.i, builder.p

local RLU = RollFor.RollingLogicUtils
local RS = RollFor.Types.RollingStrategy

local BAG = 69

-- Two static bonuses that know nothing about each other, held in tables the test writes
-- and the modifiers read. This is the shape an extension's chain link would leave behind.
local sr_plus, role_bonus = {}, {}

local function register_modifiers()
  RLU.clear_modifiers()

  RLU.register_delta( {
    name = "sr_plus",
    rounds = { RS.SoftResRoll },
    apply = function( player ) return sr_plus[ player.name ] end
  } )

  RLU.register_delta( {
    name = "role_bonus",
    rounds = { RS.SoftResRoll, RS.NormalRoll, RS.TieRoll },
    apply = function( player ) return role_bonus[ player.name ] end
  } )
end

local function no_modifiers()
  RLU.clear_modifiers()
  sr_plus, role_bonus = {}, {}
end

AccumulationSpec = {}

-- 50 + 30 + 20 = 100, announced as exactly that, and previewed as one " (+50)" in both
-- places a name is printed before the rolling starts.
function AccumulationSpec:should_accumulate_two_modifiers_and_decompose_the_winning_roll()
  -- Given
  no_modifiers()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, item2, p1, p2 = i( "Bag", BAG ), i( "Hearthstone", 123 ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, BAG ), sr( p2.name, BAG ) )
      :build()

  sr_plus[ p1.name ] = 30
  role_bonus[ p1.name ] = 20
  register_modifiers()

  -- When
  loot_facade.notify( "LootOpened", item, item2 )

  -- Then: the drop announcement carries the combined bonus, summed into one number.
  chat.raid( "Princess Kenny dropped 2 items:" )
  chat.raid( "1. [Bag] (SR by Obszczymucha and Psikutas (+50))" )
  chat.raid( "2. [Hearthstone]" )

  -- When
  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )

  -- Then: and so does the roll call.
  chat.raid_warning( "Roll for [Bag]. SR by Obszczymucha and Psikutas (+50)" )

  -- When: Psikutas rolls 50, which is worth 100, and beats Obszczymucha's flat 99.
  rf.roll( p1, 50, 1, 100 )
  rf.roll( p2, 99, 1, 100 )

  -- Then: the breakdown, in the order the modifiers were placed.
  chat.console( "RollFor: Psikutas rolled the highest (50+30+20=100) for [Bag] (SR)." )
  chat.raid( "Psikutas rolled the highest (50+30+20=100) for [Bag] (SR)." )
end

-- Addition commutes. Registering them the other way round changes the order the breakdown
-- lists them in and nothing about who wins.
function AccumulationSpec:should_reach_the_same_total_whichever_order_they_registered_in()
  -- Given
  no_modifiers()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", BAG ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, BAG ), sr( p2.name, BAG ) )
      :build()

  sr_plus[ p1.name ] = 30
  role_bonus[ p1.name ] = 20

  RLU.clear_modifiers()
  RLU.register_delta( {
    name = "role_bonus",
    rounds = { RS.SoftResRoll },
    apply = function( player ) return role_bonus[ player.name ] end
  } )
  RLU.register_delta( {
    name = "sr_plus",
    rounds = { RS.SoftResRoll },
    apply = function( player ) return sr_plus[ player.name ] end
  } )

  -- When
  loot_facade.notify( "LootOpened", item )
  chat.raid( "Princess Kenny dropped 1 item:" )
  chat.raid( "1. [Bag] (SR by Obszczymucha and Psikutas (+50))" )

  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )
  chat.raid_warning( "Roll for [Bag]. SR by Obszczymucha and Psikutas (+50)" )

  rf.roll( p1, 50, 1, 100 )
  rf.roll( p2, 99, 1, 100 )

  -- Then
  chat.console( "RollFor: Psikutas rolled the highest (50+20+30=100) for [Bag] (SR)." )
  chat.raid( "Psikutas rolled the highest (50+20+30=100) for [Bag] (SR)." )
end

TieSpec = {}

-- SR-PLUS §6.1, reproduced and fixed. Psikutas holds +30 for the soft-res round only. He
-- rolls 39, which is worth 69 and ties Obszczymucha's flat 69. The tie round is a different
-- round, so nothing adjusts it -- and the announcement says the bare number the player
-- actually rolled, instead of subtracting a bonus that was never applied.
function TieSpec:should_announce_the_bare_number_after_a_tie_reroll()
  -- Given
  no_modifiers()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", BAG ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, BAG ), sr( p2.name, BAG ) )
      :build()

  sr_plus[ p1.name ] = 30
  RLU.clear_modifiers()
  RLU.register_delta( {
    name = "sr_plus",
    rounds = { RS.SoftResRoll },
    apply = function( player ) return sr_plus[ player.name ] end
  } )

  -- When
  loot_facade.notify( "LootOpened", item )
  chat.raid( "Princess Kenny dropped 1 item:" )
  chat.raid( "1. [Bag] (SR by Obszczymucha and Psikutas (+30))" )

  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )
  chat.raid_warning( "Roll for [Bag]. SR by Obszczymucha and Psikutas (+30)" )

  rf.roll( p1, 39, 1, 100 )
  rf.roll( p2, 69, 1, 100 )

  -- Then: 39+30 is 69, which ties. Two winners on one total, so no breakdown is shown --
  -- they did not get there the same way, and attributing either to both would be a lie.
  chat.console( "RollFor: Obszczymucha and Psikutas rolled the highest (69) for [Bag] (SR)." )
  chat.raid( "Obszczymucha and Psikutas rolled the highest (69) for [Bag] (SR)." )

  -- When: the tie round, which sr_plus does not take part in.
  rf.ace_timer.tick()
  chat.raid( "Obszczymucha and Psikutas /roll for [Bag] now." )
  rf.roll( p1, 50, 1, 100 )
  rf.roll( p2, 40, 1, 100 )

  -- Then: Psikutas rolled 50 and the raid is told 50.
  chat.console( "RollFor: Psikutas re-rolled the highest (50) for [Bag] (SR)." )
  chat.raid( "Psikutas re-rolled the highest (50) for [Bag] (SR)." )
end

-- The other half of the same rule: a modifier that *does* declare the tie round fires there
-- and says so, and the re-roll announcement decomposes correctly. Neither case needs a
-- special case anywhere -- the announcer is right whenever modifiers record what they did.
function TieSpec:should_decompose_a_tie_reroll_that_a_modifier_took_part_in()
  -- Given
  no_modifiers()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", BAG ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, BAG ), sr( p2.name, BAG ) )
      :build()

  role_bonus[ p1.name ] = 20
  RLU.clear_modifiers()
  RLU.register_delta( {
    name = "role_bonus",
    rounds = { RS.SoftResRoll, RS.TieRoll },
    apply = function( player ) return role_bonus[ player.name ] end
  } )

  -- When
  loot_facade.notify( "LootOpened", item )
  chat.raid( "Princess Kenny dropped 1 item:" )
  chat.raid( "1. [Bag] (SR by Obszczymucha and Psikutas (+20))" )

  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )
  chat.raid_warning( "Roll for [Bag]. SR by Obszczymucha and Psikutas (+20)" )

  rf.roll( p1, 49, 1, 100 )
  rf.roll( p2, 69, 1, 100 )

  chat.console( "RollFor: Obszczymucha and Psikutas rolled the highest (69) for [Bag] (SR)." )
  chat.raid( "Obszczymucha and Psikutas rolled the highest (69) for [Bag] (SR)." )

  -- When: the tie round, which role_bonus does take part in.
  rf.ace_timer.tick()
  chat.raid( "Obszczymucha and Psikutas /roll for [Bag] now." )
  rf.roll( p1, 40, 1, 100 )
  rf.roll( p2, 55, 1, 100 )

  -- Then: 40 plus 20 beats 55, and the raid is told how.
  chat.console( "RollFor: Psikutas re-rolled the highest (40+20=60) for [Bag] (SR)." )
  chat.raid( "Psikutas re-rolled the highest (40+20=60) for [Bag] (SR)." )
end

EmptySpec = {}

-- The guarantee the other 51 suites rest on, said out loud once: with nothing registered,
-- a roll is what was rolled and the announcement is the bare number.
function EmptySpec:should_change_nothing_with_no_modifiers_registered()
  -- Given
  no_modifiers()
  local loot_facade, chat = mock_loot_facade(), mock_chat()
  local item, p1, p2 = i( "Bag", BAG ), p( "Psikutas" ), p( "Obszczymucha" )
  local rf = new_roll_for()
      :loot_facade( loot_facade )
      :raid_roster( p1, p2 )
      :chat( chat )
      :soft_res_data( sr( p1.name, BAG ), sr( p2.name, BAG ) )
      :build()

  -- When
  loot_facade.notify( "LootOpened", item )
  chat.raid( "Princess Kenny dropped 1 item:" )
  chat.raid( "1. [Bag] (SR by Obszczymucha and Psikutas)" )

  rf.loot_frame.click( 1 )
  rf.rolling_popup.click( "Roll" )
  chat.raid_warning( "Roll for [Bag]. SR by Obszczymucha and Psikutas" )

  rf.roll( p1, 50, 1, 100 )
  rf.roll( p2, 99, 1, 100 )

  -- Then
  chat.console( "RollFor: Obszczymucha rolled the highest (99) for [Bag] (SR)." )
  chat.raid( "Obszczymucha rolled the highest (99) for [Bag] (SR)." )
end

os.exit( lu.LuaUnit.run() )
