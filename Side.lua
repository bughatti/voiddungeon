----------------------------------------------------------------------
-- Side.lua — the tabs beside the dungeon map (VoidMap's side area, borrowed).
--   Quests  your quests for this dungeon (the quest log's header for it)
--   Loot    every boss's drops, or the selected boss's
--   Path    entrance, bosses and stops in Atlas's order; hover = spot on the map
--   Tips    VoidCheatSheet's notes (needs VoidCheatSheet)
----------------------------------------------------------------------
local _, ns = ...
local J = ns.J
local A = J.A
local S = {}
ns.Side = S

local ROW_H = 18
local TABS = { "Quests", "Loot", "Path", "Tips" }
local frame, list, head, more
local tabBtns, rows, entries, offset = {}, {}, {}, 0

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

local function questEntries(out)
    local d = J.cur
    local want = d and d.name:lower()
    local ids = (ns.DQ and d and ns.DQ[d.name]) or {}
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
    end
    if #mine == 0 then out[#out + 1] = { text = "   none", r = 0.5, g = 0.5, b = 0.55 } end

    -- 2) not picked up yet: for your race and class, not done, not in the log
    local race = select(3, UnitRace("player"))
    local class = select(3, UnitClass("player"))
    local level = UnitLevel("player")
    local ready, later = {}, {}
    for _, qid in ipairs(ids) do
        local q = ns.QI and ns.QI[qid]
        if q and not listed[qid] and not done(qid) and not inLog(qid) and hasBit(q[4], race) and hasBit(q[5], class) then
            local e = { qid = qid, q = q }
            for _, p in ipairs(q[7] or {}) do
                if done(p) then e.needPre = nil; break end
                e.needPre = e.needPre or p
            end
            if e.needPre then
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
        if e.needPre then
            right = "|cff8c8c9eafter a quest|r"
        elseif e.needLevel then
            right = "|cff8c8c9eat " .. e.needLevel .. "|r"
        elseif s and s[1] == "i" then
            right = "|cffffd200inside|r"
        else
            local mi = s and s[4] and s[4] > 0 and C_Map.GetMapInfo(s[4])
            right = mi and ("|cffffd200" .. mi.name .. "|r") or ""
        end
        out[#out + 1] = { text = ("[%d] %s"):format(q[2] or 0, q[1]), r = r, g = g, b = b, right = right, missing = e }
    end
    if #ready + #later > 0 then
        out[#out + 1] = { head = "Not picked up yet" }
        for _, e in ipairs(ready) do add(e, false) end
        for _, e in ipairs(later) do add(e, true) end
        out[#out + 1] = { text = "Click one: route to where it starts.", r = 0.45, g = 0.45, b = 0.5 }
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
                right = it[2] > 0 and (it[2] .. "%") or "|cff8c8c9e?|r" }
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

-- VoidCheatSheet's sheet for this dungeon, if it's installed.
local function sheet()
    local D = VoidCheatSheetData
    if not (D and D.dungeons and J.cur) then return nil end
    local want = J.cur.name:lower():gsub("^the ", "")
    for _, d in ipairs(D.dungeons) do
        local n = (d.name or ""):lower():gsub("^the ", ""):gsub(" %(.*%)$", "")
        if n == want or want:find(n, 1, true) or n:find(want, 1, true) then return d end
    end
end

local function tipEntries(out)
    local d = sheet()
    if not d then
        out[#out + 1] = { text = VoidCheatSheetData and ("No tips for " .. J.cur.name .. " yet.")
            or "Tips come from VoidCheatSheet: install it to see boss notes here.", r = 0.6, g = 0.6, b = 0.65, wrap = true }
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

local BUILD = { Quests = questEntries, Loot = lootEntries, Path = pathEntries, Tips = tipEntries }

----------------------------------------------------------------------
-- Rows
----------------------------------------------------------------------
local function rowEnter(r)
    local e = r.e
    if not e then return end
    if e.row and ns.Canvas then ns.Canvas:Glow(e.row) end
    if e.item then
        GameTooltip:SetOwner(r, "ANCHOR_LEFT")
        GameTooltip:SetItemByID(e.item)
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
        if m.needPre then
            local p = ns.QI and ns.QI[m.needPre]
            GameTooltip:AddLine("First: " .. (p and p[1] or ("quest " .. m.needPre)), 1, 0.5, 0.5, true)
            local ps = p and startText(p[6])
            if ps then GameTooltip:AddLine("   which starts: " .. ps, 0.8, 0.6, 0.6, true) end
        end
        if m.needLevel then GameTooltip:AddLine("Needs level " .. m.needLevel, 1, 0.5, 0.5) end
        if q[6] and q[6][1] ~= "i" then GameTooltip:AddLine("Click: route there", 0.5, 0.8, 1) end
        GameTooltip:Show()
    elseif e.wrap and r.title:IsTruncated() then
        GameTooltip:SetOwner(r, "ANCHOR_LEFT")
        GameTooltip:SetText(e.text, 1, 1, 1, 1, true)
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
    if e.back then J:Select(nil); return end
    if e.newRun then J:NewRun(); return end
    if e.missing then
        -- a quest that must come first: route to that one instead
        local m = e.missing
        if m.needPre and ns.QI and ns.QI[m.needPre] then
            routeTo({ q = ns.QI[m.needPre] })
        else
            routeTo(m)
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
    r:RegisterForClicks("LeftButtonUp")
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
