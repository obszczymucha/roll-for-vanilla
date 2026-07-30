╭─── Claude Code v2.1.218 ─────────────────────────────────────────────────────╮
│                                                    │ Tips for getting        │
│             Welcome back Obszczymucha!             │ started                 │
│                                                    │ Run /init to create a … │
│                       ▐▛███▜▌                      │ ─────────────────────── │
│                      ▝▜█████▛▘                     │ What's new              │
│                        ▘▘ ▝▝                       │ Changed `/code-review`… │
│  Opus 4.8 · Claude Pro · obszczymucha@gmail.com's  │ Added screen-reader an… │
│  Organization                                      │ Fixed Windows paths wi… │
│  /home/alien/.projects/lua/roll-for-vanilla/master │ /release-notes for more │
╰──────────────────────────────────────────────────────────────────────────────╯


❯ 1x Interface/AddOns/RollFor/src/RollController.lua:1284: No RollTracker found 
  for item 29757.                                                               
  [C]: in function 'error'                                                      
  [Interface/AddOns/RollFor/src/RollController.lua]:83: in function             
  <Interface/AddOns/RollFor/src/RollController.lua:79>                          
  [Interface/AddOns/RollFor/src/RollController.lua]:1284: in function           
  'loot_awarded'                                                                
  [Interface/AddOns/RollFor/src/LootAwardCallback.lua]:33: in function          
  'on_loot_awarded'                                                             
  [Interface/AddOns/RollFor/main.lua]:50: in function                           
  <Interface/AddOns/RollFor/main.lua:42>                                        
  [Interface/AddOns/RollFor/src/TradeTracker.lua]:63: in function 'func'        
  [Interface/AddOns/Chinchilla/Libs/AceTimer-3.0-17/AceTimer-3.0.lua]:57: in    
  function <...AddOns/Chinchilla/Libs/AceTimer-3.0/AceTimer-3.0.lua:50>         
                                                                                
  Locals:                                                                       
  (*temporary)="No RollTracker found for item 29757."                           
                                                                                
  What's the most likely cause of this.                                         

  Searched for 1 pattern, read 3 files (ctrl+o to expand)

● The error is a defensive error() thrown by get_roll_tracker() at
  RollController.lua:83 because there's no entry in the roll_trackers table for
  item 29757.

  Most likely cause: the item was handed out by trading it to a player, without 
  a roll ever having been tracked for it in RollFor.

  Here's the chain the stack trace shows:

  1. TradeTracker.lua:63 → main.lua:50 — you completed a trade, giving item
  29757 to someone.
  2. trade_complete_callback (main.lua:42) resolves the item id, sees it's a
  known dropped item, and calls loot_award_callback.on_loot_awarded(...).
  3. LootAwardCallback.lua:33 calls roll_controller.loot_awarded(item_id, ...).
  4. loot_awarded (RollController.lua:1284) immediately calls
  get_roll_tracker(item_id), which errors because a RollTracker is only ever
  created in new_roll_tracker (RollController.lua:90) — i.e. when a roll/preview
  was actually started for that item.

  So item 29757 was never rolled through RollFor (you just looted it and traded
  it directly to a raider), yet the trade-detection path still tries to register
  the award against a roll tracker that doesn't exist.

  The underlying bug: loot_awarded assumes a roll tracker always exists, but the
  trade path can legitimately award items that were never rolled. Compare with
  RollController.lua:1466, which guards the same lookup with if not 
  roll_trackers[ item_id ] then return end. loot_awarded (and the
  alid/awarded_loot.award bookkeeping in on_loot_awarded, which you probably
  still want to run) needs to tolerate a missing tracker rather than hard-error.

  Want me to make loot_awarded handle the no-tracker case gracefully?

✻ Churned for 45s

※ recap: Diagnosing a RollFor Lua error where item 29757 had no RollTracker. Cause: the item was traded directly without ever being rolled, and loot_awarded errors instead of tolerating a missing tracker. Next: make loot_awarded handle the no-tracker case gracefully. (disable recaps in /config)

❯ It was soft ressed, the item was auto looted and then traded without rolling. 

  Searched for 1 pattern (ctrl+o to expand)

