RollFor = RollFor or {}
local m = RollFor

if m.CoreLootHandlers then return end

local M = {}

-- Core's own loot handlers, registered through the same ctx.on_loot an extension uses.
--
-- They used to live inside LootFacadeListener as register_core, which left the dispatcher
-- holding four jobs at once: the mechanism, core's client list, the parsing of a loot
-- message, and a schedule that restated the anchors. None of those are the same job, and
-- the dispatcher is the only one of them that is not about a particular component.
--
-- So they come through the front door now. Core is a client of its own pipeline, holding no
-- privilege an extension does not have -- which is what makes the phases below readable as
-- the contract they always were rather than as an implementation detail of the registry.
--
-- Note how few sibling anchors are left. A phase says when a handler runs, so the only
-- `after` worth writing is one that orders two handlers core registers into the same phase
-- and genuinely cares about the order of. Everything else that used to be spelled as an
-- anchor was a phase difference wearing a handler's name -- and in one case a name that
-- belonged to an extension, which is how core came to hold a position open for a feature it
-- does not ship.

---@param listener LootFacadeListener
---@param c table -- the components each handler is a method on
function M.register( listener, c )
  local on_loot = listener.on_loot

  -- Records what dropped, which everything downstream reads.
  on_loot( "LootOpened", { name = "dropped_loot", phase = "Loot",
    callback = function() c.dropped_loot.on_loot_opened() end } )

  -- The drop has settled and nothing has been handed out, which is the only moment the
  -- announcement is true at.
  on_loot( "LootOpened", { name = "dropped_loot_announce", phase = "PostLoot",
    callback = function() c.dropped_loot_announce.on_loot_opened() end } )

  -- The automatic claimants, first in Award: every registered policy gets its turn at every
  -- slot before the two fall-throughs below see the corpse.
  on_loot( "LootOpened", { name = "award_policies", phase = "Award",
    callback = function() c.award_policies.on_loot_opened() end } )

  -- Award, both of them, and both as the fallback rather than as a claimant: master_loot
  -- clears its slot cache ready for a human to pick somebody, and roll_controller starts a
  -- roll for what nobody took. Whatever an automatic policy claimed is already gone by here.
  on_loot( "LootOpened", { name = "master_loot", phase = "Award",
    callback = function() c.master_loot.on_loot_opened() end } )
  on_loot( "LootOpened", { name = "roll_controller", phase = "Award",
    callback = function() c.roll_controller.loot_opened() end } )

  -- Not an award at all: it counts what is in the corpse so it can hand the raid back to
  -- group loot once the last item is out of it.
  on_loot( "LootOpened", { name = "auto_group_loot", phase = "PostAward",
    callback = function() c.auto_group_loot.on_loot_opened() end } )

  -- And again on every slot that clears. Whether the client accepts a batch of awards in one
  -- pass or silently refuses all but the first is not settled and does not need to be: run the
  -- loop over every slot and again on each clear, and both stories end with one loot window
  -- opened and everything assigned.
  on_loot( "LootSlotCleared", { name = "award_policies", phase = "Award",
    callback = function() c.award_policies.on_loot_slot_cleared() end } )

  -- A slot clearing is an award landing: this confirms it and announces it.
  on_loot( "LootSlotCleared", { name = "master_loot", phase = "PostAward",
    callback = function( slot ) c.master_loot.on_loot_slot_cleared( slot ) end } )

  -- After master_loot, and this one is a real sibling constraint rather than a phase in
  -- disguise: the count only reaches zero once the award that emptied the corpse has been
  -- confirmed.
  on_loot( "LootSlotCleared", { name = "auto_group_loot", phase = "PostAward", after = "master_loot",
    callback = function() c.auto_group_loot.on_loot_slot_cleared() end } )

  -- Tearing an abandoned award down, which is housekeeping and not the roll it starts on
  -- LootOpened. Same component, same event name, different phase -- a phase is per event.
  on_loot( "LootClosed", { name = "roll_controller", phase = "PostAward",
    callback = function() c.roll_controller.loot_closed() end } )

  -- This covers the scenario where the master looter assigns the loot and then moves immediately,
  -- causing the loot frame to close. In normal circumstances, when the last item gets assigned,
  -- the LOOT_SLOT_CLEARED fires and then LOOT_CLOSED event follows. In this case, however,
  -- LOOT_CLOSED fires first, because of the player movement and the LOOT_SLOT_CLEARED doesn't
  -- (because we're not looting anymore).
  on_loot( "ChatMsgLoot", { name = "master_loot", phase = "Loot",
    callback = function( message ) c.master_loot.on_chat_msg_loot( message ) end } )
end

m.CoreLootHandlers = M
return M
