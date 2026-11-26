# VoidDungeon Changelog

## 0.9.1 — 2026-11-26

- **Fixed: Void players losing each other every hour (WoW Forever).** On the hour, every player's addon checked the new hour's shared channel at once. With 200+ players the channel's owner couldn't answer them all in time, so most addons gave up on it and moved to backup channels: within minutes everyone was spread over 4 channels, sharing only with a slice of the others, and the players box dropped (230 to 65 on the Alliance side). Now a few players check right away and the rest later, spread out, so everyone stays together. A channel taken over by someone else is still left within minutes. Also: the players box shows the right count a minute after the hour instead of five, and a channel's owner is no longer missed in channels of 300+ players.

## 0.9.0 — 2026-11-25

- **Maps for WoW Forever's new dungeons (Blackmaw Hold, Alcaz Prison, The Shaper's Terrace).** No map of them exists anywhere, so the dungeon map now shows the game's own top-down picture of the dungeon (the one your minimap is made from), straight from the game's files.
- **The area you're in lights up** on those maps (Blackmaw Hold, The Shaper's Terrace): the game names your area, and the dungeon's ground says which part of the map that is.
- **Blackmaw Hold's route, drawn:** where each boss stands, worked out from our runs, with a line kept to the walkable floor. A best guess: Shift-click the map to pin a boss (or the entrance) where it really is, and the line follows.
- **A route box by your minimap** in Blackmaw Hold: the whole route on a small map that stays on screen, the area you're in lit, "Next: ..." on top. Drag it anywhere; right-click hides it until your next dungeon.
- **"Next: ..." on your minimap** in any dungeon with a route.
- **A finished leg goes away:** once a boss is dead, the line to it is no longer drawn (its number stays, grey).
- **The marking board knows more mobs** from Void players' fights, Blackmaw Hold and Alcaz Prison among them.

## 0.8.2 — 2026-11-24

- **Layers work again after the game's November 20 update (WoW Forever).** The update gave every NPC a number of its own, so the layer read off the NPCs around you kept jumping. The layer engine every Void addon shares (from VoidLayer 0.6.0) now names your layer itself and lets the game keep the name right: a world refresh or a hop gives you a new name, Void players who turn out to be on one layer take one name, and a layer hop turns down an invite from a helper who's on your layer already.

## 0.8.1 — 2026-11-23

- **Better pack guesses in dungeons with look-alike packs (WoW Forever).** In Sunken Temple the same troll packs stand on every side of the ring, and the marking board could guess the mobs of the wrong side ("Probably Nightmare Wyrmkin" on a troll). When several spots fit your last fight, it now names a mob only when all of them agree. Measured on 400 recorded pulls: 84% of its guesses right instead of 80%, with fewer guesses where it can't be sure.
- **No more run reset in the middle of a dungeon.** Two fights in a row with packs cleared minutes earlier (Sunken Temple's pit) could look like a fresh instance and clear your boss ticks. A fresh instance now needs packs cleared at least 10 minutes before.

## 0.8.0 — 2026-11-23

- **Where each quest starts, also inside the dungeon (WoW Forever).** A quest given inside names the dungeon and the nearest number on its map ("inside Blackrock Depths: next to 18 Summoner's Tomb"), and an item that starts a quest says which boss or mob drops it and where. Places outside name the zone they're really in.
- **What you can do right now comes first.** Quests you can start now are at the top with "start now"; the rest say what's missing: a level, the quests before them, a profession skill ("Needs Mining 230, you have 167"), or an item you must carry.
- **The right version of a quest.** Where a quest comes in two versions (A Taste of Flame), the one you can take now is shown, not the one behind a 10-quest chain.
- **Libram quests:** Mathredis Firestar and Lorekeeper Lydros only offer them while you carry that Libram, so they now say "Only while you carry a Libram of ..." instead of "Get it".
- **Bring, turn in, breadcrumbs:** what to bring (The Spectral Chalice: Star Ruby, Gold Bar, Truesilver Bar), where you hand it in, and "Optional: it only sends you to ..." for a quest you can skip.
- **Dungeon map numbers:** hovering a number lists who else stands there and the quests that point to it; hovering a quest lights up all its spots.

## 0.7.5 — 2026-11-21

- **Sunken Temple: boss order and notes (WoW Forever).** The Path tab and the next-boss card follow the order from a clean run: Atal'alarion (click the statues around the altar in the map's order), the six troll guards on the balconies that drop Jammal'an's shield, the Avatar of Hakkar for the egg quest (optional: how the summoning goes), Jammal'an and Ogom, Dreamscythe and Weaver, Morphaz and Hazzas, and the Shade of Eranikus.
- **Layer hopping:** only layers a Void player can bring you to are offered (the same change as VoidLayer 0.5.2).

