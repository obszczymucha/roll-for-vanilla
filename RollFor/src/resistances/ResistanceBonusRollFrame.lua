RollFor = RollFor or {}
local m = RollFor

if m.ResistanceBonusRollFrame then return end

local M = {}

-- Who has earned a bonus roll, and how many. Rendering only: ResistanceBonusRollRegistry
-- owns the database, this file turns its rows into widget calls. ListPopup owns the
-- window itself.
--
-- The registry's own get_rows() deliberately keeps everyone it has ever paid out to,
-- roster or not -- that's what lets the lockout-wipe summary count a roll earned by
-- someone who has since stepped out. This window is the display, not the record, so it
-- narrows that down to who's actually in the group right now.

---@class ResistanceBonusRollFrame
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field on_group_changed fun()
---@field get_frame fun(): Popup?

---@param popup_builder PopupBuilder
---@param content_transformer BonusRollFrameContentTransformer
---@param registry ResistanceBonusRollRegistry
---@param group_roster GroupRoster
---@param db table
function M.new( popup_builder, content_transformer, registry, group_roster, db )
  ---@type ListPopup
  local list

  -- registry.get_rows() answers for everyone it's ever paid out to; this is the subset
  -- of that who's actually standing in the group right now.
  ---@return BonusRollRegistryRow[]
  local function rows()
    local in_group = {}

    for _, player in ipairs( group_roster.get_group_players() ) do
      in_group[ player.name ] = true
    end

    local result = {}

    for _, row in ipairs( registry.get_rows() ) do
      if in_group[ row.player_name ] then table.insert( result, row ) end
    end

    return result
  end

  ---@return BonusRollFrameData
  local function content()
    return {
      rows = rows(),
      buttons = {
        { type = "Close", callback = function() list.hide() end }
      }
    }
  end

  list = m.ListPopup.new( {
    name = "RollForResistanceBonusRollFrame",
    slash_command = "rfbr",
    db = db,
    popup_builder = popup_builder,
    content_transformer = content_transformer,
    content = content,
    row_type = "bonus_roll_row"
  } )

  registry.subscribe( list.refresh_if_visible )

  ---@type ResistanceBonusRollFrame
  return {
    show = list.show,
    hide = list.hide,
    toggle = list.toggle,
    -- The roster is read fresh on every refresh, so redrawing is all it takes for
    -- someone who joined to appear and someone who left to drop off.
    on_group_changed = list.refresh_if_visible,
    get_frame = list.get_frame
  }
end

m.ResistanceBonusRollFrame = M
return M
