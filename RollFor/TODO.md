# TODO

## Part 1

 - [x] Refactor FrameBuilder to enable/disable anchor.
 - [x] Create "boss name" frame and anchor LootFrame to it.
 - [x] Prettify loot frame.
 - [x] Implement SoftresLootListDecorator.
 - [ ] Separate "loot frame" content into a testable component.
 - [ ] Test "loot frame" content.


# Part 2
Done.


# Part 3
Automation.

1. Add "auto-process" configuration toggle.
2. When "auto-process" is enabled and the loot frame is shown, the first item
   on the list should be previewed.
3. Once the item is assigned the next item should be previewed, until all items are
   processed.


# Missing bits

1. Add "RollFor" whisper/raid/RL/party message with a link.
2. Fix SR info in the LootFrame if 2 items dropped and 2 different players soft res it (works currently in DroppedLootAnnounce - replicate that).
