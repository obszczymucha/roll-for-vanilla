RollFor = RollFor or {}
local m = RollFor

if m.TieRollGuiData then return end

local clear_table = m.clear_table
local blue = m.colors.blue

local M = {}

local first_roll_padding = 7

function M.new( group_roster )
  local tie_roll_iterations = {}
  -- It is possible to have multiple ties in a row.
  -- We're pro so we will cover all scenarios.
  local current_tie_roll_iteration = 0

  local function update_padding( content )
    local first = true

    for _, v in ipairs( content ) do
      v.padding = first and first_roll_padding or nil
      first = false
    end
  end

  local function sort( content )
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

    update_padding( content )
  end

  local function add_roll( player_name, roll )
    local iteration = tie_roll_iterations[ current_tie_roll_iteration ]

    for _, v in ipairs( iteration.content ) do
      if v.player_name == player_name and not v.roll then
        v.roll = roll
        sort( iteration.content )
        return
      end
    end
  end

  local function waiting_for_rolls( content )
    for _, v in ipairs( content ) do
      if not v.roll then
        return true
      end
    end

    return false
  end

  local function get()
    local result = {}

    for _, iteration in ipairs( tie_roll_iterations ) do
      table.insert( result, { type = "text", value = string.format( "There was a tie (%s):", blue( iteration.roll ) ), padding = 10 } )

      for _, v in ipairs( iteration.content ) do
        table.insert( result, v )
      end

      if waiting_for_rolls( iteration.content ) then
        table.insert( result, { type = "text", value = "Waiting for remaining rolls...", padding = 10 } )
      end
    end

    return result
  end

  local function populate_rolls( tied_player_names, roll_type, roll )
    local content = {}

    for _, player_name in ipairs( tied_player_names ) do
      local player = group_roster.find_player( player_name )

      table.insert( content, {
        type = "roll",
        roll_type = roll_type,
        player_name = player_name,
        player_class = player.class,
        roll = nil,
      } )
    end

    sort( content )
    table.insert( tie_roll_iterations, { roll = roll, roll_type = roll_type, content = content } )
    current_tie_roll_iteration = current_tie_roll_iteration + 1
  end

  local function clear()
    clear_table( tie_roll_iterations )
    if m.vanilla then tie_roll_iterations.n = 0 end
    current_tie_roll_iteration = 0
  end

  local function start( tied_player_names, roll_type, roll )
    populate_rolls( tied_player_names, roll_type, roll )
  end

  return {
    clear = clear,
    start = start,
    add_roll = add_roll,
    get = get
  }
end

m.TieRollGuiData = M
return M
