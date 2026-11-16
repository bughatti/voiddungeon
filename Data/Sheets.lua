----------------------------------------------------------------------
-- VoidDungeon — boss sheets for WoW Forever's dungeons (moved here from VoidCheatSheet 2026-11-15:
-- the user, "fold the sheet part of forever into the dungeon guide"; VoidCheatSheet is retail only)
-- Sources: method.gg/wow-forever/dungeons (RFC, WC, SFK, BFD, Stockade,
--   Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands, City of
--   Dalaran), warcrafttavern.com/forever/guides (dungeons list, Hall of
--   Thanes, Gnomeregan, Razorfen Kraul), conquestcapped.com WoW Forever
--   guides (Deadmines, Ruins of Lordaeron, City of Dalaran),
--   accountshark.net (Excavation Site: Wetlands), kami-labs.fr and
--   zockify.com dungeon lists, Blizzard "WoW Forever Beta Development
--   Notes" forum thread (us.forums.blizzard.com/en/wow/t/2360696).
--   Original-Classic boss data for unchanged dungeons = Classic-era
--   knowledge; anything not confirmed was left out.
-- Researched 2026-10-20 against the Oct 8 / Oct 16 beta builds (cap 30).
-- Re-checked 2026-11-13 against post-launch sources
--   (research_notes/forever-dungeon-audit-1..3.md). Level ranges now follow
--   VoidDB (VoidDungeon/Data/Entrances.lua). Text ending in
--   "(one source, unconfirmed)" comes from a single guide only.
----------------------------------------------------------------------
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end   -- WoW Forever only
local _, ns = ...
-- VoidDungeon's own table (was VoidCheatSheetData's Forever part): Side.lua's Tips tab and the boss
-- card (Sheets.lua) read it
local D = { dungeons = {}, byName = {}, byExactName = {}, byInstanceBoss = {}, byEncounterID = {}, instanceAliases = {} }
ns.Sheets = D
local FIRST_FOREVER_INDEX = 1

-- Alternate GetInstanceInfo() names. Guides disagree on the Forever
-- client's instance names (e.g. "The Stockade" vs "Stormwind Stockade"),
-- so every candidate is registered in D.byInstanceBoss below, and in
-- D.instanceAliases (normalized key -> dungeon) so FindInstance resolves
-- names that are not a substring of the entry name (wing names etc.).
-- SM / Dire Maul wing names: VoidDB, Warcraft Tavern, wiki (2026-11-13
-- audit); what GetInstanceInfo() returns in Forever is still unverified.
local INSTANCE_ALIASES = {
    ["The Hall of Thanes"] = { "Hall of Thanes" },
    ["The Deadmines"] = { "Deadmines" },
    ["The Stockade (Stormwind Stockade)"] = { "The Stockade", "Stormwind Stockade", "Stockade", "Stormwind Stockades" },
    ["The City of Dalaran"] = { "City of Dalaran", "Dalaran" },
    ["Scarlet Monastery"] = {
        "Scarlet Monastery: Graveyard", "Scarlet Monastery: Library",
        "Scarlet Monastery: Armory", "Scarlet Monastery: Cathedral",
        "The Scarlet Monastery - Graveyard", "The Scarlet Monastery - Library",
        "The Scarlet Monastery - Armory", "The Scarlet Monastery - Cathedral",
    },
    ["The Temple of Atal'Hakkar (Sunken Temple)"] = { "The Temple of Atal'Hakkar", "Temple of Atal'Hakkar", "Sunken Temple" },
    ["Lower Blackrock Spire"] = { "Blackrock Spire" },
    ["Dire Maul"] = {
        "Dire Maul (East)", "Dire Maul (West)", "Dire Maul (North)",
        "Warpwood Quarter", "Capital Gardens", "Gordok Commons",
    },
}

----------------------------------------------------------------------
-- RAGEFIRE CHASM (13-18, Horde, Orgrimmar)
-- Classic data; Forever changes not confirmed (Method's Forever guide
-- lists the same 4 bosses and abilities, labels the dungeon "Classic").
-- 2026-11-13: Jergosh kill order flipped to adds first (3 guides vs 1);
-- Bazzalan kill order is split between guides.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Ragefire Chasm",
    trashNotes = "Searing Blade Enforcers Shield Slam the tank (2s stun) - pulling several = chain-stun, pull one pack at a time. Searing Blade Warlocks spam Shadow Bolt with a Voidwalker - LoS-pull them. Ragefire Shamans heal - interrupt. Molten Elementals have Fire Shield (melee takes fire damage). Searing Blade Cultists put Curse of Agony on players (one source, unconfirmed).",
    bosses = {
        { name = "Oggleflint", order = 1, contentType = "dungeon", bossType = "Tank and spank with trogg adds",
          tldr = "Trogg chieftain sitting in a crowd of troggs, with two of them right next to him. Pull the surrounding troggs off first or the group gets swarmed.",
          abilities = { { name = "Cleave", desc = "Frontal cleave - face him away from the group." } },
          tank = "Face him away from the group. Pull the nearby troggs in small groups first.",
          healer = "Easy fight once the room is cleared.",
          dps = "Stay behind him. Clear trogg packs before pulling.",
          positioning = "Boss faced away from party.",
          wipes = "Pulling him with the whole trogg room." },
        { name = "Taragaman the Hungerer", order = 2, contentType = "dungeon", bossType = "Melee AoE",
          tldr = "Fire Nova hits everyone in melee and Uppercut launches the tank. Tank him in the middle of the platform so the knockback does not throw anyone into lava.",
          abilities = {
              { name = "Fire Nova", desc = "Instant fire AoE on everyone in melee range." },
              { name = "Uppercut", desc = "Knocks the tank back and up." },
          },
          tank = "Center of the platform, back away from the lava edge. Retaunt/re-engage after Uppercut.",
          healer = "Fire Nova damage on all melee - group heals. Stay at range.",
          dps = "Ranged at max range. Melee expect Fire Nova ticks.",
          positioning = "Middle of the platform. Clear patrols first.",
          wipes = "Tank knocked into lava; patrol joining the fight." },
        { name = "Jergosh the Invoker", order = 3, contentType = "dungeon", bossType = "Caster with 2 adds",
          tldr = "Warlock boss with two adds. CC one add, kill the other, then turn on Jergosh.",
          abilities = {
              { name = "Immolate", desc = "Fire DoT." },
              { name = "Curse of Weakness", desc = "Reduces the target's damage. Decurse if possible." },
          },
          tank = "Grab Jergosh and both adds.",
          healer = "Watch Immolate ticks; decurse if you can.",
          dps = "CC one add, kill the free one, then Jergosh.",
          positioning = "Pull to a cleared area.",
          wipes = "Splitting DPS across all three targets." },
        { name = "Bazzalan", order = 4, contentType = "dungeon", bossType = "Melee with 2 adds (final boss)",
          tldr = "Rogue-type boss with two adds; poisons the tank and Sinister Strikes. CC one add; guides split on whether to kill the other add or Bazzalan next.",
          abilities = {
              { name = "Poison", desc = "Poison on the current target - cleanse." },
              { name = "Sinister Strike", desc = "Instant physical hit." },
          },
          tank = "Hold boss and adds.",
          healer = "Cleanse the poison if you can.",
          dps = "CC one add. Then pick one target as a group - the free add or Bazzalan.",
          positioning = "Standard.",
          wipes = "Rare - adds overwhelming an undergeared tank." },
    },
}

----------------------------------------------------------------------
-- HALL OF THANES (13-20, NEW in Forever, Old Ironforge / Dun Morogh)
-- Forever-only dungeon. Sources: Method + Warcraft Tavern (beta), wow.gg
-- (2026-11-08). Final boss name "Durgen Dirgehammer" is settled (Atlas NPC
-- 261319 + wow.gg).
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "The Hall of Thanes",
    trashNotes = "Dark Iron Engineers throw bombs at the tank's spot - step out before it lands. Dark Iron Looters do heavy poisoned-dagger damage. Dark Iron Summoners cast big Fireballs and summon a fire elemental - interrupt/stun, LoS-pull them. Lesser Stone Golems hit hard and are fast (cannot be outrun). Undead dwarf patrols near Faldrim's tomb. Bloodhound Runts give a disease (Infected Wounds), and the Seaforium powder kegs can be shot to hurt nearby packs (one source, unconfirmed).",
    bosses = {
        { name = "Faldrim Anvilmar", order = 1, contentType = "dungeon", bossType = "Single target caster (undead dwarf)",
          tldr = "Simple fight; the danger is pulling him together with the undead dwarf patrols around his tomb. Clear a safe spot first.",
          abilities = {
              { name = "Mind Blast", desc = "Shadow nuke. Interruptible, but does not need to be." },
              { name = "Anvilmar's Curse", desc = "Curse: -20% attack and casting speed (also makes the target immune to poisons and bleeds). Decurse if you can." },
          },
          tank = "Pull him only after the patrols near his tomb are dead.",
          healer = "Decurse Anvilmar's Curse when possible.",
          dps = "Optional Mind Blast kicks.",
          positioning = "Cleared area away from the tomb patrol path.",
          wipes = "Patrols added to the pull." },
        { name = "Magmatus", order = 2, contentType = "dungeon", bossType = "Fire elemental with a summoner add",
          tldr = "Fire elemental with a Dark Iron Summoner. Kill the Summoner first while the tank holds Magmatus away from the group.",
          abilities = {
              { name = "Fire Nova", desc = "Instant fire pulse on everyone nearby." },
              { name = "Combust", desc = "Fire damage on a random target. Burns every 2s for 12s - heal through it (one source, unconfirmed)." },
          },
          tank = "Hold Magmatus away from the party.",
          healer = "Melee take the Fire Nova pulses - keep them topped.",
          dps = "Kill the Dark Iron Summoner first (kill the patrolling one before the pull if possible). Ranged stay away from the boss.",
          positioning = "Boss away from group; ranged spread out of nova range.",
          wipes = "Leaving the Summoner alive; healer standing in nova range." },
        { name = "Plunder", order = 3, contentType = "dungeon", bossType = "Elemental guardian, knockback",
          tldr = "Only mechanic is Knock Away. Tank with your back to a wall so nobody gets knocked into another trash pack.",
          abilities = { { name = "Knock Away", desc = "Knockback on the target." } },
          tank = "Back to a wall/corner away from uncleared packs.",
          healer = "Low pressure.",
          dps = "Do not stand where a knockback sends you into trash.",
          positioning = "Corner, clear the trash around it first.",
          wipes = "Knocked into extra packs." },
        { name = "Durgen Dirgehammer", order = 4, contentType = "dungeon", bossType = "Melee + 2 golem adds (final boss)",
          tldr = "Clear every Dark Iron Looter in the room first. Boss plus two Lesser Stone Golems deal heavy tank damage, and an 8s AoE fear scatters the group. Kill the golems one by one, then Durgen.",
          abilities = {
              { name = "Fear", desc = "AoE fear, about 8 seconds. Tremor Totem helps." },
              { name = "Rend", desc = "Bleed on the tank (about 44 every 3s)." },
              { name = "Lesser Stone Golems", desc = "Two golem adds with the boss." },
          },
          tank = "Defensives and stuns at the start, when boss + 2 golems hit hardest. Damage drops as each golem dies.",
          healer = "Heavy tank damage plus Rend; pre-heal before fears.",
          dps = "Golem, second golem, then Durgen - all on the same target. Do not get feared into uncleared corners.",
          positioning = "Clear the whole room so fears are safe.",
          wipes = "Fear into Looter packs; tank overwhelmed by boss + golems." },
    },
}

----------------------------------------------------------------------
-- RUINS OF LORDAERON (15-22, NEW in Forever, Tirisfal Glades)
-- 2026-11-13: Bjork's Mighty Blow and Rath'mael's Fire Shield dropped (no
-- post-launch guide lists them); Witherfang adds first; fireplace start.
-- Forever-only dungeon. Sources: Method + Conquest Capped (Oct 8 beta).
-- Bosses can be done in any order; listed in Method's route order.
-- Rare "Lordaeron Captain" omitted (no special abilities).
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Ruins of Lordaeron",
    trashNotes = "Ghouls/Ragged Ghouls in packs of 3-4 sit close together and hit very hard - kill the Ragged Ghoul first. Kings Alley spider packs patrol fast. Shrieking Banshees silence (Deafening Shriek) - kill them first. Flesh Golems knock players into other packs. Living Monstrosity hits hard - pull alone. Stone Watchers turn to stone (heal, physical immune) - swap target or use spells. Ghouls can apply Ghoul Plague (long slow + damage loss) - cure it (one source, unconfirmed).",
    bosses = {
        { name = "Witherfang", order = 1, contentType = "dungeon", bossType = "Patrolling spider with 2 adds",
          tldr = "Giant spider patrolling Kings Alley with two adds. Clear spider patrols on her path and pull her alone if you can. If the small spiders come too, kill them first, then her.",
          abilities = { { name = "Leech Poison", desc = "Life-drain poison on the tank. Cure poison helps." } },
          tank = "Pull her alone once her patrol path is clear.",
          healer = "Cure Leech Poison if you can.",
          dps = "Small spiders first if they joined, then the boss.",
          positioning = "Cleared section of Kings Alley.",
          wipes = "Spider patrols joining." },
        { name = "The Baron", order = 2, contentType = "dungeon", bossType = "Abomination tank-buster",
          tldr = "Huge melee swings; Knockout takes nearly half the tank's HP and stuns. Keep the tank near full at all times.",
          abilities = {
              { name = "Knockout", desc = "Massive hit (about half tank HP), knockback and stun." },
              { name = "Trample", desc = "Hits everyone around him." },
          },
          tank = "Stay topped; use cooldowns for Knockout. He can be stunned.",
          healer = "Never let the tank sit below ~60% - Knockout plus melee can kill.",
          dps = "Ranged stay out of Trample range. Use stuns.",
          positioning = "Clear the Skeletal Soldier/Mage packs guarding him first.",
          wipes = "Tank caught low when Knockout lands." },
        { name = "Viktor the Vile", order = 3, contentType = "dungeon", bossType = "Optional wave event",
          tldr = "Optional: light the fireplace in the burned house SW of Lordamere Overlook. Five add waves with little downtime, Viktor on wave 6 - conserve mana.",
          abilities = { { name = "Leech Poison", desc = "Same life-drain poison as Witherfang - cure it." } },
          tank = "Have threat ready when he spawns - he hits hard.",
          healer = "Pace mana through 5 waves.",
          dps = "AoE the waves; save cooldowns for Viktor.",
          positioning = "Fight near the house.",
          wipes = "Healer out of mana before wave 6. Skip him if the group is struggling." },
        { name = "The Abandoned", order = 4, contentType = "dungeon", bossType = "Wave event caster",
          tldr = "Statue in Market Square starts the event; three add waves, boss on wave 4. Interrupt/stun Life Drain and spread for Frost Nova.",
          abilities = {
              { name = "Life Drain", desc = "Drains the tank (2s cast). Interrupt or stun at cast start." },
              { name = "Frost Nova", desc = "Roots nearby players. Spread a little." },
              { name = "Chilled", desc = "Melee who hit him get chilled." },
          },
          tank = "Pick up waves; position boss so kicks are easy.",
          healer = "Watch tank during uninterrupted drains.",
          dps = "Kick Life Drain every cast.",
          positioning = "Loose spread for Frost Nova.",
          wipes = "Life Drain uncontrolled; adds not handled." },
        { name = "Bjork", order = 5, contentType = "dungeon", bossType = "Patrolling melee",
          tldr = "Patrols the center near deadly ghoul packs. Pull him without the ghouls; during his 3s Anti-Magic Shield use physical damage or wait.",
          abilities = {
              { name = "Anti-Magic Shield", desc = "Short (about 3s) magic immunity - pause spells." },
          },
          tank = "Pull him away from the ghoul packs.",
          healer = "Steady tank healing.",
          dps = "Stop casting during Anti-Magic Shield.",
          positioning = "Clear ghoul packs around his patrol first.",
          wipes = "Pulling ghouls with him." },
        { name = "Rath'mael", order = 6, contentType = "dungeon", bossType = "Necromancer caster",
          tldr = "Not hard: stun or kick Flamestrike, and leave the fire right away if it lands.",
          abilities = {
              { name = "Flamestrike", desc = "Ground fire AoE - stop the cast or move out. It lands on the tank, so melee step off the tank while he casts (one source, unconfirmed)." },
          },
          tank = "Stun/interrupt casts where possible; walk him out of the fire.",
          healer = "Heal Flamestrike damage on slow movers.",
          dps = "Get out of fire; save a stun for Flamestrike.",
          positioning = "Move out of fire.",
          wipes = "Group stacking in Flamestrike." },
    },
}

