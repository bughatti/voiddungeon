# VoidDungeon - Dungeon Guide, Maps & Loot

**Works on:** WoW Forever

**The dungeon guide WoW Forever doesn't have, built into VoidMap: dungeon maps, your quests, boss loot and the way through.**

Open your map inside a dungeon and VoidMap shows that dungeon instead of the world: its map with every boss numbered, and beside it the dungeon's quests, loot, path and boss tips. It keeps track of which bosses you've killed this run and which one is next. Outside, you can look up any dungeon before you go.

---

## Features

### Entrances on the world map
- **Every dungeon and raid entrance** on VoidMap's zone and continent maps (WoW Forever's map shows none): a cyan ring for dungeons, orange for raids. Doors shared by several, like Scarlet Monastery or Blackrock Mountain, show one icon with a count. The few entrances no data has yet are learned from Void players walking in
- **Hover** for the name, the level range coloured for your level, and 5-player or raid size
- **Left-click** opens its dungeon map (pick the wing first when several share the door), **right-click** shows the way there with VoidGPS

### The dungeon's map
- **Every boss numbered** — hover a number for the boss's best drops, click it for its loot and tips
- **Opens by itself** — inside a dungeon, opening the map shows that dungeon. Outside, the **Dungeons** button in VoidMap's title bar opens any dungeon, picked by level
- **Every part of it** — the entrance and each wing or level get their own button at the top
- **You are here** — the game tells addons nothing about where you stand inside a dungeon, so VoidDungeon puts your own minimap in the corner of the dungeon map. Close the map and it goes back
- **How far you got** — killed bosses get a tick and dim, the next boss is marked in gold, and the boss you're standing by lights up orange. Kept through a reload or a corpse run; a new dungeon starts a new run

