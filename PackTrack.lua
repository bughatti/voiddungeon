----------------------------------------------------------------------
-- PackTrack.lua — which pack you're at, in dungeons where the game hides where you stand.
--
-- The user, 2026-11-18: "if we have all the data from a dungeon, location, mobs, types of mobs, names of mobs and
-- spells they cast we should be able to run that data through our own analyzer" / "yes build it".
--
-- Measured in Zul'Farrak 11-18: inside a dungeon an addon can't read your position (5 of 13,097 tries) nor a mob's
-- name. What it can know: after every fight the damage meter names each enemy (Mark.lua's pull recorder), and which
-- bosses died (Core.lua). So "where am I" = the pack the last fight was: Data/PackBook.lua (tools/cmd/vdungeon-packs,
-- from CMaNGOS classic-db) lists every pack of every Classic dungeon with its spot and mobs.
--   * After a fight: the meter's names -> the pack (or two pulled together) it was, nearest the last one first.
--     That pack is cleared and is where you are. A wipe moves you there but clears nothing; a boss's room is
--     cleared only by the boss's kill (the game says so: ENCOUNTER_END).
--   * Before a pull: each nameplate (level, elite, mana or rage: all the game still shows) gets a NAME only when
--     the 3 nearest uncleared packs that can be every plate on the board all say the same mob; a boss room
--     anywhere that fits casts doubt too. Replayed on 158 recorded pulls (tools/cmd/vdungeon-packs): names 27% of
--     the plates in the fight (the board alone: 9%), 93% of them right.
-- The board (Mark.lua) then ranks that row as that mob: "Probably X (by pack)".
----------------------------------------------------------------------
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end   -- WoW Forever (Classic dungeons) only

local VM = VoidMark
local PT = {}
VM.PackTrack = PT

local K, REACH, PAIR, CLEARED_COST = 3, 80, 60, 10000

-- the book of one map, built once: packs { i, x, y, z, members = { [name] = count }, boss = { npc, ... } }
local books = {}
local function book(map)
    local b = books[map]
    if b ~= nil then return b or nil end
    local raw = VM.PackBook and VM.PackBook[map]
    if type(raw) ~= "table" or type(raw.p) ~= "table" or type(raw.n) ~= "table" then
        books[map] = false
        return nil
    end
    b = { packs = {}, has = {} }
    for _, p in ipairs(raw.p) do
        local pk = { x = p[1], y = p[2], z = p[3], members = {} }
        for i = 4, #p - 1, 2 do
            local nm = raw.n[p[i]]
            if nm then
                pk.members[nm] = (pk.members[nm] or 0) + (p[i + 1] or 1)
                b.has[nm] = true
                local npc = raw.b and raw.b[p[i]]
                if npc then pk.boss = pk.boss or {}; pk.boss[#pk.boss + 1] = npc end
            end
        end
        pk.i = #b.packs + 1
        b.packs[pk.i] = pk
    end
    books[map] = b
    return b
end
PT.Book = book

local function dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function me()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

-- this run's state, per character (VoidMarkDB.packRun): a new VoidDungeon run (another dungeon, a reset, 3 hours)
-- starts it over
local function state(map)
    local db = VoidMarkDB
    local J = VoidDungeon
    local key = J and J.RunKey and J:RunKey()
    if not (db and key and map) then return nil end
    db.packRun = db.packRun or {}
    local s = db.packRun[me()]
    if type(s) ~= "table" or s.key ~= key or s.map ~= map then
        s = { key = key, map = map, cleared = {} }
        db.packRun[me()] = s
    end
    return s
end

local function bossDead(pk)
    local J = VoidDungeon
    for _, npc in ipairs(pk.boss or {}) do
        if J and J.KilledNpc and J:KilledNpc(npc) then return true end
    end
    return false
end
local function isCleared(s, pk)
    if pk.boss then return bossDead(pk) end   -- a boss's room: its kill, not a fight (wipes happen)
    return s.cleared[pk.i] and true or false
end

local function mapNow()
    local _, _, id = VM.Where()
    return id
end

-- Packs aren't always the same (the user, 2026-11-18: "we cant assume all packs will always be the same"): spawn
-- points that roll one of several mobs are in the book as every mob they can be, but WoW Forever may have changed a
-- dungeon since that data. So every fight checks the book: does the fight match a pack at all, and was each plate
-- that FOUGHT (the pull recorder notes the looks in combat) the mob guessed for it? Plates of a pack you didn't pull
-- don't count (they'd look wrong for the wrong reason). A dungeon where fights often match no pack (over 40% of 6+),
-- or where under half of the fought plates' guesses were right (10+), gets no more pack guesses: the board goes back
-- to its own answers there. VoidMarkDB.packCheck[map] keeps the counts.
local function sig(L) return ("%s|%s|%s"):format(tostring(L.lvl), tostring(L.elite), tostring(L.pt)) end
local pending   -- the last guess per plate look { map, key, byLook = { [sig] = name } }, until the next fight checks it
local function check(map)
    local db = VoidMarkDB
    if not (db and map) then return nil end
    db.packCheck = db.packCheck or {}
    local c = db.packCheck[map]
    if type(c) ~= "table" then c = { hit = 0, miss = 0, tried = 0, ok = 0 }; db.packCheck[map] = c end
    return c
end
function PT.Trusted(map)
    map = map or mapNow()
    local c = check(map)
    if not c then return true end
    if c.hit + c.miss >= 6 and c.miss > 0.4 * (c.hit + c.miss) then return false, "fights here often match no pack" end
    if c.tried >= 10 and c.ok < 0.5 * c.tried then return false, "the guessed mobs often weren't in the fight" end
    return true
end

-- After a fight: the meter's enemy names -> the pack(s) it was. -> the packs, or nil
-- fought: the looks of the plates that were in the fight ({ lvl, elite, pt }; the pull recorder's), for the check
function PT.Seen(names, wiped, map, fought)
    map = map or mapNow()
    local b = map and book(map)
    local s = b and state(map)
    if not s or type(names) ~= "table" then return nil end
    -- only names that stand in this dungeon's packs (totems, wards, summoned skeletons don't)
    local want, n = {}, 0
    for _, nm in ipairs(names) do
        if type(nm) == "string" and b.has[nm] and not want[nm] then want[nm], n = true, n + 1 end
    end
    -- was each plate that fought (this run, this dungeon) the mob guessed for it?
    local c = check(map)
    local p = pending
    pending = nil
    if c and p and p.map == map and p.key == s.key and type(fought) == "table" then
        -- only a plate that looks like one of the fight's listed mobs can be scored: the list leaves out what took
        -- under 2% of the damage (scarabs, critters) and what the book doesn't have (ZF's graveyard zombies), so a
        -- "Scarab" guess on a scarab plate isn't a miss (replay 11-18)
        local function listed(L)
            for nm in pairs(want) do
                local e = VM.SeedByName and VM.SeedByName(map, nm)
                if e and e[3] == L.elite and e[4] == L.pt and type(L.lvl) == "number" and L.lvl >= e[1] - 1 and L.lvl <= e[2] + 1 then
                    return true
                end
            end
            return false
        end
        local done = {}
        for _, L in ipairs(fought) do
            local k = type(L) == "table" and sig(L)
            local g = k and not done[k] and p.byLook[k]
            if g and listed(L) then
                done[k] = true
                c.tried = c.tried + 1
                if want[g] then c.ok = c.ok + 1 end
            end
        end
    end
    if n == 0 then
        -- a fight with mobs, none of them in the book (WoW Forever changed the dungeon?): a miss (Sol)
        local any = false
        for _, nm in ipairs(names) do if type(nm) == "string" and nm ~= "" then any = true end end
        if c and any then c.miss = c.miss + 1 end
        s.again, s.againAt, s.againPacks = 0, nil, nil   -- the streak needs fights in a row (Sol)
        return nil
    end
    local at = s.at and b.packs[s.at]
    local cands = {}
    for _, pk in ipairs(b.packs) do
        for nm in pairs(want) do
            if pk.members[nm] then cands[#cands + 1] = pk; break end
        end
    end
    local function covers(a, c)
        for nm in pairs(want) do
            if not (a.members[nm] or (c and c.members[nm])) then return false end
        end
        return true
    end
    local function cost(pk)
        return (at and dist(pk, at) or 0) + (isCleared(s, pk) and CLEARED_COST or 0)
    end
    local best, bestCost
    for _, a in ipairs(cands) do
        if covers(a) then
            local c = cost(a)
            if not bestCost or c < bestCost then best, bestCost = { a }, c end
        end
    end
    if not best then   -- two packs pulled together (they stand together)
        for i, a in ipairs(cands) do
            for j = i + 1, #cands do
                local c2 = cands[j]
                if dist(a, c2) < PAIR and covers(a, c2) then
                    local c = cost(a) + cost(c2) + dist(a, c2)
                    if not bestCost or c < bestCost then best, bestCost = { a, c2 }, c end
                end
            end
        end
    end
    if c then
        if best then c.hit = c.hit + 1 else c.miss = c.miss + 1 end
    end
    if not best then
        s.again, s.againAt, s.againPacks = 0, nil, nil   -- the streak needs fights in a row (Sol)
        return nil
    end
    -- A pack this run already cleared, fought again, twice in a row (two different packs): the instance is a fresh
    -- one (the user, 2026-11-18: "we ran 1 zf, reset and are now back in there" and the run went on as the first
    -- one: the reset came before the reload, and no boss was fought, so neither the reset message nor a boss
    -- fight could tell). The identifying above prefers uncleared packs, so this only happens when none fits.
    local again = not wiped
    for _, pk in ipairs(best) do
        if pk.boss or not s.cleared[pk.i] then again = false end
    end
    if again and s.againAt ~= best[1].i then
        s.again, s.againAt = (s.again or 0) + 1, best[1].i
        s.againPacks = s.againPacks or {}
        for _, pk in ipairs(best) do s.againPacks[#s.againPacks + 1] = pk.i end
    elseif not again then
        s.again, s.againAt, s.againPacks = 0, nil, nil
    end
    local J = VoidDungeon
    if (s.again or 0) >= 2 and J and J.NewRun then
        J:NewRun()            -- VoidDungeon's run (its boss kills) starts over: a new key
        local earlier = s.againPacks or {}
        s = state(map) or s   -- and so does this one
        for _, i in ipairs(earlier) do s.cleared[i] = true end   -- the first re-fought pack is cleared in the new run too (Sol)
        J:Print("this looks like a fresh instance (packs you cleared are back): started a new run.")
    end
    for _, pk in ipairs(best) do
        if not wiped and not pk.boss then s.cleared[pk.i] = true end
        s.at = pk.i
    end
    s.t = time and time() or 0
    return best
end

-- Before a pull: looks { { lvl =, elite =, pt = }, ... } -> names { [i] = "Mob" when the nearby packs agree }, and
-- the nearest pack that fits (nil when there's no last fight to go from in this run, or no pack fits)
function PT.Guess(looks, map)
    map = map or mapNow()
    local b = map and book(map)
    local s = b and state(map)
    local at = s and s.at and b.packs[s.at]
    if not at or type(looks) ~= "table" or #looks == 0 then return nil end
    if not PT.Trusted(map) then return nil end   -- this dungeon doesn't match the book (see check above)
    local function remember(names)   -- the next fight checks them, plate look by plate look
        local byLook = {}
        for i, nm in pairs(names or {}) do
            if looks[i] then byLook[sig(looks[i])] = nm end
        end
        pending = next(byLook) and { map = map, key = s.key, byLook = byLook } or nil   -- this run only (Sol)
        return names
    end
    local function fits(nm, L)
        local e = VM.SeedByName and VM.SeedByName(map, nm)
        return e and e[3] == L.elite and e[4] == L.pt and L.lvl >= e[1] - 1 and L.lvl <= e[2] + 1
    end
    -- plates the game shows too little of (a "??" boss, no power type) don't narrow anything
    local usable = {}
    for i, L in ipairs(looks) do
        if type(L.lvl) == "number" and L.lvl > 5 and L.pt ~= nil and L.elite ~= nil then usable[#usable + 1] = i end
    end
    if #usable == 0 then return nil end
    local cands = {}
    for _, pk in ipairs(b.packs) do
        -- an uncleared boss counts from anywhere (a group can run or swim past trash)
        if not isCleared(s, pk) and (dist(pk, at) <= REACH or pk.boss) then cands[#cands + 1] = pk end
    end
    table.sort(cands, function(x, y) return dist(x, at) < dist(y, at) end)
    -- can this pack be every plate at once, with no more of a mob than it holds? (Sol: one healer can't be two
    -- healer-looking plates.) Counts are upper limits: a spawn point that rolls one of several mobs counts for each.
    local function canHold(pk, out)
        local owner = {}   -- slot "name#k" -> plate index
        local function try(i, seen)
            for nm in pairs(out[i]) do
                for k = 1, math.min(pk.members[nm] or 0, #usable) do
                    local slot = nm .. "#" .. k
                    if not seen[slot] then
                        seen[slot] = true
                        if not owner[slot] or try(owner[slot], seen) then owner[slot] = i; return true end
                    end
                end
            end
            return false
        end
        for _, i in ipairs(usable) do
            if not try(i, {}) then return false end
        end
        return true
    end
    local agree, first, used = {}, nil, 0
    for _, i in ipairs(usable) do agree[i] = {} end
    for _, pk in ipairs(cands) do
        local out, ok = {}, true
        for _, i in ipairs(usable) do
            local set, any = {}, false
            for nm in pairs(pk.members) do
                if fits(nm, looks[i]) then set[nm], any = true, true end
            end
            if not any then ok = false; break end
            out[i] = set
        end
        ok = ok and canHold(pk, out)
        if ok then
            -- past the 3 nearest (or out of reach) only a boss's room still votes, and only to cast doubt
            local far = used >= K or dist(pk, at) > REACH
            if not far or (pk.boss and first) then
                first = first or pk
                for i, set in pairs(out) do
                    for nm in pairs(set) do agree[i][nm] = true end
                end
                if not far then used = used + 1 end
            end
        end
    end
    if not first then
        -- no one pack holds every plate (the board shows all plates in view: often two packs): each plate on its
        -- own, among the 3 nearest uncleared packs that could hold it (replayed: names 13% of plates, 92% right)
        local names, any = {}, false
        for _, i in ipairs(usable) do
            local set, n, seenAny = {}, 0, false
            for _, pk in ipairs(cands) do
                local has
                for nm in pairs(pk.members) do
                    if fits(nm, looks[i]) then has = has or {}; has[nm] = true end
                end
                if has then
                    local far = n >= K or dist(pk, at) > REACH
                    if not far or (pk.boss and seenAny) then
                        seenAny = true
                        for nm in pairs(has) do set[nm] = true end
                        if not far then n = n + 1 end
                    end
                end
            end
            local only, c = nil, 0
            for nm in pairs(set) do only, c = nm, c + 1 end
            if c == 1 then names[i], any = only, true end
        end
        return remember(any and names or nil), nil
    end
    local names = {}
    for i, set in pairs(agree) do
        local only, count = nil, 0
        for nm in pairs(set) do only, count = nm, count + 1 end
        if count == 1 then names[i] = only end
    end
    return remember(names), first
end

-- where the tracker thinks you are (for the board's tooltip and tests): the pack index, how many cleared
function PT.Status(map)
    map = map or mapNow()
    local b = map and book(map)
    local s = b and state(map)
    if not s then return nil end
    local n = 0
    for _ in pairs(s.cleared) do n = n + 1 end
    return s.at, n
end
