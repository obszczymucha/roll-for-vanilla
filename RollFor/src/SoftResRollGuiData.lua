RollFor = RollFor or {}
local m = RollFor

if m.SoftResRollGuiData then return end

local clear = m.clear_table
local RollType = m.Types.RollType

-- I take the list of players who soft res an item
-- and generate the data for RollingPopup to display.
local M = {}

function M.new( softres, group_roster )
  local content = {}

  local function update_padding()
    local first = true

    for _, v in ipairs( content ) do
      v.padding = first and 10 or nil
      first = false
    end
  end

  local function sort()
    table.sort( content, function( a, b )
      if not a.roll and not b.roll then
        return a.player_name < b.player_name
      end

      if not a.roll then
        return false
      end

      if not b.roll then
        return true
      end

      if a.roll == b.roll then
        return a.player_name < b.player_name
      end

      return a.roll > b.roll
    end )

    update_padding()
  end

  local function add_roll( player_name, roll )
    for _, v in ipairs( content ) do
      if v.player_name == player_name and not v.roll then
        v.roll = roll
        sort()
        return
      end
    end
  end

  local function get()
    return content
  end

  local function populate_rolls( item_id )
    local players = softres.get( item_id )
    local first = true

    for _, sr_player in ipairs( players ) do
      local player = group_roster.find_player( sr_player.name )

      for _ = 1, sr_player.rolls do
        table.insert( content, {
          type = "roll",
          roll_type = RollType.SoftRes,
          player_name = sr_player.name,
          player_class = player.class,
          roll = nil,
          padding = first and 10 or nil
        } )

        first = false
      end
    end
  end

  local function start( item_id )
    clear( content )
    if m.vanilla then content.n = 0 end

    populate_rolls( item_id )
  end

  return {
    start = start,
    add_roll = add_roll,
    get = get
  }
end

m.SoftResRollGuiData = M
return M
