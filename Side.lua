----------------------------------------------------------------------
-- Side.lua — the tabs beside the dungeon map (VoidMap's side area, borrowed).
--   Quests  your quests for this dungeon (the quest log's header for it)
--   Loot    every boss's drops, or the selected boss's
--   Path    entrance, bosses and stops in Atlas's order; hover = spot on the map
--   Tips    the boss sheets (Data/Sheets.lua) + the boss card box (Sheets.lua)
--   Marks   your own markers per mob, used by the marking board in the run (Mark.lua)
--   Reserve soft reserve for the group (Reserve.lua)
--   BoE     BoE drops from your runs, handed out to the guild (Handout.lua)
----------------------------------------------------------------------
local _, ns = ...
local J = ns.J
local A = J.A
local S = {}
ns.Side = S

local ROW_H = 18
local TABS = { "Quests", "Loot", "Path", "Tips", "Marks", "Reserve", "BoE" }
local frame, list, head, more
local tabBtns, rows, entries, offset = {}, {}, {}, 0
S.open = {}   -- Quests tab: dungeon quests whose chain is unfolded (this session)

local function tab() return (VoidDungeonDB and VoidDungeonDB.tab) or "Path" end

----------------------------------------------------------------------
-- Entries per tab: { head = "..." } or { text, r, g, b, right, icon, item, row, quest, wrap }
----------------------------------------------------------------------
-- Race / class bit masks (bit raceID-1 / classID-1; 0 = everyone). Masks pass 2^32, so no bit.band.
local function hasBit(mask, id)
    if not mask or mask == 0 or not id then return true end
    return math.floor(mask / 2 ^ (id - 1)) % 2 == 1
end

local function questColor(level)
    local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level or 0)
    return c and c.r or 1, c and c.g or 0.82, c and c.b or 0
end

local function done(qid) return C_QuestLog.IsQuestFlaggedCompleted(qid) end
local function inLog(qid) return C_QuestLog.GetLogIndexForQuestID(qid) ~= nil end

-- Where a quest starts, as text: "Nara Wildmane, Thunder Bluff".
local function startText(s)
    if not s then return nil end
    if s[1] == "i" then
        local item = C_Item.GetItemNameByID(s[2]) or "an item"
        return item .. (s[3] ~= "" and (" (drops from " .. s[3] .. ")") or "")
    end
    local mi = s[4] and s[4] > 0 and C_Map.GetMapInfo(s[4])
    return (s[3] ~= "" and s[3] or "?") .. (mi and (", " .. mi.name) or "")
end

-- A dungeon's quest IDs. A map with no list of its own ("Scarlet Monastery", the overview of its
-- wings) gets the lists of every "Name: wing" entry, each quest once.
local function dungeonQuests(name)
    if not (ns.DQ and name) then return {} end
    if ns.DQ[name] then return ns.DQ[name] end
    local ids, seen, prefix = {}, {}, name .. ":"
    for key, list in pairs(ns.DQ) do
        if key:sub(1, #prefix) == prefix then
            for _, q in ipairs(list) do
                if not seen[q] then seen[q] = true; ids[#ids + 1] = q end
            end
        end
    end
    table.sort(ids)
    return ids
end

local function questEntries(out)
    local d = J.cur
    local want = d and d.name:lower()
    local ids = dungeonQuests(d and d.name)
    local listed = {}

    -- 1) in your log: this dungeon's quests, plus whatever sits under its header in the log
    local mine = {}
    local n = C_QuestLog.GetNumQuestLogEntries()
    local inHeader = false
    for i = 1, n do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                local h = (info.title or ""):lower()
                -- "Scarlet Monastery" is the header for all four wings
                inHeader = want and h ~= "" and (h == want or want:find(h, 1, true) == 1 or h:find(want, 1, true) == 1)
            elseif info.questID and not info.isHidden and (inHeader or tContains(ids, info.questID)) then
                mine[#mine + 1] = info
            end
        end
    end
    -- the quest's rewards under it (the user, 2026-11-13: Sword of Omen, an SM quest reward, wasn't
    -- in VoidDungeon): "Reward: A, B" or "Pick one: A / B / C"
    -- "pick one" only when known: VoidQuest reads the real split from your quest log or a quest giver
    -- seen before; the data's VoidDB fills ("unsplit: A / B") don't say which are a choice
    local function rewardRow(qid, dim)
        local VF = VoidQuest and VoidQuest.Forever
        local text = VF and VF.RewardText and VF:RewardText(qid)
        if not text then
            local q = ns.QI and ns.QI[qid]
            local s = q and q[8]
            if not s or s == "" then return end
            local u = s:match("^unsplit:%s*(.*)$")
            text = u and (u .. (u:find(" / ", 1, true) and " (not known yet which are a choice)" or " (and rewards not known yet)"))
                or s:gsub("^choose:%s*", "pick one: "):gsub(";%s*choose:%s*", ", and pick one: ")
        end
        local pick = text:find("^pick one: ")
        local k = dim and 0.55 or 1
        out[#out + 1] = { text = "      " .. (pick and ("Pick one: " .. text:sub(11)) or ("Reward: " .. text)),
            r = 0.55 * k, g = 0.8 * k, b = 1 * k, wrap = true }
    end
    out[#out + 1] = { head = "In your log" }
    for _, info in ipairs(mine) do
        listed[info.questID] = true
        local r, g, b = questColor(info.level)
        out[#out + 1] = { text = ("[%d] %s"):format(info.level or 0, info.title or "?"), r = r, g = g, b = b,
            right = C_QuestLog.IsComplete(info.questID) and "|cff33ff33Done|r" or "", quest = info.questID }
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
            if o.text and o.text ~= "" then
                out[#out + 1] = { text = "   " .. o.text, r = o.finished and 0.4 or 0.75,
                    g = o.finished and 0.8 or 0.75, b = o.finished and 0.4 or 0.8 }
            end
        end
        rewardRow(info.questID)
    end
    if #mine == 0 then out[#out + 1] = { text = "   none", r = 0.5, g = 0.5, b = 0.55 } end

    -- 2) not picked up yet: for your race and class, not done, not in the log
    local race = select(3, UnitRace("player"))
    local class = select(3, UnitClass("player"))
    local level = UnitLevel("player")
    local ready, later = {}, {}
    local env = ns.Chain and ns.Chain.GameEnv()
    for _, qid in ipairs(ids) do
        local q = ns.QI and ns.QI[qid]
        if q and not listed[qid] and not done(qid) and not inLog(qid) and hasBit(q[4], race) and hasBit(q[5], class) then
            local e = { qid = qid, q = q }
            -- the whole way in (Chain.lua): every quest before this one, with where you stand on each
            e.steps = ns.Chain and ns.Chain:Steps(qid, env) or {}
            e.left = ns.Chain and ns.Chain:Left(e.steps) or 0
            e.start = ns.Chain and ns.Chain:Start(e.steps)
            if e.left > 0 then
                later[#later + 1] = e
            elseif (q[3] or 0) > level then
                e.needLevel = q[3]
                later[#later + 1] = e
            else
                ready[#ready + 1] = e
            end
        end
    end
    local byLevel = function(a, b) return (a.q[2] or 0) < (b.q[2] or 0) end
    table.sort(ready, byLevel)
    table.sort(later, byLevel)
    local function add(e, dim)
        local q = e.q
        local s = q[6]
        local r, g, b = questColor(q[2])
        if dim then r, g, b = r * 0.55, g * 0.55, b * 0.55 end
        local right
        if e.left > 0 then
            right = ("|cff8c8c9e%d quest%s first|r"):format(e.left, e.left == 1 and "" or "s")
        elseif e.needLevel then
            right = "|cff8c8c9eat " .. e.needLevel .. "|r"
        elseif s and s[1] == "i" then
            right = "|cffffd200inside|r"
        else
            local mi = s and s[4] and s[4] > 0 and C_Map.GetMapInfo(s[4])
            right = mi and ("|cffffd200" .. mi.name .. "|r") or ""
        end
        local open = e.left > 0 and S.open[e.qid]
        out[#out + 1] = { text = ("%s[%d] %s"):format(e.left > 0 and (open and "|cff4fd8ff- |r" or "|cff4fd8ff+ |r") or "", q[2] or 0, q[1]),
            r = r, g = g, b = b, right = right, missing = e, wrap = true }
        rewardRow(e.qid, dim)
        if open then
            -- the way in, oldest first: where you stand on each step, and where to start now
            for i, s in ipairs(e.steps) do
                local sq = s.q
                local title = sq and sq[1] or ("quest " .. s.qid)
                local here = s == e.start
                local sr, sg, sb = 0.75, 0.75, 0.8
                local sright
                if s.state == "done" then
                    sr, sg, sb, sright = 0.4, 0.62, 0.4, "|cff66aa66done|r"
                elseif s.state == "log" then
                    sr, sg, sb, sright = 1, 0.82, 0, "|cffffd200in your log|r"
                elseif s.state == "ready" then
                    sr, sg, sb = questColor(sq[2])
                    local st = sq[6]
                    local mi = st and st[1] ~= "i" and st[4] and st[4] > 0 and C_Map.GetMapInfo(st[4])
                    sright = st and st[1] == "i" and "|cffffd200an item|r" or (mi and ("|cffffd200" .. mi.name .. "|r")) or ""
                elseif s.state == "level" then
                    sright = "|cff8c8c9eat " .. tostring(s.n) .. "|r"
                elseif s.state == "after" then
                    sr, sg, sb, sright = 0.55, 0.55, 0.6, ""
                else
                    sr, sg, sb, sright = 0.55, 0.55, 0.6, "|cff8c8c9eunknown|r"
                end
                out[#out + 1] = { text = ("    %s%d. %s%s"):format(here and "|cff55ff55>|r " or "", i,
                    sq and ("[" .. (sq[2] or 0) .. "] ") or "", title), r = sr, g = sg, b = sb, right = sright, step = s, wrap = true }
            end
            out[#out + 1] = { text = ("    %d. %s"):format(#e.steps + 1, q[1]), r = 0.55, g = 0.55, b = 0.6,
                right = "|cff8c8c9ethis one|r" }
        end
    end
    if #ready + #later > 0 then
        out[#out + 1] = { head = "Not picked up yet" }
        for _, e in ipairs(ready) do add(e, false) end
        for _, e in ipairs(later) do add(e, true) end
        out[#out + 1] = { text = "Click one: the way there. With quests before it (+): the whole chain, where you stand on each, and where to start.", r = 0.45, g = 0.45, b = 0.5, wrap = true }
    elseif #ids == 0 then
        out[#out + 1] = { head = "Not picked up yet" }
        out[#out + 1] = { text = "No quests known for " .. (d and d.name or "this dungeon") .. " yet.", r = 0.5, g = 0.5, b = 0.55, wrap = true }
    end
end

-- Route to where a missing quest starts: VoidGPS when installed (crosses continents),
-- else a map pin on that zone.
local function routeTo(e)
    local q, s = e.q, e.q[6]
    if not s then return end
    if s[1] == "i" then
        J:Print(q[1] .. " starts from " .. startText(s) .. ".")
        return
    end
    if not (s[4] and s[4] > 0) then J:Print("No known spot for " .. q[1] .. "'s giver.") return end
    local target = { name = s[3] ~= "" and s[3] or q[1], sub = q[1], map = s[4], x = s[5], y = s[6] }
    if VoidGPS and VoidGPS.RouteTo and VoidGPS:RouteTo(target) then return end
    if C_Map.CanSetUserWaypointOnMap(s[4]) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(s[4], s[5], s[6]))
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        J:Print("Map pin set: " .. startText(s) .. " (" .. q[1] .. ").")
    end
end

local function bossRows()
    local m = J.map and ns.Atlas[J.map]
    local out = {}
    for _, key in ipairs(J.cur and J.cur.maps or {}) do
        for _, r in ipairs(ns.Atlas[key].rows) do
            if r.npc then out[#out + 1] = r end
        end
    end
    return out, m
end

-- Forever's own new items (no drop chance known) that several bosses of this dungeon list:
-- dungeon-wide drops. Shown once, under "Any boss", not repeated under every boss.
local function sharedUnknown(rows)
    local count = {}
    for _, r in ipairs(rows) do
        for _, it in ipairs(J:Loot(r.npc)) do
            if it[2] == 0 then count[it[1]] = (count[it[1]] or 0) + 1 end
        end
    end
    local shared = {}
    for id, n in pairs(count) do if n >= 2 then shared[id] = true end end
    return shared
end

local function lootOf(out, r, skip)
    local any = false
    for _, it in ipairs(J:Loot(r.npc)) do
      if not (skip and skip[it[1]]) then
        local name, q, icon = J:Item(it[1])
        if not name then
            out[#out + 1] = { text = "   loading...", r = 0.5, g = 0.5, b = 0.5 }
            any = true
        elseif J:Shown(it[1], q) then
            local c = ITEM_QUALITY_COLORS[q] or { r = 1, g = 1, b = 1 }
            out[#out + 1] = { text = name, r = c.r, g = c.g, b = c.b, icon = icon, item = it[1],
                right = (ns.Reserve and ns.Reserve:Tag(it[1]) or "") .. (it[2] > 0 and (it[2] .. "%") or "|cff8c8c9e?|r") }
            any = true
        end
      end
    end
    if not any then out[#out + 1] = { text = "   no notable drops known", r = 0.5, g = 0.5, b = 0.55 } end
end

local function anyBoss(out, shared)
    if not next(shared) then return end
    out[#out + 1] = { head = "Any boss (Forever's new loot, chance not known yet)" }
    local ids = {}
    for id in pairs(shared) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local name, q, icon = J:Item(id)
        if not name then
            out[#out + 1] = { text = "   loading...", r = 0.5, g = 0.5, b = 0.5 }
        elseif J:Shown(id, q) then
            local c = ITEM_QUALITY_COLORS[q] or { r = 1, g = 1, b = 1 }
            out[#out + 1] = { text = name, r = c.r, g = c.g, b = c.b, icon = icon, item = id, right = "|cff8c8c9e?|r" }
        end
    end
end

local function lootEntries(out)
    local bosses = bossRows()
    local shared = sharedUnknown(bosses)
    if J.sel and J.sel.npc then
        out[#out + 1] = { head = J.sel[2], row = J.sel }
        lootOf(out, J.sel, shared)
        anyBoss(out, shared)
        out[#out + 1] = { text = "< all bosses", r = A[1], g = A[2], b = A[3], back = true }
        return
    end
    local here = J.cur and J.cur == J.inside
    for _, r in ipairs(bosses) do
        local dead = here and J:IsKilled(r)
        out[#out + 1] = { head = ((r[1] ~= "" and (r[1] .. ") ")) or "") .. r[2] .. (dead and "  |cff33ff33(killed)|r" or ""), row = r }
        lootOf(out, r, shared)
    end
    anyBoss(out, shared)
end

local function pathEntries(out)
    local here = J.cur and J.cur == J.inside
    local nextRow = here and J.NextBoss and J:NextBoss() or nil
    local done = 0
    for _, key in ipairs(J.cur and J.cur.maps or {}) do
        local m = ns.Atlas[key]
        if #J.cur.maps > 1 then out[#out + 1] = { head = key:find("Ent$") and "Entrance" or m.zone } end
        for _, r in ipairs(m.rows) do
            local c = r[3] == "e" and { 0.5, 0.75, 1 } or r[3] == "o" and { 0.55, 0.85, 0.55 } or r.rare and { 1, 0.6, 0.9 } or { 0.92, 0.92, 0.95 }
            local right = (r.npc and ns.Loot and ns.Loot[r.npc]) and "|cff8c8c9eloot|r" or ""
            if here and J:IsKilled(r) then
                c = { 0.45, 0.45, 0.5 }
                right = "|cff33ff33killed|r"
                done = done + 1
            elseif here and J.near == r then
                right = "|cffff8c1ayou're here|r"
            elseif nextRow == r then
                right = "|cffffd200next|r"
            end
            out[#out + 1] = { text = (r[1] ~= "" and (r[1] .. ") ") or "      ") .. r[2], r = c[1], g = c[2], b = c[3],
                row = r, mapKey = key, right = right }
        end
    end
    if here then
        out[#out + 1] = { text = done > 0 and ("Start a new run (%d killed in this one)"):format(done) or "Start a new run",
            r = A[1], g = A[2], b = A[3], newRun = true }
    end
end

-- this dungeon's boss sheet (Data/Sheets.lua; it was VoidCheatSheet's until 2026-11-15)
local function sheet()
    local D = ns.Sheets
    if not (D and D.dungeons and J.cur) then return nil end
    local want = J.cur.name:lower():gsub("^the ", "")
    local alias = D.instanceAliases[(J.cur.name:lower():gsub("[%s%-']", ""))]
    if alias then return alias end
    for _, d in ipairs(D.dungeons) do
        local n = (d.name or ""):lower():gsub("^the ", ""):gsub(" %(.*%)$", "")
        if n == want or want:find(n, 1, true) or n:find(want, 1, true) then return d end
    end
end

local function tipEntries(out)
    -- the boss card's on / off box (Sheets.lua)
    local SH = ns.SheetCard
    if SH then
        local on = SH:On()
        out[#out + 1] = { text = "Boss card when a fight starts", icon = on and "Interface\\Buttons\\UI-CheckBox-Check" or "Interface\\Buttons\\UI-CheckBox-Up",
            r = 0.88, g = 0.88, b = 0.9, click = function() SH:Set(not SH:On()) end,
            tip = "A small card with the boss's short version and the tip for your role pops up when a boss fight starts. Drag it anywhere." }
    end
    local d = sheet()
    if not d then
        out[#out + 1] = { text = "No tips for " .. J.cur.name .. " yet.", r = 0.6, g = 0.6, b = 0.65, wrap = true }
        return
    end
    local function add(label, s)
        if s and s ~= "" then out[#out + 1] = { text = (label and ("|cff00c7ff" .. label .. ":|r ") or "") .. s, r = 0.88, g = 0.88, b = 0.9, wrap = true } end
    end
    local selName = J.sel and J.sel[2] and J.sel[2]:gsub(" %(.*%)$", ""):lower()
    local shown = 0
    for _, b in ipairs(d.bosses or {}) do
        if not selName or (b.name or ""):lower() == selName then
            out[#out + 1] = { head = b.name }
            add(nil, b.tldr)
            for _, a in ipairs(b.abilities or {}) do add(a.name, a.desc) end
            add("Tank", b.tank); add("Healer", b.healer); add("DPS", b.dps); add("Wipes", b.wipes)
            shown = shown + 1
        end
    end
    if selName and shown == 0 then
        out[#out + 1] = { text = "No notes for " .. J.sel[2] .. ".", r = 0.6, g = 0.6, b = 0.65 }
    end
    if not selName and d.trashNotes then
        out[#out + 1] = { head = "Trash" }
        add(nil, d.trashNotes)
    end
    if selName then out[#out + 1] = { text = "< all bosses", r = A[1], g = A[2], b = A[3], back = true } end
end

----------------------------------------------------------------------
-- Marks: plan the markers ahead of time (the user, 2026-11-14: "a section somewhere for someone
-- to go through and mark them ... so when i run it, it comes up that way and i can just hit the
-- green checkmark"). The dungeon's mobs (the dungeon list, plus mobs your pulls named in a dungeon
-- the list doesn't have), grouped by what they do, with their spells; click one to pick its
-- marker. In the run the marking board's green check puts your marks on them (Mark.lua planOf).
----------------------------------------------------------------------
-- this map's dungeon -> the game's instance map id (the dungeon list's key); wings share their
-- dungeon's id. WoW Forever's new dungeons: learned when you're inside (VoidMarkDB.instIds).
local INST = { ["shadowfang keep"] = 33, ["stormwind stockades"] = 34, ["the stockade"] = 34,
    ["the deadmines"] = 36, ["wailing caverns"] = 43, ["razorfen kraul"] = 47, ["blackfathom deeps"] = 48,
    ["uldaman"] = 70, ["gnomeregan"] = 90, ["sunken temple"] = 109, ["the temple of atal'hakkar"] = 109,
    ["razorfen downs"] = 129, ["scarlet monastery"] = 189, ["zul'farrak"] = 209, ["blackrock spire"] = 229,
    ["lower blackrock spire"] = 229, ["upper blackrock spire"] = 229, ["blackrock depths"] = 230,
    ["onyxia's lair"] = 249, ["scholomance"] = 289, ["zul'gurub"] = 309, ["stratholme"] = 329,
    ["maraudon"] = 349, ["ragefire chasm"] = 389, ["molten core"] = 409, ["the molten core"] = 409,
    ["dire maul"] = 429, ["blackwing lair"] = 469, ["ruins of ahn'qiraj"] = 509, ["ahn'qiraj"] = 531,
    ["naxxramas"] = 533 }
local function instOf(name)
    if type(name) ~= "string" then return nil end
    local n = name:lower()
    local base = n:gsub(":.*$", ""):gsub("%s*%(.*%)$", "")
    local learnedIds = VoidMarkDB and VoidMarkDB.instIds or {}
    return INST[n] or INST[base] or learnedIds[n] or learnedIds[base]
end
S.InstOf = instOf

local MARK_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
local function markIcon(i, size)
    return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:%d|t"):format(i, size or 0)
end
local ROLE_ORDER = { "healer", "mana burn", "crowd control", "summoner", "dispeller", "caster", "" }
local ROLE_HEAD = { healer = "Healers", ["mana burn"] = "Mana burners", ["crowd control"] = "Crowd control",
    summoner = "Summoners", dispeller = "Dispellers", caster = "Casters", [""] = "The rest" }

-- the wing this map page shows ("Scarlet Monastery: Armory" -> Armory, "Dire Maul (East)" -> East); nil = all
local function wingOf(name)
    if type(name) ~= "string" then return nil end
    local w = name:match(": (.+)$") or name:match("%((.-)%)$")
    if not w or w == "Entrance" then return nil end
    return w
end
S.WingOf = wingOf

-- the dungeon's mobs: { name, lo, hi, elite, pt, role, spells, learned }; on a wing's page only that
-- wing's (the list knows the wings of Scarlet Monastery and Dire Maul)
local function dungeonMobs(inst, wing)
    local out, have = {}, {}
    local VM = VoidMark
    for _, e in ipairs(VM and VM.Seed and VM.Seed[inst] or {}) do
        local inWing = not wing or not e[10] or e[10] == "" or ("," .. e[10] .. ","):find("," .. wing .. ",", 1, true)
        if inWing and not have[e[8]] then
            have[e[8]] = true
            out[#out + 1] = { name = e[8], lo = e[1], hi = e[2], elite = e[3] == 1, pt = e[4], role = e[7] or "", spells = e[9] }
        end
    end
    -- mobs your pulls named here that the list doesn't have (WoW Forever's new dungeons)
    local tag = ":" .. inst .. "|"
    for key, names in pairs(VoidMarkDB and VoidMarkDB.seen or {}) do
        if key:find(tag, 1, true) then
            local elite, pt, lvl = key:match("|(%d)|(%d+)|(%-?%d+)$")
            for nm, c in pairs(names) do
                if nm ~= "t" and type(c) == "number" and not have[nm] then
                    have[nm] = true
                    out[#out + 1] = { name = nm, lo = tonumber(lvl), hi = tonumber(lvl), elite = elite == "1",
                        pt = tonumber(pt), role = tonumber(pt) == 0 and "caster" or "", learned = true }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local function setMark(inst, name, mk)
    if VoidMark and VoidMark.PlanSet then VoidMark.PlanSet(inst, name, mk) end
    S:Refresh()
end

local function markMenu(r, mm)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(r, function(_, root)
        root:CreateTitle(mm.name)
        for i = 8, 1, -1 do
            root:CreateButton(markIcon(i, 14) .. " " .. MARK_NAMES[i], function() setMark(mm.inst, mm.name, i) end)
        end
        root:CreateButton("Leave it unmarked", function() setMark(mm.inst, mm.name, 0) end)
        root:CreateButton("No mark of mine (the board decides)", function() setMark(mm.inst, mm.name, nil) end)
    end)
end

local function marksEntries(out)
    local d = J.cur
    local inst = d and instOf(d.name)
    out[#out + 1] = { text = "Mark the mobs you know: in the run, the marking board's green check puts your marks on them, before its own picks.",
        r = 0.6, g = 0.6, b = 0.66, wrap = true }
    if not inst then
        out[#out + 1] = { text = "No mob list for this one yet: run it once and the mobs you fight show up here.", r = 0.5, g = 0.5, b = 0.55, wrap = true }
        return
    end
    local mobs = dungeonMobs(inst, wingOf(d.name))
    if #mobs == 0 then
        out[#out + 1] = { text = "No mobs known here yet: run it once and the mobs you fight show up here.", r = 0.5, g = 0.5, b = 0.55, wrap = true }
        return
    end
    local VM = VoidMark
    local marked = 0
    local shown = {}   -- the mobs on this page: "Clear all" clears only these (a wing's page leaves the other wings alone)
    for _, m in ipairs(mobs) do shown[#shown + 1] = m.name end
    for _, role in ipairs(ROLE_ORDER) do
        local group = {}
        for _, m in ipairs(mobs) do if (m.role or "") == role then group[#group + 1] = m end end
        if #group > 0 then
            out[#out + 1] = { head = ROLE_HEAD[role] }
            for _, m in ipairs(group) do
                local mk = VM and VM.PlanGet and VM.PlanGet(inst, m.name)
                if mk then marked = marked + 1 end
                local mm = { inst = inst, name = m.name, mob = m }
                local lv = m.lo and (m.lo == m.hi and tostring(m.lo) or (m.lo .. "-" .. m.hi)) or "?"
                local mark = (mk and mk > 0) and (markIcon(mk) .. " ") or (mk == 0 and "|cff8c8c9e-|r " or "   ")
                out[#out + 1] = { text = mark .. m.name, r = mk and 1 or 0.85, g = mk and 1 or 0.85, b = mk and 1 or 0.85,
                    right = "|cff8c8c9e" .. lv .. (m.elite and " elite" or "") .. "|r", markMob = mm, wrap = true,
                    click = function(row) markMenu(row, mm) end,
                    menu = function() setMark(inst, m.name, nil) end }
                if m.spells and m.spells ~= "" then
                    out[#out + 1] = { text = "      " .. m.spells, r = 0.5, g = 0.5, b = 0.56, markMob = mm, wrap = true,
                        click = function(row) markMenu(row, mm) end, menu = function() setMark(inst, m.name, nil) end }
                end
            end
        end
    end
    out[#out + 1] = { text = ("%d of %d marked. Click a mob: pick its marker. Right-click: clear."):format(marked, #mobs),
        r = 0.45, g = 0.45, b = 0.5, wrap = true }
    -- start over: every mark of yours for this dungeon, after a yes (the user, 2026-11-14: "what if
    -- they need to reset it cause they marked something wrong")
    if marked > 0 then
        local dname = d.name
        out[#out + 1] = { text = "Clear all my marks here", r = 1, g = 0.45, b = 0.45,
            click = function()
                StaticPopupDialogs.VOIDDUNGEON_CLEAR_MARKS = StaticPopupDialogs.VOIDDUNGEON_CLEAR_MARKS or {
                    text = "Clear all your marks for %s? The marking board goes back to its own picks there.",
                    button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
                    OnAccept = function(_, data)
                        if type(data) == "table" and VoidMark and VoidMark.PlanSet then
                            for _, nm in ipairs(data.names) do VoidMark.PlanSet(data.inst, nm, nil) end
                        end
                        S:Refresh()
                    end,
                }
                StaticPopup_Show("VOIDDUNGEON_CLEAR_MARKS", dname, nil, { inst = inst, names = shown })
            end }
    end
end

local BUILD = { Quests = questEntries, Loot = lootEntries, Path = pathEntries, Tips = tipEntries, Marks = marksEntries,
    Reserve = function(out) if ns.Reserve then ns.Reserve:Entries(out) end end,
    BoE = function(out) if ns.Handout then ns.Handout:Entries(out) end end }

----------------------------------------------------------------------
-- Rows
----------------------------------------------------------------------
local function rowEnter(r)
    local e = r.e
    if not e then return end
    if e.row and ns.Canvas then ns.Canvas:Glow(e.row) end
    if e.tip then   -- a plain explanation (the boss card box)
        GameTooltip:SetOwner(r, "ANCHOR_LEFT")
        GameTooltip:SetText(e.text or "", 1, 1, 1)
        GameTooltip:AddLine(e.tip, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    elseif e.item then
        GameTooltip:SetOwner(r, "ANCHOR_LEFT")
        GameTooltip:SetItemByID(e.item)
        -- soft reserve: who has it, and how to reserve it (Reserve.lua)
        local SR = ns.Reserve
        if SR and SR:Session() and not e.menu then
            local who, n = SR:WhoText(e.item)
            GameTooltip:AddLine(" ")
            if n > 0 then GameTooltip:AddLine("Reserved by: " .. who, 0.4, 1, 0.4, true) end
            GameTooltip:AddLine("Right-click: reserve it (main spec or off spec)", 0.5, 0.8, 1)
        end
        GameTooltip:Show()
    elseif e.quest then
        GameTooltip:SetOwner(r, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink("quest:" .. e.quest)
        GameTooltip:Show()
    elseif e.missing then
        local m = e.missing
        local q = m.q
        GameTooltip:SetOwner(r, "ANCHOR_LEFT")
        GameTooltip:SetText(q[1], 1, 0.82, 0)
        GameTooltip:AddLine(("Level %d (you can take it at %d)"):format(q[2] or 0, q[3] or 0), 0.8, 0.8, 0.8)
        local st = startText(q[6])
        if st then GameTooltip:AddLine("Starts: " .. st, 1, 1, 1, true) end
        if (m.left or 0) > 0 then
            local doneN = #m.steps - m.left
            GameTooltip:AddLine(("%d quest%s before this one%s"):format(m.left, m.left == 1 and "" or "s",
                doneN > 0 and (" (%d more already done)"):format(doneN) or ""), 1, 0.5, 0.5, true)
            local s = m.start
            if s and s.state == "log" then
                GameTooltip:AddLine("Start: " .. s.q[1] .. ", in your quest log", 0.4, 1, 0.4, true)
            elseif s then
                local ps = startText(s.q[6])
                GameTooltip:AddLine("Start: " .. s.q[1] .. (ps and (", from " .. ps) or ""), 0.4, 1, 0.4, true)
            else
                GameTooltip:AddLine("Nothing in it you can take yet (a level or a quest elsewhere first).", 0.8, 0.6, 0.6, true)
            end
            GameTooltip:AddLine("Click: show the whole chain", 0.5, 0.8, 1)
        else
            if m.needLevel then GameTooltip:AddLine("Needs level " .. m.needLevel, 1, 0.5, 0.5) end
            if q[6] and q[6][1] ~= "i" then GameTooltip:AddLine("Click: the way there", 0.5, 0.8, 1) end
        end
        GameTooltip:Show()
    elseif e.step then
        local s, sq = e.step, e.step.q
        GameTooltip:SetOwner(r, "ANCHOR_LEFT")
        GameTooltip:SetText(sq and sq[1] or ("quest " .. s.qid), 1, 0.82, 0)
        if sq then GameTooltip:AddLine(("Level %d (you can take it at %d)"):format(sq[2] or 0, sq[3] or 0), 0.8, 0.8, 0.8) end
        local st = sq and startText(sq[6])
        if st then GameTooltip:AddLine("Starts: " .. st, 1, 1, 1, true) end
        local why = ({ done = "Done.", log = "In your quest log.", ready = "You can take it now.",
            after = "Comes after the step above it.", nodata = "Not in the quest data: ask in game.",
        })[s.state] or (s.state == "level" and ("You can take it at level " .. tostring(s.n) .. "."))
        if why then GameTooltip:AddLine(why, 0.7, 0.9, 0.7) end
        if s.state == "log" then GameTooltip:AddLine("Click: track it", 0.5, 0.8, 1)
        elseif s.state ~= "done" and sq and sq[6] and sq[6][1] ~= "i" then GameTooltip:AddLine("Click: the way there", 0.5, 0.8, 1) end
        GameTooltip:Show()
    elseif e.markMob then
        local mm, m = e.markMob, e.markMob.mob
        GameTooltip:SetOwner(r, "ANCHOR_LEFT")
        GameTooltip:SetText(mm.name, 1, 0.82, 0)
        local lv = m.lo and (m.lo == m.hi and tostring(m.lo) or (m.lo .. "-" .. m.hi)) or "?"
        GameTooltip:AddLine(("Level %s%s, %s"):format(lv, m.elite and " elite" or "",
            m.pt == 0 and "uses mana" or m.pt == 3 and "uses energy" or "uses rage"), 0.8, 0.8, 0.8)
        if m.role and m.role ~= "" then GameTooltip:AddLine("What it does: " .. m.role, 1, 1, 1) end
        if m.spells and m.spells ~= "" then GameTooltip:AddLine("Spells: " .. m.spells, 1, 1, 1, true) end
        if m.learned then GameTooltip:AddLine("Named by your own pulls here (not in the dungeon list).", 0.6, 0.6, 0.6, true) end
        local mk = VoidMark and VoidMark.PlanGet and VoidMark.PlanGet(mm.inst, mm.name)
        GameTooltip:AddLine(" ")
        if mk and mk > 0 then GameTooltip:AddLine("Your mark: " .. markIcon(mk, 14) .. " " .. MARK_NAMES[mk], 0.2, 1, 0.2)
        elseif mk == 0 then GameTooltip:AddLine("Your mark: leave it unmarked", 0.2, 1, 0.2)
        else GameTooltip:AddLine("No mark of yours: the board decides.", 0.6, 0.6, 0.6) end
        GameTooltip:AddLine("Inside, the game hides mob names: the board knows this one by its level, elite and mana or rage, so two mobs that look alike need the same mark.", 0.55, 0.55, 0.6, true)
        GameTooltip:AddLine("Click: pick a marker. Right-click: clear.", 0.5, 0.8, 1)
        GameTooltip:Show()
    elseif e.wrap and r.title:IsTruncated() then
        GameTooltip:SetOwner(r, "ANCHOR_LEFT")
        GameTooltip:SetText(e.full or e.text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end
end

local function rowClick(r, button)
    local e = r.e
    if not e then return end
    if e.item and IsModifiedClick("CHATLINK") then
        local _, link = C_Item.GetItemInfo(e.item)
        if link then ChatEdit_InsertLink(link) end
        return
    end
    if e.item and IsModifiedClick("DRESSUP") then
        local _, link = C_Item.GetItemInfo(e.item)
        if link then DressUpItemLink(link) end
        return
    end
    -- right-click: the row's own menu (BoE tab), else an item's reserve menu (Reserve.lua)
    if button == "RightButton" then
        if e.menu then e.menu(r)
        elseif e.item and ns.Reserve then ns.Reserve:ItemMenu(r, e.item) end
        return
    end
    if e.click then e.click(r); return end
    if e.back then J:Select(nil); return end
    if e.newRun then J:NewRun(); return end
    if e.missing then
        -- quests before it: open / close its chain; none: the way to its giver
        local m = e.missing
        if (m.left or 0) > 0 then
            S.open[m.qid] = not S.open[m.qid] or nil
            S:Refresh()
        else
            routeTo(m)
        end
        return
    end
    if e.step then
        -- a step of a chain: track it when it's in your log, else the way to its giver
        local s = e.step
        if s.state == "log" then
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then C_SuperTrack.SetSuperTrackedQuestID(s.qid) end
            J:Print("tracking " .. (s.q and s.q[1] or ("quest " .. s.qid)) .. ".")
        elseif s.state ~= "done" and s.q then
            routeTo({ q = s.q })
        end
        return
    end
    if e.row and e.row.npc then
        if e.mapKey and e.mapKey ~= J.map then J:ShowMap(e.mapKey) end
        J:Select(e.row)
    elseif e.mapKey and e.mapKey ~= J.map then
        J:ShowMap(e.mapKey)
    end
end

local function row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, list)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetPoint("RIGHT", list, "RIGHT", 0, 0)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(A[1], A[2], A[3], 0.12)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(15, 15)
    r.icon:SetPoint("LEFT", 4, 0)
    r.title = J.text(r, 11)
    r.title:SetWordWrap(false)
    r.prog = J.text(r, 10)
    r.prog:SetPoint("RIGHT", -6, 0)
    r.prog:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", rowEnter)
    r:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if ns.Canvas then ns.Canvas:Glow(nil) end
    end)
    r:SetScript("OnClick", rowClick)
    rows[i] = r
    return r
end

function S:Refresh()
    if not (frame and frame:IsVisible() and J.cur) then return end
    local t = tab()
    for name, b in pairs(tabBtns) do b:SetSelected(name == t) end
    wipe(entries)
    BUILD[t](entries)
    -- long text wraps onto more rows instead of being cut with "..." (the user, 2026-11-13: words
    -- cut in half / cut off are a bug, not a style)
    -- the title's room: 6 px left, 6 px right, 4 px before the right-hand text (Sol review)
    -- 22, not 16: the game draws a line a few pixels wider than the measure (live 11-14: "before..." cut)
    local avail = (list:GetWidth() or 0) - 22
    if avail > 60 then
        if not S.meas then
            S.meas = J.text(frame, 11)
            S.meas:Hide()
        end
        local wrapped = {}
        for _, e in ipairs(entries) do
            if e.wrap and e.text and not e.icon then
                -- the indent (chain steps, rewards) stays on every line: splitting into words dropped it
                local lead = e.text:match("^(%s*)") or ""
                local line, first = "", true
                -- the first line shares its row with the right-hand text
                local rightW = 0
                if e.right and e.right ~= "" then
                    S.meas:SetText(e.right)
                    rightW = S.meas:GetStringWidth() + 4
                end
                local function flush()
                    local x = {}
                    for k, v in pairs(e) do x[k] = v end
                    -- still wrap: a line that doesn't fit after all shows the whole text on hover
                    x.text, x.full = line, e.text
                    if not first then x.right = nil end
                    wrapped[#wrapped + 1] = x
                    first, line = false, ""
                end
                for word in e.text:gmatch("%S+") do
                    local try = line == "" and (lead .. word) or (line .. " " .. word)
                    S.meas:SetText(try)
                    if line ~= "" and S.meas:GetStringWidth() > avail - (first and rightW or 0) then
                        flush()
                        line = lead .. word
                    else
                        line = try
                    end
                end
                if line ~= "" then flush() end
            else
                wrapped[#wrapped + 1] = e
            end
        end
        wipe(entries)
        for i, e in ipairs(wrapped) do entries[i] = e end
    end
    head:SetText(J.cur.name)
    local n = math.max(1, math.floor((list:GetHeight() or 0) / ROW_H))
    offset = math.max(0, math.min(offset, #entries - n))
    for i = 1, n do
        local r, e = row(i), entries[i + offset]
        r.e = e
        if not e then
            r:Hide()
        else
            r:Show()
            r.title:ClearAllPoints()
            r.title:SetPoint("RIGHT", r.prog, "LEFT", -4, 0)
            if e.head then
                r.icon:Hide()
                r.title:SetPoint("LEFT", 6, 0)
                r.title:SetFont(J.FONT, 10, "OUTLINE")
                r.title:SetText(e.head)
                r.title:SetTextColor(A[1], A[2], A[3])
                r.prog:SetText("")
            else
                r.title:SetFont(J.FONT, 11, "")
                if e.icon then
                    r.icon:SetTexture(e.icon)
                    r.icon:Show()
                    r.title:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
                else
                    r.icon:Hide()
                    r.title:SetPoint("LEFT", 6, 0)
                end
                r.title:SetText(e.text or "")
                r.title:SetTextColor(e.r or 1, e.g or 1, e.b or 1)
                r.prog:SetText(e.right or "")
            end
        end
    end
    for i = n + 1, #rows do rows[i]:Hide() end
    more:SetShown(#entries > n + offset)
end

-- Canvas.lua: a marker is hovered -> nothing to do in the list yet (kept for later: scroll to it).
function S:Hover(row) end

----------------------------------------------------------------------
-- Build
----------------------------------------------------------------------
local function build()
    local W = WorldMapFrame
    frame = CreateFrame("Frame", nil, W)
    S.frame = frame
    frame:SetFrameLevel(W.ScrollContainer:GetFrameLevel() + 21)
    J.fill(frame, 0.07, 0.07, 0.09, 1):SetAllPoints()
    local edge = J.fill(frame, A[1], A[2], A[3], 0.35, "BORDER")
    edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
    frame:EnableMouse(true)

    head = J.text(frame, 12, "OUTLINE")
    head:SetPoint("TOPLEFT", 10, -7)
    head:SetTextColor(A[1], A[2], A[3])

    local prev
    for _, name in ipairs(TABS) do
        local b = J.button(frame, name, function()
            VoidDungeonDB.tab = name
            offset = 0
            S:Refresh()
        end)
        b:SetPoint("TOPLEFT", prev or frame, prev and "TOPRIGHT" or "TOPLEFT", prev and 3 or 8, prev and 0 or -26)
        tabBtns[name] = b
        prev = b
    end

    list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", 4, -52)
    list:SetPoint("BOTTOMRIGHT", -2, 16)
    more = J.text(frame, 9)
    more:SetPoint("BOTTOM", 0, 3)
    more:SetTextColor(0.5, 0.5, 0.56)
    more:SetText("scroll for more")
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, d)
        offset = math.max(0, offset - d * 3)
        S:Refresh()
    end)
    frame:SetScript("OnSizeChanged", function() S:Refresh() end)
    frame:SetScript("OnShow", function() S:Refresh() end)
    frame:Hide()

    J:OnChange(function(what)
        if what == "select" and J.sel then
            -- a boss picked on the map: show its loot (or keep Tips if that's open)
            if tab() ~= "Tips" then VoidDungeonDB.tab = "Loot" end
        end
        if what == "dungeon" or what == "map" then offset = 0 end
        S:Refresh()
    end)
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    if VoidMap and VoidMap.OnReady and VoidMap.SetSideOwner then VoidMap:OnReady(build) end
end)
