----------------------------------------------------------------------
-- Entrances.lua — every dungeon and raid entrance on VoidMap's world map (WoW Forever has no
-- entrance icons: its dungeon journal is empty, so Blizzard's own provider shows nothing).
--
-- Data: Data/Entrances.lua (tools/cmd/vdungeon-entrances, from VoidDB). Shown on the zone
-- map of the entrance and on the maps above it (continent, the zone around a city), never on
-- the Azeroth map. Instances sharing a door (Scarlet Monastery's wings, Blackrock Mountain)
-- become one icon listing all of them.
--   hover        name, levels (coloured for you), 5-player / raid size
--   left-click   the dungeon view (a list first when several share the door)
--   right-click  the way there (VoidGPS), or a map pin without it
--
-- The icons are our own frames on Blizzard's canvas, not Blizzard map pins: nothing here runs
-- Blizzard's pin code (see VoidMap/PinGuard.lua for why that matters in combat).
----------------------------------------------------------------------
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end
local _, ns = ...
local J = ns.J
local A = J.A

local E = {}
ns.EntranceIcons = E

local W, canvas
local icons = {}
local ICON = 26

local MAPTYPE_ZONE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
local MAPTYPE_CONTINENT = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2

local function hasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function isRaid(e) return (e.size or 5) > 5 end

local function levelColor(lv)
    if GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(lv)
        if c then return c.r, c.g, c.b end
    end
    return 1, 0.82, 0
end

local function sizeText(e)
    if isRaid(e) then return e.size .. "-player raid" end
    if (e.size or 0) == 0 then return "instance" end
    return "5-player dungeon"
end

local function levelText(e)
    if (e.min or 0) == 0 then return "?" end
    if e.min == e.max then return tostring(e.min) end
    return e.min .. "-" .. e.max
end

----------------------------------------------------------------------
-- Where each entrance lands on the map being shown
----------------------------------------------------------------------
-- x, y of (uiMap, x, y) on the shown map, or nil when it isn't on it
local rectCache = {}
local function project(fromMap, x, y, onMap)
    if fromMap == onMap then return x, y end
    local key = fromMap .. ">" .. onMap
    local r = rectCache[key]
    if r == nil then
        r = false
        if C_Map.GetMapRectOnMap then
            local ok, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, fromMap, onMap)
            if ok and minX and maxX and maxX > minX and maxY > minY then r = { minX, maxX, minY, maxY } end
        end
        rectCache[key] = r
    end
    if not r then return nil end
    local px, py = r[1] + x * (r[2] - r[1]), r[3] + y * (r[4] - r[3])
    if px < 0 or px > 1 or py < 0 or py > 1 then return nil end
    return px, py
end

