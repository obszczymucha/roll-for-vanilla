RollFor = RollFor or {}
local m = RollFor

if m.Sandbox then return end

local M = {}

---@class Sandbox
---@field run fun( args: string? )

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
---@param main table
function M.new( main )
  local RT = m.Types.RollType
  local RS = m.Types.RollingStrategy
  local hearthstone = 6948

  local step = 0

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

  local function item()
    ---@diagnostic disable-next-line: redundant-parameter
    local _, link = m.api.GetItemInfo( hearthstone )
    link = link or "|cffffffff|Hitem:6948::::::::20:257::::::|h[Hearthstone]|h|r"

    return link, m.ItemUtils.get_tooltip_link( link ), m.get_item_texture( m.api, hearthstone )
  end

  ---@param rolls table[]
  ---@param strategy RollingStrategyType?
  local function roll_popup( rolls, strategy )
    local link, tooltip_link, texture = item()

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

  ---@type Sandbox
  return {
    run = run
  }
end

m.Sandbox = M
return M
