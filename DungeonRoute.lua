----------------------------------------------------------------------
-- Route.lua -- the best route through a dungeon, drawn on the map, and as steps in the Path tab.
-- The user, 2026-11-19: "this pug group has no idea where to go ... drawing a line and explaining these type of
-- details and they show in the dungeon map".
--
-- Data/Routes.lua (tools/cmd/vdungeon-routes): per dungeon, the steps in the best order, each with the line that
-- leads to it on its Atlas map, a note, and a warning for traps (the Celebras ritual in Maraudon).
-- Inside the dungeon the next step is the first one whose boss is still alive in this run: its leg of the line is
-- bright, finished legs are grey.
--
-- ns.Route:Draw(canvas, mapTex, size, key)   from Canvas:Refresh
-- ns.Route:PathEntries(out)                    from Side.lua's Path tab
----------------------------------------------------------------------
local _, ns = ...
local J = ns.J
local R = {}
ns.Route = R

-- the Atlas row of a step's boss (for "killed in this run")
local function rowFor(s)
    local m = s.npc and ns.Atlas[s.map]
    if not m then return nil end
    for _, r in ipairs(m.rows) do
        if r.npc == s.npc then return r end
    end
end
R.RowFor = rowFor

local function inside() return J.cur and J.cur == J.inside end

local function killed(s)
    local r = rowFor(s)
    return r and J.IsKilled and J:IsKilled(r) and true or false
end

