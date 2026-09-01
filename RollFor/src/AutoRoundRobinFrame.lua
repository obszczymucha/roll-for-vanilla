RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobinFrame then return end

local M = {}

-- Which items auto round robin is allowed to hand out. The same tree window auto-loot uses, over
-- the round-robin catalogue instead: AutoLootFrame owns the window, AutoLootTree owns the tree,
-- and all this file does is name the catalogue and wire the Queue button to the other window.

---@class AutoRoundRobinFrame
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field get_frame fun(): Popup?

---@param popup_builder PopupBuilder
---@param content_transformer AutoLootFrameContentTransformer
---@param db table the persisted autorobin_db -- its `ids` is the selection this tree edits
---@param frame_db table where the window position is remembered
---@param on_queue fun() -- toggles the queue window
---@return AutoRoundRobinFrame
function M.new( popup_builder, content_transformer, db, frame_db, on_queue )
  m.AutoRoundRobinDb.ensure_seeded( db )

  ---@type AutoLootFrame
  local frame = m.AutoLootFrame.new( {
    popup_builder = popup_builder,
    content_transformer = content_transformer,
    db = frame_db,
    name = "RollForAutoRoundRobinFrame",
    title = "RollFor Auto Round Robin",
    roots = m.AutoLootTree.build( db, m.AutoRoundRobinDb.non_bosses ),
    make_link = m.AutoRoundRobinDb.make_link,
    extra_buttons = {
      { type = "Queue", callback = on_queue }
    }
  } )

  ---@type AutoRoundRobinFrame
  return frame
end

m.AutoRoundRobinFrame = M
return M
