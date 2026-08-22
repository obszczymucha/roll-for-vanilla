RollFor = RollFor or {}
local m = RollFor

if m.Inspector then return end

local M = m.Module.new( "Inspector" )

local getn = m.getn

-- The server only serves one inspect request at a time and rate limits them,
-- so requests are queued and fired one by one.
local THROTTLE = 1.5   -- seconds between two inspect requests
local TIMEOUT = 2.5    -- consider a request lost after this long
local MAX_RETRIES = 3  -- the server silently drops requests it doesn't like
local TICK = 0.2

---@alias InspectError "no_unit"|"not_a_player"|"cannot_inspect"|"timeout"

---@class Inspector
---@field inspect fun( unit: string, callback: fun( unit: string?, guid: string?, error: InspectError? ), on_retry: (fun( unit: string, retry: number ))? )
---@field is_busy fun(): boolean
---@field clear fun()

---@param api table
---@param ace_timer AceTimer
---@param event_frame table
---@return Inspector
function M.new( api, ace_timer, event_frame )
  local m_queue = {}
  local m_current
  local m_ready_guids = {}
  local m_next_request_at = 0
  local m_timer
  local start_timer

  local function guid( unit )
    return m.UnitGUID( api, unit )
  end

  local function can_inspect( unit )
    if not api.UnitExists( unit ) then return false, "no_unit" end
    if not api.UnitIsPlayer( unit ) then return false, "not_a_player" end

    return api.CanInspect( unit, true ) and true or false, "cannot_inspect"
  end

  local function clear_inspect_player()
    -- Don't yank the data out from under Blizzard's inspect window.
    local frame = api.InspectFrame
    if frame and frame:IsVisible() then return end

    api.ClearInspectPlayer()
  end

  local function stop_timer()
    if not m_timer then return end

    ace_timer.CancelTimer( M, m_timer )
    m_timer = nil
  end

  local function finish( request, error_type )
    m_current = nil
    m_next_request_at = api.GetTime() + THROTTLE

    -- A dropped request looks exactly like a slow one, so try again before
    -- reporting it. Requeueing at the front keeps the throttle in charge.
    if error_type == "timeout" and (request.retries or 0) < MAX_RETRIES then
      request.retries = (request.retries or 0) + 1

      M.debug.add( string.format( "%s: timed out, retry %s of %s", request.unit, request.retries, MAX_RETRIES ) )
      table.insert( m_queue, 1, request )
      clear_inspect_player()
      start_timer()

      if request.on_retry then request.on_retry( request.unit, request.retries ) end
      return
    end

    if error_type then
      M.debug.add( string.format( "%s: %s", request.unit, error_type ) )
      request.callback( nil, request.guid, error_type )
    else
      M.debug.add( string.format( "%s: ready", request.unit ) )
      request.callback( request.unit, request.guid )
    end

    clear_inspect_player()
  end

  local function start_request( request )
    local ok, error_type = can_inspect( request.unit )

    if not ok then
      m_current = request
      finish( request, error_type )
      return
    end

    request.guid = guid( request.unit )
    request.started_at = api.GetTime()
    m_ready_guids[ request.guid ] = nil
    m_current = request

    M.debug.add( string.format( "inspecting %s", request.unit ) )
    api.NotifyInspect( request.unit )
  end

  local function tick()
    local now = api.GetTime()

    if m_current then
      if m_ready_guids[ m_current.guid ] then
        finish( m_current )
      elseif now - m_current.started_at >= TIMEOUT then
        finish( m_current, "timeout" )
      end

      return
    end

    if now < m_next_request_at then return end

    local request = table.remove( m_queue, 1 )

    if not request then
      stop_timer()
      return
    end

    start_request( request )
  end

  function start_timer()
    if m_timer then return end
    m_timer = ace_timer.ScheduleRepeatingTimer( M, tick, TICK )
  end

  -- Requests inspect data for a unit. The callback fires with the unit once its
  -- gear can be read, or with an error if it can't. on_retry fires in between,
  -- so the caller can say something instead of going quiet for ten seconds.
  ---@param unit string
  ---@param callback fun( unit: string?, guid: string?, error: InspectError? )
  ---@param on_retry (fun( unit: string, retry: number ))?
  local function inspect( unit, callback, on_retry )
    table.insert( m_queue, { unit = unit, callback = callback, on_retry = on_retry } )
    start_timer()
  end

  local function is_busy()
    return m_current and true or getn( m_queue ) > 0
  end

  local function clear()
    m_queue = {}
    m_current = nil
    m_ready_guids = {}
    stop_timer()
  end

  event_frame.subscribe( "INSPECT_READY", function( unit_guid )
    if unit_guid then m_ready_guids[ unit_guid ] = true end
  end )

  ---@type Inspector
  return {
    inspect = inspect,
    is_busy = is_busy,
    clear = clear
  }
end

m.Inspector = M
return M
