# VoidDungeon - Dungeon Journal, Maps & Loot

**Works on:** WoW Forever

**The dungeon journal WoW Forever doesn't have, built into VoidMap: dungeon maps, your quests, boss loot and the way through.**

Open your map inside a dungeon and VoidMap shows that dungeon instead of the world: its map with every boss numbered, and beside it the dungeon's quests, loot, path and boss tips. It keeps track of which bosses you've killed this run and which one is next. Outside, you can look up any dungeon before you go.

---

## Features

### Entrances on the world map
- **Every dungeon and raid entrance** on VoidMap's zone and continent maps (WoW Forever's map shows none): a cyan ring for dungeons, orange for raids. Doors shared by several, like Scarlet Monastery or Blackrock Mountain, show one icon with a count
- **Hover** for the name, the level range coloured for your level, and 5-player or raid size
- **Left-click** opens its dungeon map (pick the wing first when several share the door), **right-click** shows the way there with VoidGPS

### The dungeon's map
- **Every boss numbered** — hover a number for the boss's best drops, click it for its loot and tips
- **Opens by itself** — inside a dungeon, opening the map shows that dungeon. Outside, the **Dungeons** button in VoidMap's title bar opens any dungeon, picked by level
- **Every part of it** — the entrance and each wing or level get their own button at the top
- **You are here** — the game tells addons nothing about where you stand inside a dungeon, so VoidDungeon puts your own minimap in the corner of the dungeon map. Close the map and it goes back
- **How far you got** — killed bosses get a tick and dim, the next boss is marked in gold, and the boss you're standing by lights up orange. Kept through a reload or a corpse run; a new dungeon starts a new run

### Tabs beside the map
- **Quests** — your quests for this dungeon and how far along you are, then the dungeon's quests you haven't picked up yet, the ones you can take first. Click one and VoidGPS routes you to its quest giver (or the map gets a waypoint), or to the quest before it if there is one
- **Loot** — every boss's drops with their drop chances. WoW Forever's new items, which any boss can drop, have a list of their own. **Shift-click** links an item, **Ctrl-click** tries it on
- **Path** — the entrance, the bosses and the stops in order, with killed, "you're here" and next marked. Hover a line to see it on the map
- **Tips** — short boss notes, when **VoidCheatSheet** is installed

### Soft reserve (raids and dungeons)
- **Stops loot grabbing:** before the run each player reserves the items they'll roll on, and only they press Need
- **The leader opens it** on the **Reserve** tab (1, 2 or 3 per person). Everyone with VoidDungeon reserves from the **Loot** tab: right-click an item, **main spec** or **off spec**. Players without it whisper the leader `!sr [item]` (add `os` for off spec), and a **softres.it** list can be pasted in
- **Fit check:** your own game checks the item when you reserve it (armor type, weapon skill, class), and the leader sees "can't use" next to a reserve that doesn't fit. Main spec reserves beat off spec ones
- **When an item comes up:** you see "you reserved it: Need" or "reserved by A and B: Greed or pass". The leader's VoidDungeon names the reservers in group chat and calls out anyone else who presses Need (the leader can switch that off)
- **Master loot:** if your group uses it, the master looter rolls an item among its reservers, main spec first, and hands it to the winner in one click
- Reserves only, never gold: WoW Forever doesn't allow gold-bid raids

### BoE from your runs
- **Every bind-on-equip item** (green or better) you loot goes on the **BoE** tab's list
- **Ask your guild** in one click: the items go to guild chat with links. Guildies with VoidDungeon also get a small box with a **Want** button per item, and a whisper with the item's link counts too
- **Pick who gets each item**, then at any mailbox VoidDungeon fills one mail per person with their items: you just press Send

---

## Slash Commands

| Command | What it does |
|---|---|
| `/vdungeon` | Open the dungeon you're in (or the last one you looked at) · also `/vdn` |
| `/vdungeon <name>` | Open a dungeon by name, for example `/vdungeon wailing` |

---

## Getting Started

1. Install with the CurseForge app, or copy the `VoidDungeon` folder into `World of Warcraft/_forever_/Interface/AddOns/`. It needs **VoidMap**.
2. Restart WoW.
3. Walk into a dungeon and open your map.

---

## Good to Know

- Soft reserve needs the leader to have VoidDungeon; the rest of the group can use whispers or softres.it. When nobody who reserved an item is in the group, it's a free roll.

- Maps cover the Classic dungeons and most of WoW Forever's new ones. The few without a map yet (The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, The Shaper's Terrace) show their bosses and loot until they get one.
- Drop chances are Classic's. WoW Forever's new items have no known chance yet.

---

## Compatibility

- **WoW Forever**
- Requires **VoidMap**. Works with **VoidGPS** (routes to quest givers) and **VoidCheatSheet** (boss tips)

---

## Credits

- **Dungeon maps** by the Atlas Team: Dan Gilbert, Lothaer, Arith Hsu and the Atlas Team ([Atlas](https://github.com/arithmandar/Atlas)), GPL-2.0-or-later.
- **Drop chances, dungeon quests and entrances** from [NorgannonDB](https://github.com/zmarotrix/NorgannonDB) (GPL-3.0), built on Questie's database. Which quests belong to which dungeon also comes from Blizzard's own WoW Forever quest data.

---

*Part of the Void addon family by Vede · GPL-3.0 licensed · [Source & bug reports](https://github.com/bughatti/voiddungeon) · [All Void addons](https://www.curseforge.com/members/bughatti/projects) · free M+ & raid player lookups at [voidscout.io](https://voidscout.io) · more at [tinkerline.io](https://tinkerline.io/addons/voiddungeon/) · [Discord](https://discord.gg/7ZHmx7zMDh)*
