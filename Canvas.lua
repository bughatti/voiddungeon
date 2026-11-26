----------------------------------------------------------------------
-- Canvas.lua — the dungeon map in VoidMap's map area, and our toolbar strip.
--
-- Dungeon mode lays our own frames over VoidMap's map area and toolbar (Blizzard's
-- canvas stays underneath, untouched) and borrows VoidMap's side area for Side.lua.
-- On: opening the map inside a dungeon, the Dungeons title button, or /vj.
-- Off: "World map" in our toolbar, or opening the map outside a dungeon.
----------------------------------------------------------------------
local _, ns = ...
local J = ns.J
local A = J.A
local VM, W

local C = {}
ns.Canvas = C
local canvas, tool, mapTex, noMap, markers = nil, nil, nil, nil, {}
local credit
local INSET = 210   -- the "You are here" minimap box (below)

-- Dungeons nobody has drawn (Blackmaw Hold, Alcaz Prison, The Shaper's Terrace): the game's own minimap tiles,
-- drawn by file ID (Data/GameMaps.lua, tools/cmd/vdungeon-gamemaps; the user, 2026-11-25: "capture the map").
-- g.crop = the square { left, top, size } in tiles; each tile shows the part of it inside that square.
local tiles = {}
local function hideTiles(from)
    for i = from or 1, #tiles do tiles[i]:Hide() end
end
local function drawGameMap(g, size)
    local l, t, sz = g.crop[1], g.crop[2], g.crop[3]
    local px = size / sz   -- screen pixels per tile
    local n = 0
    for row = 0, g.rows - 1 do
        for col = 0, g.cols - 1 do
            local id = g.ids[row * g.cols + col + 1]
            local a, b = math.max(col, l), math.min(col + 1, l + sz)
            local c, d = math.max(row, t), math.min(row + 1, t + sz)
            if id and id > 0 and b > a and d > c then
                n = n + 1
                local tx = tiles[n]
                if not tx then
                    tx = canvas:CreateTexture(nil, "ARTWORK")
                    tiles[n] = tx
                end
                tx:SetTexture(id)
                tx:SetTexCoord(a - col, b - col, c - row, d - row)
                tx:ClearAllPoints()
                tx:SetPoint("TOPLEFT", mapTex, "TOPLEFT", (a - l) * px, -(c - t) * px)
                tx:SetSize((b - a) * px, (d - c) * px)
                tx:Show()
            end
        end
    end
    hideTiles(n + 1)
    return n > 0
end

-- "You are here", as near as the game allows inside (the user, 2026-11-25: "find a way"). The game hides your
-- position from addons in dungeons but still names the area you're in (GetSubZoneText; GetMinimapZoneText when
-- there's no sub area). The terrain files say which ground belongs to which area (GameMaps[key].areas, row runs
-- in chunks of 1/16 tile), so that area lights up. Only while you're inside the dungeon shown.
local areaTex = {}
local gmNow   -- { g, key, size, col } while a game map is shown (declared here: C.HereArea below reads it; Codex 11-25)
local function hereArea(g)
    if not (g.areas and J.inside and J.inside == J.cur) then return nil end
    local sub = GetSubZoneText and GetSubZoneText() or ""
    if g.areas[sub] then return sub end
    local mz = GetMinimapZoneText and GetMinimapZoneText() or ""
    if g.areas[mz] then return mz end
end
C.HereArea = function() return gmNow and hereArea(gmNow.g) end
local function drawArea(g, name, size)
    local runs = name and g.areas[name] or {}
    local l, t, sz = g.crop[1], g.crop[2], g.crop[3]
    local px = size / sz
    local n = 0
    for k = 1, #runs - 2, 3 do
        local y, x1, x2 = runs[k] / 16, runs[k + 1] / 16, (runs[k + 2] + 1) / 16
        -- clip to the shown square
        local a, b = math.max(x1, l), math.min(x2, l + sz)
        local c, d = math.max(y, t), math.min(y + 1 / 16, t + sz)
        if b > a and d > c then
            n = n + 1
            local tx = areaTex[n]
            if not tx then
                tx = canvas:CreateTexture(nil, "OVERLAY")
                areaTex[n] = tx
            end
            tx:SetColorTexture(A[1], A[2], A[3], 0.3)
            tx:ClearAllPoints()
            tx:SetPoint("TOPLEFT", mapTex, "TOPLEFT", (a - l) * px, -(c - t) * px)
            tx:SetSize((b - a) * px, (d - c) * px)
            tx:Show()
        end
    end
    for i = n + 1, #areaTex do areaTex[i]:Hide() end
end

-- Boss pins on a game map (no spawn data for these dungeons): Shift-click the map, pick the boss. Saved in tile
-- units (VoidDungeonDB.pins[key][npc or name] = { x, y }) so a new crop doesn't move them; shipped ones in
-- GameMaps[key].pins. Yours win.
local function rowKey(r) return r.npc or r[2] end
local function pinOf(key, g, r)
    local own = VoidDungeonDB and VoidDungeonDB.pins and VoidDungeonDB.pins[key]
    return (own and own[rowKey(r)]) or (g.pins and g.pins[rowKey(r)])
