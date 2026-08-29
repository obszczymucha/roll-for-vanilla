RollFor = RollFor or {}
local m = RollFor

if m.ResistanceAnnouncer then return end

local M = {}

-- Reads the resistance list out to the group. ResistanceCheck owns the numbers;
-- this file turns its rows into one chat line each, as they arrive, and owns the
-- two settings that say whether and how much gets read out.

-- The two schools the list can report, in the shorthand the raid says out loud.
local school_labels = {
  [ m.ResistanceRegistry.ResistanceType.Fire ] = "FR",
  [ m.ResistanceRegistry.ResistanceType.Shadow ] = "SR"
}

---@class ResistanceAnnouncer
---@field announce fun()
---@field is_enabled fun(): boolean
---@field set_enabled fun( value: boolean )
---@field is_including_cached fun(): boolean
---@field set_including_cached fun( value: boolean )

-- What the number doesn't say on its own, in the order it gets read out. Food is
-- already counted in personal, so "(food)" only says part of it isn't gear.
---@param row ResistanceRow
---@return string -- empty when there's nothing to point out
local function notes( row )
  local result = {}

  if row.missing_neck then table.insert( result, "no neck" ) end
  if row.food then table.insert( result, "food" ) end
  if m.getn( result ) == 0 then return "" end

  return string.format( " (%s)", table.concat( result, ", " ) )
end

-- Personal rather than total: the raid buff is the raid's doing, and what's
-- being read out is what each player turned up with.
---@param row ResistanceRow
---@return string?  -- nil when the row has nothing to say
local function format_row( row )
  local school = school_labels[ row.resistance_type ]
  -- A player who was never scanned, or whom the inspect couldn't reach, has no
  -- number to announce. Saying nothing beats announcing a zero they didn't earn.
  if not school or not row.personal then return nil end

  return string.format( "%s %d %s%s", row.player_name, row.personal, school, notes( row ) )
end

---@param chat Chat
---@param resistance_check ResistanceCheck
---@param db table -- where the two settings are remembered
---@return ResistanceAnnouncer
function M.new( chat, resistance_check, db )
  -- Announcing to the raid is the point of the button, so it's on unless it was
  -- turned off. Repeating numbers that were already read out on an earlier check
  -- is not, so that one is off unless it was turned on. Both are written back on
  -- first read, so what the checkboxes show is what's stored.
  if db.enabled == nil then db.enabled = true end
  if db.include_cached == nil then db.include_cached = false end

  -- Announcing runs as a session, opened by announce() and closed when the scan
  -- it kicked off runs dry. Outside one, results still land -- a scan can outlive
  -- the click that started it -- and nothing is said about them. Inside one,
  -- every player is announced once: the set is what keeps a redraw from repeating
  -- lines that already went out.
  local m_active = false
  local m_announced = {}

  local function is_enabled() return db.enabled and true or false end

  local function is_including_cached() return db.include_cached and true or false end

  -- Walks the list and marks everyone who has a number as read out. Whether they
  -- are actually read out is the caller's to say: at session open the players who
  -- were already cached are marked without being spoken, which is what "include
  -- cached" turns off. Afterwards every sweep speaks, because anything new by
  -- then came back from the scan.
  ---@param speak boolean
  local function sweep( speak )
    for _, row in ipairs( resistance_check.get_rows() ) do
      if not m_announced[ row.player_name ] then
        local line = format_row( row )

        if line then
          m_announced[ row.player_name ] = true
          if speak then chat.announce( line ) end
        end
      end
    end
  end

  -- Opens the session, so the players still being inspected are read out as their
  -- results land. Deliberately does not close it when nothing is in flight yet:
  -- the caller starts the scan right after this, and closing here would mean
  -- nothing was ever announced.
  local function announce()
    m_active = false
    if not is_enabled() then return end

    m_active = true
    m_announced = {}
    sweep( is_including_cached() )
  end

  -- Every scan result redraws the list, and that's the signal to say what's new.
  resistance_check.subscribe( function()
    if not m_active then return end

    -- Unticking the checkbox mid-scan stops the rest of it, rather than only
    -- taking effect on the next check.
    if is_enabled() then sweep( true ) end

    -- The last inspect has landed, so there's nothing left to wait for. Closing
    -- here is what stops a later group change or clear from announcing again.
    if not resistance_check.is_scanning() then m_active = false end
  end )

  ---@type ResistanceAnnouncer
  return {
    announce = announce,
    is_enabled = is_enabled,
    set_enabled = function( value ) db.enabled = value and true or false end,
    is_including_cached = is_including_cached,
    set_including_cached = function( value ) db.include_cached = value and true or false end
  }
end

m.ResistanceAnnouncer = M
return M
