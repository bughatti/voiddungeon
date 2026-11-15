# VoidDungeon Changelog

## 0.4.2 — 2026-11-15

- **Plan your marks ahead of time: the new Marks tab.** Open a dungeon on the map and the Marks tab lists its mobs, grouped by what they do (healers, mana burners, crowd control, summoners, casters, the rest), each with its level and the spells worth knowing ("Scarlet Adept: Heal, Holy Smite"). Click a mob to give it a marker, or "leave it unmarked"; right-click (or "No mark of mine") takes yours off again, and "Clear all my marks here" starts the dungeon over. In the run, the marking board's green check puts your marks on those mobs, before any pick of its own. Inside a dungeon the game hides mob names, so the board recognizes a mob by its level, elite and mana or rage, or by what your earlier pulls proved it to be: two mobs that look alike need the same mark. Mobs your pulls named in WoW Forever's new dungeons show up on the tab too. Scarlet Monastery and Dire Maul are split by wing: each wing's page lists only the mobs that stand in that wing.

- **The way in to a dungeon quest.** A dungeon quest with quests before it now says how many ("3 quests first") and has a **+**: click it and the whole chain unfolds under it, oldest first. Every step shows where you stand on it (done, in your log, the zone you can take it in now, or the level you need), a green **>** marks where to start, and a click on a step routes you there or tracks it. It used to show only the one quest right before, which could send you to a giver who wouldn't offer it yet. Chains are followed all the way back (the Lord Valthalak amulet chain is 28 quests), the Horde or Alliance version is picked for you where a chain has one per side, and breadcrumbs you no longer need are left out.

- **WoW Forever: what other Void players' fights proved helps you too.** Which mob each look turned out to be is now shared between Void players (over the same whispers VoidQuest uses; VoidDungeon joins that channel itself if you don't have VoidQuest). Once three players' pulls agree, a look your own pulls don't know yet shows "Seen in other players' fights here" and gets its green check. Your own pulls always win, and a new find only goes out after you've left the dungeon or 10 minutes later. **Share fight results** in the hub's quick switches turns it off. See Privacy on the addon page.

- **Fixed: the marking board listed and marked mobs behind walls.** Nameplates show through walls, so the next room's pack could end up on the board. The game dims the nameplate of a mob it can't see you to, and the board now leaves those out (and so do the big check and the Mark key). Your target always counts. A mob that steps out from behind the wall shows up on the board within half a second. If you've changed your nameplate fading settings so a hidden mob can't be told apart from a far one, nothing is left out.

## 0.4.1 — 2026-11-14

- **The marking board learns from your fights.** Inside a dungeon the game hides mob names from addons during a fight but names them once it's over, so VoidDungeon now notes which mob each look (level, elite, mana or rage, area) really was. After two pulls agree, the row knows the mob instead of guessing, and its green check is for exactly that mob. It works in WoW Forever's new dungeons too, which aren't in the mob list: there it learns from mobs fought alone, from packs of one kind, by elimination once some are known, and by comparing pulls: a look's mob is the one name present every time that look is in the fight. Nothing is sent anywhere.

## 0.4.0 — 2026-11-14

- **New: mark the pack.** In dungeon and raid groups a marking board shows the mobs in front of you, one row each, with a button per marker (Skull, X and the crowd-control markers of the classes in your group).
  - **A green check on the mobs that matter most**, from the dungeon's mob list: healers first, then mana burn, crowd control and summoners. The big green check at the top marks them all in one click. Hover a row to see which mob it probably is (the game hides mob names from addons inside dungeons).
  - **In combat** the rows wait for the fight to end, but the marker bar at the bottom always works: target a mob, or hover it and press a key, to mark it. Keys for the big check and every marker: Key Bindings > AddOns > VoidDungeon.
  - **Learn my picks** (off by default) turns the markers you choose into the checks for mobs that look the same; **Forget** clears them for the dungeon you're in.
  - **A see-through slider** fades the board's background; the names and markers stay solid.
  - `/vmark hide` and `/vmark show` turn the board off and on; it's also a switch in the Void hub.
- **VoidDungeon is in the Void hub's drawer.**

## 0.3.1