----------------------------------------------------------------------
-- THE DEADMINES (17-26, Westfall)
-- Forever CHANGE (single source - Conquest Capped, Oct 8 beta): same layout
-- and boss order, but boss damage retuned (Rhahk'Zor Slam ~330 vs 64-86,
-- Smite Slam ~220 vs 50, Greenskin Poisoned Harpoon higher) + new loot.
-- Instance cap now 5 players (kami-labs). Mechanics otherwise Classic.
-- 2026-11-13: Cookie added; Smite/Greenskin adds added; VanCleef stun
-- skips the second summon. Rare Miner Johnson omitted.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "The Deadmines",
    trashNotes = "Defias packs throughout - casters (Defias Wizards/Evokers) behind melee, pull with LoS. Goblin Engineers summon Remote-Controlled Golems near Gilnid. Ship deck: Defias Pirates/Squallshapers in big packs plus VanCleef's Blackguards (stealthed). Forever beta: evading mobs now walk to you instead of standing still, and the dungeon is darker.",
    bosses = {
        { name = "Rhahk'Zor", order = 1, contentType = "dungeon", bossType = "Tank and spank (stun)",
          tldr = "Ogre with two Defias Watchmen. Rhahk'Zor Slam stuns for 3s and hits much harder in Forever (about 330 in beta).",
          abilities = { { name = "Rhahk'Zor Slam", desc = "3s stun on the tank, ~330 damage in Forever beta (one source, unconfirmed)." } },
          tank = "Expect the stun spikes; defensive if undergeared.",
          healer = "Keep the tank high before each Slam.",
          dps = "Kill the Watchmen or CC them.",
          positioning = "Standard.",
          wipes = "Slam + Watchmen at low tank HP." },
        { name = "Sneed's Shredder", altNames = { "Sneed" }, order = 2, contentType = "dungeon", bossType = "Two-stage (Shredder then Sneed)",
          tldr = "Shredder fears players (Terrify) into leftover adds; when it dies Sneed hops out and disarms the tank. Clear the lumber room first.",
          abilities = {
              { name = "Terrify", desc = "Fear - can send players into surviving adds." },
              { name = "Disarm (Sneed)", desc = "Sneed disarms the tank after exiting the Shredder." },
          },
          tank = "Clear adds first. Grab Sneed fast when he pops out.",
          healer = "Watch feared players.",
          dps = "Swap to Sneed immediately.",
          positioning = "Fight in a cleared area.",
          wipes = "Fears into goblin packs." },
        { name = "Gilnid", order = 3, contentType = "dungeon", bossType = "Tank and spank + engineer adds",
          tldr = "Goblin smelter with Molten Metal. Kill the Goblin Engineers - their Remote-Controlled Golems vanish when they die.",
          abilities = { { name = "Molten Metal", desc = "Fire damage. Also slows 50%; Blessing of Freedom removes it (one source, unconfirmed)." } },
          tank = "Pick up golems as they appear.",
          healer = "Moderate.",
          dps = "Kill Goblin Engineers first.",
          positioning = "Clear the foundry ledges first.",
          wipes = "Golems piling up." },
        { name = "Mr. Smite", order = 4, contentType = "dungeon", bossType = "Weapon swap with group stuns",
          tldr = "Two stealthed Defias Blackguards join him - kill them before 66%. At 66% and 33% he Smite Stomps (group stun) and swaps weapons. Smite Slam hits much harder in Forever.",
          abilities = {
              { name = "Smite Stomp", desc = "Stuns the group at 66% and 33% while he changes weapons." },
              { name = "Smite Slam", desc = "3s stun on the tank, ~220 damage in Forever beta, used after 33% (one source, unconfirmed)." },
              { name = "Defias Blackguards", desc = "Two stealthed adds with him - kill them first." },
          },
          tank = "Pick up both Blackguards; re-grab him after each weapon swap; defensives around Slam.",
          healer = "Top everyone before 66%/33% - you will be stunned too.",
          dps = "Both Blackguards before 66%, then Smite. Slow damage near 66% and 33% if the tank or healer is low.",
          positioning = "Clear the ship-side pirates before pulling.",
          wipes = "Group stun at 66% with the Blackguards still alive." },
        { name = "Captain Greenskin", order = 5, contentType = "dungeon", bossType = "Cleave + poison",
          tldr = "Comes with a Defias Squallshaper, a Pirate and a Companion. Cleave - face him away. Poisoned Harpoon ticks much harder in Forever - cure poison.",
          abilities = {
              { name = "Cleave", desc = "Frontal cleave." },
              { name = "Poisoned Harpoon", desc = "Hit plus 1-minute Nature DoT; cure poison. Forever beta: 198 every 10s (one source, unconfirmed)." },
              { name = "Three adds", desc = "Squallshaper, Pirate and Companion fight with him." },
          },
          tank = "Face him away from the party; hold the adds too.",
          healer = "Cure the harpoon poison.",
          dps = "Stay behind. CC the Squallshaper, kill the Companion and Pirate, then the boss (one source, unconfirmed).",
          positioning = "Boss faced away.",
          wipes = "Cleave on melee; uncured harpoon stacks." },
        { name = "Cookie", order = 6, contentType = "dungeon", bossType = "Patrolling cook (easy to miss)",
          tldr = "Patrols the ship deck, so groups often walk past him. Acid Splash burns the tank and Cookie's Cooking heals him.",
          abilities = {
              { name = "Acid Splash", desc = "DoT on the tank." },
              { name = "Cookie's Cooking", desc = "Self-heal." },
          },
          tank = "Find him on the deck and pull him to a cleared spot.",
          healer = "Heal through the acid DoT.",
          dps = "Burn him; the self-heal stretches the fight.",
          positioning = "Cleared part of the deck.",
          wipes = "Rare." },
        { name = "Edwin VanCleef", order = 7, contentType = "dungeon", bossType = "Final boss with Blackguard adds",
          tldr = "Starts with two Defias Blackguards and calls two more at ~50%. A stun as he reaches ~50% (e.g. Hammer of Justice) stops the second pair from being summoned at all.",
          abilities = { { name = "Call Blackguards", desc = "Two more Defias Blackguard adds at ~50% health - skipped if he is stunned then." } },
          tank = "Pick up Blackguards as they come.",
          healer = "Spike if the second pair spawns.",
          dps = "Kill Blackguards, then VanCleef.",
          positioning = "Clear the deck first.",
          wipes = "Four adds + boss on the tank at once." },
    },
}

----------------------------------------------------------------------
-- WAILING CAVERNS (15-24, The Barrens)
-- Classic data; Forever changes not confirmed (Method labels it "Classic";
-- only beta note: Serpentbloom Snakes now despawn after a few minutes).
-- 2026-11-13: Conquest Capped (single source) lists Skum, Cobrahn and
-- Mutanus hitting ~4-5x Classic; added as flagged notes.
-- Rare Deviate Faerie Dragon omitted.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Wailing Caverns",
    trashNotes = "Druids of the Fang cast Druid's Slumber (sleep, can hit the healer) - interrupt; they turn into serpents near death and hit hard. Deviate Dreadfangs fear (Terrify). Deviate Shamblers heal with Wild Regeneration - interrupt. Deviate Vipers spit cleansable poison. Long winding paths with wandering mobs - check for patrols before each pull.",
    bosses = {
        { name = "Lady Anacondra", order = 1, contentType = "dungeon", bossType = "Druid caster",
          tldr = "Fang lord caster: Lightning Bolt, heals, Sleep, Thorns. Pull her away from nearby mobs - the fight snowballs fast.",
          abilities = {
              { name = "Sleep", desc = "Sleeps a target - interrupt." },
              { name = "Healing Touch", desc = "Self/ally heal - interrupt." },
              { name = "Lightning Bolt", desc = "Nature nuke on the tank." },
              { name = "Thorns Aura", desc = "Melee take damage when hitting." },
          },
          tank = "LoS-pull her away from adds.",
          healer = "Watch for Sleep on yourself.",
          dps = "Kick Healing Touch and Sleep.",
          positioning = "Pull to a cleared corridor.",
          wipes = "Uninterrupted heals + slept healer." },
        { name = "Kresh", order = 2, contentType = "dungeon", bossType = "Tank and spank",
          tldr = "Turtle with high armor; just tank and spank. Casters do the heavy lifting.",
          abilities = { { name = "Bite", desc = "Melee bite on the tank." } },
          tank = "Easy.", healer = "Easy.", dps = "Spell damage preferred (high armor).",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Lord Cobrahn", order = 3, contentType = "dungeon", bossType = "Druid caster + snake adds",
          tldr = "Fang lord with Deviate Python adds; goes Serpent Form near death. Interrupt Druid's Slumber before Healing Touch.",
          abilities = {
              { name = "Druid's Slumber", desc = "Sleep - often on the healer. Highest-priority kick." },
              { name = "Healing Touch", desc = "Self-heal - interrupt." },
              { name = "Lightning Bolt", desc = "Nuke." },
              { name = "Cobrahn Serpent Form", desc = "Turns into a serpent near death and hits harder. Forever: about 5x Classic bonus damage, slower swings (one source, unconfirmed)." },
          },
          tank = "Hold boss and pythons.",
          healer = "Stand where kicks can protect you; have a plan if slept.",
          dps = "Interrupts first, damage second.",
          positioning = "Standard.",
          wipes = "Slept healer + serpent-form damage." },
        { name = "Lord Pythas", order = 4, contentType = "dungeon", bossType = "Druid caster + adds",
          tldr = "Fang lord with a Druid of the Fang and a Deviate Shambler. Adds first (stun them), interrupt Sleep, watch Thunderclap slow.",
          abilities = {
              { name = "Thunderclap", desc = "AoE damage + movement/attack slow." },
              { name = "Druid's Slumber", desc = "Sleep - interrupt." },
              { name = "Healing Touch", desc = "Self-heal - interrupt." },
              { name = "Lightning Bolt", desc = "Nuke." },
          },
          tank = "Grab all three.",
          healer = "Thunderclap damage on melee.",
          dps = "Adds first, stun them, kick the boss.",
          positioning = "Standard.",
          wipes = "Shambler heals + sleeps overlapping." },
        { name = "Skum", order = 5, contentType = "dungeon", bossType = "Tank and spank",
          tldr = "Only mechanic is Chained Bolt - spread out and kill him.",
          abilities = { { name = "Chained Bolt", desc = "Chains between nearby players. Forever: over 4x Classic damage per jump (one source, unconfirmed)." } },
          tank = "Easy.", healer = "Group damage from chains.", dps = "Spread.",
          positioning = "Spread to limit chains.", wipes = "Melee stacked for chains." },
        { name = "Lord Serpentis", order = 6, contentType = "dungeon", bossType = "Druid caster + 2 adds",
          tldr = "Last Fang lord, two druid adds, same kit. Kill the adds, then the boss. All 4 Fang lords dead = Mutanus event can be started.",
          abilities = {
              { name = "Druid's Slumber", desc = "Sleep - interrupt." },
              { name = "Healing Touch", desc = "Heal - interrupt." },
              { name = "Lightning Bolt", desc = "Nuke." },
          },
          tank = "Hold all three.", healer = "Watch for sleeps.", dps = "Adds first, kick heals.",
          positioning = "Standard.", wipes = "Too many uninterrupted casts." },
        { name = "Verdan the Everliving", order = 7, contentType = "dungeon", bossType = "Heavy melee + group root",
          tldr = "Hits the tank VERY hard. Grasping Vines damages and roots everyone - healer focuses the tank.",
          abilities = { { name = "Grasping Vines", desc = "Physical AoE + root on everyone." } },
          tank = "Cooldowns - big melee hits.", healer = "Tank focus, top the group after Vines.",
          dps = "Burn him.", positioning = "Standard.", wipes = "Tank dies to melee." },
        { name = "Mutanus the Devourer", order = 8, contentType = "dungeon", bossType = "Escort event final boss",
          tldr = "Only spawns after all 4 Fang lords (Anacondra, Cobrahn, Pythas, Serpentis) are dead and you escort the Disciple of Naralex. Two add waves, then Mutanus with fear, stun and Naralex's Nightmare (sleep).",
          abilities = {
              { name = "Thundercrack", desc = "AoE stun (2-2.5s). Forever: heavy nature damage with it (one source, unconfirmed)." },
              { name = "Terrify", desc = "4s fear." },
              { name = "Naralex's Nightmare", desc = "Sleep/control on a player." },
          },
          tank = "Grab wave adds off the Disciple; reposition after fears.",
          healer = "Heal the Disciple during waves if needed.",
          dps = "Clear the dungeon first; burn waves, then boss.",
          positioning = "Stay near the Disciple during waves.",
          wipes = "A Fang lord still alive (no event); Disciple dies to adds." },
    },
}

----------------------------------------------------------------------
-- SHADOWFANG KEEP (20-30, Silverpine Forest)
-- Classic data; Forever changes not confirmed (Method labels it "Classic").
-- Rare Deathsworn Captain omitted. 2026-11-13: Fel Steed / Shadow Charger
-- stable encounter added (Atlas + CC + wow.gg); Springvale kill order and
-- Arugal's Thundershock stun updated.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Shadowfang Keep",
    trashNotes = "Wailing Guardsmen silence everyone in melee (Screams of the Past) repeatedly. Haunted Servitors curse (Haunting Spirits summons ghosts). Lupine Horrors summon Lupine Delusions - kill them fast. Son of Arugal casts Arugal's Gift (shadow DoT). Shadowfang Moonwalkers can go magic-immune (Anti-Magic Shield). Fel Steeds stun with Fel Stomp. Tormented Officers curse a weapon skill down.",
    bosses = {
        { name = "Rethilgore", order = 1, contentType = "dungeon", bossType = "Tank and spank + adds",
          tldr = "Kill adds then boss; Soul Drain drains the target. Killing him frees the prisoners who open the courtyard door.",
          abilities = { { name = "Soul Drain", desc = "Drain on the target. Forever: roots for 10s, hits far harder, and should be interrupted (one source, unconfirmed)." } },
          tank = "Hold boss and adds.", healer = "Heal through Soul Drain.", dps = "Adds, then boss. Use stuns.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Fel Steed", altNames = { "Shadow Charger" }, order = 2, contentType = "dungeon", bossType = "Optional stable horses",
          tldr = "Optional: a Fel Steed and a Shadow Charger in the stables past Rethilgore. Fel Stomp stuns.",
          abilities = { { name = "Fel Stomp", desc = "Stun. Forever: 3s, and the target takes extra physical damage (one source, unconfirmed)." } },
          tank = "Hold both.", healer = "Heal through the stuns.",
          dps = "Focus the same horse.", positioning = "Stable area.",
          wipes = "Rare." },
        { name = "Razorclaw the Butcher", order = 3, contentType = "dungeon", bossType = "Tank and spank",
          tldr = "Butcher Drain drains a player. Minor adds - kill them, then the boss.",
          abilities = { { name = "Butcher Drain", desc = "Drains a player." } },
          tank = "Easy.", healer = "Easy.", dps = "Adds first.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Baron Silverlaine", order = 4, contentType = "dungeon", bossType = "Healing debuff on tank",
          tldr = "Veil of Shadow cuts healing on the tank by 75% for 15s. Do not pull him with extra adds.",
          abilities = { { name = "Veil of Shadow", desc = "Curse: -75% healing taken for 15s on the tank. Decurse if you can." } },
          tank = "Defensives while Veil is up; pull him alone.",
          healer = "Pre-heal before Veil; decurse if possible.",
          dps = "Stuns help.", positioning = "Clear his room first.",
          wipes = "Veil + adds = tank dies." },
        { name = "Commander Springvale", order = 5, contentType = "dungeon", bossType = "Paladin with 2 adds",
          tldr = "Comes with a Haunted Servitor and a Wailing Guardsman. Kill the Servitor first; CC the Guardsman or keep it away from the healer (its silence hits melee range). Interrupt Holy Light.",
          abilities = {
              { name = "Holy Light", desc = "Self-heal - interrupt." },
              { name = "Hammer of Justice", desc = "Stun." },
              { name = "Divine Shield", desc = "Full immunity for 10s (one source, unconfirmed)." },
          },
          tank = "Hold all three; drag the Guardsman away from the healer.", healer = "Stay out of the Guardsman's melee silence.",
          dps = "Servitor first, kick Holy Light.",
          positioning = "Standard.", wipes = "Silenced healer; uninterrupted heals." },
        { name = "Odo the Blindwatcher", order = 6, contentType = "dungeon", bossType = "Soft enrage",
          tldr = "Howling Rage stacks up his damage and size over time - shorter fight is safer. Kill the two Vile Bats first.",
          abilities = {
              { name = "Howling Rage", desc = "Growing damage buff over the fight." },
              { name = "Vile Bats", desc = "Two bat adds that cleave and can disarm." },
          },
          tank = "Face bats away from the group.", healer = "Ramping tank damage.",
          dps = "Bats first, then burn Odo.", positioning = "Bats faced away.",
          wipes = "Fight runs long; Howling Rage stacks." },
        { name = "Fenrus the Devourer", order = 7, contentType = "dungeon", bossType = "Tank and spank (poison)",
          tldr = "Toxic Saliva poison DoT - cleanse it. Otherwise dies fast.",
          abilities = { { name = "Toxic Saliva", desc = "Poison DoT. Cleanse." } },
          tank = "Easy.", healer = "Cure poison.", dps = "Burn.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Wolf Master Nandos", order = 8, contentType = "dungeon", bossType = "Add summoner",
          tldr = "Guarded by four wolves; killing them aggros Nandos. He hits hard and summons Bleak Worgs / Lupine Horrors - kill adds, then boss.",
          abilities = { { name = "Summon Worgen", desc = "Summons Bleak Worg or Lupine Horror adds." } },
          tank = "Pick up every summon.", healer = "Spiky tank damage.",
          dps = "Swap to adds, Lupine Horrors fastest.", positioning = "Standard.",
          wipes = "Adds piling up." },
        { name = "Archmage Arugal", order = 9, contentType = "dungeon", bossType = "Teleporting caster (final boss)",
          tldr = "Void Bolt hits hard, Shadow Port teleports him around the room, Arugal's Curse takes control of a player for 10s, and Thundershock stuns everyone near him. Use LoS on Void Bolt and crowd-control the cursed player.",
          abilities = {
              { name = "Void Bolt", desc = "Big shadow hit - break LoS when possible. Forever: about 5x Classic, can one-shot cloth (one source, unconfirmed)." },
              { name = "Shadow Port", desc = "Teleports to another spot in the room." },
              { name = "Arugal's Curse", desc = "Controls a player for 10s - taunt/CC them." },
              { name = "Thundershock", desc = "AoE damage plus a stun on everyone near him." },
          },
          tank = "Chase him after each teleport; LoS Void Bolts.",
          healer = "Tank spikes from Void Bolt.",
          dps = "Follow the teleports; CC the cursed player.",
          positioning = "Use pillars for LoS.",
          wipes = "Tank eats repeated Void Bolts; cursed player kills the healer." },
    },
}

