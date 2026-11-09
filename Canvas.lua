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

    -- the picture: square, as big as the area allows, centered
    local w, h = canvas:GetSize()
    local size = math.max(64, math.min(w, h) - 8)
    mapTex:SetSize(size, size)
    if m and m.img then
        mapTex:SetTexture(J.MAPS .. key)
        mapTex:Show()
        noMap:Hide()
    else
        mapTex:Hide()
        noMap:SetText("No map for " .. J.cur.name .. " yet.\nWe'll draw one; the Path tab has its bosses.")
        noMap:Show()
    end

    -- markers on every spot a legend row has
    local nextRow = J.NextBoss and J:NextBoss() or nil
    local n = 0
    if m and m.img then
        local scale = size / 512
        for _, r in ipairs(m.rows) do
            local s = r[4]
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
end

-- Light up a row's markers (Side.lua's hover).
function C:Glow(row)
    for _, mk in ipairs(markers) do
        if mk:IsShown() then mk.glow:SetShown(mk.row == row or mk.row == J.sel) end
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
local INSET = 210

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
function C:UpdateInset()
    local want = J.mode and canvas and canvas:IsVisible() and J.inside and J.cur == J.inside
        and (VoidDungeonDB and VoidDungeonDB.inset ~= false)
    if want then borrow() else giveBack() end
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
    canvas:SetScript("OnSizeChanged", function() C:Refresh() end)
    mapTex = canvas:CreateTexture(nil, "ARTWORK")
    mapTex:SetPoint("CENTER")
    noMap = text(canvas, 13)
    noMap:SetPoint("CENTER")
    noMap:SetJustifyH("CENTER")
    noMap:SetTextColor(0.7, 0.7, 0.75)
    local credit = text(canvas, 9)
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

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    if not (VoidMap and VoidMap.OnReady and VoidMap.SetSideOwner) then
        J:Print("needs VoidMap 0.2.3 or newer.")
        return
    end
    VoidMap:OnReady(build)
end)