### Tabs beside the map
- **Quests** — your quests for this dungeon and how far along you are, then the dungeon's quests you haven't picked up yet, the ones you can take first. Each shows its rewards ("Pick one: ..." when you choose one). Click one and VoidGPS routes you to its quest giver (or the map gets a waypoint).
- **The way in, for quests with quests before them** — a quest marked **+** has a chain in front of it ("3 quests first"). Click it and the chain unfolds under it, oldest first, every step with where you stand: **done**, **in your log**, the zone you can take it in now, or the level you need. A green **>** marks where to start, and a click on a step routes you there (or tracks it when it's already in your log). Follows chains all the way back (the longest is 28 quests), picks the version for your faction where a chain has one per side, and skips breadcrumbs you no longer need
- **Loot** — every boss's drops with their drop chances. WoW Forever's new items, which any boss can drop, have a list of their own. **Shift-click** links an item, **Ctrl-click** tries it on
- **Path** — the entrance, the bosses and the stops in order, with killed, "you're here" and next marked. Hover a line to see it on the map
- **Tips** — every boss: the short version, its abilities and what to do, and the tip for tanks, healers and damage. Plus the dungeon's dangerous trash
- **Marks** — plan your markers ahead of time: the dungeon's mobs grouped by what they do (healers, crowd control, casters...), with their level and the spells worth knowing. Click one to give it a marker (or "leave it unmarked"), right-click to take yours off, or "Clear all my marks here" to start over; in the run, the marking board's green check puts your marks on them first

### Boss card
- **When a boss fight starts**, a small card pops up with the boss's short version and the tip for your group role (tank, healer or damage)
- **Tips** on the card opens the dungeon's full notes (right after the fight when you click it during one). Drag the card anywhere; it goes 3 seconds after the fight
- **On or off:** the **Boss card when a fight starts** box at the top of the Tips tab, or **Boss card** in the Void hub's quick switches
- (These were VoidCheatSheet's WoW Forever sheets: VoidCheatSheet is for retail now, everything for WoW Forever's dungeons is here)

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

### Mark the pack
- **A marking board** comes up in dungeon and raid groups: the mobs in front of you, one row each, with their name, level and elite tag, and a button per marker (Skull, X, and the crowd-control markers of the classes in your group)
- **A green check** on the mobs that matter most, from the dungeon's mob list: healers first, then mana burn, crowd control and summoners. The big green check at the top marks them all in one click. Hover a row to see which mob it probably is
- **Why "probably":** inside dungeons the game hides a mob's name from addons (it shows it to you), so VoidDungeon matches by dungeon, level, elite and mana or rage. Where two mobs look the same, the check only shows when most of them matter
- **It learns from your fights:** once a fight is over the game does tell addons which mobs it was, so VoidDungeon notes which mob each look really was. After two pulls agree, that row stops guessing: hover it to see "Seen in your fights here", and its check is for exactly that mob
- **And from other Void players' fights (WoW Forever):** what their pulls proved is shared too. Once three players agree, a look your own pulls don't know yet shows "Seen in other players' fights here" and gets its check. Your own pulls always win. **Share fight results** in the hub's quick switches turns it off
- **In combat** the rows wait for the fight to end (the game won't let an addon change what a button marks mid-fight). The bar at the bottom always works: target a mob and click a marker
- **Keys** for the big check and for each marker on the mob under your mouse (these work in combat too): Key Bindings > AddOns > VoidDungeon
- **Learn my picks** (off by default): the markers you pick become the checks for mobs that look the same. **Forget** clears them for the dungeon you're in
- **See-through:** the slider at the bottom right fades the board's background (drag or mouse wheel); the names and markers stay solid
- In a party anyone can mark; in a raid only the leader and assistants (the game's rule)

---

## Slash Commands

| Command | What it does |
|---|---|
| `/vdungeon` | Open the dungeon you're in (or the last one you looked at) · also `/vdn` |
| `/vdungeon <name>` | Open a dungeon by name, for example `/vdungeon wailing` |
| `/vmark hide` · `/vmark show` | Turn the marking board off or back on |
| `/vmark forget` | Forget every learned marker pick (all dungeons) |

---

## Getting Started

1. Install with the CurseForge app, or copy the `VoidDungeon` folder into `World of Warcraft/_forever_/Interface/AddOns/`. It needs **VoidMap**.
2. Restart WoW.
3. Walk into a dungeon and open your map.

---

## Privacy & Data

- **Shared fight results (WoW Forever):** for a look your pulls proved (dungeon, area, elite, mana or rage, level), which mob it was. Nothing about you, your group or your loot. A new find goes out once you've left the dungeon, or 10 minutes later, so it never shows where you are. Used by others only once three players agree and the dungeon's mob list allows that mob at that look.
- **Dungeon entrances (WoW Forever):** only for the few dungeons whose entrance no data has (Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace): the spot where you walked in, rounded to 1% of the zone map. It goes out 10 minutes later, and others use it once two players saw the same. **Share fight results** turns it off too.
- **Camp blueprint drops (WoW Forever):** when a "Blueprint: ..." item drops in a dungeon, which blueprint, which dungeon and which boss. Not who looted it or who was there. It goes out 10 minutes later, and others use it once two players saw the same. **Share fight results** turns it off too.
- **How:** by hidden addon whisper, one player at a time, over VoidNet, the one hidden channel all Void addons share (VoidDungeon joins it itself when no other Void addon is installed). Its name and password change every hour, with backups; if someone takes it over, bans or kicks Void players or changes its password, everyone moves to a backup and that player is ignored for 24 hours. Like any whisper, the player who gets it can see which character sent it; once three players agree, players pass it along, and whoever gets it from them sees their name, not yours. Fight reports don't save names.
- **Soft reserve:** your reserves go to your group as addon messages; the leader's VoidDungeon names the reservers in group chat when an item drops and answers whispered `!sr` requests.
- **BoE from your runs:** "Ask your guild" posts the items in guild chat; guildies' Want clicks come back as addon whispers.
- **Your own marks** (Marks tab) and learned picks stay on your PC.
- **Off switch:** **Share fight results** in the hub's quick switches.
- **Kept on your computer (WoW Forever):** the Void players you heard from in the last 2 hours (names and a time, deleted after 2 hours, never shown or shared) and players marked for attacking the channel (24 hours).
- **Helping other players change layer (WoW Forever):** VoidDungeon carries the Void layer helper. When a Void player on your layer asks (from VoidLayer or VoidSweep), you send them a quick group invite that ends on its own, only while you're solo, out of combat and outside dungeons. A short pop-up says so once. **Help Void layer hopping** in the hub's quick switches turns it off (one switch for every Void addon).

---

## Good to Know

- Soft reserve needs the leader to have VoidDungeon; the rest of the group can use whispers or softres.it. When nobody who reserved an item is in the group, it's a free roll.

- Maps cover the Classic dungeons and most of WoW Forever's new ones. The few without a map yet (Alcaz Prison, Blackmaw Hold, Shaper's Terrace) show their bosses and loot until they get one.
- Drop chances are Classic's. WoW Forever's new items have no known chance yet.

---

## Compatibility

- **WoW Forever**
- Requires **VoidMap**. Works with **VoidGPS** (routes to quest givers)

---

## Credits

- **Dungeon maps** by the Atlas Team: Dan Gilbert, Lothaer, Arith Hsu and the Atlas Team ([Atlas](https://github.com/arithmandar/Atlas)), GPL-2.0-or-later.
- **Drop chances, dungeon quests and entrances** from VoidDB. Which quests belong to which dungeon also comes from Blizzard's own WoW Forever quest data. **VoidDB**, the game data the Void addons ship, is built from Blizzard's game data, finds shared by Void players, and open data: NorgannonDB by Maro, QuestieDB, pfQuest by Shagu, DungeonJournal by Exehn and CMaNGOS classic-db (GPL-3.0; pfQuest MIT). Full credits and licences: NOTICE.txt in the addon folder. Thank you to all of them.
- **Boss notes** written by us from WoW Forever's dungeon guides and our own runs; a note only one guide gives says so.
- **Which mobs matter for marking:** each mob's spells, level and class from the [CMaNGOS classic database](https://github.com/cmangos/classic-db) (GPL-3.0)

---

*Part of the Void addon family by Vede · GPL-3.0 licensed · [Source & bug reports](https://github.com/bughatti/voiddungeon) · [All Void addons](https://www.curseforge.com/members/bughatti/projects) · free M+ & raid player lookups at [voidscout.io](https://voidscout.io) · more at [tinkerline.io](https://tinkerline.io/addons/voiddungeon/) · [Discord](https://discord.gg/7ZHmx7zMDh)*