----------------------------------------------------------------------
-- BLACKFATHOM DEEPS (24-32, Ashenvale)
-- Classic data; Forever changes not confirmed (Method labels it "Classic";
-- only Forever note is the new Stormwind Harbor boat to Auberdine).
-- Optional Lorgus Jett / Baron Aquanis omitted. Old Serra'kis before or
-- after Kelris: guides split (2026-11-13) - kept before, check in game.
-- Boss name is "Ghamoo-ra" (lower-case r: Atlas, CC, wow.gg).
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Blackfathom Deeps",
    trashNotes = "Twilight Shadowmages mind control (Dominate Mind) - kill first. Fallenroot Hellcallers Mana Burn - interrupt/stun. Twilight Acolytes heal - interrupt. Fallenroot Shadowstalkers are stealthed. Murkshallow Snapclaws and Blackfathom Myrmidons disarm the tank. Sea Witches Frost Nova. Murloc packs at Gelihast - pull 1-2 at a time.",
    bosses = {
        { name = "Ghamoo-ra", order = 1, contentType = "dungeon", bossType = "Tank and spank (high armor)",
          tldr = "Turtle with high armor. Trample hits everyone around him; use Sunder Armor/Faerie Fire.",
          abilities = { { name = "Trample", desc = "AoE hit on everyone nearby." } },
          tank = "Easy.", healer = "Melee take Trample.", dps = "Armor reduction; casters shine.",
          positioning = "Ranged at range.", wipes = "Rare." },
        { name = "Lady Sarevess", order = 2, contentType = "dungeon", bossType = "Naga caster + 2 adds",
          tldr = "Two naga adds - CC/kill them first. Face her away so Forked Lightning does not hit the group.",
          abilities = {
              { name = "Forked Lightning", desc = "Frontal lightning cone." },
              { name = "Frost Nova", desc = "Roots nearby players." },
              { name = "Slow", desc = "Slows a target." },
          },
          tank = "Face her away from the party.", healer = "Avoid her front.",
          dps = "Adds first, then boss.", positioning = "Boss faced away.",
          wipes = "Group in the Forked Lightning cone." },
        { name = "Gelihast", order = 3, contentType = "dungeon", bossType = "Murloc boss",
          tldr = "Clear the murlocs in small pulls first. His only ability is Net (10s root).",
          abilities = { { name = "Net", desc = "10s root on a target." } },
          tank = "Pull murlocs back in 1-2 packs.", healer = "Easy once cleared.",
          dps = "Do not chase pulls.", positioning = "Room cleared first.",
          wipes = "Pulling the whole murloc cave." },
        { name = "Old Serra'kis", order = 4, contentType = "dungeon", bossType = "Underwater",
          tldr = "Underwater fight - the risk is drowning. Click the shrine by Gelihast after his kill for Blessing of Blackfathom (water breathing) first.",
          abilities = {
              { name = "Underwater fight", desc = "Get Blessing of Blackfathom from Gelihast's shrine, or watch your breath bar." },
              { name = "Leech Pulse", desc = "Health drain (one source, unconfirmed)." },
          },
          tank = "Take the shrine buff, then engage quickly.", healer = "Make sure everyone has the shrine buff; watch HP.",
          dps = "Burn fast; surface if needed.", positioning = "Underwater.",
          wipes = "Drowning." },
        { name = "Twilight Lord Kelris", order = 5, contentType = "dungeon", bossType = "Caster",
          tldr = "Clear the adds in his room, LoS-pull using the entrance wall. Mind Blast on tank, Sleep on random players.",
          abilities = {
              { name = "Mind Blast", desc = "Shadow nuke on the tank." },
              { name = "Sleep", desc = "Sleeps a random player. Can catch several players standing close - spread a little (one source, unconfirmed)." },
          },
          tank = "LoS-pull to the wall.", healer = "Wake/cover slept players.",
          dps = "Burn.", positioning = "Entrance wall for LoS.",
          wipes = "Pulled with room adds." },
        { name = "Aku'mai", order = 6, contentType = "dungeon", bossType = "Brazier event + final boss",
          tldr = "Lighting the 4 braziers past Kelris spawns add waves - light them ONE at a time and clear each wave. Aku'mai drops Poison Clouds and frenzies.",
          abilities = {
              { name = "Poison Cloud", desc = "Heavy nature damage every 5s for 45s - leave it at once. Forever: ~527 a tick, about 10x Classic (one source, unconfirmed)." },
              { name = "Frenzied Rage", desc = "+75% attack speed - tank cooldowns." },
          },
          tank = "Cooldowns on Frenzied Rage.", healer = "Tank focus during frenzy.",
          dps = "Move out of clouds.", positioning = "Away from clouds.",
          wipes = "Lighting multiple braziers at once." },
    },
}

----------------------------------------------------------------------
-- THE STOCKADE (24-32, Stormwind City, Alliance quests)
-- 2026-11-13: order now Targorr, Kam, Hamhock, Bazil, Dextren (left
-- hallway) per Atlas + CC + wow.gg; VoidDB names it "Stormwind
-- Stockades" (aliased).
-- Classic data; Forever changes not confirmed (Method labels it "Classic").
-- NAME: Blizzard beta notes/Method/WT say "The Stockade"; datamined lists
-- (kami-labs, zockify) say "Stormwind Stockade". Combined name so the
-- substring lookup matches either; both exact names registered as aliases.
-- Rare Bruegal Ironknuckle omitted.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "The Stockade (Stormwind Stockade)",
    trashNotes = "Corridors of open cells with linked prisoner packs (Defias Inmates/Convicts/Captives/Insurgents). Fears and knockbacks send people into extra cells - pull slowly. Captives apply Infected Wound (more physical damage taken), Inmates Rend (worse with Infected Wound). Insurgents Demoralizing Shout. Runners at low HP pull more packs.",
    bosses = {
        { name = "Targorr the Dread", order = 1, contentType = "dungeon", bossType = "Tank and spank, enrage",
          tldr = "Can be in different cells of the first hallway - check before pulling. Enrages at low health (about 20-30%).",
          abilities = {
              { name = "Thrash", desc = "Extra attacks." },
              { name = "Enrage", desc = "At low HP." },
          },
          tank = "Cooldown for the enrage.", healer = "Spike at enrage.", dps = "Burn the last stretch fast.",
          positioning = "Pull him out of his cell.", wipes = "Extra prisoner pulls." },
        { name = "Kam Deepfury", order = 2, contentType = "dungeon", bossType = "Strong prisoner",
          tldr = "More of a strong prisoner than a boss: fights in Defensive Stance, Shield Slam stuns the tank 2s, Improved Blocking raises block.",
          abilities = {
              { name = "Shield Slam", desc = "2s stun on the tank." },
              { name = "Defensive Stance", desc = "Takes less damage - just a slower kill." },
          },
          tank = "Easy.", healer = "Easy.", dps = "Burn.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Hamhock", order = 3, contentType = "dungeon", bossType = "Caster + Bloodlust",
          tldr = "Spams Chain Lightning and Bloodlusts himself and nearby adds. Stuns and attack-speed slows (Thunderclap) help.",
          abilities = {
              { name = "Chain Lightning", desc = "Bouncing nature damage - spread. Can be interrupted (one source, unconfirmed)." },
              { name = "Bloodlust", desc = "+30% attack and cast speed on him and adds. Purge it (one source, unconfirmed)." },
          },
          tank = "Thunderclap/slows.", healer = "Group damage from chains.",
          dps = "Spread; stun him.", positioning = "Spread.", wipes = "Bloodlusted adds." },
        { name = "Bazil Thredd", order = 4, contentType = "dungeon", bossType = "AoE stun",
          tldr = "Smoke Bomb stuns everyone near him for 4s - ranged stay away. When the tank is stunned he hits the next player on threat. Uses Battle Shout.",
          abilities = {
              { name = "Smoke Bomb", desc = "4s AoE stun around him." },
              { name = "Battle Shout", desc = "Raises his attack power." },
          },
          tank = "Expect threat loss windows. Face him away from the group (one source, unconfirmed).", healer = "Stay out of Smoke Bomb range.",
          dps = "Ranged stay back; melee watch threat.", positioning = "Ranged at max range.",
          wipes = "Healer stunned while he chews a DPS." },
        { name = "Dextren Ward", order = 5, contentType = "dungeon", bossType = "AoE fear (left hallway)",
          tldr = "Down the left hallway; the other bosses are down the right. Intimidating Shout fears the group - pull him where fears will not run people into other cells. Tremor Totem negates it.",
          abilities = { { name = "Intimidating Shout", desc = "AoE fear." } },
          tank = "Pull to a cleared section.", healer = "Fear Ward/Tremor if available.",
          dps = "Burn.", positioning = "Away from uncleared cells.", wipes = "Fears into extra packs." },
    },
}

----------------------------------------------------------------------
-- EXCAVATION SITE: WETLANDS (26-33, NEW in Forever, Wetlands)
-- Forever-only dungeon (added Oct 1 beta). Sources: Method + AccountShark,
-- re-checked with wow.gg (2026-11-13) + Warcraft Tavern. Shadetooth enrage
-- 20% vs 30% still differs - generic text. Dust Storm = miss chance
-- (wow.gg + WT). Highland Horror is optional / Alliance-only.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Excavation Site: Wetlands",
    trashNotes = "Thicket Lurkers/Stalkers hide invisibly in tall grass until aggroed - fear paths into grass = wipes. Thicket Hunters apply Infected Wound (disease) - cleanse. Thicket Matriarchs/Lurkers Rend Flesh (big bleed). Young Riptooth packs of 3 - kill one at a time. Dragonmaw Warders Mortal Strike (-50% healing) and Net (10s root, Blessing of Freedom breaks it). Dragonmaw Saboteurs throw bombs at an area. Dragonmaw Thaumaturgists come with a fire elemental - kill it first. Highland Lurkers poison - cleanse. Thicket Matriarchs call adds at low health - kill them early in the pack (one source, unconfirmed).",
    bosses = {
        { name = "Saltspine", order = 1, contentType = "dungeon", bossType = "Patrolling crocolisk",
          tldr = "Patrols the edge of the crocolisk lake - clear nearby trash first or the pull overwhelms the group. Dust Storm hampers everyone within 10 yards.",
          abilities = {
              { name = "Dust Storm", desc = "Everyone within 10 yards misses more often (about +25%), so the tank and melee build less threat." },
              { name = "Tendon Rip", desc = "Heavy slow on the target." },
              { name = "Fatal Bite", desc = "Hard bite on the target." },
          },
          tank = "Build threat early; Dust Storm hurts it.", healer = "Stay out of 10 yards.",
          dps = "Casters stay out of Dust Storm range; watch threat.", positioning = "Clear the lake edge first.",
          wipes = "Pulling him with lake packs." },
        { name = "Shadetooth", order = 2, contentType = "dungeon", bossType = "Raptor + 2 adds, fear",
          tldr = "Patrols the raptor path with two Thicket Hunters. Terrifying Roar fears players into hidden grass packs - Tremor Totem/Fear Ward, or clear the grass first. Enrages at low health.",
          abilities = {
              { name = "Terrifying Roar", desc = "Fear - sends players into hidden stealthed packs." },
              { name = "Rend", desc = "Bleed on the tank (~77 every 3s)." },
              { name = "Enrage", desc = "At low health: faster, harder attacks. Stuns/slows help." },
          },
          tank = "Fight on cleared ground; save cooldowns for the enrage. Do not drag him over the water toward Saltspine's spot - it can reset him (one source, unconfirmed).",
          healer = "Cleanse Infected Wound from the Thicket Hunters.",
          dps = "CC one Hunter, burn the other, then boss.", positioning = "Cleared cove, away from tall grass.",
          wipes = "Fear into hidden Lurker packs." },
        { name = "Highland Horror", order = 3, contentType = "dungeon", bossType = "Optional Alliance quest boss (no loot)",
          tldr = "Optional, Alliance quest boss only. Do not pull the slimes around him; kill fast and grab the quest item.",
          abilities = {
              { name = "Entangling Roots", desc = "Root." },
              { name = "Wild Regeneration", desc = "Heal - interrupt." },
          },
          tank = "Pull clean.", healer = "Easy.", dps = "Kick heals.",
          positioning = "Away from slimes.", wipes = "Slimes added." },
        { name = "Relic Guardian", order = 4, contentType = "dungeon", bossType = "Titan construct (final boss)",
          tldr = "Start it at the Archival Panel to its right; it is higher level (misses/dodges hurt threat). Arcing Smash frontal, Knock Away drops threat, War Stomp knocks back and stuns - ranged stay far.",
          abilities = {
              { name = "Arcing Smash", desc = "Frontal cleave - face away." },
              { name = "Knock Away", desc = "Single-target knock that reduces threat." },
              { name = "War Stomp", desc = "AoE knockback + stun." },
              { name = "Thunderclap", desc = "AoE damage + attack/movement slow." },
          },
          tank = "Face away; retaunt after Knock Away. It also has a separate 5s stun (one source, unconfirmed). Its knockback can throw you off an edge, so tank away from drops (one source, unconfirmed).", healer = "Stay out of Thunderclap/War Stomp range.",
          dps = "Ranged stay back; watch threat. It can be stunned/slowed (kite if needed).",
          positioning = "Boss faced away, ranged spread at range.",
          wipes = "Threat loss after Knock Away; mana runs out on a long fight." },
    },
}

