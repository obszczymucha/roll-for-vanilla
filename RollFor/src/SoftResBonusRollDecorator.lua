RollFor = RollFor or {}
local m = RollFor

if m.SoftResBonusRollDecorator then return end

local M = {}

-- I annotate soft-ressers with the bonus rolls the item on offer is worth to them.
--
-- Only the *read* path lives here. The rolling logic is handed the registry separately
-- and does the spending, which is what keeps this a pure decorator: everything that asks
-- softres.get() who is rolling -- rolling, and the preview popup that calls it first --
-- gets the bonus allowance for free and none of them has to know where it came from.
--
-- A bonus roll is never a ticket into a roll the player wasn't already in, so this only
-- ever adds a number to a player already on the list.
---@param softres GroupAwareSoftRes
---@param registry ResistanceBonusRollRegistry
---@param config Config
---@return GroupAwareSoftRes
function M.new( softres, registry, config )
  ---@param item_data ItemData
  ---@return RollingPlayer[]
  local function get( item_data )
    local players = softres.get( item_data )
    if not config.resistance_bonus_rolls_enabled() then return players end

    -- Each roller is copied before it's annotated, the way SoftResNetherVortexDecorator
    -- copies before rewriting `rolls`. SoftRes.get does clone what it returns, but m.clone
    -- is shallow: the list is new and the roller tables in it are the stored ones. Writing
    -- through them would leave a bonus_rolls behind on the soft-res data itself, and the
    -- first thing that would break is turning the feature off -- the stale number would
    -- keep producing bonus placeholders after the decorator had stopped annotating.
    local result = {}

    for i, player in ipairs( players ) do
      local annotated = m.clone( player )
      annotated.bonus_rolls = registry.count_for_item( player.name, item_data.item_id )
      result[ i ] = annotated
    end

    return result
  end

  local decorator = m.clone( softres )
  decorator.get = get

  return decorator
end

m.SoftResBonusRollDecorator = M
return M