-- More than one way in (Maraudon: orange or purple first; the user, 2026-11-19: "this run they started on purple
-- side"). Data/Routes.lua: the dungeon's first route + others = { {side, enter, steps} }. Which one:
--   1. the side kept with this run (picked from where you came in, or switched in the Path tab);
--   2. else the side whose order the dead bosses follow furthest (a run from before this, a missed sub zone);
--   3. else outside: the side last picked in the Path tab; else the first.
local function sides(base)
    local t = { base }
    for _, o in ipairs(base.others or {}) do t[#t + 1] = o end
    return t
end
R.Sides = sides

-- main bosses dead in a row from the start of this side's order
local function lead(rt)
    local n = 0
    for _, s in ipairs(rt.steps) do
        if s.npc and not s.opt then
            if not killed(s) then break end
            n = n + 1
        end
    end
    return n
end

local function bySide(base, name)
    if not name then return nil end
    for _, rt in ipairs(sides(base)) do
        if rt.side == name then return rt end
    end
end

function R.For(cur)
    local base = cur and ns.Routes and ns.Routes[cur.name] or nil
    if not (base and base.others) then return base end
    if inside() then
        local rt = bySide(base, J.RunSide and J:RunSide())
        if rt then return rt end
        local best, bn, tie = base, lead(base), false
        for _, o in ipairs(base.others) do
            local n = lead(o)
            if n > bn then best, bn, tie = o, n, false elseif n == bn then tie = true end
        end
        if bn > 0 and not tie then
            if J.SetRunSide then J:SetRunSide(best.side, true) end   -- keep it (quiet: we're mid-draw)
            return best
        end
    end
    local pref = VoidDungeonDB and VoidDungeonDB.routeSide and VoidDungeonDB.routeSide[cur.name]
    return bySide(base, pref) or base
end

-- the side you came in by, from the sub zone (Maraudon: The Wicked Grotto = purple, Foulspore Cavern = orange). Only
-- while no boss of this run is dead: later the wings join and a sub zone says nothing about the way in.
function R:WatchEntry()
    if not (inside() and J.RunSide and not J:RunSide()) then return end
    local base = ns.Routes and ns.Routes[J.cur.name]
    if not (base and base.others) then return end
    for _, rt in ipairs(sides(base)) do
        for _, s in ipairs(rt.steps) do
            if s.npc and killed(s) then return end   -- any boss dead = mid-run (Sol)
        end
    end
    local sub = GetSubZoneText and GetSubZoneText() or ""
    if sub == "" or (issecretvalue and issecretvalue(sub)) then return end
    for _, rt in ipairs(sides(base)) do
        for _, z in ipairs(rt.enter or {}) do
            if z == sub then J:SetRunSide(rt.side); return end
        end
    end
end

-- the Path tab's switch: the next side in the list (inside: this run; outside: what you'd like to see)
function R:NextSide()
    local base = J.cur and ns.Routes and ns.Routes[J.cur.name]
    if not (base and base.others) then return end
    local all, cur = sides(base), R.For(J.cur)
    local nx = all[1]
    for i, rt in ipairs(all) do
        if rt == cur then nx = all[i % #all + 1] end
    end
    if inside() then
        J:SetRunSide(nx.side)
    else
        VoidDungeonDB = VoidDungeonDB or {}
        VoidDungeonDB.routeSide = VoidDungeonDB.routeSide or {}
        VoidDungeonDB.routeSide[J.cur.name] = nx.side
        if J.Changed then J:Changed("live") end
    end
end

if CreateFrame then
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
        ev:RegisterEvent(e)
    end
    ev:SetScript("OnEvent", function()
        -- after Core.lua has set J.inside for this zone
        if C_Timer then C_Timer.After(0.5, function() R:WatchEntry() end) else R:WatchEntry() end
    end)
end

-- the next step: the first main (not optional) step whose boss isn't dead in this run. Optional stops (a quest
-- ghost, a skippable boss) never hold the route up. nil = outside; past the end = all done.
function R.NextIndex(route)
    if not (route and inside()) then return nil end
    for i, s in ipairs(route.steps) do
        if s.npc and not s.opt and not killed(s) then return i end
    end
    return #route.steps + 1
end

-- "done", "next" or "todo" (outside the dungeon: everything "todo"). An optional stop is "done" only once its boss
-- is dead.
function R.State(route, i)
    local n = R.NextIndex(route)
    if not n then return "todo" end
    local s = route.steps[i]
    if s.opt then return (s.npc and killed(s)) and "done" or "todo" end
    -- dead is done, wherever it sits in the order (a group that went another way)
    if i < n or (s.npc and killed(s)) then return "done" end
    if i == n then return "next" end
    return "todo"
end

----------------------------------------------------------------------
-- on the map
----------------------------------------------------------------------
local layer
local lines, badges = {}, {}

local STYLE = {
    done = { 0.55, 0.55, 0.6, 0.45, 2 },
    next = { 1, 0.85, 0.1, 1, 4 },
    todo = { 1, 0.3, 0.2, 0.85, 2.5 },
    opt  = { 0.45, 0.75, 1, 0.8, 2 },
}

local function badge(i)
    local b = badges[i]
    if b then return b end
    b = CreateFrame("Frame", nil, layer)
    b:SetSize(15, 15)
    b.bg = b:CreateTexture(nil, "ARTWORK")
    b.bg:SetAllPoints()
    b.bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    b.t = b:CreateFontString(nil, "OVERLAY")
    b.t:SetFont(J.FONT, 9, "OUTLINE")
    b.t:SetPoint("CENTER", 0, 0)
    badges[i] = b
    return b
end

-- the colour key in the map's top-left corner (the user, 2026-11-19: "why is there a blue and red lines" / "yes add
-- the key"): a short line in each colour + what it means
-- (no "done": a done leg's line goes away, 2026-11-25)
local KEY = { { "todo", "main route" }, { "opt", "optional" }, { "next", "next" } }
local keyBox
local function colourKey()
    if keyBox then return keyBox end
    keyBox = CreateFrame("Frame", nil, layer)
    keyBox:SetFrameLevel(layer:GetFrameLevel() + 3)
    local bg = keyBox:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    local y, w = -5, 0
    for _, k in ipairs(KEY) do
        local st = STYLE[k[1]]
        local sw = keyBox:CreateTexture(nil, "ARTWORK")
        sw:SetSize(16, math.max(2, math.floor(st[5] + 0.5)))
        sw:SetPoint("LEFT", keyBox, "TOPLEFT", 6, y - 6)
        sw:SetColorTexture(st[1], st[2], st[3], 1)
        local t = keyBox:CreateFontString(nil, "OVERLAY")
        t:SetFont(J.FONT, 10, "OUTLINE")
        t:SetPoint("LEFT", sw, "RIGHT", 5, 0)
        t:SetText(k[2])
        t:SetTextColor(0.9, 0.9, 0.92)
        w = math.max(w, (t:GetStringWidth() or 50) + 33)
        y = y - 13
    end
    keyBox:SetSize(math.max(w, 80), -y + 3)
    return keyBox
end
R.ColourKey = colourKey

function R:Draw(canvas, mapTex, size, key)
    if not layer then
        layer = CreateFrame("Frame", nil, canvas)
        -- under the boss markers (canvas + 5), over the picture
        layer:SetFrameLevel(canvas:GetFrameLevel() + 3)
    end
    layer:ClearAllPoints()
    layer:SetAllPoints(mapTex)
    for _, l in ipairs(lines) do l:Hide() end
    for _, b in ipairs(badges) do b:Hide() end
    if keyBox then keyBox:Hide() end
    local route = R.For(J.cur)
    local m = ns.Atlas[key]
    -- a game map (Canvas.lua: the game's own minimap, no Atlas picture): stops + lines come from your pins
    -- and the walkable ground (C.GameView); a step not pinned yet is left off
    local view = not (m and m.img) and ns.Canvas and ns.Canvas.GameView and ns.Canvas.GameView(route, key)
    if not ((m and m.img and mapTex:IsShown()) or view) then return end
    local scale = size / 512
    local li, bi = 0, 0
    local function seg(x1, y1, x2, y2, th, r, g, b, a)
        li = li + 1
        local l = lines[li]
        if not l then
            l = layer:CreateLine(nil, "ARTWORK")
            lines[li] = l
        end
        l:SetThickness(th)
        l:SetColorTexture(r, g, b, a)
        l:SetStartPoint("TOPLEFT", mapTex, x1 * scale, -y1 * scale)
        l:SetEndPoint("TOPLEFT", mapTex, x2 * scale, -y2 * scale)
        l:Show()
    end
    -- a one-off way (Data/Way.lua, the user 2026-11-19: "redraw a red line the way i need to go"): thick bright red,
    -- drawn first so the route's own legs don't hide it... then drawn again on top below
    local way = ns.Way and J.cur and ns.Way.dungeon == J.cur.name and ns.Way or nil
    if not route and not way then return end
    route = route or { steps = {} }
    for i, s0 in ipairs(route.steps) do
        local s = s0
        if view then s = view[i] end
        if s and s.map == key then
            local state = R.State(route, i)
            local st = STYLE[(s.opt and state == "todo") and "opt" or state]
            -- a leg you've done goes away (the user, 2026-11-25: "when a boss is killed, the line to that boss can go
            -- away"); its number stays, grey, so the order still reads
            local ln = state ~= "done" and s.line
            if ln then
                for p = 1, #ln - 3, 2 do
                    li = li + 1
                    local l = lines[li]
                    if not l then
                        l = layer:CreateLine(nil, "ARTWORK")
                        lines[li] = l
                    end
                    l:SetThickness(st[5])
                    l:SetColorTexture(st[1], st[2], st[3], st[4])
                    l:SetStartPoint("TOPLEFT", mapTex, ln[p] * scale, -ln[p + 1] * scale)
                    l:SetEndPoint("TOPLEFT", mapTex, ln[p + 2] * scale, -ln[p + 3] * scale)
                    l:Show()
                end
            end
            -- the step's number in the route, beside its stop
            bi = bi + 1
            local b = badge(bi)
            b:ClearAllPoints()
            b:SetSize(15, 15)
            b:SetPoint("CENTER", mapTex, "TOPLEFT", s.x * scale + 13, -s.y * scale + 11)
            b.bg:SetVertexColor(st[1] * 0.35, st[2] * 0.35, st[3] * 0.35, 0.95)
            b.t:SetText(i)
            b.t:SetTextColor(st[1], st[2], st[3])
            b:Show()
        end
    end
    -- the key, whenever this map shows route steps
    if bi > 0 then
        local kb = colourKey()
        kb:ClearAllPoints()
        kb:SetPoint("TOPLEFT", mapTex, "TOPLEFT", 6, -6)
        kb:Show()
    end
    -- the one-off way on top: a dark edge, then bright red
    if way then
        for _, sgm in ipairs(way.segs) do
            if sgm.map == key then
                local ln = sgm.line
                for p = 1, #ln - 3, 2 do seg(ln[p], ln[p + 1], ln[p + 2], ln[p + 3], 8, 0, 0, 0, 0.7) end
                for p = 1, #ln - 3, 2 do seg(ln[p], ln[p + 1], ln[p + 2], ln[p + 3], 5, 1, 0.1, 0.1, 1) end
            end
        end
        -- one-off marks (Maraudon's Vylestem Vines, 2026-11-19): bright green numbered dots, walking order
        for _, mk in ipairs(way.marks or {}) do
            if mk.map == key then
                bi = bi + 1
                local b = badge(bi)
                b:ClearAllPoints()
                b:SetPoint("CENTER", mapTex, "TOPLEFT", mk.x * scale, -mk.y * scale)
                b:SetSize(17, 17)
                b.bg:SetVertexColor(0.1, 0.75, 0.15, 1)
                b.t:SetText(mk.n)
                b.t:SetTextColor(1, 1, 1)
                b:Show()
            end
        end
    end
end

----------------------------------------------------------------------
-- the Path tab
----------------------------------------------------------------------
function R:PathEntries(out)
    local route = R.For(J.cur)
    if not route then return false end
    out[#out + 1] = { head = "Best route" .. (route.side and (": " .. route.side:lower()) or "") }
    -- more than one way in: say which one and let a click switch it
    local base = ns.Routes[J.cur.name]
    if base.others then
        local why = not inside() and "the way you plan to go in"
            or (J.RunSide and J:RunSide()) and "the way this run went in" or "the usual way, until we see where you went in"
        out[#out + 1] = { text = route.side .. " (" .. why .. ").  |cff8cc8ffClick: show " ..
            ((function()
                local all = sides(base)
                for k, rt in ipairs(all) do if rt == route then return all[k % #all + 1].side:lower() end end
                return all[1].side:lower()
            end)()) .. "|r",
            r = 0.75, g = 0.85, b = 1, wrap = true, click = function() R:NextSide() end }
    end
    for i, s in ipairs(route.steps) do
        local state = R.State(route, i)
        local c = state == "done" and { 0.45, 0.45, 0.5 } or state == "next" and { 1, 0.82, 0 }
            or s.opt and { 0.55, 0.75, 1 } or { 0.92, 0.92, 0.95 }
        local right = state == "done" and "|cff33ff33done|r" or state == "next" and "|cffffd200next|r"
            or s.opt and "|cff8c8c9eoptional|r" or ""
        out[#out + 1] = { text = i .. ". " .. s.label, r = c[1], g = c[2], b = c[3], right = right,
            row = rowFor(s), mapKey = s.map, wrap = true }
        if state ~= "done" then
            if s.note then out[#out + 1] = { text = "      " .. s.note, r = 0.62, g = 0.62, b = 0.68, wrap = true } end
            if s.warn then out[#out + 1] = { text = "      |cffff5050!|r " .. s.warn, r = 1, g = 0.5, b = 0.42, wrap = true } end
        end
    end
    return true
end