----------------------------------------------------------------------
-- CITY OF DALARAN (28-33, NEW in Forever, Alterac Mountains)
-- Forever-only dungeon (added Oct 8 beta). Needs the Dalaran Sewers Key;
-- one key holder opens it for the group (Method + CC).
-- Sources: Method + Conquest Capped, re-checked with wow.gg (2026-11-03)
-- + Warcraft Tavern. Boss lists differ between guides
-- (kami-labs/games.gg also mention a Mana Wraith/Mana Elemental - not
-- confirmed, omitted). Lyn the Ignored needs the Tome of Dalaran.
-- 2026-11-13: Mana Devourer before Fel Ancient (Atlas + wow.gg);
-- "Modera" spelling (WT + wow.gg); barrier NPC name dropped (guides differ).
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "The City of Dalaran",
    trashNotes = "Most damage (even melee) is ARCANE - warrior/paladin tanks block little. Kirin Tor Necromancers spam Raise Dead and Unholy Frenzy (+75% attack speed) - kill first. Mana Phantoms Mana Burn - interrupt/stun. Phantasms Reflection Field reflects spells - check target. Seeking Remnants detect stealth. Fallen Mages Frostbolt - LoS-pull. Fragmented Sentries Arcing Smash frontal.",
    bosses = {
        { name = "Atrexis the Grave Knight", order = 1, contentType = "dungeon", bossType = "Patrolling melee + raised adds",
          tldr = "Patrols with three Kirin Tor Necromancers - kill a couple before the pull. Hits the tank hard and raises dead; kill the first adds, then focus him.",
          abilities = {
              { name = "Raise Dead", desc = "Summons undead adds until he dies." },
              { name = "Disarm", desc = "Disarms the tank." },
              { name = "Unholy Frenzy", desc = "Attack speed buff on himself/allies." },
              { name = "Strike", desc = "Instant hit." },
          },
          tank = "Cooldowns; he hits hard, especially frenzied.", healer = "Heavy tank healing.",
          dps = "First adds, then boss.", positioning = "Thin out the necromancers before engaging.",
          wipes = "Necromancers + frenzied adds overwhelm the tank." },
        { name = "Lyn the Ignored", order = 2, contentType = "dungeon", bossType = "Secret boss (Tome of Dalaran)",
          tldr = "Only appears if someone brings the Tome of Dalaran (the Black Tome from Arugal's room in SFK, charged at the Ambermill Leyline Focus). Summon spot: past Atrexis, skip the ramp to Arcane Anomaly and go straight on to the floor circle. Raises dead, Shadow Bolt Volleys the group, and puts Curse of Thorns on the tank - decurse.",
          abilities = {
              { name = "Raise Dead", desc = "Continuous undead adds." },
              { name = "Shadow Bolt Volley", desc = "Hits the whole group." },
              { name = "Curse of Thorns", desc = "Tank takes damage whenever they deal damage - decurse." },
          },
          tank = "Grab raised adds.", healer = "Group healing for volleys; decurse.",
          dps = "Boss focus, clean adds as needed.", positioning = "Standard.",
          wipes = "Curse left on tank; volley damage + adds." },
        { name = "Arcane Anomaly", order = 3, contentType = "dungeon", bossType = "Rotating beam",
          tldr = "Arcane Bolt blasts the tank (~500). Focal Blast is a 3s beam sweeping clockwise or counterclockwise - read the direction and move with it.",
          abilities = {
              { name = "Arcane Bolt", desc = "~500 arcane on the tank." },
              { name = "Focal Blast", desc = "3s channeled sweeping beam." },
          },
          tank = "Tank spikes from Arcane Bolt.", healer = "Big tank heals, heal beam hits.",
          dps = "Move with the beam direction.", positioning = "Krasus Landing.",
          wipes = "Group caught by the sweep." },
        { name = "Arcanic Enigma", order = 4, contentType = "dungeon", bossType = "Caster + Mana Phantoms",
          tldr = "Two Mana Phantoms - interrupt/stun their Mana Burn, do not let it go off. Dispel Manamorph (polymorph), ranged avoid the Silence, split damage between Manalings and boss.",
          abilities = {
              { name = "Manamorph", desc = "Polymorph-like on random targets - dispel." },
              { name = "Silence", desc = "AoE silence - ranged can avoid." },
              { name = "Summon Manaling", desc = "Adds." },
          },
          tank = "Hold boss, grab Manalings.", healer = "Dispel Manamorph; stay out of Silence.",
          dps = "Kill Phantoms first, kick Mana Burn.", positioning = "Southern bank garden.",
          wipes = "Mana Burn draining the healer." },
        { name = "Unstable Sentinel", order = 5, contentType = "dungeon", bossType = "Construct, pulsing AoE",
          tldr = "Arcing Smash frontal - face away. Malfunction pulses AoE within 25 yards; ranged stand beyond 25 yd and a stun before the cast prevents it.",
          abilities = {
              { name = "Arcing Smash", desc = "Frontal cleave." },
              { name = "Malfunction", desc = "Pulsing AoE within 25 yards - stun to prevent." },
          },
          tank = "Face away; he hits relatively hard.", healer = "Stay 25+ yards out.",
          dps = "Stun on Malfunction cast. Kill the tomes first (one source, unconfirmed).", positioning = "Ranged 25+ yards away.",
          wipes = "Melee/healer eating full Malfunction." },
        { name = "Mana Devourer", order = 6, contentType = "dungeon", bossType = "Mana drain DPS check",
          tldr = "Clear the whole room near the Violet Hold first. Debilitate hits everyone and drains mana - kill him before the healer runs dry.",
          abilities = {
              { name = "Drain Vitality", desc = "Arcane DoT on the tank." },
              { name = "Debilitate", desc = "Group arcane damage + drains 200 mana from everyone. Reaches 45 yards, so range does not dodge it (one source, unconfirmed)." },
          },
          tank = "Pull clean.", healer = "Efficient heals; mana is the clock.",
          dps = "Cooldowns - this is a burn. Reportedly immune to Arcane - Arcane mages swap school (one source, unconfirmed).", positioning = "Room cleared.",
          wipes = "Healer out of mana." },
        { name = "Fel Ancient", order = 7, contentType = "dungeon", bossType = "Roots + ground pools",
          tldr = "Talk to the NPC at the barrier to drop it. Entangle roots for 10s with damage; move out of green Fel Timbers pools immediately.",
          abilities = {
              { name = "Entangle", desc = "10s root that deals damage. Blessing of Freedom removes it." },
              { name = "Fel Timbers", desc = "Green damaging pool on the ground - move." },
          },
          tank = "Move boss out of pools.", healer = "Freedom/heal rooted players.",
          dps = "Get out of green.", positioning = "Keep clean ground.",
          wipes = "Rooted in a pool." },
        { name = "Shade of the Archmage", order = 8, contentType = "dungeon", bossType = "Mana-cycle caster (final boss)",
          tldr = "Speak to Archmage Modera for the Purple Parlor portal. Move him away from where Bounding Mana was cast (sphere returns + Arcane Explosion 20 yd). At 0 mana: Mass Polymorph, then Evocation and the fight resets - save cooldowns for after.",
          abilities = {
              { name = "Arcane Bolt", desc = "Heavy arcane damage on the tank." },
              { name = "Bounding Mana", desc = "Sphere moves out and back; explodes for Arcane Explosion (20 yd) on return." },
              { name = "Mass Polymorph", desc = "At 0 mana; polymorphs the group." },
              { name = "Evocation", desc = "Restores his mana after Mass Polymorph." },
          },
          tank = "Drag him away from the Bounding Mana spot.", healer = "Top everyone before Mass Polymorph.",
          dps = "Cooldowns after Evocation phases.", positioning = "Relocate after every Bounding Mana. Do not leave the room - it resets the fight (one source, unconfirmed).",
          wipes = "Standing near the sphere return; low HP going into polymorph." },
    },
}

----------------------------------------------------------------------
-- GNOMEREGAN (29-38, Dun Morogh)
-- Classic data; Forever changes not confirmed (Warcraft Tavern: "hasn't
-- changed much", only loot/reward updates). Rare Dark Iron Ambassador
-- omitted.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Gnomeregan",
    trashNotes = "Long, multi-level dungeon - pulls from ramps and lower paths drag in extra packs. Irradiated troggs/leper gnomes in big groups. Mechanical mobs in the Launch Bay and Engineering Labs hit hard. Workshop Key from Electrocutioner 6000 opens the back entrance for later runs.",
    bosses = {
        { name = "Grubbis", order = 1, contentType = "dungeon", bossType = "Escort/defense event",
          tldr = "Blastmaster Emi Shortfuse starts an event near the entrance (trogg waves); Grubbis and his pet Chomper arrive at the end. Kill Chomper first.",
          abilities = { { name = "Chomper", desc = "Pet add - both can be stunned or feared." } },
          tank = "Hold Grubbis and Chomper; protect Emi during waves.", healer = "Tank focus; save DPS who pull aggro.",
          dps = "Kill Chomper, then Grubbis.", positioning = "Near Emi.",
          wipes = "Waves overrunning the group." },
        { name = "Viscous Fallout", order = 2, contentType = "dungeon", bossType = "Tank and spank",
          tldr = "Simple tank-and-spank ooze that wanders (Atlas). Reportedly immune to Frost - frost mages swap school (one source, unconfirmed).",
          abilities = { { name = "Melee", desc = "No notable abilities confirmed." } },
          tank = "Easy.", healer = "Tank focus.", dps = "Burn.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Electrocutioner 6000", order = 3, contentType = "dungeon", bossType = "Chain lightning",
          tldr = "Chain Bolt and Megavolt cannot be interrupted. Spread out; tank at max melee range so chains do not jump into melee.",
          abilities = {
              { name = "Chain Bolt", desc = "Uninterruptible chain lightning - spread." },
              { name = "Megavolt", desc = "Uninterruptible nature hit." },
          },
          tank = "Max melee range from others.", healer = "Top the group after chains.",
          dps = "Spread out.", positioning = "Spread on the Launch Bay platform.",
          wipes = "Stacked group taking full chains." },
        { name = "Crowd Pummeler 9-60", order = 4, contentType = "dungeon", bossType = "Melee AoE",
          tldr = "Arcing Smash hits around him and he tramples nearby players. Tank him against a wall away from the healer; casters at max range.",
          abilities = {
              { name = "Arcing Smash", desc = "Small-radius AoE around him." },
              { name = "Trample", desc = "Hits nearby players." },
          },
          tank = "Back to a wall, away from the healer.", healer = "Max range.",
          dps = "Ranged at max range; melee from behind.", positioning = "Engineering Labs wall.",
          wipes = "Healer in Trample range." },
        { name = "Mekgineer Thermaplugg", order = 5, contentType = "dungeon", bossType = "Bomb adds + threat reset (final boss)",
          tldr = "Walking Bombs pour from the wall vents - DPS kill/kite them; spawns increase at 50% and speed up at 20%. Knock Away resets threat: tank recenters and taunts. Press the button at an active vent to stop it briefly.",
          abilities = {
              { name = "Summon Walking Bomb", desc = "Bomb adds walk to players and explode." },
              { name = "Knock Away", desc = "Knocks the tank back and resets threat." },
          },
          tank = "Middle of the room; taunt immediately after each knockback.",
          healer = "Stay away from bombs; tank first, bomb damage second.",
          dps = "Swap to bombs, watch threat after knockbacks. A ranged can hit the vent buttons.",
          positioning = "Boss centered so bombs walk farther.",
          wipes = "Bombs reaching the healer; DPS pulling aggro after Knock Away." },
    },
}

----------------------------------------------------------------------
-- RAZORFEN KRAUL (29-38, The Barrens)
-- Classic data; Forever changes not confirmed (Warcraft Tavern: "hasn't
-- really changed", only loot/rewards). Rares Earthcaller Halmgar and
-- Blind Hunter omitted. 2026-11-13: Charlga (Purity/Renew/immunities) and
-- Agathelos (Rampage/Frenzy) filled in from WT + warcraft.wiki.gg.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Razorfen Kraul",
    trashNotes = "Quillboar casters: Death's Head Acolytes Mana Burn, Razorfen Groundshakers AoE stun, Death's Head Seers are high priority. Beast trainers bring pets. Tight thorn tunnels make LoS pulls easy but patrols common.",
    bosses = {
        { name = "Roogug", order = 1, contentType = "dungeon", bossType = "Shaman + adds",
          tldr = "Summons a Stone Rumbler and fights next to a Death's Head Seer - the Seer is the most dangerous add.",
          abilities = { { name = "Summon Stone Rumbler", desc = "Earth elemental add." } },
          tank = "Grab boss + Rumbler.", healer = "Moderate.", dps = "Seer first.",
          positioning = "Standard.", wipes = "Seer ignored." },
        { name = "Aggem Thorncurse", order = 2, contentType = "dungeon", bossType = "Add summoner",
          tldr = "Beastmaster that keeps summoning low-HP boar spirits - cleave them down and focus the boss.",
          abilities = { { name = "Summon Boar Spirit", desc = "Repeated low-HP adds." } },
          tank = "Pick up spirits.", healer = "Moderate.", dps = "Cleave spirits, focus boss.",
          positioning = "Standard.", wipes = "Spirits stacking up on the healer." },
        { name = "Death Speaker Jargba", order = 3, contentType = "dungeon", bossType = "Caster with mind control",
          tldr = "Dominate Mind takes over a player and Shadow Bolt hits harder with nobody in melee. Adds: Acolyte (Mana Burn) and Groundshaker (AoE stun).",
          abilities = {
              { name = "Dominate Mind", desc = "Mind controls a player - CC them." },
              { name = "Shadow Bolt", desc = "Stronger when no one is in melee range." },
          },
          tank = "Keep him in melee.", healer = "Watch the Mana Burn add.",
          dps = "Kill the Acolyte/Groundshaker; CC the MC'd player.", positioning = "Melee on him.",
          wipes = "MC'd player killing the healer." },
        { name = "Overlord Ramtusk", order = 4, contentType = "dungeon", bossType = "Warrior + 2 adds",
          tldr = "Two Razorfen Spearhides whose Whirling Barrage is a heavy AoE. Kill/CC the Spearhides.",
          abilities = { { name = "Whirling Barrage (adds)", desc = "Heavy AoE from the Spearhides." } },
          tank = "Hold all three.", healer = "Group damage from the adds.", dps = "Adds first.",
          positioning = "Standard.", wipes = "Spearhides left alive." },
        { name = "Agathelos the Raging", order = 5, contentType = "dungeon", bossType = "Heavy-hitting boar",
          tldr = "Sealed in his pen until the guards around it die. Very high melee damage, Rampage stuns players near him, and he frenzies at low health - tank cooldowns.",
          abilities = {
              { name = "Rushing Charge", desc = "Charge at a target. Staying in melee range denies it (one source, unconfirmed)." },
              { name = "Rampage", desc = "Hits everyone near him and stuns them briefly." },
              { name = "Frenzy", desc = "Faster, harder hits at low health." },
              { name = "Fake death", desc = "May pretend to die - keep attacking until he is really dead (one source, unconfirmed)." },
          },
          tank = "Cooldowns; he hits very hard, more so in Frenzy.", healer = "Big tank healing; top melee after Rampage.", dps = "Burn.",
          positioning = "Standard.", wipes = "Tank dies to melee." },
        { name = "Charlga Razorflank", order = 6, contentType = "dungeon", bossType = "Priestess (final boss)",
          tldr = "Chain Bolt bounces between players - spread out. Purity makes her briefly immune and wipes your debuffs off her; Renew heals her - dispel or purge it. Stuns, silences and Shadow damage do nothing.",
          abilities = {
              { name = "Chain Bolt", desc = "Bouncing nature damage." },
              { name = "Purity", desc = "Short immunity that also clears debuffs on her - skip DoTs and magic debuffs." },
              { name = "Renew", desc = "Heal over time on her - dispel/purge it." },
              { name = "Immunities", desc = "Cannot be stunned or silenced; immune to Shadow." },
          },
          tank = "Hold her. Tank her on the ramp; she can teleport back to her hut (one source, unconfirmed).", healer = "Group damage.", dps = "Spread. Direct damage over DoTs; Shadow casters use another school.",
          positioning = "Spread.", wipes = "Rare." },
    },
}