## 0.7.4 — 2026-11-21

- **Smaller dungeon entrances on the map.** About half the size, like a quest helper's marks, so they don't cover the map.

## 0.7.3 — 2026-11-20

- **Alcaz Prison: boss order and notes (WoW Forever).** The Path tab and the next-boss card now follow the order that works with the quests: Tidemistress Ca'zass, Overseer Wrex, Katerina the Cleaner, Blazeroar, then The Questioner on the way back. You only get the prisoner's quest in Maximum Security, and its key drops from The Questioner. Each boss has a short note. This order comes from one run, so tell us if your group finds a better one.
- **Alcaz Prison's entrance on the map (WoW Forever).** It's on Alcaz Island in Dustwallow Marsh, measured where a player walked in.
- **Fixed: some entrances weren't learned when you walked in.** On the new Forever dungeons the game already counts you as inside a moment before the loading screen, so the walk-in was thrown away. Blackmaw Hold and Shaper's Terrace are still being learned this way.

## 0.7.2 — 2026-11-20

- **Quest objects on the dungeon map (WoW Forever).** While the quest is in your log, small lettered dots show where its objects are: The Talisman of Kazdor in Zul'Farrak gets all seven (the two Clay Vessels, both satchels, the Shallow Grave, the Sandfury Cache, the War Chest). Hover a dot for what it gives and how to get it. Green = a player found it there, yellow = about here.
- **Fixed: 5 Alliance-only quests showed to the Horde** in the Quests tab (Tabetha's Task, Journey to the Marsh, Cenarion Aid, A Simple Request, The Hunter's Charm).
- **Zul'Farrak's numbers on the map.** The bosses and spots printed on the Zul'Farrak map now have their markers too.
- **More quests in the Quests tab (WoW Forever).** A quest belongs to a dungeon when what it asks for comes only from a chest or other object inside it, even when the game files it elsewhere: The Talisman of Kazdor (rogues) is now on Zul'Farrak's list, with Rituals of Power in Scarlet Monastery and more.

## 0.7.1 — 2026-11-20

- **More dungeon loot and quests (WoW Forever).** Boss loot and dungeon quests now come from WoW Forever's newest data (the loot list nearly doubled), and the marking board knows more mobs proven by real fights.

## 0.7.0 — 2026-11-19

