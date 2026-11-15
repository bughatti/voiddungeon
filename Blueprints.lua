----------------------------------------------------------------------
-- Blueprints.lua -- where WoW Forever's camp blueprints really drop, learned from loot (the user,
-- 2026-11-15: the level-3 sources aren't in any data and the guides disagree; "mark as unconfirmed"
-- plus this recorder to confirm or correct them).
--
-- When a loot window shows a "Blueprint: ..." item inside a dungeon, VoidDungeon notes the dungeon
-- (always readable) and the boss: the corpse's NPC when the game lets addons read it (it hides mob
-- identity inside dungeons), else the boss whose encounter you finished in the last 5 minutes there.
--   VoidDungeonDB.blueprints[itemID] = { { dungeon, boss (or nil), t }, ... }   your own, 5 kept
-- and shares it over the Void network (kind "b": piece = item, key = dungeon, value = boss or "?").
-- Another player's answer counts once 2 different players handed the same one over.
--
-- VoidDungeon:BlueprintDrops(item) -> { { dungeon, boss, own = true | n = players }, ... }
----------------------------------------------------------------------
local _, ns = ...
local J = ns.J
local B = {}
J.Blueprints = B

local SW = "b"
local KEEP = 5               -- your own records per blueprint
local BOSS_RECENT = 300      -- a finished encounter this recent names the boss of a drop

local function secret(v) return issecretvalue and issecretvalue(v) end
local function clean(s)
    if type(s) ~= "string" or secret(s) then return nil end
    s = s:gsub("[%c~%^:;=|/]", "")
    if s == "" or #s > 50 then return nil end
    return s
end

local npcName   -- npc id -> boss name, from the dungeon maps' legends
local function bossOf(npc)
    if not npcName then
        npcName = {}
        for _, m in pairs(ns.Atlas or {}) do
            for _, r in ipairs(m.rows or {}) do
                if r.npc then npcName[r.npc] = r[2] end
            end
        end
    end
    return npc and npcName[npc]
end

local function db()
    VoidDungeonDB = VoidDungeonDB or {}
    VoidDungeonDB.blueprints = VoidDungeonDB.blueprints or {}
    return VoidDungeonDB.blueprints
end

local function swarm()
    if not (VoidSwarm and VoidSwarm.Want) then return nil end
    if not B.wanted then
        B.wanted = true
        VoidDungeonDB = VoidDungeonDB or {}
        VoidDungeonDB.swarmB = VoidDungeonDB.swarmB or {}
        VoidSwarm.Want(SW, { need = 2, store = VoidDungeonDB.swarmB, maxPieces = 60, maxKeys = 20,
            paused = function() return VoidMarkDB and VoidMarkDB.shareOff and true or false end,   -- "Share fight results" off
            valid = function(piece, key, value)
                local item = tonumber(piece)
                return item and item > 200000 and item < 400000 and clean(key) == key
                    and (value == "?" or clean(value) == value) and true or false
            end })
    end
    return VoidSwarm.Get and VoidSwarm.Get()
end

local lastBoss    -- { name, dungeon, t }

-- note one drop (from a loot window, or a test)
function B:Record(item, dungeon, boss)
    item, dungeon, boss = tonumber(item), clean(dungeon), clean(boss)
    if not (item and dungeon) then return false end
    local list = db()[item] or {}
    db()[item] = list
    local known = false
    for _, r in ipairs(list) do
        if r.dungeon == dungeon and r.boss == boss then r.t = time(); known = true end
    end
    if not known then
        table.insert(list, 1, { dungeon = dungeon, boss = boss, t = time() })
        while #list > KEEP do table.remove(list) end
    end
    -- every sighting goes out, a repeat too (Codex: one first seen while the network was down was
    -- never shared)
    local net = swarm()
    if net and net.Report then pcall(net.Report, net, SW, tostring(item), dungeon, boss or "?", 600) end
    return true
end

-- where a blueprint drops, as far as you or 2+ other players have seen
function B:Of(item)
    local out, seen = {}, {}
    for _, r in ipairs(db()[tonumber(item) or 0] or {}) do
        local k = r.dungeon .. "|" .. (r.boss or "?")
        if not seen[k] then
            seen[k] = true
            out[#out + 1] = { dungeon = r.dungeon, boss = r.boss, own = true }
        end
    end
    local net = swarm()
    if net and net.Piece then
        local ok, piece = pcall(net.Piece, net, SW, tostring(item))
        for dungeon, boss in pairs(ok and piece or {}) do
            local k = dungeon .. "|" .. boss
            if not seen[k] then
                seen[k] = true
                local _, n = net:Get(SW, tostring(item), dungeon)
                out[#out + 1] = { dungeon = dungeon, boss = boss ~= "?" and boss or nil, n = n }
            end
        end
    end
    return out
end
function J:BlueprintDrops(item) return B:Of(item) end

local function inDungeon()
    local name, kind = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then return nil end
    return clean(name)
end

-- the boss of a loot slot: the corpse's NPC if readable, else the encounter just finished here
local function slotBoss(slot, dungeon)
    if GetLootSourceInfo then
        local src = { GetLootSourceInfo(slot) }
        for k = 1, #src, 2 do
            local g = src[k]
            if type(g) == "string" and not secret(g) then
                local _, _, _, _, _, id = strsplit("-", g)
                local name = bossOf(tonumber(id or ""))
                if name then return name end
            end
        end
    end
    if lastBoss and lastBoss.dungeon == dungeon and time() - lastBoss.t <= BOSS_RECENT then return lastBoss.name end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("LOOT_OPENED")
ev:RegisterEvent("ENCOUNTER_END")
ev:SetScript("OnEvent", function(_, event, a1, a2, _, _, a5)
    if event == "ENCOUNTER_END" then
        local name = a5 == 1 and clean(a2)
        local dungeon = inDungeon()
        if name and dungeon then lastBoss = { name = name, dungeon = dungeon, t = time() } end
        return
    end
    local dungeon = inDungeon()
    if not (dungeon and GetNumLootItems) then return end
    for slot = 1, GetNumLootItems() do
        local _, name = GetLootSlotInfo(slot)
        if type(name) == "string" and not secret(name) and name:find("^Blueprint: ") then
            local link = GetLootSlotLink and GetLootSlotLink(slot)
            local item = type(link) == "string" and not secret(link) and tonumber(link:match("item:(%d+)"))
            if item then pcall(B.Record, B, item, dungeon, slotBoss(slot, dungeon)) end
        end
    end
end)
