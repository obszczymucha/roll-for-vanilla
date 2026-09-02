RollFor = RollFor or {}
local m = RollFor

if m.AutoRoundRobinFrame then return end

local M = {}

-- Which items auto round robin is allowed to hand out. The same tree window auto-loot uses, over
-- the round-robin catalogue instead: AutoLootFrame owns the window, AutoLootTree owns the tree,
-- and all this file does is name the catalogue and wire the Queues button to the other window.
--
-- Two levels here, not three: the round-robin catalogue is Category -> items (see
-- AutoRoundRobinDb), and each of those categories owns a queue.
--
-- The one thing this window knows that the auto-loot one doesn't is the master loot threshold,
-- which is why decorate_row lives here.

---@class AutoRoundRobinFrame
---@field show fun()
---@field hide fun()
---@field toggle fun()
---@field refresh fun() -- the threshold changed under us; redraw if we're on screen
---@field get_frame fun(): Popup?

---@param popup_builder PopupBuilder
---@param content_transformer AutoLootFrameContentTransformer
---@param db table the persisted autorobin_db -- its `ids` is the selection this tree edits
---@param frame_db table where the window position is remembered
---@param on_queues fun() -- toggles the queues window
---@param on_changed fun()? -- a row was ticked, so what this window selects is now different
---@return AutoRoundRobinFrame
function M.new( popup_builder, content_transformer, db, frame_db, on_queues, on_changed )
  m.AutoRoundRobinDb.ensure_seeded( db )

  -- The Trash category's rows name a quality (see AutoRoundRobinDb), and a quality below the
  -- master loot threshold can't be handed out at all -- GiveMasterLoot refuses it, so the award
  -- pass drops it before asking which queue serves it. Ticking such a row does nothing, which is
  -- worth saying out loud rather than leaving as a checkbox that quietly lies.
  --
  -- Read per refresh, not baked into the tree: the threshold is the raid leader's setting and can
  -- change while this window is open.
  ---@param row AutoLootFrameTreeNode
  local function decorate_row( row )
    local quality = row.data.quality
    if not quality then return end

    local threshold = m.api.GetLootThreshold() or 0
    if quality >= threshold then return end

    row.desaturated = true
    -- States what's wrong rather than what's required: "%s or lower" reads as nonsense on the
    -- Uncommon row, which is already the lowest threshold the client offers.
    row.tooltip_text = {
      row.data.name,
      string.format( "%s items can't be master looted while the loot threshold is %s.",
        m.AutoRoundRobinDb.quality_name( quality ), m.AutoRoundRobinDb.quality_name( threshold ) )
    }
  end

  ---@type AutoLootFrame
  local frame = m.AutoLootFrame.new( {
    popup_builder = popup_builder,
    content_transformer = content_transformer,
    db = frame_db,
    name = "RollForAutoRoundRobinFrame",
    title = "RollFor Auto Round Robin",
    roots = m.AutoLootTree.build_flat( db ),
    make_link = m.AutoRoundRobinDb.make_link,
    extra_buttons = {
      { type = "Queues", callback = on_queues }
    },
    decorate_row = decorate_row,
    on_changed = on_changed
  } )

  ---@type AutoRoundRobinFrame
  return frame
end

m.AutoRoundRobinFrame = M
return M