----------------------------------------------------------------------
-- SCARLET MONASTERY (30-45, Tirisfal Glades) - all 4 wings in one entry
-- Wings (VoidDB): Graveyard 30-38, Library 33-41, Armory 34-42,
-- Cathedral 36-45.
-- Classic data; Forever changes not confirmed (in beta, labeled "Classic"
-- by Method). Classic GetInstanceInfo returns "Scarlet Monastery" for all
-- wings; VoidDB / Warcraft Tavern use "Scarlet Monastery: <Wing>" -
-- all forms aliased in INSTANCE_ALIASES. Verify in game.
-- Rares (Ironspine, Azshir, Fallen Champion) omitted. 2026-11-13:
-- Fairbanks added (Atlas + Warcraft Tavern).
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Scarlet Monastery",
    trashNotes = "Humanoid Scarlet packs flee at low HP and pull more packs - stun/slow runners. Library and Cathedral have healer/caster mobs - interrupt heals. Cathedral courtyard has many patrols. Armory: big packs before Herod. Graveyard: undead + spirits, easy.",
    bosses = {
        { name = "Interrogator Vishas", order = 1, contentType = "dungeon", bossType = "Graveyard - caster",
          tldr = "Graveyard. Easy caster; Shadow Word: Pain on players.",
          abilities = { { name = "Shadow Word: Pain", desc = "Shadow DoT." } },
          tank = "Easy.", healer = "Dispel/heal DoT.", dps = "Burn.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Bloodmage Thalnos", order = 2, contentType = "dungeon", bossType = "Graveyard - fire/shadow caster",
          tldr = "Graveyard end boss. Flame Spike puts fire on the ground - move out; ranged stand well back. Also listed: Flame Shock and a Shadow Bolt that cannot be kicked (one source, unconfirmed).",
          abilities = {
              { name = "Flame Spike", desc = "Fire on the ground - move." },
              { name = "Fire Nova", desc = "AoE around him (Classic data)." },
          },
          tank = "Easy.", healer = "Melee damage.", dps = "Move out of fire.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Houndmaster Loksey", order = 3, contentType = "dungeon", bossType = "Library - boss + hounds",
          tldr = "Library. Comes with Scarlet tracking hounds and Bloodlusts. Kill hounds or AoE them.",
          abilities = { { name = "Bloodlust", desc = "Self attack speed buff." } },
          tank = "Grab all hounds.", healer = "Bloodlust spike.", dps = "Hounds, then boss.",
          positioning = "Standard.", wipes = "Hounds on the healer." },
        { name = "Arcanist Doan", order = 4, contentType = "dungeon", bossType = "Library - caster, 50% blast",
          tldr = "Library end boss. At 50% he casts Arcane Bubble then Detonation - RUN AWAY from him immediately. Also Silence and Polymorph.",
          abilities = {
              { name = "Arcane Bubble + Detonation", desc = "At 50% (Classic data): bubble, then huge AoE - get out of range." },
              { name = "Silence", desc = "AoE silence." },
              { name = "Polymorph", desc = "Sheeps a player." },
          },
          tank = "Run out with the group at 50%, retaunt after.", healer = "Run at the bubble.",
          dps = "Run at the bubble, back in after.", positioning = "Clear exit space.",
          wipes = "Standing in Detonation." },
        { name = "Herod", order = 5, contentType = "dungeon", bossType = "Armory - Whirlwind",
          tldr = "Armory. Whirlwind (yells Blades of Light) - melee step out. Enrages at low HP; on death a swarm of Scarlet adds runs in - AoE them.",
          abilities = {
              { name = "Whirlwind", desc = "Spinning AoE - melee back off. He takes no damage while spinning, so hold cooldowns (one source, unconfirmed)." },
              { name = "Rushing Charge", desc = "Charges a target." },
              { name = "Enrage", desc = "At low health." },
              { name = "Scarlet swarm", desc = "A wave of weak Scarlet adds after he dies." },
          },
          tank = "Cooldown at enrage.", healer = "Save mana for the add swarm.",
          dps = "Melee leave during Whirlwind; AoE the swarm.", positioning = "Room cleared.",
          wipes = "Melee eating Whirlwind; OOM healer when the swarm arrives." },
        { name = "High Inquisitor Fairbanks", order = 6, contentType = "dungeon", bossType = "Cathedral - hidden priest",
          tldr = "Cathedral, in a hidden room on the right. Heals himself and keeps dispelling the tank's buffs. Interrupt the heal (one source, unconfirmed).",
          abilities = {
              { name = "Heal", desc = "Self-heal - interrupt." },
              { name = "Dispel Magic", desc = "Strips buffs from the tank often." },
          },
          tank = "Hold him; rebuff after dispels.", healer = "Expect lost buffs/HoTs on the tank.",
          dps = "Kick the heal.", positioning = "His side room.",
          wipes = "Rare." },
        { name = "Scarlet Commander Mograine", order = 7, contentType = "dungeon", bossType = "Cathedral - paladin",
          tldr = "Cathedral. Paladin with Divine Shield, Hammer of Justice, Crusader Strike, Lay on Hands. Killing him brings Whitemane.",
          abilities = {
              { name = "Divine Shield", desc = "Immunity bubble." },
              { name = "Hammer of Justice", desc = "Stun." },
              { name = "Crusader Strike", desc = "Melee strike." },
              { name = "Lay on Hands", desc = "Big self heal." },
          },
          tank = "Hold him.", healer = "Save mana for Whitemane.", dps = "Burn.",
          positioning = "Center of the chapel.", wipes = "Low mana going into Whitemane." },
        { name = "High Inquisitor Whitemane", order = 8, contentType = "dungeon", bossType = "Cathedral - resurrection (final)",
          tldr = "Enters when Mograine dies. At 50% she Deep Sleeps the group and resurrects Mograine - then kill both. Interrupt her heals.",
          abilities = {
              { name = "Deep Sleep", desc = "Sleeps the whole group at ~50%." },
              { name = "Scarlet Resurrection", desc = "Revives Mograine." },
              { name = "Heal", desc = "Interrupt." },
              { name = "Holy Smite", desc = "Holy nuke." },
          },
          tank = "Pick up the revived Mograine fast.", healer = "Top everyone before 50%.",
          dps = "Kick heals; burn her after the res.", positioning = "Standard.",
          wipes = "Mograine + Whitemane together with a drained healer." },
    },
}

----------------------------------------------------------------------
-- RAZORFEN DOWNS (37-46, The Barrens) - opened in beta Oct 1
-- Classic data; Forever changes not confirmed. Rare Ragglesnout omitted.
-- 2026-11-13: Plaguemaw the Rotting is not a rare (Atlas) - he ends the
-- Belnistrasz idol event (Warcraft Tavern); added.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Razorfen Downs",
    trashNotes = "Dense linked undead and quillboar packs. Death's Head Necromancers raise adds - kill first. Belnistrasz idol event (quest) spawns waves - defend him until the ritual finishes. Belnistrasz cannot be healed, so keep every add off him (one source, unconfirmed).",
    bosses = {
        { name = "Tuten'kash", order = 1, contentType = "dungeon", bossType = "Gong event",
          tldr = "Optional gong event: ring the gong for two add waves, the third ring brings Tuten'kash. Face him away (Web Spray), cleanse poison, decurse.",
          abilities = {
              { name = "Virulent Poison", desc = "Poison - cleanse." },
              { name = "Web Spray", desc = "Frontal web that roots for about 5s." },
              { name = "Curse of Tuten'kash", desc = "Slows attack and cast speed - decurse." },
          },
          tank = "Pick up the waves; face Tuten'kash away from the group.", healer = "Cleanse poison, remove the curse.", dps = "AoE waves; stay out of his front.",
          positioning = "Near the gong.", wipes = "Waves overwhelm the group." },
        { name = "Plaguemaw the Rotting", order = 2, contentType = "dungeon", bossType = "End of the Belnistrasz event",
          tldr = "Shows up after the idol event waves. The boss himself is simple; the fast add waves before him are the real danger (one source, unconfirmed).",
          abilities = { { name = "Event waves", desc = "Quick add waves ahead of him." } },
          tank = "Hold the waves off Belnistrasz.", healer = "Pace mana through the waves.", dps = "AoE the waves, then burn him.",
          positioning = "Around Belnistrasz.", wipes = "Belnistrasz dies to adds." },
        { name = "Mordresh Fire Eye", order = 3, contentType = "dungeon", bossType = "Fire caster",
          tldr = "Skeletal fire caster - Fireball and Fire Nova. Interrupt where possible.",
          abilities = {
              { name = "Fireball", desc = "Fire nuke." },
              { name = "Fire Nova", desc = "AoE around him." },
          },
          tank = "Hold him.", healer = "Melee take novas.", dps = "Kick Fireball.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Glutton", order = 4, contentType = "dungeon", bossType = "Tank and spank",
          tldr = "Disease cloud and a frenzy - tank cooldowns at frenzy.",
          abilities = { { name = "Disease Cloud", desc = "Disease damage around him." } },
          tank = "Cooldown at frenzy.", healer = "Cleanse disease.", dps = "Burn.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Amnennar the Coldbringer", order = 5, contentType = "dungeon", bossType = "Frost lich (final boss)",
          tldr = "Lich with Frost Nova and Amnennar's Wrath (AoE frost); summons frost spectres as his health drops. Kill spectres fast.",
          abilities = {
              { name = "Amnennar's Wrath", desc = "AoE frost damage." },
              { name = "Frost Nova", desc = "Roots nearby players." },
              { name = "Frost spectres", desc = "Adds as his health drops." },
          },
          tank = "Grab spectres.", healer = "Group frost damage.", dps = "Spectres, then boss.",
          positioning = "Standard.", wipes = "Spectres + Wrath on low group." },
    },
}

----------------------------------------------------------------------
-- ULDAMAN (38-48, Badlands) - opened in beta Oct 1
-- Classic data; Forever changes not confirmed. 2026-11-13: Revelosh,
-- Obsidian Sentinel and Ancient Stone Keeper added (Atlas CF_Uldaman
-- order + Warcraft Tavern mechanics, one source); Ironaya staff gate added.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Uldaman",
    trashNotes = "Shadowforge dwarves and Stonevault troggs in linked packs; dwarf casters behind melee. Earthen constructs in the lower halls hit hard. Scorpids and basilisks near the excavation.",
    bosses = {
        { name = "Baelog", order = 1, contentType = "dungeon", bossType = "The Lost Dwarves (3 bosses)",
          tldr = "Baelog, Eric the Swift and Olaf fight together. Focus one at a time; CC if possible. Horde only: Alliance find them friendly. Order: Eric, Olaf, Baelog; Eric's charge can reach the healer (one source, unconfirmed).",
          abilities = { { name = "Three dwarves", desc = "Baelog, Eric the Swift and Olaf engage together." } },
          tank = "Grab all three.", healer = "Heavy tank damage early.", dps = "Focus one at a time.",
          positioning = "Standard.", wipes = "Spread damage across all three." },
        { name = "Revelosh", order = 2, contentType = "dungeon", bossType = "Trogg caster + 2 adds",
          tldr = "Chain Lightning caster with two trogg adds - kick it and spread. Drops the Shaft of Tsol, half of the staff needed for Ironaya (one source, unconfirmed).",
          abilities = { { name = "Chain Lightning", desc = "Bouncing nature damage - interrupt, spread." } },
          tank = "Hold him and both adds.", healer = "Group damage from chains.", dps = "Kick Chain Lightning; spread.",
          positioning = "Spread.", wipes = "Uninterrupted chains on a stacked group." },
        { name = "Ironaya", order = 3, contentType = "dungeon", bossType = "Stone giant",
          tldr = "Reaching her needs the Staff of Prehistoria: the Shaft of Tsol (Revelosh) plus the Gni'kiv Medallion (Lost Dwarves' chest). Knock Away (threat drop), Arcing Smash frontal, War Stomp AoE stun.",
          abilities = {
              { name = "Knock Away", desc = "Knockback + threat drop." },
              { name = "Arcing Smash", desc = "Frontal cleave." },
              { name = "War Stomp", desc = "AoE stun." },
              { name = "DoT immune", desc = "Damage over time does not work on her (one source, unconfirmed)." },
          },
          tank = "Retaunt after Knock Away; face away.", healer = "Out of stomp range.",
          dps = "Watch threat.", positioning = "Boss faced away.",
          wipes = "Threat loss to a DPS." },
        { name = "Obsidian Sentinel", order = 4, contentType = "dungeon", bossType = "Construct that splits",
          tldr = "Immune to DoTs. At 66% and 33% it sheds Obsidian Shards - kill the shards (one source, unconfirmed).",
          abilities = { { name = "Obsidian Shards", desc = "Adds split off at 66% and 33%." } },
          tank = "Pick up the shards.", healer = "Moderate.", dps = "Shards when they appear; no DoTs.",
          positioning = "Standard.", wipes = "Shards left alive." },
        { name = "Ancient Stone Keeper", order = 5, contentType = "dungeon", bossType = "Earth construct",
          tldr = "Sand Storms slow and silence nearby players - ranged and healer at max range (one source, unconfirmed).",
          abilities = { { name = "Sand Storms", desc = "AoE slow + silence." } },
          tank = "Hold him.", healer = "Max range.", dps = "Ranged at max range.",
          positioning = "Ranged/healer far back.", wipes = "Healer silenced in the storms." },
        { name = "Galgann Firehammer", order = 6, contentType = "dungeon", bossType = "Fire caster dwarf",
          tldr = "Dwarf fire caster - ranged stay spread, interrupt casts. Two Shadowforge Geologists come with him (kill them first) and Amplify Flames should be dispelled (one source, unconfirmed).",
          abilities = { { name = "Fire spells", desc = "Fire damage on the group." } },
          tank = "Hold him.", healer = "Fire damage.", dps = "Kick.",
          positioning = "Spread.", wipes = "Rare." },
        { name = "Grimlok", order = 7, contentType = "dungeon", bossType = "Trogg caster",
          tldr = "Trogg chieftain caster; interrupt his Lightning Bolts. Comes with a Geomancer, a Brawler and a Jadespine Basilisk that stuns healers - kill the basilisk first (one source, unconfirmed).",
          abilities = { { name = "Lightning Bolt", desc = "Nature nuke." } },
          tank = "Hold him.", healer = "Moderate.", dps = "Kick.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Archaedas", order = 8, contentType = "dungeon", bossType = "Titan construct, add waves (final)",
          tldr = "Activated at his altar. He keeps awakening Earthen Guardians and later Vault Warders; Ground Tremor stuns the group. Burn him while the tank holds the awakened adds.",
          abilities = {
              { name = "Awaken Earthen Guardian", desc = "Wakes the statues in the room." },
              { name = "Awaken Vault Warder", desc = "Bigger constructs later in the fight." },
              { name = "Ground Tremor", desc = "AoE stun." },
              { name = "20% wave", desc = "At 20% he wakes four elite adds that die when he does (one source, unconfirmed)." },
          },
          tank = "Pick up every awakened add.", healer = "Heavy tank damage; mana check.",
          dps = "Boss focus unless adds get loose.", positioning = "Center of the chamber.",
          wipes = "Adds stacking faster than the boss dies." },
    },
}