-- { x, y, list = { entries } } for the shown map; entries sharing a door merge
local function spotsFor(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    if not (info and (info.mapType == MAPTYPE_ZONE or info.mapType == MAPTYPE_CONTINENT)) then return {} end
    -- how close two doors must be to share an icon (a continent merges Blackrock Mountain's two)
    local near = info.mapType == MAPTYPE_CONTINENT and 0.025 or 0.025
    local out = {}
    for _, e in ipairs(ns.Entrances or {}) do
        local placed = {}   -- one icon per instance per map (two doors far apart = two icons)
        for _, s in ipairs(e.at) do
            local x, y = project(s[1], s[2], s[3], mapID)
            if x then
                local dup = false
                for _, p in ipairs(placed) do
                    if math.abs(p[1] - x) < near and math.abs(p[2] - y) < near then dup = true; break end
                end
                if not dup then
                    placed[#placed + 1] = { x, y }
                    local spot
                    for _, o in ipairs(out) do
                        if math.abs(o.x - x) < near and math.abs(o.y - y) < near then spot = o; break end
                    end
                    if not spot then
                        spot = { x = x, y = y, list = {}, map = s[1], mx = s[2], my = s[3] }
                        out[#out + 1] = spot
                    end
                    spot.list[#spot.list + 1] = e
                end
            end
        end
    end
    return out
end

----------------------------------------------------------------------
-- Actions
----------------------------------------------------------------------
local function openView(e)
    local d = e.dungeon and J.byName[e.dungeon]
    if d then J:Open(d) return true end
    J:Print(e.name .. ": no dungeon map yet.")
    return false
end

local function wayThere(spot)
    local names = {}
    for _, e in ipairs(spot.list) do names[#names + 1] = e.name end
    local target = { name = names[1], sub = (#names > 1 and (#names .. " instances") or "entrance"),
        map = spot.map, x = spot.mx, y = spot.my }
    if VoidGPS and VoidGPS.RouteTo and VoidGPS:RouteTo(target) then return end
    if C_Map.SetUserWaypoint and UiMapPoint and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(spot.map) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(spot.map, spot.mx, spot.my))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end
end

local function pickMenu(owner, spot)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then openView(spot.list[1]) return end
    GameTooltip:Hide()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, e in ipairs(spot.list) do
            local r, g, b = levelColor(e.min)
            local label = ("%s  |cff%02x%02x%02x%s|r"):format(e.name, math.floor(r * 255), math.floor(g * 255),
                math.floor(b * 255), levelText(e))
            root:CreateButton(label, function() openView(e) end)
        end
    end)
end

----------------------------------------------------------------------
-- Icons
----------------------------------------------------------------------
local function icon(i)
    local b = icons[i]
    if b then return b end
    b = CreateFrame("Button", nil, canvas)
    b:SetSize(ICON, ICON)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- a dark disc with a coloured ring: the game's own dungeon art alone is lost on the parchment
    local mask = b:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints()
    b.ring = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.ring:SetAllPoints()
    b.ring:AddMaskTexture(mask)
    local inner = b:CreateMaskTexture()
    inner:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    inner:SetPoint("TOPLEFT", 2, -2); inner:SetPoint("BOTTOMRIGHT", -2, 2)
    b.disc = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.disc:SetPoint("TOPLEFT", 2, -2); b.disc:SetPoint("BOTTOMRIGHT", -2, 2)
    b.disc:SetColorTexture(0.05, 0.05, 0.07, 0.92)
    b.disc:AddMaskTexture(inner)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("TOPLEFT", 3, -3); b.tex:SetPoint("BOTTOMRIGHT", -3, 3)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.18)
    b.hl:AddMaskTexture(mask)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetFont(J.FONT, 10, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", 3, -2)
    b:SetScript("OnClick", function(self, button)
        local spot = self.spot
        if not spot then return end
        if button == "RightButton" then wayThere(spot)
        elseif #spot.list > 1 then pickMenu(self, spot)
        else openView(spot.list[1]) end
    end)
    b:SetScript("OnEnter", function(self)
        local spot = self.spot
        if not spot then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for k, e in ipairs(spot.list) do
            if k > 1 then GameTooltip:AddLine(" ") end
            GameTooltip:AddLine(e.name, A[1], A[2], A[3])
            local r, g, b = levelColor(e.min)
            GameTooltip:AddDoubleLine("Level " .. levelText(e), sizeText(e), r, g, b, 0.8, 0.8, 0.8)
            if not (e.dungeon and J.byName[e.dungeon]) then GameTooltip:AddLine("No dungeon map yet.", 0.55, 0.55, 0.6) end
            -- an entrance no data has, learned from walk-ins (EntranceLearn.lua)
            if e.measured then GameTooltip:AddLine("Entrance: where Void players walked in.", 0.55, 0.8, 0.55) end
            if e.learned == "own" then GameTooltip:AddLine("Entrance: where you walked in.", 0.55, 0.8, 0.55)
            elseif e.learned then GameTooltip:AddLine(("Entrance: where %d Void players walked in."):format(e.learned), 0.55, 0.8, 0.55) end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(#spot.list > 1 and "Left-click: pick one for the dungeon view" or "Left-click: dungeon view", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Right-click: the way there", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icons[i] = b
    return b
end

local function styleIcon(b, spot)
    local raid = false
    for _, e in ipairs(spot.list) do if isRaid(e) then raid = true end end
    if raid then b.ring:SetColorTexture(1, 0.5, 0.15, 1) else b.ring:SetColorTexture(A[1], A[2], A[3], 1) end
    local atlas = raid and "Raid" or "Dungeon"
    if hasAtlas(atlas) then
        b.tex:SetAtlas(atlas)
        b.tex:SetVertexColor(1, 1, 1)
    else
        b.tex:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        if raid then b.tex:SetVertexColor(1, 0.45, 0.3) else b.tex:SetVertexColor(1, 1, 1) end
    end
    b.count:SetText(#spot.list > 1 and #spot.list or "")
end

-- canvas units per pin unit, so icons keep one size on screen at any zoom
local function canvasScale()
    local s = W.GetCanvasScale and W:GetCanvasScale()
    return (s and s > 0) and s or 1
end

function E:Place()
    if not (W and canvas) then return end
    local cs = canvasScale()
    local cw, ch = canvas:GetSize()
    for _, b in ipairs(icons) do
        if b:IsShown() and b.spot then
            b:SetScale(1 / cs)
            b:ClearAllPoints()
            b:SetPoint("CENTER", canvas, "TOPLEFT", b.spot.x * cw * cs, -b.spot.y * ch * cs)
        end
    end
end

-- the frame level Blizzard gives its own dungeon entrance pins (above the map art tiles, which
-- are frames too, below quest and player pins); a plain read of the level table
local function iconLevel()
    local m = W.GetPinFrameLevelsManager and W:GetPinFrameLevelsManager()
    local ok, lv = pcall(function() return m and m:GetValidFrameLevel("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE") end)
    if ok and type(lv) == "number" then return lv end
    return canvas:GetFrameLevel() + 500
end

function E:Refresh()
    if not (W and canvas) then return end
    for _, b in ipairs(icons) do b:Hide(); b.spot = nil end
    if J.mode or (VoidDungeonDB and VoidDungeonDB.entrances == false) then return end
    local level = iconLevel()
    for i, spot in ipairs(spotsFor(W:GetMapID())) do
        local b = icon(i)
        b.spot = spot
        styleIcon(b, spot)
        b:SetFrameLevel(level)
        b:Show()
    end
    self:Place()
end

----------------------------------------------------------------------
-- Start (once VoidMap is ready)
----------------------------------------------------------------------
local function setup()
    W = WorldMapFrame
    canvas = W and W.GetCanvas and W:GetCanvas()
    if not canvas then return end
    if W.OnMapChanged then hooksecurefunc(W, "OnMapChanged", function() E:Refresh() end) end
    if W.OnCanvasScaleChanged then hooksecurefunc(W, "OnCanvasScaleChanged", function() E:Place() end) end
    canvas:HookScript("OnSizeChanged", function() E:Place() end)
    W:HookScript("OnShow", function() E:Refresh() end)
    hooksecurefunc(J, "SetMode", function() E:Refresh() end)   -- the dungeon view covers the map
    E:Refresh()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    if VoidMap and VoidMap.OnReady then VoidMap:OnReady(setup) end
end)

----------------------------------------------------------------------
-- Learning entrances no data has (formerly its own file; kept in Entrances.lua so a /reload
-- loads it: a new TOC file needs a game restart)
-- EntranceLearn.lua -- entrances no data has, learned from players walking in (the user,
-- 2026-11-15: "do we have coordinates for all new 9 dungeons, it doesnt show on the map";
-- decided: measure + recorder, the web lists only say where to walk).
--
-- Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold and Shaper's Terrace have no entrance in any data
-- we ship (Data/Entrances.lua: ns.EntrancesUnknown). While you're outdoors VoidDungeon keeps your last
-- few positions; when you WALK into one of those (you were moving a moment before, no summon, no
-- flight, not a login or reload), the spot just outside is its entrance:
--   VoidDungeonDB.entranceSpots[name] = { map, x, y, t }   your own; shown at once
-- and it goes to other Void players 10 minutes later (kind "e": piece = name, key = uiMap, value =
-- the 1% map cell "x:y"), used by them once 2 different players handed the same over.
-- Learned entrances join ns.Entrances (e.learned = "own" | n players), so the map icon, the way
-- there and J:EntranceOf / J:DropsOf all use them.
----------------------------------------------------------------------
-- (J is the file's own local)
local L = {}
J.EntranceLearn = L

local SW = "e"
local FRESH = 8          -- s: the last outdoor position must be this recent when you zone in
local MOVE_SPAN = 4      -- s: and you moved within this long before it
local MOVED = 0.002      -- of the map's width: a few yards (standing still = not walking in)
local SUMMON_GAP = 120   -- s after a summon offer: a zone-in may be the summon

local function secret(v) return issecretvalue and issecretvalue(v) end
local function norm(s) return (s or ""):lower():gsub("^the ", ""):gsub("[^%w]", "") end

local function db()
    VoidDungeonDB = VoidDungeonDB or {}
    VoidDungeonDB.entranceSpots = VoidDungeonDB.entranceSpots or {}
    return VoidDungeonDB.entranceSpots
end

-- the unknown entrance a GetInstanceInfo name means, or nil
local function unknownOf(name)
    if type(name) ~= "string" or secret(name) then return nil end
    local n = norm(name)
    for _, u in ipairs(ns.EntrancesUnknown or {}) do
        if norm(u.name) == n or (u.dungeon and norm(u.dungeon) == n) then return u end
    end
end
local function unknownByName(name)
    for _, u in ipairs(ns.EntrancesUnknown or {}) do if u.name == name then return u end end
end

local function swarm()
    if not (VoidSwarm and VoidSwarm.Want) then return nil end
    if not L.wanted then
        L.wanted = true
        VoidDungeonDB = VoidDungeonDB or {}
        VoidDungeonDB.swarmE = VoidDungeonDB.swarmE or {}
        VoidSwarm.Want(SW, { need = 2, store = VoidDungeonDB.swarmE, maxPieces = 12, maxKeys = 3,
            paused = function() return VoidMarkDB and VoidMarkDB.shareOff and true or false end,   -- "Share fight results" off
            valid = function(piece, key, value)
                local m = tonumber(key)
                local cx, cy = tostring(value):match("^(%d%d?):(%d%d?)$")
                return unknownByName(piece) ~= nil and m ~= nil and m > 0 and m < 100000 and tostring(m) == key
                    and cx ~= nil and true or false
            end })
    end
    return VoidSwarm.Get and VoidSwarm.Get()
end

local function cellOf(x, y)
    local cx, cy = math.floor(x * 100), math.floor(y * 100)
    if cx < 0 or cx > 99 or cy < 0 or cy > 99 then return nil end
    return cx .. ":" .. cy
end

-- where an unknown entrance is: own spot first, else the one 2+ players agree on
-- -> map, x, y, learned ("own" or the number of players) | nil
function L:SpotOf(name)
    local own = db()[name]
    if own and own.map and own.x and own.y then return own.map, own.x, own.y, "own" end
    local net = swarm()
    if not (net and net.Piece) then return nil end
    local ok, piece = pcall(net.Piece, net, SW, name)
    for key, value in pairs(ok and piece or {}) do
        local cx, cy = tostring(value):match("^(%d+):(%d+)$")
        local _, n = net:Get(SW, name, key)
        if cx and n and n >= 2 then
            return tonumber(key), (tonumber(cx) + 0.5) / 100, (tonumber(cy) + 0.5) / 100, n
        end
    end
end

-- learned entrances into ns.Entrances (replacing earlier learned ones), then the map icons
function L:Apply()
    local list = ns.Entrances
    if not list then return end
    for i = #list, 1, -1 do if list[i].learned then table.remove(list, i) end end
    for _, u in ipairs(ns.EntrancesUnknown or {}) do
        local map, x, y, how = self:SpotOf(u.name)
        if map then
            list[#list + 1] = { name = u.name, dungeon = u.dungeon, min = u.min, max = u.max, size = u.size,
                at = { { map, x, y } }, learned = how }
        end
    end
    if J.ForgetDrops then J:ForgetDrops() end
    if ns.EntranceIcons and ns.EntranceIcons.Refresh then ns.EntranceIcons:Refresh() end
end

-- note a walk-in (from the zone-in check, or a test)
function L:Record(name, map, x, y)
    local u = unknownByName(name)
    map, x, y = tonumber(map), tonumber(x), tonumber(y)
    if not (u and map and x and y) or x <= 0 or x >= 1 or y <= 0 or y >= 1 then return false end
    db()[name] = { map = map, x = math.floor(x * 10000 + 0.5) / 10000, y = math.floor(y * 10000 + 0.5) / 10000, t = time() }
    local cell = cellOf(x, y)
    local net = swarm()
    if cell and net and net.Report then pcall(net.Report, net, SW, name, tostring(map), cell, 600) end
    J:Print(("noted %s's entrance where you walked in (%.1f, %.1f): it's on the map now."):format(name, x * 100, y * 100))
    self:Apply()
    return true
end

----------------------------------------------------------------------
-- Watching: your outdoor positions, then the zone-in
----------------------------------------------------------------------
local samples = {}   -- { t, map, x, y }, newest last, a few seconds' worth
local summonedAt
local leaving   -- the walk-in spot as it was when the loading screen began (or false)

local function sample()
    if UnitOnTaxi and UnitOnTaxi("player") then wipe(samples) return end
    -- Alcaz Prison 2026-11-20 (measured, VoidDev dungeon log): the game already says "in a dungeon"
    -- a moment before the loading screen, while you still stand outside. Keep the outdoor positions
    -- taken so far (zonedIn wipes them; FRESH keeps them from going stale) instead of dropping them.
    if IsInInstance() then return end
    local map = C_Map.GetBestMapForUnit("player")
    if not map or secret(map) then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if not (x and y) or secret(x) or secret(y) or x <= 0 or y <= 0 then return end
    samples[#samples + 1] = { t = GetTime(), map = map, x = x, y = y }
    while #samples > 8 do table.remove(samples, 1) end
end

-- the walk-in spot: the newest outdoor position, if fresh and you were moving just before it
local function walkedIn()
    local last = samples[#samples]
    if not last or GetTime() - last.t > FRESH then return nil end
    if summonedAt and GetTime() - summonedAt < SUMMON_GAP then return nil end
    for i = #samples - 1, 1, -1 do
        local s = samples[i]
        if last.t - s.t > MOVE_SPAN then break end
        if s.map == last.map and math.max(math.abs(s.x - last.x), math.abs(s.y - last.y)) >= MOVED then return last end
    end
    return nil
end

local function zonedIn()
    local name, kind = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then return end
    local u = unknownOf(name)
    -- judged when the loading screen began: a slow load must not make the walk-in look stale (Codex)
    local spot = u and leaving
    leaving = nil
    wipe(samples)
    if u and spot then pcall(L.Record, L, u.name, spot.map, spot.x, spot.y) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(ev.RegisterEvent, ev, "CONFIRM_SUMMON")
ev:RegisterEvent("PLAYER_LEAVING_WORLD")
ev:SetScript("OnEvent", function(_, event, isLogin, isReload)
    if event == "PLAYER_LOGIN" then
        -- listen for other players' finds from the start, and hand your own over again (one first
        -- seen while the network was down still goes out; a repeat isn't held again)
        C_Timer.After(3, function()
            local net = swarm()
            if not (net and net.Report) then return end
            for name, s in pairs(db()) do
                local cell = unknownByName(name) and s.map and s.x and s.y and cellOf(s.x, s.y)
                if cell then pcall(net.Report, net, SW, name, tostring(s.map), cell, 600) end
            end
        end)
        C_Timer.NewTicker(1, function() pcall(sample) end)
        -- other players' finds arrive over time: look again now and then
        C_Timer.NewTicker(120, function() pcall(L.Apply, L) end)
        C_Timer.After(5, function() pcall(L.Apply, L) end)
    elseif event == "PLAYER_LEAVING_WORLD" then
        -- samples are outdoor positions only (sample() takes none inside), so no IsInInstance() check
        -- here: it can already be true on the outdoor side (Alcaz Prison); leaving a dungeon finds none
        leaving = walkedIn() or false
    elseif event == "CONFIRM_SUMMON" then
        summonedAt = GetTime()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if isLogin or isReload then wipe(samples); leaving = nil return end
        pcall(zonedIn)
    end
end)
