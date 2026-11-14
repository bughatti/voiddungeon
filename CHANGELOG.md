# VoidDungeon Changelog

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
