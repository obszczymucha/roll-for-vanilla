# RollFor
A World of Warcraft (1.12.1) addon that manages rolling for items.  

## Demo

<video controls width="1024">
  <source src="https://www.twitch.tv/obszczymucha/clip/HonorablePolishedLapwingFeelsBadMan-ok8O2OAuDTIncys2" type="video/mp4">
  Your browser does not support the video tag.
</video>

In this example, the addon automatically detects that the item is soft-reserved by two players.  
It restricts rolling for the item to these players only and resolves any tie automatically.  
The Master Looter then assigns the item directly to the winner.

<img src="docs/gui-sr-tie.gif" alt="soft-res rolling" style="width:1024;height:380">


## Features
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
 * Integrates with https://raidres.fly.dev.
 * Minimap icon shows soft res status and who did not soft res.
 * Fully automated (shows who soft ressed, only accepts rolls from players who SR).

---

### And more
 * Supports "**two top rolls win**" rolling.
 * Supports **raid rolls**.
 * Supports offspec rolls (`/roll 99`).
 * Supports transmog rolls (`/roll 98`).
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

### In the loot window

Shift + left click for normal roll.  
Alt + left click for raid-roll.

When you click, the addon will insert into the edit box either  
```
/rf <item link>
```

or

```
/rr <item link>
```

Press Enter to start rolling.  

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

1. Create a Soft Res list at https://raidres.fly.dev.  
2. Ask raiders to add their items.
3. When ready, lock the raid and click on **RollFor export** button.

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


## Need more help?

Feel free to contact me if you need more help.  
Whisper **Jogobobek** in-game on Nordaanar Turtle WoW or
**Obszczymucha** on Discord.