----------------------------------------------------------------------
-- THE DROWNED CITY (35-40, off Stranglethorn Vale) - new in WoW Forever
-- Added 2026-11-14 (the user: "add min'loth and all others"). Every claim below is in at least
-- two guides that agree: outputlag.com (updated 11-13, verified 1.60.1), warcrafttavern.com
-- (Luxrah, hotfixes through 11-13) and mmonster.co (updated 11-10); and checked against the
-- user's own runs (VoidDev, 11-14): the spells each boss hit the group with on the damage meter,
-- the adds, the areas, encounter ids 3478 (Deathless Marrow, "Deathless Guardians") and 3479
-- (Min'loth). Single-source details (Braxton, Zin'aka, Min'loth's Horrifying Presence, freeing
-- bubbled players before Dreadrise dies, Marrow's wave timing) are left out.
-- research_notes/drowned-city-bosses.md.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "The Drowned City",
    trashNotes = "Chasm Crawlers and Makrura Snappers stack Sunder Armor and Muscle Tear on the tank: one pack at a time. Risen Sentries charge and knock back: fight with your back to a wall. Profane Necromancers raise Drowned Spirits: kill or interrupt them first. Brinescale Sorceresses cast Frostbolt and Fear: interrupt the Fear (Tremor Totem helps). Quest tablets of I'lalai: past Zul'Alai, by Var'Taka, by Captain Dreadrise and by Min'loth (the fourth counted in our run, in the Abyssal Dais). The Glowing Pearls after Var'Taka and Dreadrise open the way on.",
    bosses = {
        { name = "Zul'Alai", order = 1, contentType = "dungeon", bossType = "Melee, enrages at 30%",
          tldr = "Undead troll at the top of the hill past the entrance. Monstrous Slam stuns everyone near him, so melee step out of the cast. At 30% he swings faster and heals: save cooldowns and burn him.",
          abilities = {
              { name = "Monstrous Slam", desc = "Cast: stuns and damages everyone near him. Step out of melee range when you see it." },
              { name = "Rotted Strike", desc = "Slows the tank's movement and attacks. Dispel it." },
              { name = "Undying Oath", desc = "At 30% health: faster attacks and self-healing." },
          },
          tank = "Hold him still so melee can step out of each Slam.",
          healer = "Dispel Rotted Strike. Heavier tank damage below 30%.",
          dps = "Ranged stay out of the Slam. Cooldowns for the last 30%.",
          positioning = "Melee ready to step out of the Slam.",
          wipes = "A Slam stunning the whole group during the 30% phase." },
        { name = "Var'Taka", order = 2, contentType = "dungeon", bossType = "Naga with 2 healers",
          tldr = "Two Brinescale Priestesses heal him and throw Frostbolts: crowd-control or kill them first. He cleaves in front, so only the tank stands there. Harpoon pulls a random player to him: walk straight back out.",
          abilities = {
              { name = "Cleave", desc = "Frontal hit: only the tank in front." },
              { name = "Harpoon", desc = "Pulls a random player to him. Get out of the cleave." },
              { name = "Brinescale Priestess", desc = "2 adds: heal him and cast Frostbolt. Interrupt, crowd-control or kill first." },
          },
          tank = "Face him away from the group.",
          healer = "Frostbolts on the group while the priestesses live.",
          dps = "Priestesses first (interrupt the heals), then him.",
          positioning = "Boss faced away; harpooned players walk back out.",
          wipes = "Priestesses left alive healing him." },
        { name = "Captain Dreadrise", order = 3, contentType = "dungeon", bossType = "Caster, traps a player",
          tldr = "Pirate captain on the north side of the central pool. Clear his pirates first. Embrine traps a random player in a drowning water bubble: everyone breaks it. Interrupt every Waterbolt Volley.",
          abilities = {
              { name = "Embrine", desc = "Traps a random player in a water bubble that stuns and drowns them. Kill the bubble." },
              { name = "Waterbolt Volley", desc = "Hits the whole group. Interrupt it every time." },
          },
          tank = "Pull him away from any pirates still up.",
          healer = "The bubbled player takes drowning damage.",
          dps = "Switch to the bubble at once, then back to him. Interrupts on Waterbolt Volley.",
          positioning = "Clear the pirates around him first.",
          wipes = "A missed Waterbolt Volley while someone is drowning in a bubble." },
        { name = "Deathless Marrow", order = 4, contentType = "dungeon", bossType = "Caster with add waves",
          encounterID = 3478, altNames = { "Deathless Guardians" },   -- the game's encounter name
          tldr = "Bloodbolt hits the whole group for the entire fight. Adds come in waves, and every add that dies makes the boss take 20% more damage. Kill the first adds on top of him to stack that, then burn him while the tank holds the rest. Loot the Ancient Gurubashi Idol right away.",
          abilities = {
              { name = "Bloodbolt", desc = "Hits the whole group again and again: the main damage of the fight." },
              { name = "Adds die = +20% damage", desc = "Each add killed makes the boss take 20% more damage, and it stacks." },
              { name = "Deathless Guardian", desc = "Add: Shield Slam (stun)." },
              { name = "Deathless Sorcerer", desc = "Add: Fireball." },
              { name = "Deathless Watcher", desc = "Add: Charge." },
          },
          tank = "Grab each wave and hold the adds on top of the boss so the cleave kills them there. Once the boss is burning, keep the later adds off the group.",
          healer = "Bloodbolt never stops: pace your mana, use cheaper heals, take a mana potion early. Eat and drink before the pull, it's a long fight.",
          dps = "Cleave the first 3 to 6 adds down on the boss to stack his damage taken, then everything on the boss. Killing only adds runs the healer dry; ignoring them all leaves the boss too tough.",
          positioning = "Adds on top of the boss.",
          wipes = "The healer running out of mana in a fight that goes on too long without the stacks." },
        { name = "Gill", order = 5, contentType = "dungeon", bossType = "Rare elite",
          tldr = "Rare near the way to the Primeval Elemental. Throws dynamite at the tank that splashes: everyone else spreads out.",
          abilities = { { name = "Throw Dynamite", desc = "On the tank, splashes nearby players." } },
          tank = "Stand apart from the group.", healer = "Splash damage if people stack.",
          dps = "Spread out.", positioning = "Spread.", wipes = "The group stacked on the tank." },
        { name = "Min'loth the Serpent", order = 6, contentType = "dungeon", bossType = "Final boss, two phases",
          encounterID = 3479,
          tldr = "Final boss at the back, two health bars. Troll phase: Drench on the tank and Deluge on everyone, burn it. At 0% he turns into a serpent with full health: Poison Bolt Volley poisons the whole group and he Fears. Cleanse poison, keep Tremor Totem or Fear Ward up.",
          abilities = {
              { name = "Drench", desc = "Troll phase: heavy hit on the tank." },
              { name = "Deluge", desc = "Troll phase: damage on the whole group." },
              { name = "Serpent form", desc = "At 0% health he becomes a serpent with full health." },
              { name = "Poison Bolt Volley", desc = "Serpent phase: poisons the whole group. Cleanse, or heal through it." },
              { name = "Fear", desc = "Serpent phase. Tremor Totem / Fear Ward." },
          },
          tank = "Troll phase: Drench hurts. Serpent phase: get him back fast after Fears.",
          healer = "Cleanse the poison; group healing for Deluge and the volleys. Save mana: the second health bar is a whole new fight.",
          dps = "Burn both phases. Your cooldowns for the serpent.",
          positioning = "Tremor Totem where it covers everyone.",
          wipes = "Poison left on the group in the serpent phase." },
        { name = "Primeval Elemental", order = 7, contentType = "dungeon", bossType = "Hidden underwater boss",
          tldr = "Hidden boss in a flooded round chamber under Ataal'Byzal: kill every Undying Offering there and he appears. Interrupt Freeze Water and his Waterbolt. You're underwater the whole time: watch your breath (water breathing helps).",
          abilities = {
              { name = "Freeze Water", desc = "Slows and damages. Interrupt it." },
              { name = "Waterbolt", desc = "On the tank. Interruptible." },
          },
          tank = "Hold him where the group can reach air.",
          healer = "Tank damage from Waterbolt.",
          dps = "Interrupts on Freeze Water and Waterbolt.",
          positioning = "Underwater: mind your breath.",
          wipes = "Drowning, or letting Freeze Water finish." },
        { name = "Umbra", order = 8, contentType = "dungeon", bossType = "Rare elite murloc with adds",
          tldr = "Rare murloc with five Saltscale Murlocs whose bleeds stack. Tank them together and kill them with area damage.",
          abilities = { { name = "Bleed", desc = "The Saltscale Murlocs' bleeds stack on whoever they hit." } },
          tank = "Pick up all five adds.", healer = "Stacking bleeds.",
          dps = "Area damage on the adds.", positioning = "Adds stacked together.", wipes = "Loose adds stacking bleeds on the healer." },
    },
}

----------------------------------------------------------------------
-- ZUL'FARRAK (43-50, Tanaris) - not in the cap-30 beta
-- Classic data, not yet confirmed on Forever (audit 2026-11-13: no
-- post-launch source shows a reworked boss). Rares Zerillis/Dustwraith
-- omitted. Theka added (Atlas + Conquest Capped). Nekrum/Sezz'ziz and
-- Ruuzlu are alt names on the Bly / Ukorz sheets.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Zul'Farrak",
    trashNotes = "Classic data, not yet confirmed on Forever. Open-area troll packs that link and run. Sandfury casters heal and Shadow Bolt. Scarab swarms near Theka. Basilisks around Antu'sul. Pyramid stairs event: huge troll waves - the classic wipe.",
    bosses = {
        { name = "Antu'sul", order = 1, contentType = "dungeon", bossType = "Totem caster + basilisks",
          tldr = "Calls basilisk adds as his health drops and drops totems. Kill the healing ward/totems, pick up basilisks.",
          abilities = { { name = "Basilisk adds", desc = "Summoned as his health drops." } },
          tank = "Grab basilisks.", healer = "Ramping damage.", dps = "Kill totems; burn him.",
          positioning = "Standard.", wipes = "Too many basilisks." },
        { name = "Theka the Martyr", order = 2, contentType = "dungeon", bossType = "Disease + physical immunity",
          tldr = "Cure his disease. Near 30% he turns immune to physical (and shadow) damage for a while - melee stop, casters and hunters finish him (one source, unconfirmed).",
          abilities = {
              { name = "Disease", desc = "Curable disease on players." },
              { name = "Martyr form", desc = "Physical-immune phase at low health." },
          },
          tank = "Hold him through the immune phase.", healer = "Cure the disease.",
          dps = "Casters/hunters carry the last stretch.", positioning = "Standard.",
          wipes = "Melee-heavy group stuck on the immune phase." },
        { name = "Witch Doctor Zum'rah", order = 3, contentType = "dungeon", bossType = "Caster + graveyard zombies",
          tldr = "Raises zombies from the graves around him and casts Shadow Bolt. Burn him, AoE zombies.",
          abilities = {
              { name = "Shadow Bolt", desc = "Shadow nuke. Forever guide lists a Shadow Bolt Volley - interrupt it (one source, unconfirmed)." },
              { name = "Summon Zombies", desc = "Zombies rise from graves." },
              { name = "Ward of Zum'rah", desc = "Ward that raises skeletons - kill it (one source, unconfirmed)." },
          },
          tank = "Pull him out of the graveyard if possible.", healer = "Shadow damage.",
          dps = "Boss focus.", positioning = "Away from graves.", wipes = "Zombie swarm." },
        { name = "Hydromancer Velratha", order = 4, contentType = "dungeon", bossType = "Water caster (Gahz'rilla pool)",
          tldr = "Naga caster at the pool - interrupt her heals. Her pool is where you summon Gahz'rilla.",
          abilities = {
              { name = "Healing Wave", desc = "Interrupt." },
          },
          tank = "Hold her.", healer = "Easy.", dps = "Kick heals.",
          positioning = "Pool edge.", wipes = "Rare." },
        { name = "Gahz'rilla", order = 5, contentType = "dungeon", bossType = "Summoned hydra",
          tldr = "Summoned with the Mallet of Zul'Farrak at the pool. Freeze Solid freezes a player; Gahz'rilla Slam knocks the group up.",
          abilities = {
              { name = "Freeze Solid", desc = "Freezes a target." },
              { name = "Gahz'rilla Slam", desc = "Knocks players into the air." },
              { name = "Icicle", desc = "Frost damage." },
          },
          tank = "Hold her at the pool.", healer = "Heal through Slam falls.", dps = "Burn.",
          positioning = "Pool platform.", wipes = "Rare if the group is geared." },
        { name = "Sergeant Bly", altNames = { "Nekrum Gutchewer", "Shadowpriest Sezz'ziz" }, order = 6, contentType = "dungeon", bossType = "Pyramid stairs event",
          tldr = "Freeing the prisoners (key from Sandfury Executioner) starts the stairs event: waves of trolls charge up while Shadowpriest Sezz'ziz and Nekrum Gutchewer join. At the top, Bly and his crew turn hostile. Kill Nekrum first, kick Sezz'ziz's heals, stay grouped for Psychic Scream; vs Bly's crew, kill the healer/casters first - Bly shield-bashes (one source, unconfirmed).",
          abilities = { { name = "Troll waves", desc = "Large waves on the stairs; Sezz'ziz (priest) and Nekrum come down." } },
          tank = "Hold the top of the stairs; let waves come to you.", healer = "Pace mana for a long event.",
          dps = "AoE waves; kill Sezz'ziz.", positioning = "Top of the pyramid.",
          wipes = "Healer OOM mid-waves; group spread down the stairs." },
        { name = "Chief Ukorz Sandscalp", altNames = { "Ruuzlu" }, order = 7, contentType = "dungeon", bossType = "Final boss + Ruuzlu",
          tldr = "Fights alongside Ruuzlu. Ukorz cleaves and enrages - tank both, face away. Kill Ruuzlu first (one source, unconfirmed).",
          abilities = {
              { name = "Cleave", desc = "Frontal." },
              { name = "Enrage", desc = "At low health." },
          },
          tank = "Face both away.", healer = "Spike at enrage.", dps = "Behind; kill one at a time.",
          positioning = "Faced away.", wipes = "Cleave on melee." },
    },
}

----------------------------------------------------------------------
-- MARAUDON (45-52, Desolace) - not in the cap-30 beta
-- Classic data, not yet confirmed on Forever (audit 2026-11-13). Razorlash
-- and Rotgrip added in Atlas order (WT + CC tips). Theradras: Repulsive
-- Gaze = fear, Dust Field = knockback (WT + CC). Landslide: adds despawn
-- when he dies (WT + CC). Gizlock placement per Atlas (map B).
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Maraudon",
    trashNotes = "Classic data, not yet confirmed on Forever. Satyr wing (purple) has stealthed Putridus Shadowstalkers. Inner caverns: large elementals and Theradrim Guardians hit hard and knock back. Many linked plant packs. Long dungeon - pick a wing (orange/purple) or inner route.",
    bosses = {
        { name = "Noxxion", order = 1, contentType = "dungeon", bossType = "Ooze split",
          tldr = "Periodically goes untargetable and splits into Noxxion's Spawns - kill/AoE the spawns. Toxic Volley poisons the group.",
          abilities = {
              { name = "Toxic Volley", desc = "Group poison damage." },
              { name = "Summon Spawns", desc = "Becomes untargetable and spawns small oozes." },
          },
          tank = "Grab spawns.", healer = "Cure poison; group heals.", dps = "AoE spawns.",
          positioning = "Standard.", wipes = "Spawns ignored." },
        { name = "Razorlash", order = 2, contentType = "dungeon", bossType = "Plant melee",
          tldr = "Big plant with Puncture and Cleave. Casters fight from max range.",
          abilities = {
              { name = "Cleave", desc = "Frontal - face him away." },
              { name = "Puncture", desc = "Hit on the tank." },
          },
          tank = "Face him away.", healer = "Tank focus.", dps = "Casters at max range; melee from behind.",
          positioning = "Faced away.", wipes = "Rare." },
        { name = "Lord Vyletongue", order = 3, contentType = "dungeon", bossType = "Ranged satyr",
          tldr = "Satyr lord with Multi-Shot and Blink, plus satyr adds. Clear stealthed trash first. One guide says: tank or CC his two satyr guards and kill him first; he also Smoke Bombs (stun) and Shoots (one source, unconfirmed).",
          abilities = {
              { name = "Multi-Shot", desc = "Hits several players." },
              { name = "Blink", desc = "Teleports away." },
          },
          tank = "Re-engage after Blink.", healer = "Group damage.", dps = "Adds first, or boss first with the guards CC'd.",
          positioning = "Standard.", wipes = "Stealthed adds joining." },
        { name = "Celebras the Cursed", order = 4, contentType = "dungeon", bossType = "Druid caster",
          tldr = "Wrath and Entangling Roots. Burn Celebras himself - his adds keep coming back. After he dies he returns friendly (Celebras the Redeemed) for the Scepter quest.",
          abilities = {
              { name = "Wrath", desc = "Nature nuke." },
              { name = "Entangling Roots", desc = "Root." },
          },
          tank = "Hold him; hold the adds without chasing kills.", healer = "Moderate.", dps = "Kick Wrath; boss first, adds after.",
          positioning = "Standard.", wipes = "Killing adds while he lives." },
        { name = "Landslide", order = 5, contentType = "dungeon", bossType = "Earth giant",
          tldr = "Knock Away and Trample; summons Theradrim Shardlings. Burn Landslide - the shardlings vanish when he dies. Tank against a wall.",
          abilities = {
              { name = "Knock Away", desc = "Knockback on the tank." },
              { name = "Trample", desc = "Hits nearby players." },
              { name = "Summon Shardlings", desc = "Rock adds that despawn when he dies. The summon also stuns nearby players (one source, unconfirmed)." },
          },
          tank = "Back to a wall; hold the shardlings.", healer = "Melee take Trample.", dps = "Boss only; ignore the shardlings.",
          positioning = "Wall.", wipes = "Damage wasted on adds; knockbacks into packs." },
        { name = "Tinkerer Gizlock", order = 6, contentType = "dungeon", bossType = "Goblin engineer",
          tldr = "Throws bombs and uses a Goblin Dragon Gun cone. Avoid his front.",
          abilities = {
              { name = "Bomb", desc = "AoE explosive." },
              { name = "Goblin Dragon Gun", desc = "Frontal fire cone." },
          },
          tank = "Face away.", healer = "AoE damage.", dps = "Behind him.",
          positioning = "Faced away.", wipes = "Rare." },
        { name = "Rotgrip", order = 7, contentType = "dungeon", bossType = "Underwater crocolisk",
          tldr = "Crocolisk under the water - pull him up to the surface. Fatal Bite hits hard, so the tank needs cooldowns.",
          abilities = { { name = "Fatal Bite", desc = "Heavy bite on the tank." } },
          tank = "Pull him to the surface; cooldowns for Fatal Bite.", healer = "Tank focus.", dps = "Burn.",
          positioning = "At the surface, not underwater.", wipes = "Fighting him underwater." },
        { name = "Princess Theradras", order = 8, contentType = "dungeon", bossType = "Final boss",
          tldr = "Repulsive Gaze fears the group - bring Fear Ward, Tremor Totem or Berserker Rage. Dust Field knocks back players around her, so fight away from edges and the river. Boulders on players.",
          abilities = {
              { name = "Repulsive Gaze", desc = "Group fear - Fear Ward / Tremor Totem / Berserker Rage." },
              { name = "Dust Field", desc = "Knockback around her." },
              { name = "Boulder", desc = "Hurls boulders at players." },
              { name = "Thrash", desc = "Extra attacks." },
          },
          tank = "Hold her away from edges and the water.", healer = "Fear protection ready; spread damage.",
          dps = "Do not get knocked or feared into the river.", positioning = "Away from edges and the river; ranged spread.",
          wipes = "Fears and knockbacks with no counter." },
    },
}

