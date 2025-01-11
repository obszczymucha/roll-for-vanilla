# TODO

1. Fix SR info in the LootFrame if 2 items dropped and 2 different players soft res it (works currently in DroppedLootAnnounce - replicate that).
2. Disable the loot frame when rolling.
3. Add awarding support for multiple winners.
4. Make loot messages less verbose - if below threshold, then don't display.
5. Fix RollingPopupContent to display multiple winners if multiple items dropped and they're equal to the number of winners.
6. Verify tie rolls visually.
7. Update /htr with SR.
8. Get master loot candidate index directly in the master looting function. Everything else relies on a boolean (is_on_master_loot_candidate_list).

Can of worms opened.

Support this scenario:
2 items dropped.
3 players roll.
Top roll is 96
The other two rolls are tied.
Now fucking what :D
In this scenario we have to mark the top roll as a winner and tie roll the others.


Support another scenario:
3 items dropped.
4 players roll.
The top roll is a tie (2 players).
Then the other two rolls are also a tie.
In this scenario the top tie rolls are the winners and we tie roll the others.


