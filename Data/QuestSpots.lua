-- VoidDungeon: quest objects on the dungeon maps (ours, hand-kept: the open data names these objects but has no spot
-- for them inside instances, and the game gives addons no position there). The user, 2026-11-20, alone in Zul'Farrak on
-- The Talisman of Kazdor: "so you put the dots on the maps with labels of the bosses, why cant we put dots on it for
-- the items".
-- [Atlas map key] = { { quest = questID, label, x, y (512x512 map art), name, gives, note, sure = measured by a player }, ... }
-- A dot shows while that quest is in your log. Objects and what they give: NorgannonDB (VoidDB, credits: NOTICE.txt);
-- spots: sure = a player found it there; the rest = "about here" until a run confirms them.
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end   -- WoW Forever only
local _, ns = ...
ns.QuestSpots = {
    ["CL_ZulFarrak"] = {
        -- The Talisman of Kazdor (rogues, from Fahrad at Ravenholdt Manor; you must be alone)
        { quest = 80411, label = "a", x = 420, y = 236, name = "Clay Vessel", gives = "Vile Concoction",
          note = "In the huts on the right side of the first big courtyard, before the hall up to Theka (2).", sure = true },
        { quest = 80411, label = "b", x = 450, y = 170, name = "Antu'Sul's Satchel", gives = "Offering of Bone",
          note = "Next to the cage by Antu'sul (1). He's immune to Sap and Blind: throw a Vile Concoction into the cauldron in front of him, or (a rogue did it 11-20) Vanish when he comes at you: he walks off long enough to loot the satchel." },
        { quest = 80411, label = "c", x = 336, y = 286, name = "Clay Vessel", gives = "Vile Concoction",
          note = "The hut nearest the base of the pyramid courtyard.", sure = true },
        { quest = 80411, label = "d", x = 330, y = 130, name = "Zum'Rah's Satchel", gives = "Ward of the Dead",
          note = "Throw the second Vile Concoction into Witch Doctor Zum'rah's cauldron (3, the graveyard); the satchel is beside him." },
        { quest = 80411, label = "e", x = 298, y = 134, name = "Shallow Grave", gives = "Offering of Flesh",
          note = "Wear the Ward of the Dead trinket: a glowing Shallow Grave in the graveyard. Bone + Flesh = Blood Magic Essence." },
        { quest = 80411, label = "f", x = 352, y = 192, name = "Sandfury Cache", gives = "Hollow Emblem",
          note = "Facing the pyramid (7), go right to the east courtyard wall, up onto the ledge and along it. Emblem + Essence = Emblem of Blood Magic." },
        { quest = 80411, label = "g", x = 318, y = 186, name = "Spellbound War Chest", gives = "Talisman of Kazdor",
          note = "Up on the pyramid (7). Needs the Emblem of Blood Magic." },
    },
}