----------------------------------------------------------------------
-- THE TEMPLE OF ATAL'HAKKAR / SUNKEN TEMPLE (49-56, Swamp of Sorrows)
-- Classic data, not yet confirmed on Forever (audit 2026-11-13). NAME:
-- lists say "Sunken Temple" (kami-labs, VoidDB) vs "Temple of
-- Atal'Hakkar" (Warcraft Tavern) - combined name + aliases. Atal'ai
-- Defender minibosses folded into one. Dreamscythe/Weaver are pulled one
-- at a time; Morphaz/Hazzas are a separate pair (WT + CC).
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "The Temple of Atal'Hakkar (Sunken Temple)",
    trashNotes = "Classic data, not yet confirmed on Forever. Dragonkin (Nightmare Wyrmkin/Wanderers etc.) sleep and breathe - face them away. Atal'ai troll casters hex and heal - interrupt. Oozes and drakes downstairs. Big linked packs on the balconies around Jammal'an.",
    bosses = {
        { name = "Atal'alarion", order = 1, contentType = "dungeon", bossType = "Statue puzzle boss",
          tldr = "Summoned by activating the six statues in the right order, in the lower ring around the Pit of Refuse. Sweeping Slam and Pound - tank faces him away. Statue order S, N, SW, SE, NW, NE; he also has Ground Tremor, a group stun (one source, unconfirmed).",
          abilities = {
              { name = "Sweeping Slam", desc = "Frontal knock." },
              { name = "Pound", desc = "Tank hit." },
          },
          tank = "Face away.", healer = "Tank focus.", dps = "Behind.",
          positioning = "Faced away.", wipes = "Rare." },
        { name = "Atal'ai Defenders", order = 2, contentType = "dungeon", bossType = "6 balcony trolls",
          tldr = "Gasher, Loro, Hukku, Zolo, Mijan and Zul'Lor on the balconies - all six must die to drop the barrier to Jammal'an.",
          abilities = { { name = "Mixed troll kits", desc = "Each is a single elite troll miniboss." } },
          tank = "Pull each balcony carefully.", healer = "Pace mana.", dps = "Kick casters.",
          positioning = "Balconies.", wipes = "Overpulling balcony packs." },
        { name = "Jammal'an the Prophet", order = 3, contentType = "dungeon", bossType = "Caster + Ogom",
          tldr = "With Ogom the Wretched. Hex of Jammal'an takes control of a player; Flamestrike - spread out; interrupt Healing Wave; kill Earthgrab Totem. Guides disagree on whether Ogom or Jammal'an dies first.",
          abilities = {
              { name = "Hex of Jammal'an", desc = "Controls a player." },
              { name = "Flamestrike", desc = "Ground fire AoE - spread and move out." },
              { name = "Shadow Word: Pain", desc = "Shadow DoT." },
              { name = "Healing Wave", desc = "Interrupt." },
              { name = "Earthgrab Totem", desc = "Roots - kill it." },
          },
          tank = "Hold both.", healer = "Watch for the hex.", dps = "Kick heals, kill totems.",
          positioning = "Spread for Flamestrike.", wipes = "Hexed player + uninterrupted heals." },
        { name = "Dreamscythe", altNames = { "Weaver" }, order = 4, contentType = "dungeon", bossType = "Two patrolling dragons (one at a time)",
          tldr = "Dreamscythe and Weaver appear after Jammal'an dies and patrol. Pull them ONE at a time, tank against a wall facing away - Acid Breath and Wing Flap.",
          abilities = {
              { name = "Acid Breath", desc = "Frontal breath." },
              { name = "Wing Flap", desc = "Knockback." },
          },
          tank = "One dragon at a time, back to a wall, faced away.", healer = "Tank focus.", dps = "Behind.",
          positioning = "Faced away, against a wall.", wipes = "Both dragons pulled together; breath on the group." },
        { name = "Morphaz", altNames = { "Hazzas" }, order = 5, contentType = "dungeon", bossType = "Dragon pair (with Hazzas)",
          tldr = "Morphaz and Hazzas come after Dreamscythe and Weaver and are pulled together. Green dragons - face both away.",
          abilities = { { name = "Dragon pair", desc = "Two dragons on the tank at once." } },
          tank = "Hold both, faced away.", healer = "Tank focus.", dps = "Behind; focus one.",
          positioning = "Faced away.", wipes = "Breath on the group." },
        { name = "Avatar of Hakkar", order = 6, contentType = "dungeon", bossType = "Quest event",
          tldr = "Quest event (Egg of Hakkar): kill Hakkari Bloodkeepers and use their blood to extinguish the eternal flames before the Avatar is summoned. Cause Insanity turns a player on the group - CC or stun them; Curse of Tongues slows casts - decurse.",
          abilities = {
              { name = "Flames/waves", desc = "Waves of adds while you extinguish the flames." },
              { name = "Cause Insanity", desc = "Takes control of a player - CC/stun them." },
              { name = "Curse of Tongues", desc = "Slower casting - decurse." },
          },
          tank = "Hold adds.", healer = "Long event - pace mana; decurse.", dps = "Kill Bloodkeepers, extinguish flames; CC the insane player.",
          positioning = "Central chamber.", wipes = "Flames not put out in time." },
        { name = "Shade of Eranikus", order = 7, contentType = "dungeon", bossType = "Final boss",
          tldr = "Attackable only after Jammal'an dies; clear ALL the dragonkin first or they join. Deep Slumber, Acid Breath, War Stomp - face away. Deep Slumber hits the top-threat player, so have an off-tank or pet ready (one source, unconfirmed).",
          abilities = {
              { name = "Deep Slumber", desc = "Sleep." },
              { name = "Acid Breath", desc = "Frontal breath." },
              { name = "War Stomp", desc = "AoE stun." },
          },
          tank = "Face away.", healer = "Pre-heal before sleeps.", dps = "Behind.",
          positioning = "Faced away; dragonkin cleared.", wipes = "Dragonkin joining; sleep + breath on the group." },
    },
}

----------------------------------------------------------------------
-- BLACKROCK DEPTHS (52-60, Blackrock Mountain) - not in the cap-30 beta
-- Classic data, not yet confirmed on Forever (audit 2026-11-13). Only the
-- main/route bosses are covered (21 total in BRD). Hotfix 11-09: throne
-- room doors reopen after a wipe on Thaurissan.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Blackrock Depths",
    trashNotes = "Classic data, not yet confirmed on Forever. Dark Iron patrols on the highway and in the city - watch pathing. Anvilrage guards in linked packs. Fireguard elementals and golems in the Manufactory. Grim Guzzler bar: attacking patrons or getting caught stealing ale turns the whole bar hostile. Bloodhound packs around the Houndmaster.",
    bosses = {
        { name = "High Interrogator Gerstahn", order = 1, contentType = "dungeon", bossType = "Shadow priest",
          tldr = "Psychic Scream fears, Mana Burn, Shadow Word: Pain and a Shadow Shield. Tremor/Fear Ward, dispel.",
          abilities = {
              { name = "Psychic Scream", desc = "AoE fear." },
              { name = "Mana Burn", desc = "Drains mana." },
              { name = "Shadow Word: Pain", desc = "DoT." },
              { name = "Shadow Shield", desc = "Self shield." },
          },
          tank = "Hold her.", healer = "Dispel; fear protection.", dps = "Kick Mana Burn.",
          positioning = "Standard.", wipes = "Fears into patrols." },
        { name = "Ring of Law", order = 2, contentType = "dungeon", bossType = "Arena event",
          tldr = "Walking into the arena starts it: add waves, then one random arena boss. Stay central and pace mana.",
          abilities = { { name = "Random boss", desc = "One of several possible arena bosses after the waves." } },
          tank = "Pick up waves.", healer = "Pace mana.", dps = "AoE waves.",
          positioning = "Center of the ring.", wipes = "OOM before the boss." },
        { name = "Lord Incendius", order = 3, contentType = "dungeon", bossType = "Fire elemental lord",
          tldr = "Fire Storm on the group, Mighty Blow knocks the tank away, Curse of the Elemental Lord. Tank him in the middle of the platform - a knock off the edge has no way back.",
          abilities = {
              { name = "Fire Storm", desc = "Fire AoE." },
              { name = "Mighty Blow", desc = "Knocks the tank back." },
              { name = "Curse of the Elemental Lord", desc = "Curse - decurse." },
          },
          tank = "Middle of the platform, away from the edges.", healer = "Fire damage; decurse.", dps = "Burn; stay off the edges.",
          positioning = "Platform center; nobody near the edges.", wipes = "Tank or players knocked off the platform." },
        { name = "General Angerforge", order = 4, contentType = "dungeon", bossType = "Adds at low health",
          tldr = "At low health he calls Anvilrage reinforcements. Burn the last third fast or have CC/AoE ready.",
          abilities = {
              { name = "Call reinforcements", desc = "Anvilrage adds near the end." },
              { name = "Sunder Armor", desc = "Stacks on the tank - armor keeps dropping." },
          },
          tank = "Grab the adds; mind the Sunder stacks.", healer = "Spike at adds.", dps = "Burn the last 30%.",
          positioning = "Clear his room first.", wipes = "Adds swarm the healer." },
        { name = "Golem Lord Argelmach", order = 5, contentType = "dungeon", bossType = "Golem activator",
          tldr = "He activates golems in his room - clear them first. Chain Lightning and Shock.",
          abilities = {
              { name = "Chain Lightning", desc = "Bouncing nature damage." },
              { name = "Lightning Shield", desc = "Hurts melee who hit him." },
          },
          tank = "Pull after the room is cleared.", healer = "Group damage; melee take shield damage.", dps = "Spread.",
          positioning = "Spread.", wipes = "Waking extra golems." },
        { name = "Ambassador Flamelash", order = 6, contentType = "dungeon", bossType = "Fire elemental + spirits",
          tldr = "Burning Spirits spawn around the room and run to empower him - kill them before they reach him.",
          abilities = { { name = "Burning Spirits", desc = "Adds that buff him on arrival." } },
          tank = "Hold him.", healer = "Fire damage.", dps = "Intercept spirits.",
          positioning = "Spread to intercept.", wipes = "Spirits reaching him." },
        { name = "The Seven", order = 7, contentType = "dungeon", bossType = "Gauntlet of 7 dwarf spirits",
          tldr = "Talk to Doom'rel to start: Anger'rel, Seeth'rel, Dope'rel, Gloom'rel, Vile'rel, Hate'rel come one at a time, then Doom'rel himself. Long - pace mana.",
          abilities = { { name = "Sequential bosses", desc = "Each dwarf has its own class-like kit." } },
          tank = "Pick up each as it activates.", healer = "Mana management.", dps = "One at a time.",
          positioning = "Vault room.", wipes = "Healer OOM mid-sequence." },
        { name = "Magmus", order = 8, contentType = "dungeon", bossType = "Gatekeeper giant",
          tldr = "Molten giant guarding the palace. The statues along the hall spout fire during the fight - keep the group out of their path.",
          abilities = {
              { name = "War Stomp", desc = "AoE stun." },
              { name = "Fiery Burst", desc = "Fire damage." },
          },
          tank = "Hold him away from statue fire.", healer = "Fire damage.", dps = "Burn.",
          positioning = "Center, away from statues.", wipes = "Group in statue fire." },
        { name = "Emperor Dagran Thaurissan", order = 9, contentType = "dungeon", bossType = "Final boss + Moira",
          tldr = "Princess Moira Bronzebeard heals him - interrupt/CC her (killing her fails the Alliance quest; kill the Emperor first and she turns friendly). Hand of Thaurissan stuns.",
          abilities = {
              { name = "Hand of Thaurissan", desc = "Stun." },
              { name = "Avatar of Flame", desc = "Fire burst." },
              { name = "Moira's heals", desc = "Interrupt/CC her." },
          },
          tank = "Hold the Emperor.", healer = "Big damage.", dps = "Kick Moira, burn the Emperor.",
          positioning = "Throne room.", wipes = "Moira healing him freely." },
    },
}

----------------------------------------------------------------------
-- LOWER BLACKROCK SPIRE (55-60, Blackrock Mountain) - not in the cap-30 beta
-- Classic data, not yet confirmed on Forever (audit 2026-11-13). Classic
-- GetInstanceInfo returns "Blackrock Spire" (LBRS + UBRS share it) -
-- aliased; substring lookup also matches. Forever group cap is 10 (Atlas +
-- VoidDB); tips assume 5. Zigris, Halycon, Gizrul added (Atlas order,
-- Warcraft Tavern tips).
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Lower Blackrock Spire",
    trashNotes = "Classic data, not yet confirmed on Forever. Huge ogre/orc/troll packs that link - Smolderthorn trolls hex and enrage. Spire spider room: eggs hatch spiderlings. Orc packs near Wyrmthalak. Patrols in the main halls. Long clear - drink between pulls.",
    bosses = {
        { name = "Highlord Omokk", order = 1, contentType = "dungeon", bossType = "Ogre boss",
          tldr = "Big ogre with Knock Away; clear the ogres around his platform first. Two adds fight with him and he enrages (one source, unconfirmed).",
          abilities = { { name = "Knock Away", desc = "Knocks the tank back." } },
          tank = "Back to a wall.", healer = "Tank focus.", dps = "Burn.",
          positioning = "Platform cleared.", wipes = "Ogre packs joining." },
        { name = "Shadow Hunter Vosh'gajin", order = 2, contentType = "dungeon", bossType = "Troll caster",
          tldr = "Hex and Curse of Blood. Decurse, burn. Two Smolderthorn Shadow Priests come with her - CC both or kill one first; her Hex can catch several players (one source, unconfirmed).",
          abilities = {
              { name = "Hex", desc = "Polymorph-like." },
              { name = "Curse of Blood", desc = "Curse - decurse." },
          },
          tank = "Hold her.", healer = "Decurse.", dps = "Burn.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "War Master Voone", order = 3, contentType = "dungeon", bossType = "Troll warrior",
          tldr = "Throw Axe, Mortal Strike, Cleave and Snap Kick. Face away, heal through MS.",
          abilities = {
              { name = "Mortal Strike", desc = "Reduces healing on the tank." },
              { name = "Cleave", desc = "Frontal." },
              { name = "Throw Axe", desc = "Ranged hit." },
          },
          tank = "Face away; cooldown during MS.", healer = "Pre-heal through MS.", dps = "Behind.",
          positioning = "Faced away.", wipes = "Tank dies under MS." },
        { name = "Mother Smolderweb", order = 4, contentType = "dungeon", bossType = "Spider",
          tldr = "Crystallize stuns players in place; poison. Clear the spider room first.",
          abilities = {
              { name = "Crystallize", desc = "Stun/encases players." },
              { name = "Mother's Milk", desc = "Poison." },
          },
          tank = "Hold her.", healer = "Cure poison.", dps = "Burn.",
          positioning = "Room cleared.", wipes = "Spiderlings + stuns." },
        { name = "Urok Doomhowl", order = 5, contentType = "dungeon", bossType = "Summon event",
          tldr = "Optional quest summon: waves of ogres before Urok. Big pulls - be ready. Roughshod Pikes help against the ogres, and Urok has a fear roar (one source, unconfirmed).",
          abilities = { { name = "Ogre waves", desc = "Adds before Urok appears." } },
          tank = "Hold waves.", healer = "Pace mana.", dps = "AoE.",
          positioning = "Standard.", wipes = "OOM before Urok." },
        { name = "Quartermaster Zigris", order = 6, contentType = "dungeon", bossType = "Orc with Stun Bomb",
          tldr = "Spread out so his Stun Bomb catches as few players as possible (one source, unconfirmed).",
          abilities = { { name = "Stun Bomb", desc = "AoE stun where it lands." } },
          tank = "Hold him.", healer = "Stay apart from the group.", dps = "Spread.",
          positioning = "Spread.", wipes = "Group stunned together." },
        { name = "Halycon", order = 7, contentType = "dungeon", bossType = "Worg mother + pups",
          tldr = "Kill her pups, then her. Gizrul the Slavener comes in right after she dies - be ready (one source, unconfirmed).",
          abilities = { { name = "Pups", desc = "Worg adds with her." } },
          tank = "Grab the pups.", healer = "Save mana for Gizrul.", dps = "Pups first.",
          positioning = "Standard.", wipes = "Gizrul arriving on a drained group." },
        { name = "Gizrul the Slavener", order = 8, contentType = "dungeon", bossType = "Follows Halycon",
          tldr = "Arrives right after Halycon dies. Enrages and uses Infected Bite - cure the disease (one source, unconfirmed).",
          abilities = {
              { name = "Enrage", desc = "Harder hits." },
              { name = "Infected Bite", desc = "Disease on the tank." },
          },
          tank = "Cooldowns for the enrage.", healer = "Cure the disease.", dps = "Burn.",
          positioning = "Halycon's area.", wipes = "Tank dies in the enrage." },
        { name = "Overlord Wyrmthalak", order = 9, contentType = "dungeon", bossType = "Final boss + adds",
          tldr = "Blast Wave, Cleave, Knock Away; calls in adds at low health. Clear the room and save cooldowns for the adds. One guide lists Cleave and Sweeping Slam, with adds at 50% - CC them (one source, unconfirmed).",
          abilities = {
              { name = "Blast Wave", desc = "AoE knock + slow." },
              { name = "Cleave", desc = "Frontal." },
              { name = "Knock Away", desc = "Tank knockback." },
              { name = "Adds", desc = "Called at low health." },
          },
          tank = "Face away; grab adds.", healer = "Spike at adds.", dps = "Burn boss, CC adds.",
          positioning = "Faced away.", wipes = "Adds + boss on healer." },
    },
}

