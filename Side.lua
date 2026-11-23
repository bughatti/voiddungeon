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

----------------------------------------------------------------------
-- Quest <-> map number (the user, 2026-11-22, in Blackrock Mountain: "look at my map ... explain how i am suppose
-- to figure this out": the map has numbers, the list has quests, nothing tied them together).
-- spotIndex: every NPC / name on this dungeon's maps -> the numbered spot it's at. A row listed under a number
-- (kind "i": Mistress Nagmara, Private Rocknot, Ribbly Screwspigot under 15) has that number's spot.
----------------------------------------------------------------------
local function plainName(s)
    return (s or ""):lower():gsub("%s*%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local idx   -- { byNpc = {}, byName = {}, key = J.cur .. J.map }: rebuilt when the dungeon or map changes
local function spotIndex()
    local key = tostring(J.cur) .. "|" .. tostring(J.map)
    if idx and idx.key == key then return idx end
    idx = { byNpc = {}, byName = {}, key = key }
    -- the map shown first: a boss on two maps (entrance + inside) is named by the one you're looking at
    local order = {}
    if J.map then order[1] = J.map end
    for _, k in ipairs(J.cur and J.cur.maps or {}) do if k ~= J.map then order[#order + 1] = k end end
    for _, k in ipairs(order) do
        local m = ns.Atlas[k]
        local anchor
        for _, r in ipairs(m and m.rows or {}) do
            if r[1] ~= "" then anchor = r elseif r[3] ~= "i" then anchor = nil end
            local a = r[1] ~= "" and r or anchor
            if a then
                local rec = { row = a, map = k, who = r }
                if r.npc and not idx.byNpc[r.npc] then idx.byNpc[r.npc] = rec end
                local n = plainName(r[2])
                if n ~= "" and not idx.byName[n] then idx.byName[n] = rec end
            end
        end
    end
    return idx
end

-- "24", or "Entrance 3" for a spot on another of this dungeon's maps
local function spotLabel(rec)
    if rec.map == J.map then return rec.row[1] end
    local z = ns.Atlas[rec.map] and ns.Atlas[rec.map].zone or ""
    local where = rec.map:find("Ent$") and "Entrance" or (z:match("Map([A-C])$") and ("Map " .. z:match("Map([A-C])$"))) or "Inside"
    return where .. " " .. rec.row[1]
end

local nearRec   -- (s): the numbered row a giver not on the legend stands next to; set below whereText's helpers
local function isCurMap(key)
    for _, k in ipairs(J.cur and J.cur.maps or {}) do if k == key then return true end end
    return false
end

local ROLE = { g = "gives it", e = "takes it back", eo = "takes it back", d = "drops it", ["do"] = "loot it",
    o = "use it", k = "", t = "" }

-- The spots a quest points at, map order: { { rec, roles = { "gives it", ... } }, ... }. From the giver, the quest's
-- targets (Data/Quests.lua QT) and, for a quest in your log, its objective text (a name on the map in it).
local function questSpots(qid, objectives)
    local I = spotIndex()
    local byRow, out = {}, {}
    local function add(rec, role)
        if not rec then return end
        local s = byRow[rec.row]
        if not s then
            s = { rec = rec, roles = {}, has = {} }
            byRow[rec.row] = s
            out[#out + 1] = s
        end
        local r = ROLE[role] or ""
        if r ~= "" and not s.has[r] then s.has[r] = true; s.roles[#s.roles + 1] = r end
    end
    local q = ns.QI and ns.QI[qid]
    local st = q and q[6]
    local gave
    if st and st[1] == "n" then gave = I.byNpc[st[2]] or I.byName[plainName(st[3])]; add(gave, "g")
    elseif st and st[1] == "o" then gave = I.byName[plainName(st[3])]; add(gave, "g")
    elseif st and st[1] == "i" and st[3] ~= "" then gave = I.byName[plainName(st[3])]; add(gave, "d") end   -- the mob that drops its starting item (Sol)
    -- not on the legend: the number it stands next to, on this dungeon's maps (the Spectral Chalice: 18)
    if st and not gave then
        local nr = nearRec(st)
        if nr and isCurMap(nr.map) then add(nr, st[1] == "i" and "d" or "g") end
    end
    for _, t in ipairs(ns.QT and ns.QT[qid] or {}) do
        local isNpc = t[1] == "k" or t[1] == "d" or t[1] == "e"
        local rec = (isNpc and I.byNpc[t[2]]) or I.byName[plainName(t[3])]
        -- handed back to the same thing it started from (the Spectral Chalice): its number too
        if not rec and st and t[2] == st[2] and ((t[1] == "e" and st[1] == "n") or (t[1] == "eo" and st[1] == "o")) then
            local nr = nearRec(st)
            if nr and isCurMap(nr.map) then rec = nr end
        end
        add(rec, t[1])
    end
    for _, o in ipairs(objectives or {}) do
        local text = type(o.text) == "string" and o.text:lower()
        if text then
            for n, rec in pairs(I.byName) do
                if #n >= 5 and text:find(n, 1, true) then add(rec, "t") end
            end
        end
    end
    table.sort(out, function(a, b)
        local x, y = tonumber(a.rec.row[1]), tonumber(b.rec.row[1])
        if (a.rec.map == J.map) ~= (b.rec.map == J.map) then return a.rec.map == J.map end
        if x and y then return x < y end
        return tostring(a.rec.row[1]) < tostring(b.rec.row[1])
    end)
    return out
end
S.QuestSpots = questSpots   -- vdungeon-spots-test

-- "On the map: 24 Overmaster Pyron · 15 Ribbly Screwspigot (gives it)" + the rows to light up on the map
local function spotLine(spots)
    if #spots == 0 then return nil end
    local parts, set = {}, {}
    for i, s in ipairs(spots) do
        set[s.rec.row] = true
        if i <= 4 then
            parts[#parts + 1] = "|cffffd200" .. spotLabel(s.rec) .. "|r " .. s.rec.who[2]
                .. (#s.roles > 0 and (" |cff8c8c9e(" .. table.concat(s.roles, ", ") .. ")|r") or "")
        end
    end
    local text = "   On the map: " .. table.concat(parts, " · ") .. (#spots > 4 and (" +" .. (#spots - 4)) or "")
    return text, set
end
S.SpotLine = spotLine

-- Where to get a quest, precisely (the user, 2026-11-22: "if its a quest i can get now, tell me where to get it and be
-- precise and informative, if there are pre req, tell me those ... if quests exist in the instance, that needs to be
-- said"). The giver inside this dungeon: its map number. Outside: the place on the map (a city / Blackrock Mountain:
-- C_Map's child map at that spot), the zone and the coordinates. What Atlas notes about the giver anywhere (a ghost,
-- it wanders) is said too: Franclorn Forgewright is only seen while you're dead.
local function atlasNote(name)
    local want = plainName(name)
    if want == "" then return nil end
    for _, m in pairs(ns.Atlas or {}) do
        for _, r in ipairs(m.rows or {}) do
            if plainName(r[2]) == want then
                local p = (r[2]:match("%((.-)%)") or ""):lower()
                if p:find("ghost", 1, true) then
                    return "a ghost: you only see them while you're dead (die, then walk back as a spirit and talk to them)"
                elseif p:find("wanders", 1, true) then
                    return "walks around: look along the halls nearby"
                end
            end
        end
    end
end

-- Every numbered spot on EVERY dungeon's maps (built once): a giver who stands in another dungeon (Lokhtos
-- Darkbargainer in Blackrock Depths gives the Molten Core quests; Dire Maul's wings give each other's) is named with
-- that dungeon and its number. Non-entrance maps first: inside wins over "at the door".
local function dungeonOf(mapKey)
    local z = ns.Atlas[mapKey] and ns.Atlas[mapKey].zone or ""
    return (z:gsub(" %(Entrance%)$", ""):gsub("Map[A-C]$", ""):gsub("^Blackrock Mountain: ", ""))
end
local gidx
local function globalIndex()
    if gidx then return gidx end
    gidx = { byNpc = {}, byName = {} }
    local keys = {}
    for k in pairs(ns.Atlas or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local ea, eb = a:find("Ent$") ~= nil, b:find("Ent$") ~= nil
        if ea ~= eb then return eb end
        return a < b
    end)
    for _, k in ipairs(keys) do
        local anchor
        for _, r in ipairs(ns.Atlas[k].rows or {}) do
            if r[1] ~= "" then anchor = r elseif r[3] ~= "i" then anchor = nil end
            local a = r[1] ~= "" and r or anchor
            if a then
                local rec = { row = a, map = k, who = r, dungeon = dungeonOf(k) }
                if r.npc and not gidx.byNpc[r.npc] then gidx.byNpc[r.npc] = rec end
                local n = plainName(r[2])
                if #n >= 5 and not gidx.byName[n] then gidx.byName[n] = rec end
            end
        end
    end
    return gidx
end
-- "4", "Entrance 3", "Map B 7": a number on another dungeon's maps
local function globalLabel(rec)
    local z = ns.Atlas[rec.map].zone or ""
    if rec.map:find("Ent$") then return "Entrance " .. rec.row[1] end
    local ab = z:match("Map([A-C])$")
    return ab and ("Map " .. ab .. " " .. rec.row[1]) or rec.row[1]
end
-- the numbered row a giver stands next to (s[8] map, s[9] number), as a spot record
nearRec = function(s)
    local m = s and s[8] and ns.Atlas[s[8]]
    if not (m and s[9]) then return nil end
    for _, r in ipairs(m.rows or {}) do
        if r[1] == s[9] then return { row = r, map = s[8], who = r, dungeon = dungeonOf(s[8]) } end
    end
end
local function sameDungeon(a, b)
    local x, y = (a or ""):lower():gsub("[^%w]", ""), (b or ""):lower():gsub("[^%w]", "")
    return x ~= "" and y ~= "" and (x:find(y, 1, true) ~= nil or y:find(x, 1, true) ~= nil)
end

-- Returns the text, whether it's inside THIS dungeon, and a short place for the list's right column.
local whereText
whereText = function(s)
    if not s then return nil, false end
    if s[1] == "i" then
        -- the item, and where the mob that drops it is: the same answer as a giver's (this dungeon's number, another
        -- dungeon's, at a door, inside but unmarked, or outdoors) (Sol)
        local item = C_Item.GetItemNameByID(s[2]) or "an item"
        if s[3] == "" then return "the item " .. item .. " (what drops it isn't known)", false end
        local loc, inside, place = whereText({ "n", 0, s[3], s[4], s[5], s[6], s[7], s[8], s[9] })   -- s[8]/s[9]: Sol
        return "the item " .. item .. ", which drops from " .. loc, inside, place
    end
    local name = s[3] ~= "" and s[3] or "?"
    local rec = (s[1] == "n" and spotIndex().byNpc[s[2]]) or spotIndex().byName[plainName(name)]
    local note = atlasNote(name)
    -- on a dungeon's entrance map = outside the door, not inside (Sol)
    local atDoor = rec and rec.map:find("Ent$") ~= nil
    if rec and not atDoor then
        return ("inside the dungeon: |cffffd200%s|r %s"):format(spotLabel(rec), rec.who[2])
            .. (note and (" (" .. note .. ")") or ""), true
    end
    local door = atDoor and (" (outside the door, on the entrance map: |cffffd200" .. spotLabel(rec) .. "|r)") or ""
    -- not on any legend, but the data knows the number it stands next to (s[8] Atlas map, s[9] number: the
    -- Spectral Chalice is next to 18 Summoner's Tomb)
    -- not on this dungeon's maps: another dungeon's (inside it, or at its door)
    if not rec then
        local G = globalIndex()
        local g = (s[1] == "n" and G.byNpc[s[2]]) or G.byName[plainName(name)]
        if g and not g.map:find("Ent$") then
            return ("inside %s: |cffffd200%s|r %s"):format(g.dungeon, globalLabel(g), g.who[2])
                .. (note and (" (" .. note .. ")") or ""), false, g.dungeon
        elseif g then
            door = (" (on %s's entrance map: |cffffd200%s|r)"):format(g.dungeon, globalLabel(g))
        end
    end
    -- on no legend at all, but the data knows the number it stands next to (s[8] Atlas map, s[9] number: the
    -- Spectral Chalice is next to 18 Summoner's Tomb)
    local nr = not rec and door == "" and nearRec(s)
    if nr then
        local here = isCurMap(nr.map)
        return ("inside %s: next to |cffffd200%s|r %s: %s"):format(here and "the dungeon" or nr.dungeon,
            here and spotLabel(nr) or globalLabel(nr), nr.row[2], name) .. (note and (" (" .. note .. ")") or ""),
            here, (not here) and nr.dungeon or nil
    end
    local mi = s[4] and s[4] > 0 and C_Map.GetMapInfo(s[4])
    if not mi then
        -- no spot outdoors, but the data knows which instance they stand in (no number: not on its map legend)
        if s[7] and door == "" then
            local here = J.cur and sameDungeon(J.cur.name, s[7])
            return ("inside %s (not marked on the map): %s"):format(here and J.cur.name == s[7] and "the dungeon" or s[7], name)
                .. (note and (" (" .. note .. ")") or ""), here and true or false, (not here) and s[7] or nil
        end
        return name .. (door ~= "" and door or " (no spot known: ask in game)") .. (note and (": " .. note) or ""), false
    end
    local place
    local ok, sub = pcall(C_Map.GetMapInfoAtPosition, s[4], s[5], s[6])
    -- only a place INSIDE that zone (in game 11-22 it returned the neighbour: "Yuka Screwspigot, Badlands, Burning Steppes")
    if ok and sub and sub.name and sub.mapID ~= s[4] and sub.name ~= mi.name and sub.parentMapID == s[4] then place = sub.name end
    return ("%s, %s%s (%.1f, %.1f)"):format(name, place and (place .. ", ") or "", mi.name, (s[5] or 0) * 100, (s[6] or 0) * 100)
        .. door .. (note and (": " .. note) or ""), false, mi.name
end
S.WhereText = whereText   -- vdungeon-spots-test

-- For a map number's tooltip (Canvas.lua): the NPCs listed under it ("Also here: Mistress Nagmara, Private Rocknot,
-- Ribbly Screwspigot"), and the quests that point at it, yours first: { "Ribbly Screwspigot (in your log)", ... }
function S:AlsoHere(row)
    local m = J.map and ns.Atlas[J.map]
    local names, under = {}, false
    for _, r in ipairs(m and m.rows or {}) do
        if r == row then under = true
        elseif under then
            if r[3] ~= "i" or r[1] ~= "" then break end
            names[#names + 1] = r[2]
        end
    end
    return #names > 0 and table.concat(names, ", ") or nil
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

function S:QuestsAt(row)
    if not (J.cur and row) then return {} end
    local race, class = select(3, UnitRace("player")), select(3, UnitClass("player"))
    local out, seen = {}, {}
    local function try(qid, title, state, objs)
        if seen[qid] then return end
        seen[qid] = true
        for _, s in ipairs(questSpots(qid, objs)) do
            if s.rec.row == row then
                local why = #s.roles > 0 and table.concat(s.roles, ", ") or nil
                out[#out + 1] = title .. " |cff8c8c9e(" .. (state and (why and (state .. ", " .. why) or state) or (why or "quest")) .. ")|r"
                return
            end
        end
    end
    -- in your log first (any quest whose objective names a spot here), then the dungeon's quests you haven't taken
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and info.questID and not info.isHeader and not info.isHidden then
            try(info.questID, info.title or "?", "in your log", C_QuestLog.GetQuestObjectives(info.questID))
        end
    end
    for _, qid in ipairs(dungeonQuests(J.cur.name)) do
        local q = ns.QI and ns.QI[qid]
        local crumbGone = q and q[13] and (done(q[13]) or inLog(q[13]))   -- as in the list (Sol)
        if q and not crumbGone and not done(qid) and not inLog(qid) and hasBit(q[4], race) and hasBit(q[5], class) then try(qid, q[1], nil) end
    end
    return out
end

-- "Mining 230" -> your skill when it's lower than that (0 = you don't have the profession), else nil.
-- GetProfessions lists primaries, fishing, cooking, first aid (Forever: First Aid 284 seen 11-22).
local function profShort(need)
    local name, n = (need or ""):match("^(.-)%s+(%d+)$")
    n = tonumber(n)
    if not (name and n) or type(GetProfessions) ~= "function" then return nil end
    local have = 0
    local profs = { GetProfessions() }   -- empty slots are nil (no archaeology): no ipairs
    for i = 1, 6 do
        local p = profs[i]
        if p then
            local pn, _, rank = GetProfessionInfo(p)
            if pn == name and type(rank) == "number" then have = rank end
        end
    end
    return have < n and have or nil
end

-- an item in your bags (C_Item.GetItemCount; nil API = assume yes, never hide a quest on a missing API)
local function carrying(itemID)
    local f = C_Item and C_Item.GetItemCount
    if type(f) ~= "function" then return true end
    local ok, n = pcall(f, itemID)
    return not ok or (type(n) == "number" and n > 0)
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
        local objs = C_QuestLog.GetQuestObjectives(info.questID) or {}
        local spotText, spotSet = spotLine(questSpots(info.questID, objs))
        out[#out + 1] = { text = ("[%d] %s"):format(info.level or 0, info.title or "?"), r = r, g = g, b = b,
            right = C_QuestLog.IsComplete(info.questID) and "|cff33ff33Done|r" or "", quest = info.questID, spots = spotSet }
        for _, o in ipairs(objs) do
            if o.text and o.text ~= "" then
                out[#out + 1] = { text = "   " .. o.text, r = o.finished and 0.4 or 0.75,
                    g = o.finished and 0.8 or 0.75, b = o.finished and 0.4 or 0.8 }
            end
        end
        -- who takes it back, and where (the user, 11-22: Lost Thunderbrew Recipe in the log, nothing said Vivian
        -- Lagrave in Kargath takes it)
        local qi = ns.QI and ns.QI[info.questID]
        local turnIn = qi and qi[14] and whereText(qi[14])
        if turnIn then
            out[#out + 1] = { text = "   |cff55ff55Turn it in:|r " .. turnIn, r = 0.9, g = 0.9, b = 0.9, wrap = true }
        end
        if spotText then
            out[#out + 1] = { text = spotText, r = 0.6, g = 0.85, b = 1, spots = spotSet, wrap = true,
                tip = "The numbers on the map for this quest. Hover: they light up." }
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
        -- a breadcrumb (q[13] = the quest it leads to) is gone from its giver once you have or did that quest (the
        -- user, 11-22, at Apothecary Zinge: "he doesnt have a quest for brd": Vivian Lagrave only leads to Lost
        -- Thunderbrew Recipe, already in the log)
        local crumbGone = q and q[13] and (done(q[13]) or inLog(q[13]))
        if q and not crumbGone and not listed[qid] and not done(qid) and not inLog(qid) and hasBit(q[4], race) and hasBit(q[5], class) then
            local e = { qid = qid, q = q }
            -- the whole way in (Chain.lua): every quest before this one, with where you stand on each
            e.steps = ns.Chain and ns.Chain:Steps(qid, env) or {}
            e.left = ns.Chain and ns.Chain:Left(e.steps) or 0
            e.start = ns.Chain and ns.Chain:Start(e.steps)
            if e.left > 0 then
                -- its first step can be taken right now: that's a quest you can get now (the user, 11-22: "tell me
                -- how i missed them": A Taste of Flame sat dim at level 58 behind "10 quests first")
                e.startNow = e.start and e.start.state == "ready" and e.start.q and true or nil
                if e.startNow then ready[#ready + 1] = e else later[#later + 1] = e end
            elseif (q[3] or 0) > level then
                e.needLevel = q[3]
                later[#later + 1] = e
            elseif q[15] and not carrying(q[15]) then
                -- offered only while you carry the item it's named after (the user, 11-22, at Mathredis Firestar:
                -- "did not have a quest for me at all": the three Libram quests)
                e.needItem = q[15]
                later[#later + 1] = e
            elseif q[11] and profShort(q[11]) then
                -- the profession isn't high enough (the user, 11-22: The Spectral Chalice needs Mining 230, Vede has 167)
                e.needSkill, e.haveSkill = q[11], profShort(q[11])
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
        local where, inside, place = whereText(s)
        local right
        if e.startNow then
            right = ("|cff55ff55start now|r |cff8c8c9e(%d first)|r"):format(e.left)
        elseif e.left > 0 then
            right = ("|cff8c8c9e%d quest%s first|r"):format(e.left, e.left == 1 and "" or "s")
        elseif e.needLevel then
            right = "|cff8c8c9eat " .. e.needLevel .. "|r"
        elseif e.needSkill then
            right = "|cff8c8c9e" .. e.needSkill .. "|r"
        elseif e.needItem then
            right = "|cff8c8c9eneeds the item|r"
        elseif inside then
            right = "|cffffd200inside|r"
        else
            right = place and ("|cffffd200" .. place .. "|r") or ""
        end
        local open = e.left > 0 and S.open[e.qid]
        local spotText, spotSet = spotLine(questSpots(e.qid))
        out[#out + 1] = { text = ("%s[%d] %s"):format(e.left > 0 and (open and "|cff4fd8ff- |r" or "|cff4fd8ff+ |r") or "", q[2] or 0, q[1]),
            r = r, g = g, b = b, right = right, missing = e, wrap = true, spots = spotSet }
        -- where to get it, or what comes first: said in the list, not only in a tooltip
        local k = dim and 0.7 or 1
        local function say(text)
            out[#out + 1] = { text = "   " .. text, r = 0.9 * k, g = 0.9 * k, b = 0.9 * k, wrap = true, full = "   " .. text }
        end
        if e.left > 0 then
            local st = e.start
            if st and st.state == "log" then
                say("|cffff8080First:|r finish " .. (st.q and st.q[1] or "the quest before it") .. " (in your quest log)")
            elseif st and st.q then
                local w = whereText(st.q[6])
                say((e.startNow and "|cff55ff55Start with:|r " or "|cffff8080First:|r ") .. st.q[1]
                    .. (w and (", get it " .. (w:find("^inside") and w or ("from " .. w))) or ""))
            else
                say("|cffff8080First:|r a quest you can't take yet (a level or another chain first). Click: the whole chain")
            end
        elseif where then
            local lead = e.needLevel and ("|cffff8080At level " .. e.needLevel .. ":|r ")
                or e.needSkill and ("|cffff8080At " .. e.needSkill .. ":|r ")
                or e.needItem and ("|cffff8080Only while you carry a " .. q[1] .. ":|r ") or "|cff55ff55Get it|r "
            say(lead .. (where:find("^inside") and where or ("from " .. where)))
        else
            -- no giver in the data at all (quests new on WoW Forever: Alcaz Prison, Krol'dok, ...)
            say("|cff8c8c9eWhere it starts isn't in our data yet (probably new on WoW Forever): ask in game.|r")
        end
        -- what it takes besides the trip: a profession, and the items to bring (The Spectral Chalice: Mining 230;
        -- Star Ruby, Gold Bar, Truesilver Bar)
        if q[13] then
            local t = ns.QI and ns.QI[q[13]]
            local tw = t and t[6] and whereText(t[6])
            say("|cff8c8c9eOptional: it only sends you to|r " .. (t and t[1] or "the next quest")
                .. (tw and ("|cff8c8c9e. You can go straight there:|r " .. tw) or ""))
        end
        if q[11] then
            local have = e.needSkill and e.haveSkill
            say("|cffff8080Needs|r " .. q[11] .. (have and (have == 0 and " (you don't have it)" or (" (you have " .. have .. ")")) or ""))
        end
        if q[12] then say("Bring: " .. q[12]) end
        if spotText then
            local k = dim and 0.6 or 1
            out[#out + 1] = { text = spotText, r = 0.6 * k, g = 0.85 * k, b = 1 * k, spots = spotSet, wrap = true,
                tip = "The numbers on the map for this quest. Hover: they light up." }
        end
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

S._QuestEntries = questEntries   -- vdungeon-spots-test

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
    -- the best route first (Route.lua), then every boss in map order
    if ns.Route and ns.Route:PathEntries(out) then out[#out + 1] = { head = "All bosses" } end
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
    if e.spots and ns.Canvas then ns.Canvas:Glow({ set = e.spots }) end   -- a quest: its numbers on the map
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