- **The best route through Maraudon on the dungeon map.** A line shows where to go (next stop yellow, the rest red, optional bosses blue, done grey) with a colour key, numbered stops, and a "Best route" list in the Path tab with tips and warnings (like Celebras's ritual). Purple side first by default: that way our group did the whole dungeon and every quest in one go.
- **Orange side first works too.** Maraudon has a second route for groups that go in by the orange portal (Noxxion first, then through Poison Falls to Vyletongue). The map picks the side from where your group went in, or from the bosses already dead, and the Path tab says which side it's showing; click there to switch.
- **"Next" follows the way you actually went.** A boss you killed out of the usual order now shows as done, and the yellow "next" glow on the map follows the route instead of the map's numbers (no optional boss turns "next" after the last main one).
- **The "You are here" box no longer covers the map.** While it shows, the dungeon map shrinks beside it instead of sitting under it, on every map.
- Thin borders on the Reserve and BoE windows never lose a side.

## 0.6.4 — 2026-11-18

- **The marking board knows which pack you're at** (Classic dungeons). The game won't tell addons where you stand inside a dungeon, but after every fight it does name the mobs you fought, so VoidDungeon knows which pack that was and that the next pull is one of the packs near it you haven't cleared. A nameplate those packs all agree on gets its name: hover the row for "Probably ... (by pack)", and the green check goes on exactly that mob. Tested on 360+ recorded pulls: about 1 in 5 plates named, 94% of them right (the board alone named under 1 in 10). Packs aren't always the same, so it checks itself after every fight and stops guessing in a dungeon where its guesses don't hold up.
- **54 dungeon mobs were missing from the marking list**, among them Zul'Farrak's Sandfury Witch Doctor (a healer), Blood Drinker and Shadowcaster: spawn spots that can be one of several mobs weren't counted. They're ranked now.
- **A reset is a new run.** After an instance reset the dungeon map still showed the last run's bosses as killed. Now a new run starts when the game says the dungeon was reset, when a boss you killed is fought again, or when two packs you cleared are back.
- With VoidQuest 0.3.41: the Quest Book's search finds dungeon drops too (VoidDungeon ships the item names).

## 0.6.3 — 2026-11-18

- **A big Mark button** (marking board): its own green check, bigger and separate from the board, that you can drag wherever your hand is. Press it between pulls to mark the whole pack, the same as the board's green check. It shows how many mobs it will mark, and greys out in combat, when the game locks marking for addons (the marker bar keys still work then). It stays where you put it.

## 0.6.2 — 2026-11-17

- **Layer helping finds players faster (WoW Forever).** A layer question now reaches the Void players it asks in about a second instead of eleven, so Refresh and hops see the other layers right away. Same message rate over time, well under the game's limit.

## 0.6.1 — 2026-11-17

- **VoidNet: one hidden channel for every Void addon (WoW Forever).** VoidLayer, VoidSweep, VoidQuest, VoidGather, VoidBounty and VoidDungeon now share ONE channel instead of one each. The Void players box shows **VoidNet** (every Void addon player online, each counted once) with **Layer helpers** under it. Players on an older version are still reached through the old channel, which goes away 30 days after the last of them updates.
- **Harder to grief:** the channel name changes every hour, with backups. If someone takes the channel over, bans or kicks Void players, or changes its password, every Void addon moves to the backup and ignores that player for 24 hours (a report from others counts only when 3 different Void players saw it). Nothing is shown as a list of names.
- **You can now help other players change layer** (WoW Forever): when a Void player on your layer asks, you send them a quick group invite, only while you're solo and out of combat. A short pop-up says so once. Don't want it? Turn it off with the hub's **Help Void layer hopping** switch (the same switch for every Void addon).
- **Void windows open in front** of other windows and come forward when you click them; only one first-time pop-up shows at a time.

## 0.6.0 — 2026-11-15

- **Boss tips for every WoW Forever dungeon are built in** (Tips tab): the short version, abilities, and tips for tanks, healers and damage. They were VoidCheatSheet's; VoidCheatSheet is for retail now.
- **Boss card:** when a boss fight starts, a small card shows the boss's short version and the tip for your role. Turn it off with the box at the top of the Tips tab or in the Void hub's quick switches.
- **Now called a dungeon guide:** "VoidDungeon - Dungeon Guide, Maps & Loot" (was "Dungeon Journal"). Nothing changes in game.

## 0.5.0 — 2026-11-15

- **Krol'dok Stronghold's entrance is on the map** (Riverglades, measured by a Void player walking in).
- **Entrances no data has are learned:** when you walk into Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold or Shaper's Terrace, VoidDungeon puts its entrance on your map where you walked in, and shares it: once two Void players agree, everyone sees it.
- **The Drowned City's entrance is on the map now** (off the northwest coast of Stranglethorn Vale).
- **Maps for Krol'dok Stronghold and The Drowned City** (the Atlas Team's new maps), with every boss and its loot. The Drowned City's bosses showed no loot before: the old data pointed at the wrong NPCs.
- **Alcaz Prison, Blackmaw Hold and Shaper's Terrace are in the dungeon list now**, with their bosses in order and their loot (no map yet). Before, only dungeons with a map were listed.
- **Dungeon quests for WoW Forever's new dungeons** (Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold, Shaper's Terrace, more for The Drowned City) and the new quests of Razorfen Downs, Zul'Farrak, Maraudon and City of Dalaran. Slavecrusher Grox in Krol'dok Stronghold drops the Expert Campfire blueprint, so VoidProf's Camping tab can show the way there.

## 0.4.4 — 2026-11-15

- **Where camp blueprints really drop:** when a "Blueprint: ..." item drops in a dungeon, VoidDungeon notes the dungeon and the boss (the one whose fight you just finished) and tells other Void players. Once 2 players have seen the same, VoidProf's Camping tab shows it as the source. Off with "Share fight results".

## 0.4.3 — 2026-11-15

- **Credits:** the game data this addon ships is now called **VoidDB**; full credits and licences of the open data in it are in NOTICE.txt and the README.

- **Which boss drops an item**, for other addons (`VoidDungeon:DropsOf(item)`): VoidProf uses it to tell you where each camping recipe drops and to route you to the dungeon.

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