end
-- The route line between pins (the user, 2026-11-25: "need a line drawn based on the data what direction to go"):
-- the shortest way over the dungeon's walkable ground (GameMaps[key].walk, from the terrain's heightmap: cliffs and
-- walls are out), from the entrance pin (if any) to the first pinned boss, then boss to boss in route order.
local walkCache, pathCache = {}, {}
local function walkOf(key, g)
    local w = g.walk
    if not w then return nil end
    local c = walkCache[key]
    if c then return c end
    local rows = {}
    for i, r in ipairs(w.rows) do
        local s, pos = {}, 0
        for k = 1, #r - 1, 2 do
            s[#s + 1] = string.rep("0", r[k] - pos)
            s[#s + 1] = string.rep("1", r[k + 1])
            pos = r[k] + r[k + 1]
        end
        s[#s + 1] = string.rep("0", w.w - pos)
        rows[i] = table.concat(s)
    end
    c = { rows = rows, w = w.w, h = w.h, x = w.x, y = w.y, per = w.per or 128 }
    walkCache[key] = c
    return c
end
local function open(c, x, y)
    if x < 0 or y < 0 or x >= c.w or y >= c.h then return false end
    return c.rows[y + 1]:byte(x + 1) == 49
end
local function inBox(c, x, y) return x >= 0 and y >= 0 and x < c.w and y < c.h end
-- Caves under the terrain (Festering Grotto is a cave in the mountain: the terrain there is the mountain's
-- slope) look like cliffs to the grid. So "not walkable" isn't a wall, just dear: 8x a floor step. The line
-- keeps to real floor wherever there is one and cuts across only where a passage the terrain can't see must be.
local BLOCKED_COST = 8
-- the walkable cell nearest a spot in tiles (a pin can sit on a rock), within ~6 cells
local function cellOf(c, tx, ty)
    local x0, y0 = math.floor(tx * c.per) - c.x, math.floor(ty * c.per) - c.y
    for r = 0, 6 do
        for dy = -r, r do
            for dx = -r, r do
                if (math.abs(dx) == r or math.abs(dy) == r) and open(c, x0 + dx, y0 + dy) then return x0 + dx, y0 + dy end
            end
        end
    end
    if inBox(c, x0, y0) then return x0, y0 end   -- in a cave the grid can't see: the spot itself
end
-- A* on the grid, 8 ways; strict = floor only (nil when there's no floor way), else blocked cells cost dear
local function astar(c, ax, ay, bx, by, strict)
    local W = c.w
    local start, goal = ay * W + ax, by * W + bx
    -- the heap holds { node, priority } entries whose priority never changes once pushed (a better way to a node
    -- pushes a new entry; the stale one is skipped as closed). Keying the heap on a shared f[node] that later
    -- changed broke its order (Codex 2026-11-25: a longer path than Dijkstra's).
    local g, from = { [start] = 0 }, {}
    local hn, hp = { start }, { 0 }   -- heap: node, priority
    local n = 1
    local closed = {}
    local function h(i)
        local dx, dy = math.abs(i % W - bx), math.abs(math.floor(i / W) - by)
        return math.max(dx, dy) + 0.4142 * math.min(dx, dy)
    end
    local function swap(a, b) hn[a], hn[b] = hn[b], hn[a]; hp[a], hp[b] = hp[b], hp[a] end
    local function push(i, pr)
        n = n + 1; hn[n], hp[n] = i, pr
        local k = n
        while k > 1 do
            local p = math.floor(k / 2)
            if hp[p] <= hp[k] then break end
            swap(p, k); k = p
        end
    end
    local function pop()
        local top = hn[1]
        hn[1], hp[1] = hn[n], hp[n]; hn[n], hp[n] = nil, nil; n = n - 1
        local k = 1
        while true do
            local l, r, m = k * 2, k * 2 + 1, k
            if l <= n and hp[l] < hp[m] then m = l end
            if r <= n and hp[r] < hp[m] then m = r end
            if m == k then break end
            swap(m, k); k = m
        end
        return top
    end
    local steps = 0
    while n > 0 do
        local cur = pop()
        if cur == goal then
            local out = {}
            while cur do table.insert(out, 1, cur); cur = from[cur] end
            return out
        end
        if not closed[cur] then
            closed[cur] = true
            steps = steps + 1
            if steps > 120000 then return nil end
            local cx, cy = cur % W, math.floor(cur / W)
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local nx, ny = cx + dx, cy + dy
                    if (dx ~= 0 or dy ~= 0) and inBox(c, nx, ny) then
                        local nb = ny * W + nx
                        local step = (dx ~= 0 and dy ~= 0) and 1.4142 or 1
                        -- a blocked cell, or a diagonal squeezing past a blocked corner: never on the floor-only
                        -- try, dear on the second
                        if not open(c, nx, ny) or (dx ~= 0 and dy ~= 0 and not (open(c, nx, cy) and open(c, cx, ny))) then
                            step = (not strict) and step * BLOCKED_COST or nil
                        end
                        local ng = step and g[cur] + step
                        if ng and not closed[nb] and (not g[nb] or ng < g[nb]) then
                            g[nb], from[nb] = ng, cur
                            push(nb, ng + h(nb))
                        end
                    end
                end
            end
        end
    end
end
-- blocked cells a straight line between two cells crosses (each counted once)
local function crossed(c, x1, y1, x2, y2)
    local n = math.max(math.abs(x2 - x1), math.abs(y2 - y1)) * 2
    local seen, k = {}, 0
    local function mark(x, y)
        local id = y * c.w + x
        if not seen[id] and not open(c, x, y) then seen[id] = true; k = k + 1 end
    end
    local px, py
    for i = 0, n do
        local t = n == 0 and 0 or i / n
        local x, y = math.floor(x1 + (x2 - x1) * t + 0.5), math.floor(y1 + (y2 - y1) * t + 0.5)
        mark(x, y)
        -- a diagonal step also passes both corners beside it, as A* counts them (Codex 2026-11-25: the straight
        -- line slipped between two blocked corners that the path itself went around)
        if px and x ~= px and y ~= py then mark(x, py); mark(px, y) end
        px, py = x, y
    end
    return k
end
local function clear(c, x1, y1, x2, y2) return crossed(c, x1, y1, x2, y2) == 0 end
-- the way between two spots (tiles), as tile points; cached
local function wayBetween(key, c, a, b)
    local ax, ay = cellOf(c, a[1], a[2])
    local bx, by = cellOf(c, b[1], b[2])
    if not (ax and bx) then return nil end
    local ck = key .. ":" .. ax .. "," .. ay .. ">" .. bx .. "," .. by
    if pathCache[ck] ~= nil then return pathCache[ck] or nil end
    -- floor only first; across what the terrain calls unwalkable only when there is no floor way (a cave)
    local p = (open(c, ax, ay) and open(c, bx, by) and astar(c, ax, ay, bx, by, true)) or astar(c, ax, ay, bx, by)
    if not p then pathCache[ck] = false; return nil end
    local W, pts = c.w, {}
    local function xy(i) return i % W, math.floor(i / W) end
    -- straighten: from each kept point, go as far along the path as a straight line can without crossing more
    -- blocked cells than the path itself does there (bp = blocked cells along the path so far)
    local bp = {}
    for i, id in ipairs(p) do
        local x, y = xy(id)
        bp[i] = (bp[i - 1] or 0) + (open(c, x, y) and 0 or 1)
    end
    local k = 1
    local x, y = xy(p[1])
    pts[1] = { x, y }
    while k < #p do
        local kx, ky = xy(p[k])
        local j = k + 1
        while j < #p do
            local jx, jy = xy(p[j + 1])
            if crossed(c, kx, ky, jx, jy) > bp[j + 1] - bp[k] then break end
            j = j + 1
        end
        x, y = xy(p[j])
        pts[#pts + 1] = { x, y }
        k = j
    end
    local out = {}
    for _, q in ipairs(pts) do out[#out + 1] = { (c.x + q[1] + 0.5) / c.per, (c.y + q[2] + 0.5) / c.per } end
    pathCache[ck] = out
    return out
end
C._walk = { walkOf = walkOf, way = wayBetween, open = open, clear = clear, crossed = crossed, astar = astar }   -- for tools/cmd/vdungeon-walk-test

-- DungeonRoute's view of a game map: per route step, the stop (from its pin) and the line to it, in the same
-- 512 x 512 space as an Atlas map. false = not pinned yet (not drawn). nil when this isn't a game map.
-- crop: the square shown ({ left, top, size } in tiles; the map's own by default)
local function viewFor(route, key, g, cr)
    if not (g and route) then return nil end
    local c = walkOf(key, g)
    cr = cr or g.crop
    local function to512(p) return (p[1] - cr[1]) / cr[3] * 512, (p[2] - cr[2]) / cr[3] * 512 end
    local own = VoidDungeonDB and VoidDungeonDB.pins and VoidDungeonDB.pins[key]
    local prev = (own and own.entrance) or (g.pins and g.pins.entrance)
    local view = {}
    for i, s in ipairs(route.steps) do
        local r = s.npc and { npc = s.npc, [2] = s.label }
        local p = r and pinOf(key, g, r)
        if p then
            local x, y = to512(p)
            local v = { map = key, x = x, y = y, opt = s.opt, npc = s.npc, label = s.label }
            local way = prev and c and wayBetween(key, c, prev, p)
            if way then
                local ln = {}
                for _, q in ipairs(way) do
                    local qx, qy = to512(q)
                    ln[#ln + 1] = qx; ln[#ln + 1] = qy
                end
                v.line = ln
            end
            view[i] = v
            if not s.opt then prev = p end   -- an optional stop doesn't move where the main route goes on from
        else
            view[i] = false
        end
    end
    return view
end
function C.GameView(route, key)
    local g = gmNow and gmNow.key == key and gmNow.g
    if not g then return nil end
    return viewFor(route, key, g)
end

-- a pin change redraws the map AND the route box beside the minimap (Codex 11-25: the box kept the old pins)
local function pinsChanged()
    C:Refresh()
    if C.RouteBox then C.RouteBox() end
end
local function pinMenu(tx, ty)
    if not (gmNow and MenuUtil and MenuUtil.CreateContextMenu) then return end
    local key, m = gmNow.key, ns.Atlas[gmNow.key]
    MenuUtil.CreateContextMenu(canvas, function(_, root)
        root:CreateTitle("Pin a boss here")
        root:CreateButton("|cff8cc8ffThe entrance|r (where the route line starts)", function()
            VoidDungeonDB.pins = VoidDungeonDB.pins or {}
            VoidDungeonDB.pins[key] = VoidDungeonDB.pins[key] or {}
            VoidDungeonDB.pins[key].entrance = { math.floor(tx * 1000 + 0.5) / 1000, math.floor(ty * 1000 + 0.5) / 1000 }
            pinsChanged()
        end)
        for _, r in ipairs(m.rows) do
            root:CreateButton((r[1] ~= "" and (r[1] .. ") ") or "") .. r[2], function()
                VoidDungeonDB.pins = VoidDungeonDB.pins or {}
                VoidDungeonDB.pins[key] = VoidDungeonDB.pins[key] or {}
                VoidDungeonDB.pins[key][rowKey(r)] = { math.floor(tx * 1000 + 0.5) / 1000, math.floor(ty * 1000 + 0.5) / 1000 }
                pinsChanged()
            end)
        end
        local own = VoidDungeonDB.pins and VoidDungeonDB.pins[key]
        if own and next(own) then
            root:CreateDivider()
            local rm = root:CreateButton("Remove a pin")
            if own.entrance then rm:CreateButton("The entrance", function() own.entrance = nil; pinsChanged() end) end
            for _, r in ipairs(m.rows) do
                if own[rowKey(r)] then
                    rm:CreateButton(r[2], function() own[rowKey(r)] = nil; pinsChanged() end)
                end
            end
        end
    end)
end
local pickBtn, mapBtns = nil, {}

local function text(parent, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(J.FONT, size or 11, flags or "")
    fs:SetTextColor(0.92, 0.92, 0.95)
    fs:SetJustifyH("LEFT")
    return fs
end

local function fill(f, r, g, b, a, layer, sub)
    local t = f:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- VoidMap's button look (dark box, cyan edge).
local function button(parent, label, onClick, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(20)
    b.bg = fill(b, 0.10, 0.12, 0.15, 1)
    b.bg:SetAllPoints()
    local edges = {}
    for i = 1, 4 do edges[i] = fill(b, A[1], A[2], A[3], 0.45, "BORDER") end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
    b.text = text(b, 10)
    b.text:SetPoint("CENTER")
    function b:SetLabel(s) self.text:SetText(s); self:SetWidth(math.max(20, self.text:GetStringWidth() + 14)) end
    function b:SetSelected(on)
        self.selected = on
        self.bg:SetColorTexture(on and A[1] * 0.3 or 0.10, on and A[2] * 0.3 or 0.12, on and A[3] * 0.3 or 0.15, 1)
        for _, e in ipairs(edges) do e:SetColorTexture(A[1], A[2], A[3], on and 1 or 0.45) end
    end
    b:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.18, 0.22, 0.28, 1)
        if tip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tip[1], 1, 1, 1)
            if tip[2] then GameTooltip:AddLine(tip[2], 0.8, 0.8, 0.8, true) end
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self) self:SetSelected(self.selected); GameTooltip:Hide() end)
    b:SetScript("OnClick", onClick)
    b:SetLabel(label)
    return b
end
J.button, J.text, J.fill = button, text, fill

----------------------------------------------------------------------
-- Mode
----------------------------------------------------------------------
-- One drawing layer (strata) above the map window: other addons' map buttons, VoidQuest's arrow
-- toggle and Blizzard's Pin / Filter sit in the window's layer at high levels, so a higher level
-- alone didn't cover them (RFK, 2026-11-08).
local UP = { BACKGROUND = "LOW", LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG", DIALOG = "FULLSCREEN",
             FULLSCREEN = "FULLSCREEN_DIALOG" }
local function lift()
    local s = UP[W:GetFrameStrata()] or "DIALOG"
    if canvas:GetFrameStrata() ~= s then
        canvas:SetFrameStrata(s)
        tool:SetFrameStrata(s)
    end
end

function J:SetMode(on)
    on = on and true or false
    if not (canvas and VM) then return end
    if on then lift() end
    self.mode = on
    if on and not self.cur then self:Show(self.inside or self.dungeons[1]) end
    canvas:SetShown(on)
    tool:SetShown(on)
    VM:SetSideOwner(on and ns.Side and ns.Side.frame or nil)
    VM:SetTitleOverride(on and self.cur and self.cur.name or nil)
    if on then C:Refresh() end
    C:UpdateInset()
    if self.modeBtn then self.modeBtn:SetSelected(on) end
end

-- Open the map in dungeon mode (at a dungeon, if given).
function J:Open(d)
    if not WorldMapFrame:IsShown() then
        if ToggleWorldMap then ToggleWorldMap() else ShowUIPanel(WorldMapFrame) end
    end
    self.forced = true
    if d and d ~= self.cur then self:Show(d) end
    self:SetMode(true)
end

----------------------------------------------------------------------
-- The map and its markers
----------------------------------------------------------------------
-- Quest objects (Data/QuestSpots.lua): small lettered dots, a third of a boss marker (the user, 2026-11-20: "why cant
-- we put dots on it for the items" ... "smaller dots though"). Green = a player found it there, gold = about here.
local qdots = {}
local function qdot(i)
    local d = qdots[i]
    if d then return d end
    d = CreateFrame("Button", nil, canvas)
    d:SetSize(10, 10)
    d:SetFrameLevel(canvas:GetFrameLevel() + 6)
    d.dot = d:CreateTexture(nil, "OVERLAY")
    d.dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    d.dot:SetAllPoints()
    d.ring = d:CreateTexture(nil, "ARTWORK")
    d.ring:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    d.ring:SetPoint("CENTER")
    d.ring:SetSize(13, 13)
    d.ring:SetVertexColor(0, 0, 0, 0.85)
    d.label = d:CreateFontString(nil, "OVERLAY")
    d.label:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    d.label:SetPoint("LEFT", d, "RIGHT", 1, 0)
    d:SetScript("OnEnter", function(self)
        local q = self.spot
        if not q then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(q.label .. ") " .. q.name, 1, 1, 1)
        if q.gives then GameTooltip:AddLine("Gives: " .. q.gives, 1, 0.82, 0) end
        if q.note then GameTooltip:AddLine(q.note, 0.85, 0.85, 0.85, true) end
        local qt = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q.quest)
        if qt then GameTooltip:AddLine("Quest: " .. qt, 0.5, 0.8, 1) end
        GameTooltip:AddLine(q.sure and "A player found it here." or "About here: not confirmed yet.",
            q.sure and 0.4 or 0.6, q.sure and 1 or 0.6, q.sure and 0.4 or 0.6)
        GameTooltip:Show()
    end)
    d:SetScript("OnLeave", function() GameTooltip:Hide() end)
    qdots[i] = d
    return d
end

local function marker(i)
    local m = markers[i]
    if m then return m end
    m = CreateFrame("Button", nil, canvas)
    m:SetSize(26, 26)
    m:SetFrameLevel(canvas:GetFrameLevel() + 5)
    m.glow = m:CreateTexture(nil, "ARTWORK")
    m.glow:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    m.glow:SetAllPoints()
    m.glow:SetVertexColor(A[1], A[2], A[3], 0.55)
    m.glow:Hide()
    -- live state (Live.lua): near = orange disc, next = gold disc, killed = darkened + check
    m.state = m:CreateTexture(nil, "BACKGROUND")
    m.state:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    m.state:SetPoint("CENTER")
    m.state:SetSize(34, 34)
    m.state:Hide()
    m.check = m:CreateTexture(nil, "OVERLAY")
    m.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    m.check:SetSize(16, 16)
    m.check:SetPoint("BOTTOMRIGHT", 6, -4)
    m.check:Hide()
    m:SetScript("OnEnter", function(self)
        self.glow:Show()
        if ns.Side then ns.Side:Hover(self.row) end
        local r = self.row
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText((r[1] ~= "" and (r[1] .. ") ") or "") .. r[2], 1, 1, 1)
        -- who else is at this number, and the quests that point here (Side.lua; the user, 2026-11-22)
        local also = ns.Side and ns.Side.AlsoHere and ns.Side:AlsoHere(r)
        if also then GameTooltip:AddLine("Also here: " .. also, 0.85, 0.85, 0.85, true) end
        local qs = ns.Side and ns.Side.QuestsAt and ns.Side:QuestsAt(r) or {}
        for i, line in ipairs(qs) do
            if i > 5 then GameTooltip:AddLine(("+%d more quests"):format(#qs - 5), 0.6, 0.6, 0.6) break end
            GameTooltip:AddLine("Quest: " .. line, 1, 0.82, 0, true)
        end
        local loot, shown = J:Loot(r.npc), 0
        for _, it in ipairs(loot) do
            local name, q = J:Item(it[1])
            if name and J:Shown(it[1], q) and shown < 4 then
                local c = ITEM_QUALITY_COLORS[q]
                GameTooltip:AddDoubleLine(name, it[2] > 0 and (it[2] .. "%") or "?",
                    c and c.r or 1, c and c.g or 1, c and c.b or 1, 0.7, 0.7, 0.75)
                shown = shown + 1
            end
        end
        if r.npc then GameTooltip:AddLine("Click: loot and tips", 0.5, 0.8, 1) end
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function(self)
        if J.sel ~= self.row then self.glow:Hide() end
        if ns.Side then ns.Side:Hover(nil) end
        GameTooltip:Hide()
    end)
    m:SetScript("OnClick", function(self) J:Select(self.row) end)
    markers[i] = m
    return m
end

function C:Refresh()
    if not (canvas and canvas:IsVisible() and J.cur) then return end
    local key = J.map
    local m = ns.Atlas[key]
    -- toolbar: dungeon picker + this dungeon's maps
    pickBtn:SetLabel(J.cur.name .. "  |cff8c8c9e" .. (J.cur.lv or "") .. "|r  v")
    for _, b in ipairs(mapBtns) do b:Hide() end
    if #J.cur.maps > 1 then
        local prev = pickBtn
        for i, k in ipairs(J.cur.maps) do
            local b = mapBtns[i] or button(tool, "", nil)
            mapBtns[i] = b
            local z = ns.Atlas[k].zone
            local label = k:find("Ent$") and "Entrance" or (z:match("Map([A-C])$") and ("Map " .. z:match("Map([A-C])$"))) or "Inside"
            b:SetLabel(label)
            b:SetScript("OnClick", function() J:ShowMap(k) end)
            b:ClearAllPoints()
            b:SetPoint("LEFT", prev, "RIGHT", i == 1 and 10 or 3, 0)
            b:SetSelected(k == key)
            b:Show()
            prev = b
        end
    end
    VM:SetTitleOverride(J.cur.name)

    -- the picture: square, as big as the area allows, centered. With the "You are here" minimap
    -- showing, the picture keeps out of its column on the right (the user, 2026-11-19: "the minimap
    -- pulled into it is covering the main map, thats needs to be fixed, its on all maps").
    local w, h = canvas:GetSize()
    local col = C:InsetWanted() and (INSET + 16) or 0
    local size = math.max(64, math.min(w - col, h) - 8)
    mapTex:SetSize(size, size)
    mapTex:ClearAllPoints()
    mapTex:SetPoint("CENTER", canvas, "CENTER", -col / 2, 0)
    local gm = m and not m.img and ns.GameMaps and ns.GameMaps[key]
    gmNow = nil
    for i = 1, #areaTex do areaTex[i]:Hide() end
    if m and m.img then
        mapTex:SetTexture(J.MAPS .. key)
        mapTex:Show()
        noMap:Hide()
        hideTiles()
        credit:SetText("Maps: Atlas Team")
    elseif gm and drawGameMap(gm, size) then
        mapTex:Hide()   -- still sizes and anchors the tiles
        noMap:Hide()
        gmNow = { g = gm, key = key, size = size, col = col }
        local here = hereArea(gm)
        drawArea(gm, here, size)
        credit:SetText((here and ("You're in |cffffffff" .. here .. "|r (lit). ") or "")
            .. "Map: the game's own minimap. Shift-click the map to pin a boss.")
    else
        mapTex:Hide()
        hideTiles()
        noMap:SetText("No map for " .. J.cur.name .. " yet.\nWe'll draw one; the Path tab has its bosses.")
        noMap:Show()
        credit:SetText("Maps: Atlas Team")
    end

    -- markers on every spot a legend row has
    local nextRow = J.NextBoss and J:NextBoss() or nil
    local n = 0
    if (m and m.img) or gmNow then
        local scale = size / 512
        for _, r in ipairs(m.rows) do
            local s = r[4]
            if gmNow then   -- a pin in tiles -> the same 512 space as an Atlas spot
                local p, c = pinOf(key, gm, r), gm.crop
                s = p and { (p[1] - c[1]) / c[3] * 512, (p[2] - c[2]) / c[3] * 512 } or {}
            end
            for i = 1, #s - 1, 2 do
                n = n + 1
                local mk = marker(n)
                mk.row = r
                mk:ClearAllPoints()
                mk:SetPoint("CENTER", mapTex, "TOPLEFT", s[i] * scale, -s[i + 1] * scale)
                mk.glow:SetShown(J.sel == r)
                local here = J.cur == J.inside
                local dead = here and J.IsKilled and J:IsKilled(r)
                if here and J.near == r then
                    mk.state:SetVertexColor(1, 0.5, 0.05, 0.75); mk.state:Show()
                elseif here and nextRow == r then
                    mk.state:SetVertexColor(1, 0.82, 0, 0.45); mk.state:Show()
                elseif dead then
                    mk.state:SetVertexColor(0, 0, 0, 0.6); mk.state:Show()
                else
                    mk.state:Hide()
                end
                mk.check:SetShown(dead or false)
                mk:Show()
            end
        end
    end
    for i = n + 1, #markers do markers[i]:Hide() end
    -- quest objects for the quests in your log (Data/QuestSpots.lua)
    local qn = 0
    local qs = m and m.img and ns.QuestSpots and ns.QuestSpots[key]
    if qs then
        local scale = size / 512
        for _, q in ipairs(qs) do
            local ok, inLog = pcall(C_QuestLog.GetLogIndexForQuestID, q.quest)
            if ok and inLog then
                qn = qn + 1
                local d = qdot(qn)
                d.spot = q
                d:ClearAllPoints()
                d:SetPoint("CENTER", mapTex, "TOPLEFT", q.x * scale, -q.y * scale)
                if q.sure then d.dot:SetVertexColor(0.35, 1, 0.35) else d.dot:SetVertexColor(1, 0.82, 0) end
                d.label:SetText(q.label)
                d.label:SetTextColor(1, 1, 1)
                d:Show()
            end
        end
    end
    for i = qn + 1, #qdots do qdots[i]:Hide() end
    -- the best route (Route.lua): its line under the markers
    if ns.Route then ns.Route:Draw(canvas, mapTex, size, key) end
end

-- Light up a row's markers (Side.lua's hover), or several: { set = { [row] = true } } (a quest's spots).
function C:Glow(row)
    local set = type(row) == "table" and row.set
    for _, mk in ipairs(markers) do
        if mk:IsShown() then mk.glow:SetShown((set and set[mk.row]) or mk.row == row or mk.row == J.sel) end
    end
end

----------------------------------------------------------------------
-- "You are here": the real minimap, borrowed into the dungeon view
--
-- The game draws the dungeon around you on the minimap but gives addons no position, so
-- while the dungeon view shows the dungeon you're in, the minimap itself sits in a corner
-- of the map. It goes back exactly where it was (parent, points, size, scale) when the map
-- closes or shows another dungeon. VoidDungeonDB.inset = false turns this off.
----------------------------------------------------------------------
local inset, held = nil, nil

local function giveBack()
    if not held then return end
    local M = Minimap
    M:SetParent(held.parent)
    M:ClearAllPoints()
    for _, p in ipairs(held.points) do M:SetPoint(unpack(p)) end
    M:SetSize(held.w, held.h)
    M:SetScale(held.scale)
    M:SetFrameStrata(held.strata)
    M:SetFrameLevel(held.level)
    held = nil
    if inset then inset:Hide() end
end

local function borrow()
    if held or not (Minimap and inset) then return end
    local M = Minimap
    held = { parent = M:GetParent(), points = {}, w = M:GetWidth(), h = M:GetHeight(), scale = M:GetScale(),
             strata = M:GetFrameStrata(), level = M:GetFrameLevel() }
    for i = 1, M:GetNumPoints() do held.points[i] = { M:GetPoint(i) } end
    inset:Show()
    M:SetParent(inset)
    M:ClearAllPoints()
    M:SetPoint("CENTER", inset, "CENTER", 0, -8)
    M:SetScale(1)
    M:SetSize(INSET - 14, INSET - 14)
    M:SetFrameStrata(inset:GetFrameStrata())
    M:SetFrameLevel(inset:GetFrameLevel() + 2)
end

-- Borrow while the dungeon view shows the dungeon you're in; give back otherwise.
-- IsVisible, not IsShown: closing the map hides its parent, and the canvas still says "shown",
-- so a later quest / item / live update would pull the minimap under the hidden map (Astra review).
function C:InsetWanted()
    return (J.mode and canvas and canvas:IsVisible() and J.inside and J.cur == J.inside
        and (VoidDungeonDB and VoidDungeonDB.inset ~= false)) and true or false
end
local lastWant
function C:UpdateInset()
    local want = C:InsetWanted()
    if want then borrow() else giveBack() end
    -- the map makes room for the box (or takes the room back) when it comes or goes
    if want ~= lastWant then lastWant = want; C:Refresh() end
end

----------------------------------------------------------------------
-- Dungeon picker: by level bracket
----------------------------------------------------------------------
local function pickMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    GameTooltip:Hide()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        if J.inside then
            root:CreateButton("|cff33ff33You're in:|r " .. J.inside.name, function() J:Show(J.inside) end)
            root:CreateDivider()
        end
        local brackets = {}
        for _, d in ipairs(J.dungeons) do
            local b = math.floor(d.min / 10) * 10
            local sub = brackets[b]
            if not sub then
                sub = root:CreateButton(("Level %d-%d"):format(b, b + 9))
                brackets[b] = sub
            end
            sub:CreateRadio(d.name .. "  |cff8c8c9e" .. (d.lv or "") .. "|r",
                function(x) return x == J.cur end, function(x) J:Show(x) end, d)
        end
    end)
end

----------------------------------------------------------------------
-- Build (once VoidMap is ready)
----------------------------------------------------------------------
local function build()
    VM, W = VoidMap, WorldMapFrame
    local sc = W.ScrollContainer

    canvas = CreateFrame("Frame", nil, W)
    canvas:SetPoint("TOPLEFT", sc, "TOPLEFT")
    canvas:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT")
    -- well above the world map's own buttons (other addons' map buttons, VoidQuest's arrow toggle)
    canvas:SetFrameLevel(sc:GetFrameLevel() + 100)
    fill(canvas, 0.04, 0.04, 0.05, 1):SetAllPoints()
    canvas:EnableMouse(true)          -- the world map underneath gets no clicks
    canvas:EnableMouseWheel(true)     -- and no zoom
    canvas:SetScript("OnMouseWheel", function() end)
    canvas:SetScript("OnMouseUp", function(_, btn)
        if btn ~= "LeftButton" or not IsShiftKeyDown() or not gmNow then return end
        -- the picture's square from the canvas (mapTex itself is hidden on a game map)
        local cx, cy = canvas:GetCenter()
        if not (cx and cy) then return end
        local size = gmNow.size
        local l, t = cx - gmNow.col / 2 - size / 2, cy + size / 2
        local x, y = GetCursorPosition()
        local s = canvas:GetEffectiveScale()
        local ox, oy = x / s - l, t - y / s
        if ox < 0 or oy < 0 or ox > size or oy > size then return end
        local c = gmNow.g.crop
        pinMenu(c[1] + ox / size * c[3], c[2] + oy / size * c[3])
    end)
    canvas:SetScript("OnSizeChanged", function() C:Refresh() end)
    mapTex = canvas:CreateTexture(nil, "ARTWORK")
    mapTex:SetPoint("CENTER")
    noMap = text(canvas, 13)
    noMap:SetPoint("CENTER")
    noMap:SetJustifyH("CENTER")
    noMap:SetTextColor(0.7, 0.7, 0.75)
    credit = text(canvas, 9)
    credit:SetPoint("BOTTOMRIGHT", -6, 4)
    credit:SetTextColor(0.45, 0.45, 0.5)
    credit:SetText("Maps: Atlas Team")
    canvas:Hide()

    inset = CreateFrame("Frame", nil, canvas)
    inset:SetSize(INSET, INSET + 16)
    inset:SetPoint("BOTTOMRIGHT", -8, 18)
    inset:SetFrameLevel(canvas:GetFrameLevel() + 20)
    fill(inset, 0.05, 0.05, 0.07, 0.92):SetAllPoints()
    local ie = {}
    for i = 1, 4 do ie[i] = fill(inset, A[1], A[2], A[3], 0.5, "BORDER") end
    ie[1]:SetPoint("TOPLEFT"); ie[1]:SetPoint("TOPRIGHT"); ie[1]:SetHeight(1)
    ie[2]:SetPoint("BOTTOMLEFT"); ie[2]:SetPoint("BOTTOMRIGHT"); ie[2]:SetHeight(1)
    ie[3]:SetPoint("TOPLEFT"); ie[3]:SetPoint("BOTTOMLEFT"); ie[3]:SetWidth(1)
    ie[4]:SetPoint("TOPRIGHT"); ie[4]:SetPoint("BOTTOMRIGHT"); ie[4]:SetWidth(1)
    local il = text(inset, 10)
    il:SetPoint("TOPLEFT", 6, -4)
    il:SetTextColor(A[1], A[2], A[3])
    il:SetText("You are here")
    inset:Hide()

    tool = CreateFrame("Frame", nil, VM.toolbar)
    tool:SetAllPoints(VM.toolbar)
    tool:SetFrameLevel(VM.toolbar:GetFrameLevel() + 100)   -- over Blizzard's Pin / Filter buttons
    fill(tool, 0.05, 0.05, 0.07, 1):SetAllPoints()
    tool:EnableMouse(true)
    local back = button(tool, "< World map", function() J.forced = false; J:SetMode(false) end,
        { "Back to the world map", "Dungeon view off. It comes back when you open the map in a dungeon." })
    back:SetPoint("LEFT", 6, 0)
    pickBtn = button(tool, "", function(self) pickMenu(self) end, { "Pick a dungeon", "Any dungeon, by level." })
    pickBtn:SetPoint("LEFT", back, "RIGHT", 8, 0)
    tool:Hide()

    J.modeBtn = VM:AddTitleButton("Dungeons", { "Dungeon view", "Maps, quests, loot and tips for every dungeon." },
        function() if J.mode then J.forced = false; J:SetMode(false) else J:Open(J.cur or J.inside) end end)

    -- Opening the map: dungeon view inside a dungeon (or when asked for), world map outside.
    W:HookScript("OnShow", function()
        local want = J.forced or J.inside ~= nil
        if J.inside and not J.forced then J:Show(J.inside) end
        J:SetMode(want)
    end)
    W:HookScript("OnHide", function() J.forced = false; giveBack() end)

    J:OnChange(function(what)
        if not J.mode then giveBack() return end
        if what == "dungeon" or what == "map" or what == "select" or what == "items" or what == "live" then C:Refresh() end
        C:UpdateInset()
    end)
end

-- On the minimap itself. Inside, the game gives no position, so nothing can sit at a PLACE on it; what can go
-- on it is text fixed to the minimap: the route's next boss, along its bottom edge, while you're in a dungeon
-- with a route (the user, 2026-11-25: "what ability do you have to draw on the minimap in a dungeon" / "find a way").
local mmLabel
local function updateMinimapLabel()
    if not Minimap then return end
    local d = J.inside
    local route = d and ns.Routes and ns.Routes[d.name]
    local i = route and ns.Route and ns.Route.NextIndex and ns.Route.NextIndex(route)
    if not i then
        if mmLabel then mmLabel:Hide() end
        return
    end
    if not mmLabel then
        mmLabel = Minimap:CreateFontString(nil, "OVERLAY")
        mmLabel:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
        mmLabel:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 8)
        mmLabel:SetJustifyH("CENTER")
    end
    local s = route.steps[i]
    mmLabel:SetText(s and ("|cffffd100Next:|r " .. s.label) or "|cff33ff33All bosses done|r")
    mmLabel:Show()
end

-- The route box (the user, 2026-11-25, third run of Blackmaw Hold: "id like a line drawn on the minimap if possible
-- for the whole trip, the second time we got lost and turned around"). The real minimap can't take it: the game
-- draws it around your position, which it hides from addons inside. So a small map of its own, by the minimap,
-- while you're in a dungeon with a game map (GameMaps): the game's picture, the whole route line (a boss you've
-- killed loses its leg), the stops numbered in order, and the area you're in lit. Drag to move; right-click hides
-- it until the next dungeon.
local box
local BOX = 240
local function boxBuild()
    box = CreateFrame("Frame", "VoidDungeonRouteBox", UIParent, "BackdropTemplate")
    box:SetSize(BOX + 8, BOX + 26)
    box:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 0, -40)
    box:SetFrameStrata("MEDIUM")
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    box:SetBackdropColor(0.03, 0.03, 0.05, 0.92)
    box:SetBackdropBorderColor(A[1], A[2], A[3], 0.8)
    box:EnableMouse(true)
    if ns.Move then ns.Move(box, { db = function() return VoidDungeonDB end, key = "routeBox" }) end
    box:SetScript("OnMouseUp", function(self, b) if b == "RightButton" then self.hiddenFor = J.inside; self:Hide() end end)
    box.title = box:CreateFontString(nil, "OVERLAY")
    box.title:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    box.title:SetPoint("TOPLEFT", 6, -5)
    box.title:SetPoint("RIGHT", -6, 0)
    box.title:SetJustifyH("LEFT")
    box.pic = CreateFrame("Frame", nil, box)
    box.pic:SetSize(BOX, BOX)
    box.pic:SetPoint("BOTTOM", 0, 4)
    box.pic:SetClipsChildren(true)
    box.tiles, box.areas, box.lines, box.badges = {}, {}, {}, {}
    box:Hide()
end
local function boxCrop(key, g)
    -- around the route (entrance + bosses) with a margin, as a square; else the map's own square. Your own pins
    -- count too, so a boss you moved stays in the box (Codex 11-25)
    local x0, y0, x1, y1
    local own = VoidDungeonDB and VoidDungeonDB.pins and VoidDungeonDB.pins[key]
    for _, set in ipairs({ g.pins or {}, own or {} }) do
        for _, p in pairs(set) do
            x0, y0 = math.min(x0 or p[1], p[1]), math.min(y0 or p[2], p[2])
            x1, y1 = math.max(x1 or p[1], p[1]), math.max(y1 or p[2], p[2])
        end
    end
    if not x0 then return g.crop end
    local size = math.max(x1 - x0, y1 - y0) * 1.25 + 0.1
    return { (x0 + x1) / 2 - size / 2, (y0 + y1) / 2 - size / 2, size }
end
local function boxUpdate()
    local d = J.inside
    local key = d and d.main
    local g = key and ns.GameMaps and ns.GameMaps[key]
    if not (g and g.pins) then
        if box then
            box:Hide()
            if not d then box.hiddenFor = nil end   -- left the dungeon: the next time in shows it again (Codex 11-25)
        end
        return
    end
    if not box then boxBuild() end
    if box.hiddenFor and box.hiddenFor == d then return end
    box.hiddenFor = nil
    local cr = boxCrop(key, g)
    local px = BOX / cr[3]
    local pic = box.pic
    local function at(tx, ty) return (tx - cr[1]) * px, -(ty - cr[2]) * px end
    -- the picture
    local n = 0
    for row = 0, g.rows - 1 do
        for col = 0, g.cols - 1 do
            local id = g.ids[row * g.cols + col + 1]
            local a, b = math.max(col, cr[1]), math.min(col + 1, cr[1] + cr[3])
            local c, e = math.max(row, cr[2]), math.min(row + 1, cr[2] + cr[3])
            if id and id > 0 and b > a and e > c then
                n = n + 1
                local tx = box.tiles[n] or pic:CreateTexture(nil, "ARTWORK")
                box.tiles[n] = tx
                tx:SetTexture(id)
                tx:SetTexCoord(a - col, b - col, c - row, e - row)
                tx:ClearAllPoints()
                local x, y = at(a, c)
                tx:SetPoint("TOPLEFT", pic, "TOPLEFT", x, y)
                tx:SetSize((b - a) * px, (e - c) * px)
                tx:Show()
            end
        end
    end
    for i = n + 1, #box.tiles do box.tiles[i]:Hide() end
    -- the area you're in
    local here
    if g.areas then
        local sub, mz = GetSubZoneText() or "", GetMinimapZoneText() or ""
        here = (g.areas[sub] and sub) or (g.areas[mz] and mz) or nil
    end
    n = 0
    local runs = here and g.areas[here] or {}
    for k = 1, #runs - 2, 3 do
        n = n + 1
        local t = box.areas[n] or pic:CreateTexture(nil, "OVERLAY")
        box.areas[n] = t
        t:SetColorTexture(A[1], A[2], A[3], 0.3)
        t:ClearAllPoints()
        local x, y = at(runs[k + 1] / 16, runs[k] / 16)
        t:SetPoint("TOPLEFT", pic, "TOPLEFT", x, y)
        t:SetSize((runs[k + 2] - runs[k + 1] + 1) / 16 * px, px / 16)
        t:Show()
    end
    for i = n + 1, #box.areas do box.areas[i]:Hide() end
    -- the route: lines to the stops still to do, numbers on all
    local route = ns.Route and ns.Route.For and ns.Route.For(d)
    local view = route and viewFor(route, key, g, cr) or {}
    local li, bi, nextLabel = 0, 0, nil
    local STY = { next = { 1, 0.85, 0.1, 1, 3 }, todo = { 1, 0.3, 0.2, 0.9, 2 }, opt = { 0.45, 0.75, 1, 0.8, 2 },
        done = { 0.55, 0.55, 0.6, 0.6, 2 } }
    local k512 = BOX / 512
    for i, s in pairs(view) do
        if s then
            local state = ns.Route.State and ns.Route.State(route, i) or "todo"
            if state == "next" then nextLabel = s.label end
            local st = STY[(s.opt and state == "todo") and "opt" or state] or STY.todo
            local ln = state ~= "done" and s.line
            if ln then
                for p = 1, #ln - 3, 2 do
                    li = li + 1
                    local l = box.lines[li] or pic:CreateLine(nil, "OVERLAY")
                    box.lines[li] = l
                    l:SetThickness(st[5])
                    l:SetColorTexture(st[1], st[2], st[3], st[4])
                    l:SetStartPoint("TOPLEFT", pic, ln[p] * k512, -ln[p + 1] * k512)
                    l:SetEndPoint("TOPLEFT", pic, ln[p + 2] * k512, -ln[p + 3] * k512)
                    l:Show()
                end
            end
            bi = bi + 1
            local b = box.badges[bi]
            if not b then
                b = CreateFrame("Frame", nil, pic)
                b:SetSize(14, 14)
                b:SetFrameLevel(pic:GetFrameLevel() + 5)
                b.bg = b:CreateTexture(nil, "BACKGROUND")
                b.bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                b.bg:SetAllPoints()
                b.t = b:CreateFontString(nil, "OVERLAY")
                b.t:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
                b.t:SetPoint("CENTER")
                box.badges[bi] = b
            end
            b:ClearAllPoints()
            b:SetPoint("CENTER", pic, "TOPLEFT", s.x * k512, -s.y * k512)
            b.bg:SetVertexColor(st[1] * 0.35, st[2] * 0.35, st[3] * 0.35, 0.95)
            b.t:SetText(i)
            b.t:SetTextColor(st[1], st[2], st[3])
            b:Show()
        end
    end
    for i = li + 1, #box.lines do box.lines[i]:Hide() end
    for i = bi + 1, #box.badges do box.badges[i]:Hide() end
    box.title:SetText((nextLabel and ("|cffffd100Next:|r " .. nextLabel) or "|cff33ff33Route|r")
        .. (here and ("  |cff8c8c9e" .. here .. "|r") or ""))
    box:Show()
end
C.RouteBox = boxUpdate

-- the lit area follows you: the game sends these when the area name changes
local zev = CreateFrame("Frame")
for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
    zev:RegisterEvent(e)
end
zev:SetScript("OnEvent", function()
    -- after Core.lua has set J.inside for this zone
    C_Timer.After(0.6, function()
        C:Refresh()
        updateMinimapLabel()
        boxUpdate()
    end)
end)
J:OnChange(function(what) if what == "live" or what == "dungeon" then updateMinimapLabel(); boxUpdate() end end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    if not (VoidMap and VoidMap.OnReady and VoidMap.SetSideOwner) then
        J:Print("needs VoidMap 0.2.3 or newer.")
        return
    end
    VoidMap:OnReady(build)
end)