- **Quest rewards on the Quests tab.** Under each quest, in your log or not picked up yet: "Reward: ..." or "Pick one: Sword of Omen / Prophetic Cane / Dragon's Blood Necklace". With VoidQuest, which items are a choice comes from the game (your quest log, or a quest giver seen before); otherwise it says when that isn't known yet.
- **Fixed: Scarlet Monastery said "No quests known".** The overview map of a dungeon with wings (Scarlet Monastery) now lists the quests of all its wings.

## 0.3.0

- **Soft reserve, for raids and dungeons.** The group leader opens it on the new **Reserve** tab (1, 2 or 3 items per person). Everyone reserves the items they'll roll on, and only they press Need.
  - **How to reserve:** with VoidDungeon, right-click an item on the Loot tab and pick main spec or off spec. Without it, whisper the leader `!sr [item]`. The leader can also paste in a softres.it list (its Gargul or CSV export).
  - **Fit check:** your own game checks whether you can use the item (armor type, weapon skill, class), and the leader sees "can't use" next to a reserve that doesn't fit.
  - **When an item comes up for a roll:** you're told "Need" or "Greed or pass", and the leader's VoidDungeon names the reservers in group chat. It also calls out anyone else who presses Need.
  - **With master loot:** the master looter rolls the item among its reservers (main spec beats off spec) and gives it to the winner in one click.
  - Gold never comes into it.
- **BoE from your runs.** Every bind-on-equip item (green or better) you loot goes on the new **BoE** tab.
  - **Ask your guild:** one click posts the items in guild chat. Guildies with VoidDungeon get a Want button per item, and a whisper with the item's link counts too.
  - **Hand them out:** pick who gets each item. At any mailbox, VoidDungeon fills one mail per person with their items; you press Send.

## 0.2.0

- **Dungeon and raid entrances on the world map.** WoW Forever's map shows no entrances; now VoidMap's zone and continent maps have an icon at each one (cyan ring = dungeon, orange = raid), 36 in all, Forever's own included (Hall of Thanes, Ruins of Lordaeron, Excavation Site, City of Dalaran). Hover for the name, levels coloured for you and the group size; left-click opens its dungeon map (a shared door like Scarlet Monastery lets you pick the wing), right-click shows the way there. Not placed yet, as the data has no entrance for them: Alcaz Prison, Barrow Deeps, Blackmaw Hold, Krol'dok Stronghold, Mount Hyjal, Shaper's Terrace, The Drowned City.

## 0.1.2

- Lets VoidGear's Forever panel list each dungeon's boss drops as upgrades for you.

## 0.1.1

- **Many more dungeon quests on the Quests tab.** Some dungeon quests were missing because the quest database didn't tie them to their dungeon, for example *Going, Going, Guano!* for Razorfen Kraul. VoidDungeon now also uses Blizzard's own WoW Forever quest data, which files each dungeon quest under its dungeon. New: 4 for Razorfen Kraul, 26 for Blackrock Depths, 23 for Uldaman, 16 for Gnomeregan, 7 for the Sunken Temple, 5 for Zul'Farrak, the Dire Maul library and Gordok quests, and the quests of Forever's own dungeons (Ruins of Lordaeron, City of Dalaran, Excavation Site: Wetlands, The Drowned City).

## 0.1.0

First version: the dungeon journal WoW Forever doesn't have, built into VoidMap.

- **The dungeon's map** when you open your map inside a dungeon, with every boss numbered: hover for its best drops, click for its loot and tips. Outside, the **Dungeons** button in VoidMap's title bar (or `/vdungeon`, `/vdungeon wailing`) opens any dungeon, picked by level. Maps for the Classic dungeons and most of Forever's new ones, by the Atlas Team.
- **You are here:** your minimap sits in the corner of the dungeon map while you look at the dungeon you're in, and goes back when you close the map.
- **How far you got:** killed bosses get a tick, the next one is marked in gold, and the one you're standing by lights up. Kept per character through a reload or a corpse run.
- **Quests:** your quests for this dungeon, then the ones you haven't picked up yet, the ones you can take first. Click one and VoidGPS routes you to the quest giver.
- **Loot:** every boss's drops with drop chances, and Forever's new items that any boss can drop. Shift-click links an item, Ctrl-click tries it on.
- **Path:** the entrance, the bosses and the stops in order. **Tips:** short boss notes from VoidCheatSheet.
