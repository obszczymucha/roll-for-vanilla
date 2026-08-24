RollFor = RollFor or {}
local m = RollFor

if m.Sandbox then return end

local M = {}

---@class Sandbox
---@field run fun( args: string? )
---@field setup fun( args: string? )
---@field roll fun( args: string? )

-- Dev harness for eyeballing the rolling popup without a raid, loot or master loot.
-- It feeds the popup handcrafted roll data directly, bypassing the loot facade and the
-- rolling logic, so it works solo.
--
--   /rft      render the next scenario
--   /rft <n>  render scenario n
--   /rft ?    list the scenarios
--
-- Scenarios 4 and 5 are the frame-pooling check: run them back to back without closing
-- the popup in between and make sure no stale cells survive the shrink to one column.
--
-- /rfsetup drives the *real* pipeline instead - rolling logic, tie detection, winners,
-- chat - by faking a raid and a soft-res import:
--
--   /rfsetup 2x[Item] Drutree,Mendunia,Pinp 2,1,1
--   /rfr Drutree 56
--   /rfsetup reset
--
-- The item has to be a real link (shift-click it) or an item id, because that is what
-- ArgsParser matches on. Roll counts are positional and default to 1.
---@param main table
function M.new( main )
  local RT = m.Types.RollType
  local RS = m.Types.RollingStrategy
  local make_player = m.Types.make_player
  local hearthstone = 6948

  local step = 0
  local saved

  -- Cycled so the rows come out in different class colours.
  local sim_classes = { "Warrior", "Mage", "Rogue", "Priest", "Druid", "Hunter", "Paladin", "Shaman", "Warlock" }

  ---@param name string
  ---@param class PlayerClass
  ---@param roll number?
  ---@param ordinal number?
  local function sr( name, class, roll, ordinal )
    return { player_name = name, player_class = class, roll_type = RT.SoftRes, roll = roll, ordinal = ordinal }
  end

  ---@param name string
  ---@param class PlayerClass
  ---@param roll number
  ---@param roll_type RollType
  local function normal( name, class, roll, roll_type )
    return { player_name = name, player_class = class, roll_type = roll_type, roll = roll }
  end

  local function make_item()
    ---@diagnostic disable-next-line: redundant-parameter
    local _, link = m.api.GetItemInfo( hearthstone )
    link = link or "|cffffffff|Hitem:6948::::::::20:257::::::|h[Hearthstone]|h|r"

    return link, m.ItemUtils.get_tooltip_link( link ), m.get_item_texture( m.api, hearthstone )
  end

  ---@param rolls table[]
  ---@param strategy RollingStrategyType?
  local function roll_popup( rolls, strategy )
    local link, tooltip_link, texture = make_item()

    -- The transformer trusts its input to be sorted, exactly as RollTracker leaves it.
    m.RollingLogicUtils.sort_roll_data( rolls )

    ---@type RollingPopupRollData
    return {
      item_link = link,
      item_tooltip_link = tooltip_link,
      item_texture = texture,
      item_count = 2,
      item_quantity = 1,
      rolls = rolls,
      winners = {},
      -- Without a Close button the popup also loses its Esc binding, which would leave
      -- the scenario stuck on screen.
      buttons = { { type = "Close", callback = function() main.rolling_popup.hide() end } },
      strategy_type = strategy or RS.SoftResRoll,
      type = "Roll"
    }
  end

  local scenarios = {
    {
      "pending only - a 2-roll and two 1-roll soft-ressers. Pips and names should align.",
      function()
        return roll_popup( {
          sr( "Drutree", "Warrior" ),
          sr( "Drutree", "Warrior" ),
          sr( "Mendunia", "Mage" ),
          sr( "Pinp", "Rogue" )
        } )
      end
    },
    {
      "part-way - Drutree cast one of two rolls, the rest are pending.",
      function()
        return roll_popup( {
          sr( "Drutree", "Warrior", 75, 1 ),
          sr( "Drutree", "Warrior" ),
          sr( "Mendunia", "Mage" ),
          sr( "Pinp", "Rogue" )
        } )
      end
    },
    {
      "all cast - cells read in cast order, the best one is bright and the spent ones dim. " ..
      "Drutree sorts above Mendunia (96 > 91) while his left cell reads lower (69 < 87).",
      function()
        return roll_popup( {
          sr( "Drutree", "Warrior", 69, 1 ),
          sr( "Mendunia", "Mage", 87, 2 ),
          sr( "Drutree", "Warrior", 96, 3 ),
          sr( "Mendunia", "Mage", 91, 4 ),
          sr( "Pinp", "Rogue", 32, 5 )
        } )
      end
    },
    {
      "wide - a 3-roll soft-resser, so every row is 3 cells. Run 5 next, without closing.",
      function()
        return roll_popup( {
          sr( "Mufasapowel", "Priest", 91, 1 ),
          sr( "Mufasapowel", "Priest", 50, 2 ),
          sr( "Mufasapowel", "Priest", 12, 3 ),
          sr( "Drutree", "Warrior", 75, 4 ),
          sr( "Drutree", "Warrior" ),
          sr( "Mendunia", "Mage" )
        } )
      end
    },
    {
      "narrow - one cell per row. POOLING CHECK: after 4, no stale cells may remain.",
      function()
        return roll_popup( {
          sr( "Drutree", "Warrior", 75, 1 ),
          sr( "Mendunia", "Mage" )
        } )
      end
    },
    {
      "tie - the tie list under the main list, name columns must line up.",
      function()
        local roll_data = roll_popup( {
          sr( "Mufasapowel", "Priest", 91, 1 ),
          sr( "Mufasapowel", "Priest", 50, 3 ),
          sr( "Drutree", "Warrior", 75, 2 ),
          sr( "Pinp", "Rogue", 75, 4 ),
          sr( "Mendunia", "Mage", 32, 5 )
        } )

        ---@type RollingPopupTieData
        return {
          roll_data = roll_data,
          tie_iterations = { {
            tied_roll = 75,
            rolls = { sr( "Drutree", "Warrior" ), sr( "Pinp", "Rogue" ) }
          } },
          type = "Tie"
        }
      end
    },
    {
      "regression canary - MS/OS rolls stay ungrouped: centered names, per-row roll type.",
      function()
        return roll_popup( {
          normal( "Drutree", "Warrior", 96, RT.MainSpec ),
          normal( "Mendunia", "Mage", 69, RT.MainSpec ),
          normal( "Pinp", "Rogue", 42, RT.OffSpec )
        }, RS.NormalRoll )
      end
    }
  }

  local function list()
    m.info( "Rolling popup scenarios:" )

    for i, scenario in ipairs( scenarios ) do
      m.info( string.format( "%s. %s", m.colors.hl( i ), scenario[ 1 ] ) )
    end
  end

  ---@param args string?
  local function run( args )
    local requested = args and tonumber( (string.gsub( args, "%s", "" )) )

    if args and string.find( args, "?", 1, true ) then return list() end

    if requested then
      if not scenarios[ requested ] then
        m.info( string.format( "No such scenario: %s. Type %s to list them.", m.colors.hl( requested ), m.colors.hl( "/rft ?" ) ) )
        return
      end

      step = requested
    else
      step = m.mod( step, m.getn( scenarios ) ) + 1
    end

    local scenario = scenarios[ step ]
    m.info( string.format( "%s. %s", m.colors.hl( step ), scenario[ 1 ] ) )

    main.rolling_popup:show()
    main.rolling_popup:refresh( scenario[ 2 ]() )
  end

  -- GroupRoster and PlayerInfo are plain tables of closures that every other component
  -- captured by reference, so overwriting their fields in place is what makes the fake
  -- raid visible everywhere. Originals are kept so `reset` can put them back.
  ---@param players Player[]
  local function fake_group( players )
    local roster, info = main.group_roster, main.player_info

    if not saved then
      saved = {
        get_all_players_in_my_group = roster.get_all_players_in_my_group,
        get_group_players = roster.get_group_players,
        get_group_unit_tokens = roster.get_group_unit_tokens,
        is_player_in_my_group = roster.is_player_in_my_group,
        find_player = roster.find_player,
        am_i_in_group = roster.am_i_in_group,
        am_i_in_raid = roster.am_i_in_raid,
        is_master_looter = info.is_master_looter,
        announce = main.chat.announce,
        softres_get = main.softres.get,
        softres_get_all_rollers = main.softres.get_all_rollers
      }
    end

    -- Chat.announce always SendChatMessage's to RAID or PARTY. Solo that goes nowhere, and
    -- the announcements are half of what there is to check, so echo them locally instead.
    main.chat.announce = function( text, use_raid_warning )
      m.info( string.format( "%s %s", m.colors.hl( use_raid_warning and "[RW]" or "[RAID]" ), text ) )
    end

    local by_name = {}
    for _, player in ipairs( players ) do by_name[ player.name ] = player end

    roster.get_all_players_in_my_group = function( f )
      local result = {}

      for _, player in ipairs( players ) do
        if not f or f( player ) then table.insert( result, player ) end
      end

      return result
    end

    roster.get_group_players = function()
      local result = {}

      for i, player in ipairs( players ) do
        table.insert( result, { name = player.name, class = player.class, online = true, unit = "raid" .. i } )
      end

      return result
    end

    roster.get_group_unit_tokens = function()
      local result = {}
      for i = 1, m.getn( players ) do table.insert( result, "raid" .. i ) end
      return result
    end

    -- SoftResPresentPlayersDecorator captures group_roster.is_player_in_my_group as an
    -- upvalue when it is constructed, so overriding the roster afterwards cannot reach it
    -- and every simulated soft-resser is filtered out as absent. Skip just that layer by
    -- delegating to the one beneath it, which keeps the awarded-loot and nether-vortex
    -- decorators in play, and do its class enrichment here.
    local function enrich( rollers )
      for _, roller in ipairs( rollers or {} ) do
        local player = by_name[ roller.name ]
        roller.class = player and player.class
      end

      return rollers
    end

    main.softres.get = function( item_data ) return enrich( main.nether_vortex_softres.get( item_data ) ) end
    main.softres.get_all_rollers = function() return enrich( main.nether_vortex_softres.get_all_rollers() ) end

    roster.is_player_in_my_group = function( name ) return by_name[ name ] and true or false end
    roster.find_player = function( name ) return by_name[ name ] end
    roster.am_i_in_group = function() return true end
    roster.am_i_in_raid = function() return true end
    info.is_master_looter = function() return true end
  end

  local function reset()
    if not saved then
      m.info( "Nothing to reset." )
      return
    end

    local roster, info = main.group_roster, main.player_info

    roster.get_all_players_in_my_group = saved.get_all_players_in_my_group
    roster.get_group_players = saved.get_group_players
    roster.get_group_unit_tokens = saved.get_group_unit_tokens
    roster.is_player_in_my_group = saved.is_player_in_my_group
    roster.find_player = saved.find_player
    roster.am_i_in_group = saved.am_i_in_group
    roster.am_i_in_raid = saved.am_i_in_raid
    info.is_master_looter = saved.is_master_looter
    main.chat.announce = saved.announce
    main.softres.get = saved.softres_get
    main.softres.get_all_rollers = saved.softres_get_all_rollers
    saved = nil

    main.unfiltered_softres.import( nil )
    m.info( "Simulation off. Soft-res data is cleared - re-import yours." )
  end

  local function setup_usage()
    m.info( string.format( "Usage: %s", m.colors.hl( "/rfsetup 2x[Item] Drutree,Mendunia,Pinp 2,1,1" ) ) )
    m.info( "Shift-click the item to insert its link. Roll counts are positional, default 1." )
    m.info( string.format( "Omit the names for a normal roll. %s injects a roll, %s ends it.",
      m.colors.hl( "/rfr <name> <roll>" ), m.colors.hl( "/rfsetup reset" ) ) )
  end

  ---@param args string?
  local function setup( args )
    args = args or ""

    if string.find( args, "^%s*reset" ) then return reset() end
    if string.find( args, "^%s*$" ) or string.find( args, "^%s*%?" ) then return setup_usage() end

    local item, count, _, rest = main.args_parser.parse( args )

    if not item then
      m.info( "Could not read an item out of that." )
      setup_usage()
      return
    end

    local names, counts = string.match( rest or "", "^%s*([^%s]*)%s*([^%s]*)" )

    local roll_counts = {}
    for n in string.gmatch( counts or "", "%d+" ) do table.insert( roll_counts, tonumber( n ) ) end

    local players, soft_reserves = {}, {}
    local i = 0

    for name in string.gmatch( names or "", "[^,]+" ) do
      i = i + 1
      local rolls = roll_counts[ i ] or 1
      table.insert( players, make_player( name, sim_classes[ m.mod( i - 1, m.getn( sim_classes ) ) + 1 ], true ) )

      -- One entry per roll: duplicates in a raidres import are what grant extra rolls.
      local items = {}
      for _ = 1, rolls do table.insert( items, { id = item.id, quality = item.quality or 3 } ) end
      table.insert( soft_reserves, { name = name, items = items } )
    end

    fake_group( players )

    main.unfiltered_softres.import( {
      metadata = { id = "SIM", instance = 0, instances = {}, origin = "raidres" },
      softreserves = soft_reserves,
      hardreserves = {}
    } )

    -- Rolling this item before leaves a finished RollTracker behind, and preview() would
    -- re-open that finished popup instead of starting over.
    main.roll_controller.reset_item( item.id )

    m.info( string.format( "Simulating %s%s with %s soft-resser%s. %s to end.",
      count > 1 and (count .. "x") or "", item.link,
      m.colors.hl( m.getn( players ) ), m.getn( players ) == 1 and "" or "s",
      m.colors.hl( "/rfsetup reset" ) ) )

    main.roll_controller.preview( item, count )
  end

  -- Goes in through the real chat parser, so it exercises roll acceptance, tie detection
  -- and the winner announcements rather than just the popup.
  ---@param args string?
  local function roll( args )
    local name, value, spec = string.match( args or "", "^%s*(%S+)%s+(%d+)%s*(%S*)" )

    if not name then
      m.info( string.format( "Usage: %s (add %s for an off-spec roll)",
        m.colors.hl( "/rfr <name> <roll>" ), m.colors.hl( "os" ) ) )
      return
    end

    -- RollingLogic.on_roll is a no-op until a strategy is rolling, and /rfsetup only opens
    -- the preview - so without this the roll vanishes with no explanation.
    if not main.rolling_logic.is_rolling() then
      m.info( string.format( "Not rolling yet - press %s on the popup first.", m.colors.hl( "Roll" ) ) )
      return
    end

    local upper = (spec == "os" or spec == "OS") and main.config.os_roll_threshold() or main.config.ms_roll_threshold()
    main.on_chat_msg_system( string.format( "%s rolls %d (1-%d)", name, tonumber( value ), upper ) )
  end

  m.slash_cmd( "rft", run )
  m.slash_cmd( "rfsetup", setup )

  ---@type Sandbox
  return {
    run = run,
    setup = setup,
    roll = roll
  }
end

m.Sandbox = M
return M
