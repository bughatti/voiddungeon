----------------------------------------------------------------------
-- The way into a dungeon quest: every quest that has to come before it, oldest first, each with
-- where YOU stand on it (the user, 2026-11-14: players love clicking a dungeon quest and seeing the
-- quests before it and where to start; "make sure ... ours to be much better").
--
-- ns.QI[q] = { title, level, minLevel, races, classes, start, all, rewards, rewardIDs, any }
--   all = every one of these first; any = one of these first (breadcrumbs, a version per faction)
--
-- Chain:Steps(qid) -> { { qid, q, state, n }, ... } oldest first, the quest itself not included.
--   state: "done" (a step already behind you: shown for context, nothing before it is walked),
--          "log" (in your quest log: do it), "ready" (you can take it now), "level" (n = the level
--          it needs), "after" (comes after a step above), "nodata" (the data doesn't know it).
-- Chain:Start(steps) -> the step to go to now (in your log, else the first you can take), or nil.
----------------------------------------------------------------------
local _, ns = ...
local C = {}
ns.Chain = C

local MAX_DEPTH = 40

-- Race / class bit masks (bit raceID-1 / classID-1; 0 = everyone). Masks pass 2^32: no bit.band.
local function hasBit(mask, id)
    if not mask or mask == 0 or not id then return true end
    return math.floor(mask / 2 ^ (id - 1)) % 2 == 1
end
C.HasBit = hasBit

-- the player's side of it (a test hands in its own)
local function gameEnv()
    return {
        done = function(q) return C_QuestLog.IsQuestFlaggedCompleted(q) and true or false end,
        inLog = function(q) return C_QuestLog.GetLogIndexForQuestID(q) ~= nil end,
        race = select(3, UnitRace("player")),
        class = select(3, UnitClass("player")),
        level = UnitLevel("player") or 0,
    }
end
C.GameEnv = gameEnv

local function fits(q, env) return q == nil or (hasBit(q[4], env.race) and hasBit(q[5], env.class)) end

-- of "one of these first": the one to suggest (in your log, else one you can take right now: your
-- race and class, your level, its own earlier quests done; else one for your race and class; else
-- the first the data knows). Codex: a blocked first choice hid a ready later one.
local function readyNow(q, env)
    if (q[3] or 0) > env.level then return false end
    for _, p in ipairs(q[7] or {}) do if not env.done(p) then return false end end
    -- and its own "one of these first" (the user, 11-22: A Taste of Flame part 1 comes in two versions; #4022
    -- needs Kalaran's 10-quest chain, #4023 nothing, and the long one was picked: "10 quests first")
    local any = q[10]
    if any and #any > 0 then
        local met = false
        for _, p in ipairs(any) do if env.done(p) then met = true; break end end
        if not met then return false end
    end
    return true
end
local function pickAny(list, env)
    local best, bestRank
    for _, p in ipairs(list) do
        local q = ns.QI and ns.QI[p]
        local ok = q and fits(q, env)
        local rank = env.inLog(p) and 1 or (ok and readyNow(q, env)) and 2 or ok and 3 or q and 4 or 5
        if not bestRank or rank < bestRank then best, bestRank = p, rank end
    end
    return best
end

-- what this quest still needs first: a list of quest IDs (empty = nothing)
local function needs(qid, env)
    local q = ns.QI and ns.QI[qid]
    local out = {}
    if not q then return out end
    for _, p in ipairs(q[7] or {}) do out[#out + 1] = p end
    local any = q[10]
    if any and #any > 0 then
        local met = false
        for _, p in ipairs(any) do if env.done(p) then met = true; break end end
        if not met then out[#out + 1] = pickAny(any, env) end
    end
    return out
end
C.Needs = needs

function C:Steps(qid, env)
    env = env or gameEnv()
    local steps, seen = {}, { [qid] = true }
    local function walk(id, depth)
        if depth > MAX_DEPTH then return end
        for _, p in ipairs(needs(id, env)) do
            if not seen[p] then
                seen[p] = true
                local q = ns.QI and ns.QI[p]
                local st
                if env.done(p) then
                    st = "done"   -- behind you: what came before it doesn't matter any more
                elseif env.inLog(p) then
                    st = "log"    -- you have it: what came before it is behind you too (a skipped breadcrumb isn't owed)
                else
                    walk(p, depth + 1)
                    if not q then st = "nodata"
                    else
                        st = "ready"
                        for _, n in ipairs(needs(p, env)) do if not env.done(n) then st = "after"; break end end
                        if st == "ready" and (q[3] or 0) > env.level then st = "level" end
                    end
                end
                steps[#steps + 1] = { qid = p, q = q, state = st, n = st == "level" and q[3] or nil }
            end
        end
    end
    walk(qid, 0)
    return steps
end

function C:Start(steps)
    for _, s in ipairs(steps) do if s.state == "log" then return s end end
    for _, s in ipairs(steps) do if s.state == "ready" then return s end end
end

-- how many steps are still to do (not done)
function C:Left(steps)
    local n = 0
    for _, s in ipairs(steps) do if s.state ~= "done" then n = n + 1 end end
    return n
end
