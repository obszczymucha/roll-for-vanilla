# RollFor
A World of Warcraft (1.12.1 and 2.5.2) addon that manages rolling for items.  

## Demo

### NEW

**Classic Look**

<img src="docs/classic-look.png?v=2">

Enable: `/rf config classic-look`

See the classic-look in action: https://youtu.be/G37j5XXBKxs


### Overview

In this example, the addon shows the soft-ressed items in the loot list.  
The Master Looter raid-rolls the trash item, then rolls non-SR items.  
Then the SR items are rolled.

<img src="docs/bindings.gif?v=2" alt="overview" style="width:1350px;height:350">

View better quality (fullscreen): https://youtu.be/f5nY-CxreIM


### Tie roll

In this example, the addon automatically detects that the item is soft-reserved by two players.  
It restricts rolling for the item to these players only and resolves any tie automatically.  
The Master Looter then assigns the item directly to the winner.

<img src="docs/gui-sr-tie.gif" alt="soft-res rolling" style="width:1024;height:380">


### Two top rolls win

In this example, two identical items drop. When clicked on any of these, the addon selects  
both and performs a "two-top-rolls-win" roll.  Then the Master Looter is presented with  
individual award buttons for each winner.

<img src="docs/two-items.gif" alt="two top rolls win" style="width:1100px;height:306">


## Features

### Fully SR-integrated loot list
<img src="docs/loot-list.gif" alt="SR-integrated loot list" style="width:720px;height:350">

---

### Automatically enables Master Loot when a boss is targeted
Disable this feature with:  
```
/rf config auto-master-loot
```

---

### Shows the loot that dropped (and who soft reserved)
<img src="docs/dropped-loot.gif" alt="Shows dropped loot" style="width:720px;height:350">

---

### Makes Master Loot window pretty and safe
* one window with players sorted by class
* adds confirmation window

<img src="docs/master-loot-window.gif" alt="Pretty Master Loot window" style="width:720px;height:350">

---

### Fully automated
 * Detects if someone rolls too many times and ignores extra rolls.
 * If multiple players roll the same number, it automatically shows it and
   waits for these players to re-roll.

<img src="docs/tie-winners.gif" alt="Tie winners" style="width:720px;height:350">

---

### Soft res integration
 * Integrates with https://raidres.fly.dev (1.12.1).
 * Integrates with https://softres.it (2.5.2) via Gargul Export.
 * Minimap icon shows soft res status and who did not soft res.
 * Fully automated (shows who soft ressed, only accepts rolls from players who SR).

---

### And more
 * Supports "**two top rolls win**" rolling.
 * Supports **raid rolls**.
 * Supports offspec rolls (`/roll 99`).
 * Supports transmog rolls (`/roll 98`) (1.12.1).
 * Automatically resolves tied rolls.
 * Highly customizable - see `/rf config` and `/rf config help`.

<img src="docs/raid-roll.gif" alt="Raid roll" style="width:720px;height:350">

---

### See it in action
https://youtu.be/vZdafun0nYo


## Usage

### Roll item
```
/rf <item link>
```

---

### Raid-roll item from your bags
```
/rr <item link>
```

---

### Insta Raid-roll item from your bags
```
/irr <item link>
```

---

### Roll for 2 items (two top rolls win)
```
/rf 2x<item link>
```

---


### Ignore SR and allow everyone to roll
If the item is SRed, the addon will only watch rolls for players who SRed.
However, if you want everyone to roll, even if the item is SRed, use `/arf`
instead of `/rf`. "arf" stands for "All Roll For".

---


## Soft-Res setup

1. Create a Soft Res list at https://raidres.fly.dev (1.12.1) or https://softres.it (2.5.2).  
2. Ask raiders to add their items.
3. When ready, lock the raid and click on **RollFor export** (raidres.fly.dev) or **Gargul Export** (softes.it) button.

<img src="docs/raidres-export.jpg" alt="Raidres export" style="width:720px;height:350">

4. Click on **Copy RollFor data to clipboard** buton.

<img src="docs/raidres-copy-to-clipboard.jpg" alt="Raidres copy to clipboard" style="width:720px;height:350">

5. Click on the minimap icon or type `/sr`.  
6. Paste the data into the window.  
7. Click **Import!**.  

<img src="docs/softres-import.jpg" alt="softres-import" style="width:720px;height:350">

The addon will tell you the status of SR import.  
Hovering over the minimap icon will tell you who did not soft-res.  

The minimap icon will be **green** if everyone in the group is soft-ressing.  
The minimap icon will be **orange** if someone has not soft-ressed.  
The minimap icon will be **red** if you have an outdated soft-res data.  
The minimap icon will be **white** if there is no soft-res data.  

To show the SR items type:
```
/srs
```

If someone needs to update their items, repeat the process and copy the data again.


### Soft-Res data format

The SR data from *Raidres* is a **Base64** encoded **JSON**. Decode it to see what's inside.  

---


### Fixing mistyped player names in SR setup

When using soft-res, the players sometimes mistype their nickname, e.g. 
`Johnny` in game will be `Jonnhy` in the raidres.fly.dev website.  
The addon is smart enough to fix simple typos like that for you.  
It will also deal with special characters in player names.  
However, sometimes there's so many typos and the addon can't match the  
player's name - you have to fix it manually.  

`/sro` (stands for SR Override) is the command to do this.  

---


### Finish rolls early
```
/fr
```

---


### Cancel rolls
```
/cr
```

---


### Show soft-ressed items
```
/srs
```

---


### Check soft-res status (to see if everyone is soft-ressing)
```
/src
```

---


### Clear soft-res data
Click on the minimap icon and click **Clear** or type:  
```
/sr init
```

---


## Shoutouts

Thank you to:
  * **Turtle WoW devs** for amazing content. You cunts should switch to a better client.  
  * **Itamedruids** for *Raidres* and adding the export function. Love your work.  
  * My fellow raiders (there's too many to mention).  
  * All bug reporters, testers and feature suggesters.  


## Need more help?

The best way to contact me is to message me on Discord.  
Username: **Obszczymucha**  

My character **Jogobobek** will no longer be available on Turtle WoW.  
I'm switching to Netherwing 3.0, perhaps under a different name :P  

Thanks Turtle for fun.

a