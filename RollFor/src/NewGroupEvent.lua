RollFor = RollFor or {}
local m = RollFor

if m.NewGroupEvent then return end

local M = {}

local function in_group()
  return m.api.IsInParty() or m.api.IsInRaid()
end

function M.new()
  local m_subscribers = {}
  local group = in_group()

  local function notify_subscribers()
    for _, subscriber in ipairs( m_subscribers ) do
      subscriber()
    end
  end

  local function on_group_changed()
    local in_group_now = in_group()

    if not group and in_group_now then
      group = true
      notify_subscribers()
      return
    end

    if group and not in_group_now then
      group = false
    end
  end

  local function subscribe( callback )
    table.insert( m_subscribers, callback )
  end

  return {
    on_group_changed = on_group_changed,
    subscribe = subscribe
  }
end

m.NewGroupEvent = M
return M
