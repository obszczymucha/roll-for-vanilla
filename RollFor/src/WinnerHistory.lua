RollFor = RollFor or {}
local m = RollFor

if m.WinnerHistory then return end

local M = {}

function M.new( db )
  local function start_session()
    db.current_session = m.lua.time()
    db.winners = db.winners or {}
    db.sessions = db.sessions or {}
    db.sessions[ db.current_session ] = {}
    db.sessions[ db.current_session ].zones = {}
    db.sessions[ db.current_session ].winners = {}
  end

  local function store_zone_count( zone_name )
    if not db.current_session or not db.sessions or not db.sessions[ db.current_session ] then start_session() end

    local count = db.sessions[ db.current_session ].zones[ zone_name ] or 0
    db.sessions[ db.current_session ].zones[ zone_name ] = count + 1
  end

  local function store_session_winner( player_name, item_id, item_link, zone_name, roll_type, winning_roll )
    if not db.current_session or not db.sessions or not db.sessions[ db.current_session ] then start_session() end
    local player = db.sessions[ db.current_session ].winners[ player_name ] or {}

    table.insert( player, {
      item_id = item_id,
      item_link = item_link,
      zone_name = zone_name,
      timestamp = m.lua.time(),
      roll_type = roll_type,
      winning_roll = winning_roll
    } )

    db.sessions[ db.current_session ].winners[ player_name ] = player
  end

  local function store_winner( player_name, item_id, item_link, zone_name, roll_type, winning_roll )
    db.winners = db.winners or {}
    db.winners[ player_name ] = db.winners[ player_name ] or {}

    table.insert( db.winners[ player_name ], {
      item_id = item_id,
      item_link = item_link,
      zone_name = zone_name,
      timestamp = m.lua.time(),
      roll_type = roll_type,
      winning_roll = winning_roll
    } )
  end

  local function add( player_name, item_id, item_link, roll_type, winning_roll )
    local zone_name = m.api.GetRealZoneText()

    store_zone_count( zone_name )
    store_session_winner( player_name, item_id, item_link, zone_name, roll_type, winning_roll )
    store_winner( player_name, item_id, item_link, zone_name, roll_type, winning_roll )
  end

  local function find( player_name, item_id )
    if not db.winners then return end
    return db.winners[ player_name ] and db.winners[ player_name ][ item_id ]
  end

  return {
    start_session = start_session,
    add = add,
    find = find
  }
end

m.WinnerHistory = M
return M
