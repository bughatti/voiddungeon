----------------------------------------------------------------------
-- Entrances.lua — every dungeon and raid entrance on VoidMap's world map (WoW Forever has no
-- entrance icons: its dungeon journal is empty, so Blizzard's own provider shows nothing).
--
-- Data: Data/Entrances.lua (tools/cmd/vdungeon-entrances, from NorgannonDB). Shown on the zone
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
    return "5-player dungeon"
end

local function levelText(e)
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