● That fully explains it and confirms the diagnosis. The key point: a 
  RollTracker is only created when the item goes through the rolling UI — either
  preview() (RollController.lua:903) or the start of a roll (:296). Since the
  item was soft-reserved, auto-looted, and traded straight to the SR'er without
  ever opening the rolling popup, preview() never ran, so roll_trackers[29757]
  was never populated.

  Then the trade path fired anyway:
  - trade_complete_callback (main.lua:50) → on_loot_awarded →
  roll_controller.loot_awarded (:1284) → get_roll_tracker(29757) → hard error().

  So it's a real bug in the trade-award path: loot_awarded assumes a tracker
  always exists, but a direct loot-and-trade (very common for single-SR items)
  legitimately has none. Note that on_loot_awarded already ran
  awarded_loot.award(...) before the crash, so the SR item did get recorded as
  awarded — the error is purely loot_awarded choking on the missing tracker
  afterward.

  The fix is to make loot_awarded tolerate a missing tracker, the same way
  RollController.lua:1466 already does (if not roll_trackers[ item_id ] then 
  return end). It still needs to fire the LootAwardedEvent for subscribers, so
  it should skip only the tracker-dependent work rather than bail entirely.

  Want me to implement that fix?

✻ Cooked for 24s

❯ please                                                                        

  Read 1 file (ctrl+o to expand)

● Update(RollFor/src/RollController.lua)
  ⎿  Added 6 lines, removed 2 lines
      1281    ---@param player_name string
      1282    ---@param player_class PlayerClass?
      1283    local function loot_awarded( item_id, item_link, player_nam
            e, player_class )
      1284 -    local roll_tracker = get_roll_tracker( item_id )         
      1285 -    roll_tracker.loot_awarded( player_name, item_id )        
      1284 +    -- The item may have never been rolled for (e.g. a soft-r
           +essed item that was                                          
      1285 +    -- auto-looted and traded directly), in which case there'
           +s no roll tracker.                                           
      1286 +    local roll_tracker = roll_trackers[ item_id ]            
      1287 +    if roll_tracker then roll_tracker.loot_awarded( player_na
           +me, item_id ) end                                            
      1288  
      1289      if ml_confirmation_data then
      1290        ml_confirmation_data = nil
     ...
      1302  
      1303      notify_subscribers( event )
      1304  
      1305 +    if not roll_tracker then return end                      
      1306 +                                                             
      1307      local data, current_iteration = roll_tracker.get()
      1308  
      1309      if data.status and data.status.type == S.Preview and data
            .item_count > 0 then

● Now let me verify the fix runs against the test suite. Let me find how tests
  are run.

  Listed 3 directories (ctrl+o to expand)

● Let me run the full test suite to make sure nothing regressed.

  Ran 2 shell commands (ctrl+o to expand)

● All tests pass (34 test files, no failures). The fix is in place.

  Summary

  The crash was in RollController.lua:loot_awarded, which unconditionally called
  get_roll_tracker( item_id ) — a function that hard-error()s when no tracker
  exists. In your scenario (soft-ressed item, auto-looted, traded directly
  without ever opening the rolling popup), no RollTracker was ever created for
  item 29757, so the trade-detection path blew up.

  The fix (RollController.lua:1283):

  -- The item may have never been rolled for (e.g. a soft-ressed item that was
  -- auto-looted and traded directly), in which case there's no roll tracker.
  local roll_tracker = roll_trackers[ item_id ]
  if roll_tracker then roll_tracker.loot_awarded( player_name, item_id ) end

  and after firing the LootAwardedEvent to subscribers:

  notify_subscribers( event )

  if not roll_tracker then return end

  So now the trade-award path still:
  - records the award (awarded_loot.award already ran upstream in
  on_loot_awarded),
  - hides any open confirmation popup,
  - fires the LootAwardedEvent for subscribers,

  but gracefully skips the tracker-dependent bookkeeping (winner resolution,
  preview refresh, loot-frame updates) when there was never a roll — instead of
  crashing. This mirrors the existing guard at RollController.lua:1466.

✻ Sautéed for 51s