----------------------------------------------------------------------
-- DIRE MAUL (East 55-60, West/North 57-60, Feralas) - all wings in one entry
-- Classic data, not yet confirmed on Forever (audit 2026-11-13). Classic
-- GetInstanceInfo returns "Dire Maul" for all wings; VoidDB uses
-- "Dire Maul (East)" etc. and Forever sources use Warpwood Quarter /
-- Capital Gardens / Gordok Commons - all aliased. Many minor bosses omitted.
-- Tribute rules fixed (games.gg + expcarry).
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Dire Maul",
    trashNotes = "Classic data, not yet confirmed on Forever. East: imps, satyrs and Warpwood treants/lashers; Pusillin runs away (chase him for the key). West: Highborne arcane casters and constructs; pylon areas packed. North: ogre packs; for a tribute run do not kill the guards.",
    bosses = {
        { name = "Zevrim Thornhoof", order = 1, contentType = "dungeon", bossType = "East - satyr",
          tldr = "East. Sacrifice locks a player in place and drains them - heal them through it.",
          abilities = { { name = "Sacrifice", desc = "Pins and drains a player." } },
          tank = "Hold him.", healer = "Heal the sacrificed player.", dps = "Burn.",
          positioning = "Standard.", wipes = "Healer sacrificed." },
        { name = "Alzzin the Wildshaper", order = 2, contentType = "dungeon", bossType = "East - shapeshifter (end)",
          tldr = "East end boss. Shifts forms during the fight - tank keeps threat through each change. Each shift resets threat, and near 35% the wall breaks and adds pour in - clear the ramp first (one source, unconfirmed).",
          abilities = { { name = "Shapeshift", desc = "Changes forms during the fight." } },
          tank = "Retaunt on form changes.", healer = "Steady.", dps = "Watch threat after shifts.",
          positioning = "Standard.", wipes = "Threat loss on a form change." },
        { name = "Tendris Warpwood", order = 3, contentType = "dungeon", bossType = "West - ancient",
          tldr = "West. Big treant with Entangle and Trample, with Ironbark protectors nearby.",
          abilities = {
              { name = "Entangle", desc = "Root." },
              { name = "Trample", desc = "Hits nearby players." },
          },
          tank = "Hold him.", healer = "Melee damage.", dps = "Burn.",
          positioning = "Standard.", wipes = "Protectors added." },
        { name = "Immol'thar", order = 4, contentType = "dungeon", bossType = "West - pylon-sealed demon",
          tldr = "West. Shut down all 5 pylons first (each guarded) to open his prison. He summons Eyes of Immol'thar and Portal teleports a player to him.",
          abilities = {
              { name = "Eye of Immol'thar", desc = "Adds." },
              { name = "Portal of Immol'thar", desc = "Teleports a player. Described as a launch into the air with fall damage (one source, unconfirmed)." },
              { name = "Trample", desc = "Hits nearby." },
          },
          tank = "Hold him, retaunt if needed.", healer = "Heal the ported player.", dps = "Kill eyes.",
          positioning = "Center.", wipes = "Eyes swarm." },
        { name = "Prince Tortheldrin", order = 5, contentType = "dungeon", bossType = "West - end boss",
          tldr = "West end. Whirlwind and Arcane Blast knockback.",
          abilities = {
              { name = "Whirlwind", desc = "Melee AoE." },
              { name = "Arcane Blast", desc = "Arcane hit + knockback. Also resets threat - stop DPS until the tank has him back (one source, unconfirmed)." },
          },
          tank = "Hold him.", healer = "Melee damage.", dps = "Melee leave on Whirlwind.",
          positioning = "Standard.", wipes = "Melee in Whirlwind." },
        { name = "King Gordok", order = 6, contentType = "dungeon", bossType = "North - ogre king (tribute)",
          tldr = "North. Fights with Cho'Rush the Observer. Tribute run: keep Guard Mol'dar, Stomper Kreeg, Guard Fengus, Guard Slip'kik, Captain Kromcrush AND Cho'Rush alive - kill only King Gordok. Cho'Rush turns friendly once the King dies; killing him first lowers the tribute.",
          abilities = {
              { name = "Mortal Strike", desc = "Healing reduction on the tank." },
              { name = "War Stomp", desc = "AoE stun." },
              { name = "Cho'Rush", desc = "Do not kill him - off-tank and interrupt. Rolls a random caster kit (priest/shaman/mage) (one source, unconfirmed)." },
          },
          tank = "Hold Gordok; off-tank Cho'Rush without killing him.", healer = "Heal through MS.", dps = "King Gordok only. Kick Cho'Rush's casts.",
          positioning = "Throne room.", wipes = "MS + stomp on low tank." },
    },
}

----------------------------------------------------------------------
-- SCHOLOMANCE (58-60, Western Plaguelands) - not in the cap-30 beta
-- Classic data, not yet confirmed on Forever (audit 2026-11-13). Side-room
-- bosses folded into the Gandling entry. Marduk Blackpool + Vectus added
-- (Atlas + WT/CC).
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Scholomance",
    trashNotes = "Classic data, not yet confirmed on Forever. Necromancers raise skeletons; Spectral Tutors silence; Risen Constructs and Bone Golems hit hard. Viewing Room: event with Vectus/Marduk. Narrow corridors - watch linked packs.",
    bosses = {
        { name = "Kirtonos the Herald", order = 1, contentType = "dungeon", bossType = "Summoned event",
          tldr = "Summoned with the Blood of Innocents at the balcony brazier. Alternates bat and humanoid forms; disarms and swoops.",
          abilities = {
              { name = "Disarm", desc = "Disarms the tank." },
              { name = "Swoop", desc = "Bat form knockdown." },
          },
          tank = "Hold through form changes.", healer = "Steady.", dps = "Burn.",
          positioning = "Balcony.", wipes = "Rare." },
        { name = "Jandice Barov", order = 2, contentType = "dungeon", bossType = "Illusions",
          tldr = "Spawns many illusions of herself - find the real one and kill her. Curse of Blood - decurse.",
          abilities = {
              { name = "Illusions", desc = "Many copies - find the real Jandice." },
              { name = "Curse of Blood", desc = "Curse." },
          },
          tank = "Find and grab the real one.", healer = "Decurse.", dps = "AoE illusions or tab-target.",
          positioning = "Standard.", wipes = "Losing track of her." },
        { name = "Rattlegore", order = 3, contentType = "dungeon", bossType = "Bone golem",
          tldr = "Hits hard with Knock Away and War Stomp. Skeleton escorts come with him - clear them first. Tank against a wall. Drops the Viewing Room Key.",
          abilities = {
              { name = "Knock Away", desc = "Knocks the tank." },
              { name = "War Stomp", desc = "AoE stun around him." },
          },
          tank = "Back to wall.", healer = "Tank focus; stay out of stomp range.", dps = "Skeletons first, then burn.",
          positioning = "Wall.", wipes = "Skeletons left alive." },
        { name = "Marduk Blackpool", altNames = { "Vectus" }, order = 4, contentType = "dungeon", bossType = "Viewing Room event pair",
          tldr = "Viewing Room event (quest-gated) with Vectus. Marduk's shadow shield hurts melee and he has a damage aura; Vectus casts Flamestrike and Blast Wave - spread.",
          abilities = {
              { name = "Shadow shield", desc = "Damages melee who hit Marduk." },
              { name = "Flamestrike / Blast Wave", desc = "Vectus's fire AoE - spread, move out." },
          },
          tank = "Hold both.", healer = "Group fire damage plus Marduk's aura.", dps = "Spread; melee watch the shield.",
          positioning = "Spread.", wipes = "Group stacked in Vectus's fire." },
        { name = "Ras Frostwhisper", order = 5, contentType = "dungeon", bossType = "Frost lich",
          tldr = "Frost caster: Chill Nova, Frostbolt Volley and Fear. Clear his adds, interrupt, bring fear counters. For the quest, use the Soulbound Keepsake on him first.",
          abilities = {
              { name = "Chill Nova", desc = "Frost AoE around him." },
              { name = "Frostbolt Volley", desc = "Hits the group - interrupt." },
              { name = "Fear", desc = "Dispel or use fear counters." },
          },
          tank = "Hold him.", healer = "Group frost damage; dispel fear.", dps = "Kick volleys.",
          positioning = "Spread.", wipes = "Group damage." },
        { name = "Darkmaster Gandling", order = 6, contentType = "dungeon", bossType = "Final boss",
          tldr = "Unlocks after the six side-room bosses (Malicia, Krastinov, Polkelt, Ravenian, Alexei and Illucia Barov). Shadow Portal teleports a player into a side room full of adds - they must fight out. Kick Arcane Missiles and remove his curse (one source, unconfirmed).",
          abilities = { { name = "Shadow Portal", desc = "Teleports a player into a side room with adds." } },
          tank = "Hold him; expect being ported.", healer = "Heal ported players.", dps = "Burn him.",
          positioning = "Center.", wipes = "Healer ported and dies." },
    },
}

----------------------------------------------------------------------
-- STRATHOLME (58-60, Eastern Plaguelands) - Live + Undead sides
-- Classic data, not yet confirmed on Forever (audit 2026-11-13). Classic
-- GetInstanceInfo returns "Stratholme" for both sides. Magistrate
-- Barthilas added (Atlas + WT + CC). Hotfix 11-09: no mounts inside.
----------------------------------------------------------------------
D.dungeons[#D.dungeons + 1] = {
    name = "Stratholme",
    trashNotes = "Classic data, not yet confirmed on Forever. Live: Scarlet Crusade packs (Battle Mages, Sorcerers, Guardsmen) in linked groups. Undead: Plague Ghouls, Bile Spewers (spawn slimes), Venom Belchers, Crypt Beasts; ziggurat acolytes/shadowcasters. Patrols in the streets. Forever hotfix: you can no longer mount inside, so timed Baron runs are on foot.",
    bosses = {
        { name = "Timmy the Cruel", order = 1, contentType = "dungeon", bossType = "Live - courtyard",
          tldr = "Spawns after you clear the scourge in his square. Ravenous Claw on the tank.",
          abilities = { { name = "Ravenous Claw", desc = "Tank damage debuff." } },
          tank = "Hold him.", healer = "Tank focus.", dps = "Burn.",
          positioning = "Square.", wipes = "Rare." },
        { name = "Cannon Master Willey", order = 2, contentType = "dungeon", bossType = "Live - rifleman summoner",
          tldr = "Calls Crimson Riflemen - kill them or tank them. Use the cannons/cannonballs nearby on the riflemen.",
          abilities = { { name = "Summon Crimson Riflemen", desc = "Ranged adds - the cannons clear them." } },
          tank = "Grab riflemen.", healer = "Ranged damage.", dps = "Adds first.",
          positioning = "Standard.", wipes = "Rifleman stacks." },
        { name = "Archivist Galford", order = 3, contentType = "dungeon", bossType = "Live - fire caster",
          tldr = "Fire Nova and Burning Winds. Burn the archive for the quest.",
          abilities = {
              { name = "Fire Nova", desc = "AoE." },
              { name = "Burning Winds", desc = "Fire damage." },
          },
          tank = "Hold him.", healer = "Fire damage.", dps = "Burn.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Balnazzar", order = 4, contentType = "dungeon", bossType = "Live - final (Dathrohan transform)",
          tldr = "Grand Crusader Dathrohan transforms into Balnazzar. Mind control and Psychic Scream - CC the controlled player, fear protection.",
          abilities = {
              { name = "Mind Control", desc = "Controls a player." },
              { name = "Psychic Scream", desc = "AoE fear." },
          },
          tank = "Hold through the transform.", healer = "Fear ward; watch MC.", dps = "Burn.",
          positioning = "Standard.", wipes = "MC'd player + fear." },
        { name = "Magistrate Barthilas", order = 5, contentType = "dungeon", bossType = "Key holder",
          tldr = "Drops the Key to the City; the Service Gate stays locked on a first visit without it. Mighty Blow knocks back and Crowd Pummel hits nearby players - tank him against a wall (one source, unconfirmed).",
          abilities = {
              { name = "Mighty Blow", desc = "Knockback on the tank." },
              { name = "Crowd Pummel", desc = "Hits players around him." },
          },
          tank = "Back to a wall.", healer = "Melee damage.", dps = "Burn.",
          positioning = "Wall.", wipes = "Rare." },
        { name = "Baroness Anastari", order = 6, contentType = "dungeon", bossType = "Undead - ziggurat",
          tldr = "Possess takes over a player - damage that player to 50% health to break it, then heal them. She also Silences and casts Banshee Curse (decurse).",
          abilities = {
              { name = "Possess", desc = "Takes control of a player - bring them to 50% HP to free them." },
              { name = "Silence", desc = "Silences a player." },
              { name = "Banshee Curse", desc = "Curse - decurse." },
          },
          tank = "Hold her.", healer = "Heal the freed player at once; decurse.", dps = "Hit the possessed player down to 50%, then back on her.",
          positioning = "Standard.", wipes = "Possessed tank." },
        { name = "Nerub'enkan", order = 7, contentType = "dungeon", bossType = "Undead - ziggurat",
          tldr = "Encasing Webs root/slow players. Summons scarab adds - AoE them.",
          abilities = {
              { name = "Encasing Webs", desc = "Root/slow." },
              { name = "Scarabs", desc = "Summoned adds - AoE them down." },
          },
          tank = "Hold him; grab the scarabs.", healer = "Steady.", dps = "AoE scarabs, then burn.",
          positioning = "Standard.", wipes = "Rare." },
        { name = "Maleki the Pallid", order = 8, contentType = "dungeon", bossType = "Undead - ziggurat",
          tldr = "Frostbolt and Drain Life. Interrupt. Ice Tomb freezes the tank for a few seconds and he turns on someone else - DPS ease off, healer covers his new target.",
          abilities = {
              { name = "Frostbolt", desc = "Frost nuke." },
              { name = "Drain Life", desc = "Drain." },
              { name = "Ice Tomb", desc = "Freezes the tank briefly; he picks another target." },
          },
          tank = "Retake him after Ice Tomb.", healer = "Cover whoever he hits during Ice Tomb.", dps = "Kick; slow down during Ice Tomb.",
          positioning = "Standard.", wipes = "A DPS dies while the tank is frozen." },
        { name = "Ramstein the Gorger", order = 9, contentType = "dungeon", bossType = "Undead - abomination",
          tldr = "After the 3 ziggurat bosses the Slaughterhouse opens: abomination waves, then Ramstein. Trample hits hard. Knockout drops the tank's threat - have a taunt ready. After him, Mindless Undead waves and three Black Guard Sentries come before the Baron (one source, unconfirmed).",
          abilities = {
              { name = "Trample", desc = "Hits nearby players." },
              { name = "Knockout", desc = "Knocks the tank away and drops threat - he moves to the next player." },
          },
          tank = "Cooldowns; taunt back after Knockout.", healer = "Heavy tank damage.", dps = "Burn; watch threat after Knockout.",
          positioning = "Standard.", wipes = "Tank dies to Ramstein." },
        { name = "Baron Rivendare", order = 10, contentType = "dungeon", bossType = "Undead - final boss",
          tldr = "Raises skeletons and uses Death Pact to sacrifice them for a big heal - kill skeletons. Unholy Aura damages everyone. Cleave - melee stand behind him (one source, unconfirmed).",
          abilities = {
              { name = "Raise Dead", desc = "Skeleton adds." },
              { name = "Death Pact", desc = "Sacrifices skeletons to heal himself." },
              { name = "Unholy Aura", desc = "Damage aura." },
              { name = "Mortal Strike", desc = "Healing reduction on tank." },
          },
          tank = "Hold him.", healer = "Aura damage.", dps = "Skeletons first.",
          positioning = "Standard.", wipes = "Death Pact heals." },
    },
}

----------------------------------------------------------------------
-- Register the bosses: by name, by the dungeon's instance names, by encounter id.
----------------------------------------------------------------------
D.byExactName = D.byExactName or {}
D.byInstanceBoss = D.byInstanceBoss or {}
D.byName = D.byName or {}
D.instanceAliases = D.instanceAliases or {}

-- name key: lower case, no spaces, dashes or apostrophes
local function NormInstanceKey(s)
    return ((s or ""):lower():gsub("[%s%-']", ""))
end

local function RegisterBossName(boss, name)
    D.byExactName[name] = boss
    local key = name:lower():gsub("[%s%-'']", "")
    D.byName[key] = boss
end

for i = FIRST_FOREVER_INDEX, #D.dungeons do
    local dungeon = D.dungeons[i]
    local list = {}
    for _, boss in ipairs(dungeon.bosses or {}) do
        RegisterBossName(boss, boss.name)
        -- altNames: the unit names of bosses that share one sheet
        -- (e.g. "Sneed" pops out of "Sneed's Shredder"), so mouseover finds them.
        for _, alt in ipairs(boss.altNames or {}) do
            RegisterBossName(boss, alt)
        end
        -- the encounter id the game sends at the pull (measured in our own runs), so the sheet
        -- pops up even where the encounter name differs from the boss (Deathless Guardians)
        if boss.encounterID then D.byEncounterID[boss.encounterID] = boss end
        list[#list + 1] = boss
    end
    D.byInstanceBoss[dungeon.name] = list
    local aliases = INSTANCE_ALIASES[dungeon.name]
    if aliases then
        for _, alt in ipairs(aliases) do
            D.byInstanceBoss[alt] = list
            D.instanceAliases[NormInstanceKey(alt)] = dungeon
        end
    end
end
