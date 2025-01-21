# TODO

1. Fix SR info in the LootFrame if 2 items dropped and 2 different players soft res it (works currently in DroppedLootAnnounce - replicate that).
2. Disable the loot frame when rolling.
3. Add awarding support for multiple winners.
4. Make loot messages less verbose - if below threshold, then don't display.
5. Fix RollingPopupContent to display multiple winners if multiple items dropped and they're equal to the number of winners.
6. Verify tie rolls visually.
7. Add a safety mechanism not to reset awarded loot if the SR list is re-imported.
8. Fix auto-master loot enabling it in Durotar.
9. Fix the winner button for single-SR winners.
10. Fix the insta raid roll "no one rolled" bug.
11. Make sure to show/hide award buttons on lootopen/close.
12. When rolling is finished and winner determined and we close the popup and reopen with the same item the data is cleared. Persist the data until awarded.
13. When awarding the item via player selection and aborting, the rolling popup doesn't show back up, the item is still selected on the list.

Not great:
RollTracker tracks rolls in parallel to each logic.
This might result in inconsistencies, because we have the logic in different spots.
Actually this saved my ass so far, because the logic is solid, it's the ui that fucks up.


