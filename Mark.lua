----------------------------------------------------------------------
-- VoidDungeon: Mark the pack (WoW Forever dungeons and raids). Was the separate VoidMark addon
-- until 2026-11-14 (the user: "we are building too many different addons ... merge it"); its frame
-- names, /vmark and VoidMarkDB stay so keys and settings keep working.
--
-- The user, 2026-11-11: "lets do a npc marker addon, it needs to know what mobs are most
-- important". Decided the same day: WoW Forever dungeons first; one key marks the pack; kill
-- order + crowd control by the classes in your group; who may mark = the game's rule (party: anyone, raid: leader + assistants, 11-14).
--
-- What matters, most first, learned from what the game shows (no hand-written lists):
--   healer          seen casting a heal (Heal, Renew, ...)
--   mana burn       seen casting Mana Burn / Drain Mana (empties your healer)
--   crowd control   seen casting fear, polymorph, stun, silence or mind control
--   summoner        seen summoning adds (Summon Skeleton, ...)
--   dispeller       seen dispelling (strips your buffs)
--   caster          seen casting damage spells, or uses mana
--   the rest        elite before normal
-- "Seen casting": every hostile nameplate's casts are watched, and the spell's kind comes from
-- the game's own spell table (SpellKinds.lua, tools/cmd/vmark-spells). Kept per mob type in
-- VoidMarkDB.mobs[npcID], so the second time you meet a Scarlet Chaplain it's known as a healer
-- before it casts.
--
-- Markers: Skull = kill first, X = kill second. Then crowd control for classes in your group,
-- on the next most important mob it works on:
--   Moon = Mage polymorph (humanoid, beast)     Square = Hunter freezing trap (any)
--   Diamond = Warlock banish (demon, elemental) Star = Rogue sap (humanoid)
--   Triangle = Priest shackle (undead)          Circle = Druid hibernate (beast, dragonkin)
-- Mobs that already carry a marker are left alone, and their markers aren't handed out again.
----------------------------------------------------------------------
local ADDON, ns = ...
ns = ns or {}
local VM = VoidMark or {}
VoidMark = VM
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end   -- WoW Forever only

local SKULL, X, SQUARE, MOON, TRIANGLE, DIAMOND, CIRCLE, STAR = 8, 7, 6, 5, 4, 3, 2, 1
local MAX_MOBS = 8
-- what a spell kind (SpellKinds.lua) says about the mob that casts it, most important first.
-- Mana burn right after healers (the user, 2026-11-11: "there are more important spells than
-- that, mana burn"): it empties your healer.
local KIND = {
    h = { score = 100, role = "healer",        color = "|cff55ff55" },
    m = { score = 85,  role = "mana burn",     color = "|cff4da6ff" },
    c = { score = 60,  role = "crowd control", color = "|cffff8040" },
    s = { score = 50,  role = "summoner",      color = "|cffc080ff" },
    x = { score = 30,  role = "dispeller",     color = "|cffffd040" },
    d = { score = 20,  role = "caster",        color = "|cffbbbbff" },
}
local KIND_ORDER = { "h", "m", "c", "s", "x", "d" }
local CC = {   -- class -> marker, the creature types it works on (nil = any), what it is
    MAGE    = { MOON,     { Humanoid = true, Beast = true, Critter = true }, "polymorph" },
    HUNTER  = { SQUARE,   nil, "freezing trap" },
    WARLOCK = { DIAMOND,  { Demon = true, Elemental = true }, "banish" },
    ROGUE   = { STAR,     { Humanoid = true }, "sap" },
    PRIEST  = { TRIANGLE, { Undead = true }, "shackle" },
    DRUID   = { CIRCLE,   { Beast = true, Dragonkin = true }, "hibernate" },
}
local CC_ORDER = { "MAGE", "HUNTER", "WARLOCK", "ROGUE", "PRIEST", "DRUID" }

local function secret(v) return issecretvalue and issecretvalue(v) end
local function safe(fn, ...)
    if not fn then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function readable(v) if secret(v) then return nil end return v end   -- dungeons hide mob identity (11-14)
local function say(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff00c7ffVoidMark|r " .. msg) end
local function icon(i) return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t"):format(i) end

local function db()
    VoidMarkDB = VoidMarkDB or {}
    VoidMarkDB.mobs = VoidMarkDB.mobs or {}
    return VoidMarkDB
end

local function npcOf(unit)
    local g = UnitGUID(unit)
    if not g or secret(g) then return nil end
    return tonumber(g:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
end
local function hostileMob(unit)
    return UnitExists(unit) and not UnitIsPlayer(unit) and UnitCanAttack("player", unit) and not UnitIsDead(unit)
end

-- Behind a wall? (the user, 2026-11-14: "its marking what it sees through walls"). Nameplates show
-- through walls; the only line-of-sight sign the game gives addons is that it DIMS a nameplate it
-- can't see you to: its alpha times nameplateOccludedAlphaMult (0.4 by default). A plate that can
-- still be in sight is never dimmer than the lower of nameplateMinAlpha (far away) and
-- nameplateNotSelectedAlpha (you have another target); a hidden one is never brighter than the
-- brightest alpha times that multiplier. When those two ranges overlap (the player changed them)
-- there's no telling, and nothing is left out. -> the cut, or nil
local function cvarNum(k)
    local v = GetCVar and safe(GetCVar, k)
    return tonumber(v)
end
local cutCache, cutAt = nil, -10
local function hiddenCut()
    local t = GetTime and GetTime() or 0
    if t - cutAt < 2 then return cutCache or nil end
    cutAt = t
    cutCache = false
    local mult = cvarNum("nameplateOccludedAlphaMult")
    if not mult or mult >= 0.95 then return nil end
    -- a negative value means "not used" (WoW Forever: nameplateNotSelectedAlpha = -1, read live 11-14)
    local function used(k) local v = cvarNum(k); if v and v >= 0 then return v end end
    local bright = math.max(used("nameplateMaxAlpha") or 1, used("nameplateSelectedAlpha") or 1)
    local dim = math.min(used("nameplateMinAlpha") or 1, used("nameplateNotSelectedAlpha") or 1)
    local hiddenMax = bright * mult
    if hiddenMax >= dim - 0.05 then return nil end
    cutCache = hiddenMax + 0.02
    return cutCache
end
VM.HiddenCut = hiddenCut

-- what was read, so a live run shows whether this holds on Forever (VoidMarkDB.los)
local function losNote(kind, a, cut, hidden, quiet)
    if quiet then return end
    local d = db()
    local l = d.los or {}
    d.los = l
    l[kind] = (l[kind] or 0) + 1
    if a then
        l.samples = l.samples or {}
        local s = l.samples
        if #s >= 40 then table.remove(s, 1) end
        s[#s + 1] = { a = math.floor(a * 100 + 0.5) / 100, cut = cut, hidden = hidden or nil }
    end
end

-- true = the game dims this mob's nameplate: it's behind a wall. false = in sight. nil = can't tell
-- (forbidden or hidden plate, settings that don't allow it). Your target always counts as in sight.
local function behindWall(unit, quiet)
    local cut = hiddenCut()
    if not cut then
        losNote("nocut", nil, nil, nil, quiet)
        if not quiet then   -- what the game gave, so a run shows why (the first live run: 2751 x nocut)
            local l = db().los
            if l and not l.cvars then
                l.cvars = {}
                for _, k in ipairs({ "nameplateOccludedAlphaMult", "nameplateMinAlpha", "nameplateMaxAlpha",
                    "nameplateSelectedAlpha", "nameplateNotSelectedAlpha" }) do
                    local v = GetCVar and safe(GetCVar, k)
                    l.cvars[k] = v == nil and "nil" or tostring(v)
                end
            end
        end
        return nil
    end
    local isT = UnitIsUnit and UnitIsUnit(unit, "target")
    if isT and not secret(isT) then return false end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and safe(C_NamePlate.GetNamePlateForUnit, unit)
    if not plate then losNote("noplate", nil, nil, nil, quiet) return nil end
    if plate.IsForbidden and plate:IsForbidden() then losNote("forbidden", nil, nil, nil, quiet) return nil end
    local ok, a = pcall(plate.GetAlpha, plate)
    if not ok or secret(a) or type(a) ~= "number" then losNote("unread", nil, nil, nil, quiet) return nil end
    local hidden = a <= cut
    losNote(hidden and "hidden" or "seen", a, cut, hidden, quiet)
    return hidden
end
VM.BehindWall = behindWall

----------------------------------------------------------------------
-- Learning what a mob does
----------------------------------------------------------------------
local MOBS_MAX = 3000
local function mobRec(npc, unit)
    local d = db().mobs
    local r = d[npc]
    if not r then
        local n = 0
        for _ in pairs(d) do n = n + 1; if n >= MOBS_MAX then return nil end end
        r = {}
        d[npc] = r
    end
    if unit then
        local name = UnitName(unit)
        if name and not secret(name) then r.n = name end
        local pt = UnitPowerType(unit)
        local pmax = UnitPowerMax(unit, 0)
        if not secret(pt) and not secret(pmax) then r.mana = (pt == 0 and (pmax or 0) > 0) or nil end
    end
    return r
end

local function sawCast(unit, spellID)
    if not (unit and spellID) or secret(spellID) or not hostileMob(unit) then return end
    local k = VM.SpellKind and VM.SpellKind[spellID]
    if not k then return end
    local npc = npcOf(unit)
    local r = npc and mobRec(npc, unit)
    if not r then return end
    r[k] = (r[k] or 0) + 1
    if k ~= "d" or not (r.sp and r.sp.d) then
        local info = C_Spell and C_Spell.GetSpellInfo and safe(C_Spell.GetSpellInfo, spellID)
        local name = (info and info.name) or (GetSpellInfo and safe(GetSpellInfo, spellID))
        if name and not secret(name) then
            r.sp = r.sp or {}   -- spell names by kind (not "s": that is the summoner count)
            r.sp[k] = name   -- the spell that showed it, for the tooltip
        end
    end
end

-- How important a mob is, and why. -> score, role ("healer" / "crowd control" / "caster" / nil), spell
local function importance(unit)
    local npc = npcOf(unit)
    local r = npc and db().mobs[npc]
    local s, role, spell = 0, nil, nil
    if r then
        -- most important first; the first that applies names the role
        for _, k in ipairs(KIND_ORDER) do
            if (r[k] or 0) > 0 then
                s = s + KIND[k].score
                if not role then role, spell = KIND[k].role, r.sp and r.sp[k] end
            end
        end
    end
    local pt = UnitPowerType(unit)
    -- in dungeons a mob's max mana is SECRET (SecretWhenUnitPowerMaxRestricted, live 11-14 error): skip it there
    local pm = UnitPowerMax(unit, 0)
    if not secret(pt) and pt == 0 and not secret(pm) and (pm or 0) > 0 then
        s = s + 15
        role = role or "caster"
    end
    local cls = UnitClassification(unit)
    if not secret(cls) then
        if cls == "elite" or cls == "rareelite" or cls == "worldboss" then s = s + 5 end
        if cls == "rare" or cls == "rareelite" then s = s + 10 end
    end
    return s, role, spell
end
VM.Importance = importance

----------------------------------------------------------------------
-- Marking the pack
----------------------------------------------------------------------
-- Who may mark: the game's own rule (the user, 2026-11-14: "i can click a mobs portrait and mark
-- them without being leader"). In a party anyone; in a raid the leader and assistants. (Until then
-- it was "leader or tank" only, a design choice, not the game's.)
local function canMark()
    if not IsInRaid() then return true end
    return (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) and true or false
end

local function groupClasses()
    local have = {}
    local _, me = UnitClass("player")
    if me then have[me] = true end
    -- in a raid, partyN is only your own subgroup: read the whole raid (Sol)
    local raid = IsInRaid and IsInRaid()
    local n = raid and (GetNumGroupMembers and GetNumGroupMembers() or 0) or 4
    for i = 1, n do
        local u = (raid and "raid" or "party") .. i
        local _, c = UnitClass(u)
        if c and UnitIsConnected(u) then have[c] = true end
    end
    return have
end

-- the pack: hostile, alive, not a critter, nobody marked it yet; before a pull the ones not
-- in combat, during a fight the ones in it
function VM:Pack()
    local fighting = UnitAffectingCombat("player")
    local list, used = {}, {}
    -- units by name: plate.namePlateUnitToken errors on WoW Forever (Layer.lua, 11-09)
    for i = 1, 40 do
        local u = "nameplate" .. i
        if hostileMob(u) and behindWall(u) ~= true then
            local idx = GetRaidTargetIndex(u)
            if idx and not secret(idx) then
                used[idx] = true
            else
                local cls = UnitClassification(u)
                local inFight = UnitAffectingCombat(u)
                if not secret(cls) and cls ~= "minus" and cls ~= "trivial" and (not secret(inFight)) and (fighting or not inFight) then
                    local s, role, spell = importance(u)
                    local ct = UnitCreatureType(u)
                    list[#list + 1] = { unit = u, score = s, role = role, spell = spell, name = readable(UnitName(u)),
                        ctype = (not secret(ct)) and ct or nil, lvl = readable(UnitLevel(u)) or 0 }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return (a.lvl or 0) > (b.lvl or 0)
    end)
    while #list > MAX_MOBS do table.remove(list) end
    return list, used
end

-- Who gets which marker: { { mob, marker, why } ... }
function VM:Plan(list, used)
    local plan, taken = {}, {}
    local function free(m) return not used[m] and not taken[m] end
    for _, m in ipairs({ SKULL, X }) do
        for _, mob in ipairs(list) do
            if not mob.marker and free(m) then
                mob.marker, taken[m] = m, true
                plan[#plan + 1] = { mob = mob, marker = m, why = mob.role or "kill" }
                break
            end
        end
    end
    -- crowd control on the next most important mobs, a pull of 3 or more only
    if #list >= 3 then
        local have = groupClasses()
        for _, cls in ipairs(CC_ORDER) do
            local c = CC[cls]
            if have[cls] and free(c[1]) then
                for _, mob in ipairs(list) do
                    if not mob.marker and (not c[2] or mob.anyType or (mob.ctype and c[2][mob.ctype])) then
                        mob.marker, taken[c[1]] = c[1], true
                        plan[#plan + 1] = { mob = mob, marker = c[1], why = c[3] }
                        break
                    end
                end
            end
        end
    end
    return plan
end

-- SetRaidTarget is restricted on WoW Forever: addon code can't call it, not even from a key or a
-- click (ADDON_ACTION_FORBIDDEN, seen live 2026-11-14 with VoidSweep's sleeping-bag star). The
-- game's own /tm can, from a secure macro: "/tm [@nameplate3] ~8" ("~" = only if that mob has no
-- marker yet). So the Mark button and the key both click VoidMarkButton (SecureActionButtonTemplate,
-- type macro). Right before the click (PreClick, out of combat) the plan is written into its macro
-- and the game runs it. In combat the game locks the macro, so marking is for before the pull; the
-- macro is emptied when combat starts, so a press then never marks a stale nameplate.

-- the plan as a macro: text, plan, or nil + why not
function VM:Macro()
    if not canMark() then return nil, nil, "in a raid only the leader and assistants can mark (the game's rule)." end
    local list, used = self:Pack()
    if #list == 0 then return nil, nil, "no unmarked mobs in view." end
    local plan = self:Plan(list, used)
    local lines = {}
    for _, p in ipairs(plan) do lines[#lines + 1] = ("/tm [@%s] ~%d"):format(p.mob.unit, p.marker) end
    return table.concat(lines, "\n"), plan
end

local function px()   -- one screen pixel (borders: never a plain 1, feedback-pixel-perfect-borders)
    local s = UIParent and UIParent:GetEffectiveScale()
    if s and s > 0 and PixelUtil and PixelUtil.GetPixelToUIUnitFactor then return PixelUtil.GetPixelToUIUnitFactor() / s end
    return 1
end

-- Made once at load, never later (secure setup only at load: a /reload in combat).
local A = { 0, 0.78, 1 }
local btn = CreateFrame("Button", "VoidMarkButton", UIParent, "SecureActionButtonTemplate,BackdropTemplate")
VM.Button = btn
btn:SetSize(104, 30)
btn:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
btn:SetFrameStrata("MEDIUM")
btn:SetClampedToScreen(true)
-- The border is drawn again at login and when the UI scale or window size changes: at load the UI
-- scale isn't applied yet, so "one pixel" came out too thin and the right side vanished (the user,
-- 2026-11-14: "right side missing line").
local looks = {}   -- [frame] = its background colour
local bgAlpha = {}  -- [frame] = function: its background opacity (the board's slider, the user 2026-11-14)
local function look(f, r, g, b, a)
    looks[f] = looks[f] or { r, g, b, a }
    local c = looks[f]
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = px() })
    f:SetBackdropColor(c[1], c[2], c[3], bgAlpha[f] and bgAlpha[f]() or c[4])
    f:SetBackdropBorderColor(A[1], A[2], A[3], 0.6)
end
look(btn, 0.08, 0.08, 0.13, 0.95)
btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
btn.text:SetPoint("CENTER")
btn.text:SetText(icon(SKULL) .. " Mark pack")
-- release only: a click on mouse-DOWN kept the button from being dragged (the user, 11-14: "its not
-- movable"); the key binding acts on release too (useOnKeyDown false)
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:SetAttribute("useOnKeyDown", false)   -- act on release even with cast-on-key-down on
btn:SetAttribute("type", "macro")
btn:SetAttribute("macrotext", "")
-- shown while you're in a group (a state driver: it works in combat too)
-- Never shown (the user, 2026-11-14: "can we take away the mark pack and just leave the box up
-- always"): the board is always up in a group now. The button stays as a hidden target for the
-- key binding (Key Bindings > AddOns > VoidMark), which still works.
btn:Hide()

----------------------------------------------------------------------
-- The pack board (the user, 2026-11-14, after measuring a dungeon): inside dungeons and raids the
-- game hides a mob's name, id, type, casts and markers from addons (the "Map" restriction, by
-- design: API doc SecretOnRestrictedMaps). It still lets an addon SHOW the hidden name. So in a
-- dungeon Mark opens this board: one row per mob in the pack with its name, level and elite tag,
-- and a marker button per row (Skull, X, the CC markers of the classes in your group, clear).
-- You decide which mob matters; one click marks it. Clicking a marker the mob already has takes
-- it off (the game's /tm toggles).
-- Every marker button is a secure macro button ("/tm [@nameplateN] M"), all made here at load
-- (secure setup only at load). The board is filled and shown only out of combat and closes when
-- combat starts (PLAYER_REGEN_DISABLED comes just before the lock), so it never marks a stale plate.
----------------------------------------------------------------------
local ROWS, BTNS, ROW_H, BTN = 8, 7, 26, 22   -- the user, 11-14: "a little bigger"
local board = CreateFrame("Frame", "VoidMarkBoard", UIParent, "BackdropTemplate")
VM.Board = board
board:SetSize(460, 40)
board:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
board:SetFrameStrata("DIALOG")
board:SetClampedToScreen(true)
bgAlpha[board] = function() return VoidMarkDB and VoidMarkDB.boardAlpha or 0.94 end
look(board, 0.04, 0.04, 0.07, 0.94)
board:Hide()
-- the title bar: grab here to drag the board (the rows are full of buttons)
board.bar = CreateFrame("Frame", nil, board)
board.bar:SetPoint("TOPLEFT", 1, -1)
board.bar:SetPoint("TOPRIGHT", -26, -1)
board.bar:SetHeight(28)
board.title = board:CreateFontString(nil, "OVERLAY", "GameFontNormal")
board.title:SetPoint("TOPLEFT", 10, -8)
board.title:SetText("|cff00c7ffMark the pack|r")
board.hint = board:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
board.hint:SetPoint("TOPRIGHT", -28, -10)
board.hint:SetText("drag here")
local close = CreateFrame("Button", nil, board)
close:SetSize(16, 16)
close:SetPoint("TOPRIGHT", -6, -7)
close.text = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
close.text:SetPoint("CENTER", 0, 1)
close.text:SetText("|cff8c8c9ex|r")
close:SetScript("OnClick", function() if not InCombatLockdown() then board:Hide() end end)
close:Hide()   -- always up in a group (the user, 11-14); /vmark hide turns it off
-- in combat: the buttons are emptied (the game locks marking for addons, and a nameplate can change
-- mob), the rows stay so you can still read them, and this line says why
board.locked = board:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
board.locked:SetPoint("BOTTOM", 0, 34)
board.locked:SetText("|cffff9933in combat: the rows wait for the fight to end; target a mob and use the bar below|r")
board.locked:Hide()

-- The marker bar (the user, 2026-11-14: "the problem with it locking in combat is when you do
-- constant pulls"). In combat the game won't let an addon change what a secure button does, but a
-- button that never changes keeps working, like the game's own raid target keys. So each of these is
-- made once at load with a fixed macro: mark your target (or the mob under the mouse when pressed by
-- a key). Works in a chain pull: target the mob the board says, click its marker here.
local BAR = { SKULL, X, SQUARE, MOON, TRIANGLE, DIAMOND, CIRCLE, STAR, 0 }
board.bar2 = {}
local barLabel = board:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
barLabel:SetPoint("BOTTOMLEFT", 10, 12)
barLabel:SetText("your target:")
for i, mk in ipairs(BAR) do
    local b = CreateFrame("Button", "VoidMarkBar" .. i, board, "SecureActionButtonTemplate")
    b:SetSize(22, 22)
    b:SetPoint("BOTTOMLEFT", 86 + (i - 1) * 26, 6)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    if mk == 0 then
        b.tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    else
        b.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        local k = mk - 1
        b.tex:SetTexCoord((k % 4) * 0.25, (k % 4 + 1) * 0.25, math.floor(k / 4) * 0.25, (math.floor(k / 4) + 1) * 0.25)
    end
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:RegisterForClicks("LeftButtonUp")
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type", "macro")
    -- fixed for good: never emptied in combat (that's the point)
    b:SetAttribute("macrotext", ("/tm [@mouseover,harm,nodead][@target,harm,nodead] %d"):format(mk))
    b.marker = mk
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(mk == 0 and "Take your target's marker off" or ("Put %s on your target"):format(icon(mk)))
        GameTooltip:AddLine("Works in combat too, also in a chain pull: target the mob first. Clicking a marker it already has takes it off.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    board.bar2[i] = b
end
-- The see-through slider (the user, 2026-11-14: "i need marker to have a slider for transparency"),
-- like the Void hub's: only the background fades; names, checks and markers stay solid. Saved.
local fade = CreateFrame("Slider", nil, board)
board.fade = fade
fade:SetOrientation("HORIZONTAL")
fade:SetSize(80, 14)
fade:SetPoint("BOTTOMRIGHT", -40, 10)
fade:SetMinMaxValues(0.1, 1)
fade:SetValueStep(0.05)
if fade.SetObeyStepOnDrag then fade:SetObeyStepOnDrag(true) end
local track = fade:CreateTexture(nil, "BACKGROUND")
track:SetColorTexture(1, 1, 1, 0.18)
track:SetHeight(3)
track:SetPoint("LEFT"); track:SetPoint("RIGHT")
fade:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
local thumb = fade:GetThumbTexture()
if thumb then thumb:SetSize(8, 14); thumb:SetVertexColor(A[1], A[2], A[3]) end
fade.pct = board:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
fade.pct:SetPoint("LEFT", fade, "RIGHT", 6, 0)
local function showPct(v) fade.pct:SetText(("%d%%"):format(math.floor(v * 100 + 0.5))) end
fade:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v * 20 + 0.5) / 20
    VoidMarkDB = VoidMarkDB or {}
    VoidMarkDB.boardAlpha = v
    look(board)
    showPct(v)
end)
fade:EnableMouseWheel(true)
fade:SetScript("OnMouseWheel", function(self, d) self:SetValue(math.max(0.1, math.min(1, self:GetValue() + d * 0.05))) end)
fade:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Background", 1, 1, 1)
    GameTooltip:AddLine("How see-through the board is. Drag or use the mouse wheel. The names, checks and markers stay solid.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
fade:SetScript("OnLeave", function() GameTooltip:Hide() end)
-- the saved value once the saved data is in (ADDON_LOADED), and on show
function board:SyncFade()
    local v = VoidMarkDB and VoidMarkDB.boardAlpha or 0.94
    fade:SetValue(v)
    showPct(v)
    look(board)
end
board.empty = board:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
board.empty:SetPoint("TOPLEFT", 12, -34)
board.empty:SetText("No mobs in view: look at the next pack (V shows enemy nameplates).")
board.empty:Hide()
-- the big green check: apply every learned suggestion at once (a secure macro button, filled by Fill)
local apply = CreateFrame("Button", "VoidMarkApply", board, "SecureActionButtonTemplate")
board.apply = apply
apply:SetSize(26, 26)
apply:SetPoint("TOPRIGHT", -92, -4)
apply:SetFrameLevel((board.bar:GetFrameLevel() or 1) + 3)
apply.tex = apply:CreateTexture(nil, "ARTWORK")
apply.tex:SetAllPoints()
apply.tex:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
apply:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
apply:RegisterForClicks("LeftButtonUp")
apply:SetAttribute("useOnKeyDown", false)
apply:SetAttribute("type", "macro")
apply:SetAttribute("macrotext", "")
apply:Hide()
apply:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Mark them all as learned")
    GameTooltip:AddLine("Puts the marker shown next to each green check on that mob. You can still change any row: every marker you pick teaches it for next time.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
apply:SetScript("OnLeave", function() GameTooltip:Hide() end)
-- "forget": clear what the board learned in this dungeon (test picks), after a yes
local forget = CreateFrame("Button", nil, board)
board.forget = forget
forget:SetSize(44, 16)
forget:SetPoint("TOPRIGHT", -128, -9)
forget:SetFrameLevel((board.bar:GetFrameLevel() or 1) + 3)
forget.text = forget:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
forget.text:SetPoint("CENTER")
forget.text:SetText("forget")
forget:SetScript("OnEnter", function(self)
    self.text:SetText("|cffffd200forget|r")
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Forget the picks learned in this dungeon")
    GameTooltip:AddLine("For test marking: the board goes back to the dungeon's mob list here. Other dungeons keep theirs (/vmark forget clears all).", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
forget:SetScript("OnLeave", function(self) self.text:SetText("forget"); GameTooltip:Hide() end)
if StaticPopupDialogs then
    StaticPopupDialogs.VOIDMARK_FORGET = {
        text = "Forget the marker picks VoidMark learned in this dungeon?",
        button1 = YES or "Yes", button2 = NO or "No",
        OnAccept = function()
            local n = VM.Forget(true)
            say(("forgot %d learned look%s in this dungeon."):format(n, n == 1 and "" or "s"))
            if board:IsShown() and not InCombatLockdown() then board:Fill() end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end
forget:SetScript("OnClick", function() if StaticPopup_Show then StaticPopup_Show("VOIDMARK_FORGET") end end)

----------------------------------------------------------------------
-- Learning (the user, 2026-11-14: "if we know which mobs are important and the box learns that,
-- then the next time ... there's just a green check mark"). The game shows us a mob's name but
-- won't let us read it in a dungeon, so a pick is remembered by what we CAN read: the dungeon,
-- your area in it (GetSubZoneText: "Footman's Armory"), elite or not, mana / rage, level. Usually
-- that's one mob type. Next time a row that looks the same shows a green check and the marker;
-- the big check in the title bar applies them all. Level may differ by one (spawns vary). The
-- most picked marker wins; "clear" teaches "leave it unmarked". VoidMarkDB.learned[key] = counts.
----------------------------------------------------------------------
local LEARN_MAX = 3000
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:16|t"
local function now() return (time and time()) or 0 end
local function where()
    -- pcall, not safe(): safe() hands back only 3 values and the instance id is the 8th
    local ok, inst, _, _, _, _, _, _, id = pcall(GetInstanceInfo)
    if not ok then inst, id = nil, nil end
    local sub = readable(GetSubZoneText and GetSubZoneText()) or ""
    id = tonumber(readable(id))
    -- the dungeon's name -> its id, so the Marks tab finds the list for WoW Forever's new dungeons too
    local nm = readable(inst)
    if id and id > 0 and type(nm) == "string" and nm ~= "" then
        local d = db()
        d.instIds = d.instIds or {}
        d.instIds[nm:lower()] = id
    end
    return ("%s:%s"):format(tostring(readable(inst) or "?"), tostring(id or 0)), sub, id
end
local function looksKey(m, dl)
    return table.concat({ m.where or "?", m.sub or "", m.elite or 0, tostring(m.pt), (m.lvl or 0) + (dl or 0) }, "|")
end
local function learned() local d = db(); d.learned = d.learned or {}; return d.learned end
-- Learning is OFF unless "learn my picks" is ticked (the user, 2026-11-14: a test click must not
-- become a "correct" suggestion; only the research list may suggest by default)
local function learning() return db().learnPicks and true or false end
local function teach(m, marker)
    if not (m and m.where) then return end
    if not learning() then return end
    local L = learned()
    local k = looksKey(m)
    local r = L[k]
    if not r then
        local n = 0
        for _ in pairs(L) do n = n + 1; if n >= LEARN_MAX then return end end
        r = {}
        L[k] = r
    end
    r[marker] = (r[marker] or 0) + 1
    r.last, r.t = marker, now()
end
-- the marker a mob that looks like this got most (nil = never seen, 0 = leave it unmarked)

local function suggest(m)
    if not (m and m.where) then return nil end
    if not learning() then return nil end
    local L = learned()
    for _, dl in ipairs({ 0, -1, 1 }) do
        local r = L[looksKey(m, dl)]
        if r then
            local best, bn = nil, 0
            for mk, n in pairs(r) do
                if type(mk) == "number" and (n > bn or (n == bn and mk == r.last)) then best, bn = mk, n end
            end
            if best then return best end
        end
    end
end
VM.Suggest, VM.Teach = suggest, teach

-- Forget what was learned (the user, 2026-11-14: "my marking is not correct though im just
-- testing it"): here = only this dungeon's picks, else all. -> how many looks were forgotten
function VM.Forget(here)
    local L, prefix, n = learned(), here and (where() .. "|"), 0
    for k in pairs(L) do
        if not prefix or k:sub(1, #prefix) == prefix then L[k] = nil; n = n + 1 end
    end
    return n
end

----------------------------------------------------------------------
-- Learning from pulls (the user, 2026-11-14: "we should be collecting all fights for the marker
-- stuff" / "yes build it"). During a fight in a dungeon the game hides mob names from addons, but
-- after it the damage meter (C_DamageMeter, EnemyDamageTaken) lists every enemy that took damage by
-- name (measured in Scarlet Monastery 11-14: 3 pulls, nothing secret). During the pull we note what
-- the board can see of each mob in the fight (level, elite, mana / rage, area); after it, each enemy
-- is matched to those looks through the dungeon list (its level range +-1, elite, power type). A
-- look only one enemy fits is credited to it: VoidMarkDB.seen[look] = { [name] = pulls }. That's
-- the game's own data, not a guess or a click, so it's on without "learn my picks". After 2 pulls
-- that agree (75%+), the board knows "34 elite mana in Crusader's Chapel" IS a Scarlet Chaplain.
----------------------------------------------------------------------
local SEEN_MAX, SURE, SURE_PULLS, CAND_MAX = 3000, 0.75, 2, 3000
local function seenDB() local d = db(); d.seen = d.seen or {}; return d.seen end
local nameIdx = {}
local function seedByName(inst, name)
    local list = VM.Seed and inst and VM.Seed[inst]
    if not list or type(name) ~= "string" then return nil end
    local idx = nameIdx[list]
    if not idx then
        idx = {}
        for _, e in ipairs(list) do idx[e[8]] = idx[e[8]] or e end
        nameIdx[list] = idx
    end
    return idx[name]
end
VM.SeedByName = seedByName

-- what pulls showed this look to be: name, pulls naming it, all pulls of the look (nil = not sure)
-- The exact level decides when it has any pulls; a level next to it only when this one has none,
-- and only for a mob the dungeon list says also comes at this level (Sol review: a neighbour must
-- never overrule what was seen at the exact level).
local function sureOf(r)
    local best, bn, total = nil, 0, 0
    for name, n in pairs(r) do
        if type(n) == "number" and name ~= "t" then
            total = total + n
            if n > bn then best, bn = name, n end
        end
    end
    if best and bn >= SURE_PULLS and bn / total >= SURE then return best, bn, total end
end
----------------------------------------------------------------------
-- Sharing what fights proved (the user, 2026-11-15: dungeon updates over the quest network, "like a
-- torrent"). The swarm (VoidSwarm.lua) is carried by VoidQuest's network, or by VoidSwarmLink.lua
-- (the same channel) without VoidQuest. The hub switch "Share fight results" (VoidMarkDB.shareOff)
-- turns it off: then nothing is sent or taken, and only your own pulls count. Piece = the dungeon's id, key = the look ("area/elite/power/level"), value = the
-- mob your pulls proved it to be. Used only once 3 different players handed the same answer over
-- (VoidSwarm counts who whispered it; the game names the sender), and only when the dungeon list
-- allows that mob at that look: a shared fake would have to be believable AND come from 3
-- characters. Your own pulls always win.
----------------------------------------------------------------------
local SW = "m"
local function swKey(m)
    local sub = (m.sub or ""):gsub("[%c~%^:;=|/]", "")
    if type(m.pt) ~= "number" or not m.lvl or m.lvl <= 0 then return nil end
    return ("%s/%d/%d/%d"):format(sub, m.elite or 0, m.pt, m.lvl)
end
VM.SwarmKey = swKey
-- a shared answer must fit the look: the dungeon list's mob with that name at that elite / power /
-- level (+-1); WoW Forever's new dungeons aren't in the list, so there any plain name goes
local function swValid(piece, key, value)
    local inst = tonumber(piece)
    if not inst or inst <= 0 then return false end
    local _, elite, pt, lvl = key:match("^(.*)/(%d)/(%d+)/(%d+)$")
    elite, pt, lvl = tonumber(elite), tonumber(pt), tonumber(lvl)
    if not lvl or lvl < 1 or lvl > 63 then return false end
    local list = VM.Seed and VM.Seed[inst]
    if not list then return #value <= 50 end
    for _, e in ipairs(list) do
        if e[8] == value and e[3] == elite and e[4] == pt and lvl >= e[1] - 1 and lvl <= e[2] + 1 then return true end
    end
    return false
end
VM.SwarmValid = swValid
local swWanted
local function swarm()
    if not (VoidSwarm and VoidSwarm.Want) then return nil end
    if not swWanted then
        swWanted = true
        local d = db()
        d.swarm = d.swarm or {}
        VoidSwarm.Want(SW, { need = 3, store = d.swarm, valid = swValid, maxPieces = 60, maxKeys = 300,
            paused = function() return db().shareOff and true or false end })
    end
    return VoidSwarm.Get()
end
VM.Swarm = swarm

local function knownAs(m)
    if not (m and m.where) then return nil end
    local S = seenDB()
    local r = S[looksKey(m)]
    if r then return sureOf(r) end
    for _, dl in ipairs({ -1, 1 }) do
        local rn = S[looksKey(m, dl)]
        local name, bn, total
        if rn then name, bn, total = sureOf(rn) end   -- (not "rn and sureOf(rn)": that keeps one value)
        local e = name and seedByName(m.inst, name)
        if e and e[3] == m.elite and e[4] == m.pt and m.lvl and m.lvl >= e[1] and m.lvl <= e[2] then
            return name, bn, total
        end
    end
    -- nothing from your own pulls: what other players' pulls proved (3 players, the swarm)
    local net, key = swarm(), swKey(m)
    if net and key and m.inst and not db().shareOff then
        local v, n, own = net:Get(SW, tostring(m.inst), key)
        if v and not own then return v, n, n, true end
    end
    -- what fights proved before this version came out (Data/MarkProven.lua, tools/cmd/vmark-proven:
    -- the author's pulls, and answers 2+ players' fights agreed on), checked like a shared answer
    local p = key and m.inst and VM.Proven and VM.Proven[m.inst]
    local v = p and p[key]
    if type(v) == "string" and swValid(tostring(m.inst), key, v) then return v, nil, nil, "shipped" end
end

-- your own proven looks -> the swarm (all of them: at login, and after each pull)
local function swReport()
    local net = swarm()
    if not net then return 0 end
    local n = 0
    for key, r in pairs(seenDB()) do
        local w, sub, elite, pt, lvl = key:match("^(.-)|(.-)|(%d)|(%d+)|(%d+)$")
        local inst = w and tonumber(w:match(":(%d+)$"))
        local name = inst and sureOf(r)
        if name then
            local k = swKey({ sub = sub, elite = tonumber(elite), pt = tonumber(pt), lvl = tonumber(lvl) })
            -- a new find waits 10 min or until you leave the dungeon (not live where you are)
            if k and net:Report(SW, tostring(inst), k, name, 600) then n = n + 1 end
        end
    end
    return n
end
VM.SwarmReport = swReport
VM.KnownAs = knownAs

-- Your own marks, set ahead of time on the Marks tab of the dungeon map (the user, 2026-11-14: "i
-- want to go mark 3 caster types usually in 1 pull in sm ... so when i run it, it comes up that way
-- and i can just hit the green checkmark"). VoidMarkDB.plan[instance map id][mob name] = marker
-- (1-8), 0 = leave it unmarked. They win over the board's own suggestions.
local function planDB() local d = db(); d.plan = d.plan or {}; return d.plan end
function VM.PlanGet(inst, name)
    local p = inst and name and planDB()[inst]
    return p and p[name]
end
function VM.PlanSet(inst, name, marker)
    if not (inst and name) then return end
    local P = planDB()
    P[inst] = P[inst] or {}
    P[inst][name] = marker
    if next(P[inst]) == nil then P[inst] = nil end
end
-- the marker your plan gives a board row's mob, and which mob that is (nil = no plan applies):
-- by its name where the game shows it (outside dungeons); inside, where names are hidden, the mob
-- your pulls proved this look to be, else every dungeon-list mob that fits the look when all of
-- them have the same mark from you (two that look alike and differ = no telling)
local function planOf(m)
    local inst = m and m.inst
    local P = inst and planDB()[inst]
    if not P or next(P) == nil then return nil end
    local nm = m.name or (m.unit and readable(UnitName(m.unit)))
    if nm then return P[nm], nm end
    local known = knownAs(m)
    if known then return P[known], known end
    local list = VM.Seed and VM.Seed[inst]
    if not list or not m.lvl or m.lvl <= 0 then return nil end
    local mk, who, n = nil, nil, 0
    for _, e in ipairs(list) do
        if e[3] == m.elite and e[4] == m.pt and m.lvl >= e[1] and m.lvl <= e[2] then
            n = n + 1
            local v = P[e[8]]
            if v == nil or (mk ~= nil and v ~= mk) then return nil end
            mk, who = v, who and (who .. " / " .. e[8]) or e[8]
        end
    end
    if n == 0 then return nil end
    return mk, who
end
VM.PlanOf = planOf

-- one pull: the looks seen in it and the enemy names the meter gave -> looks credited
local function creditPull(looks, names, wiped)
    if type(looks) ~= "table" or type(names) ~= "table" or #looks == 0 or #names == 0 then return 0 end
    local uniq, have = {}, {}
    for _, nm in ipairs(names) do
        if type(nm) == "string" and nm ~= "" and not have[nm] then have[nm] = true; uniq[#uniq + 1] = nm end
    end
    local S, n = seenDB(), 0
    local function add(key, name)
        local r = S[key]
        if not r then
            local c = 0
            for _ in pairs(S) do c = c + 1; if c >= SEEN_MAX then return false end end
            r = {}
            S[key] = r
        end
        r[name] = (r[name] or 0) + 1
        r.t = now()
        n = n + 1
        return true
    end
    -- one entry per look (two mobs that look the same are one look)
    local open, byKey = {}, {}
    for _, L in ipairs(looks) do
        local key = looksKey(L)
        if not byKey[key] and L.lvl and L.lvl > 0 then byKey[key] = true; open[#open + 1] = { L = L, key = key } end
    end
    local left = {}   -- names nobody has been matched to yet
    for _, nm in ipairs(uniq) do left[nm] = true end
    -- 1) the dungeon list: a look only one enemy fits
    for _, o in ipairs(open) do
        local fit, count = nil, 0
        for _, nm in ipairs(uniq) do
            local e = seedByName(o.L.inst, nm)
            if e and e[3] == o.L.elite and e[4] == o.L.pt and o.L.lvl >= e[1] - 1 and o.L.lvl <= e[2] + 1 then
                fit, count = nm, count + 1
            end
        end
        if count == 1 then
            if not add(o.key, fit) then return n end
            o.done, left[fit] = true, nil
        end
    end
    -- 2) elimination (WoW Forever's new dungeons aren't in the list, 11-14 The Drowned City): a look
    -- earlier pulls already know takes its mob out; when exactly one look and one enemy are left,
    -- they're each other. (Only mobs in the fight are looks, and a mob that took no damage, a
    -- sheep, isn't an enemy here: then the counts differ and nothing is guessed.)
    for _, o in ipairs(open) do
        if not o.done then
            local known = knownAs(o.L)
            -- every look known as a mob in this pull is done, also a second one known as the same
            -- mob (Sol: only the first was, the second could be paired with another name)
            if known and have[known] then o.done, left[known] = true, nil end
        end
    end
    -- One enemy name left: every look still open is that mob (live 11-14, The Drowned City: a pack
    -- of six Mindless Gorgers at levels 37 and 38 is ONE name on the meter). A pack only ends when
    -- every mob in it died, so every mob that was in the fight took damage and is on the list;
    -- not after a wipe (wiped = true: mobs lived, the counts mean nothing), and never against the
    -- dungeon list (a listed mob must fit the look it's paired with).
    if wiped then return n end
    local function fits(L, name)   -- never against the list: a listed mob must fit the look
        local e = seedByName(L.inst, name)
        return not e or (e[3] == L.elite and e[4] == L.pt and L.lvl >= e[1] - 1 and L.lvl <= e[2] + 1)
    end
    local lastName, namesLeft = nil, 0
    for nm in pairs(left) do lastName, namesLeft = nm, namesLeft + 1 end
    if namesLeft == 1 then
        for _, o in ipairs(open) do
            if not o.done and fits(o.L, lastName) then
                if not add(o.key, lastName) then return n end
                o.done = true
            end
        end
    end
    -- 3) across pulls (the user, 2026-11-14: "yes build it"; live The Drowned City: packs of two
    -- or more kinds taught nothing in 21 pulls): a look's mob is in EVERY pull that look is in, so
    -- each look keeps the names present every time (VoidMarkDB.cand[look]); one name left = that
    -- mob. Brinescale Explorer turns up in many packs, the Sorceress only where the mana look is.
    -- A pull that clears every name (a critter slipped through, a mob that took no damage) starts
    -- that look over from this pull's names.
    local C = db().cand or {}
    db().cand = C
    for _, o in ipairs(open) do
        local c = C[o.key]
        if not c then
            local k = 0
            for _ in pairs(C) do k = k + 1; if k >= CAND_MAX then break end end
            if k < CAND_MAX then c = { pulls = 0 }; C[o.key] = c end
        end
        if c then
            local nextSet, count = {}, 0
            for _, nm in ipairs(uniq) do
                if (c.pulls == 0 or (c.names and c.names[nm])) and fits(o.L, nm) then nextSet[nm] = true; count = count + 1 end
            end
            if count == 0 then   -- nothing in common: start over from this pull
                for _, nm in ipairs(uniq) do if fits(o.L, nm) then nextSet[nm] = true; count = count + 1 end end
                c.pulls = 0
            end
            c.names, c.pulls, c.t = nextSet, c.pulls + 1, now()
            if count == 1 and c.pulls >= 2 and not o.done then
                local only = next(nextSet)
                if not add(o.key, only) then return n end
                o.done = true
            end
        end
    end
    return n
end
VM.CreditPull = creditPull

-- The dungeon list (Seed.lua, tools/cmd/vmark-seed from the CMaNGOS classic database; the user,
-- 2026-11-14: "its just data to mark high importance mobs over others"): every mob of this dungeon
-- with the same elite flag and power type whose level range holds this level. -> average score of
-- those (healer 100, mana burn 85, CC 60, summoner 50, caster 20...), their names, how many, and
-- the name pulls showed it to be. A look pulls know is scored as exactly that mob.
local function seedOf(m)
    local known = knownAs(m)
    local e = known and seedByName(m.inst, known)
    if e then return e[5], { e[8] .. (e[7] ~= "" and (" (" .. e[7] .. ")") or "") }, 1, known end
    local list = VM.Seed and m and m.inst and VM.Seed[m.inst]
    if not list or not m.lvl or m.lvl <= 0 then return nil, nil, nil, known end
    local sum, n, names = 0, 0, {}
    for _, e in ipairs(list) do
        if e[3] == m.elite and e[4] == m.pt and m.lvl >= e[1] and m.lvl <= e[2] then
            sum, n = sum + e[5], n + 1
            if #names < 4 then names[#names + 1] = e[8] .. (e[7] ~= "" and (" (" .. e[7] .. ")") or "") end
        end
    end
    if n == 0 then return nil, nil, nil, known end
    return math.floor(sum / n + 0.5), names, n, known
end
VM.SeedOf = seedOf
local SEED_MIN = 50   -- a summoner or more on average: worth a Skull / X suggestion

local rows = {}
for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, board)
    row:SetSize(442, ROW_H)
    row:SetPoint("TOPLEFT", 9, -6 - i * ROW_H)
    -- hover a row: which mobs it probably is (the dungeon list) and where its suggestion comes from
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        local m = self.mob
        if not m then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local _, sharedN, _, shared = knownAs(m)
        if m.known and shared == "shipped" then
            GameTooltip:AddLine(("Seen in Void players' fights here: %s"):format(m.known), 1, 1, 1, true)
            GameTooltip:AddLine("Comes with VoidDungeon; your own fights here will replace it.", 0.6, 0.6, 0.6, true)
        elseif m.known and shared then
            GameTooltip:AddLine(("Seen in other players' fights here: %s (%d players)"):format(m.known, sharedN or 0), 1, 1, 1, true)
            GameTooltip:AddLine("Shared over the Void network once 3 players' fights agreed; your own fights here will replace it.", 0.6, 0.6, 0.6, true)
        elseif m.known then
            GameTooltip:AddLine(("Seen in your fights here: %s"):format(m.seedNames and m.seedNames[1] or m.known), 1, 1, 1, true)
            GameTooltip:AddLine("The game names mobs to addons once a fight ends; mobs that look like this were this one.", 0.6, 0.6, 0.6, true)
        elseif m.seedNames then
            GameTooltip:AddLine(("Probably: %s%s"):format(table.concat(m.seedNames, ", "),
                (m.seedN or 0) > #m.seedNames and (" (+%d more)"):format(m.seedN - #m.seedNames) or ""), 1, 1, 1, true)
            GameTooltip:AddLine("From the dungeon's mob list, by level, elite and mana / rage (the game hides the name from addons).", 0.6, 0.6, 0.6, true)
        else
            GameTooltip:AddLine("Not in the dungeon list (a new WoW Forever dungeon, or a level we don't know).", 0.6, 0.6, 0.6, true)
        end
        -- not known yet: what other players said that isn't confirmed (never used by itself)
        if not m.known then
            local net, key = swarm(), swKey(m)
            local hv, hn, need = nil, nil, nil
            if net and key and m.inst then hv, hn, need = net:Hint(SW, tostring(m.inst), key) end
            if hv then
                GameTooltip:AddLine(("Unconfirmed, from other players: %s (%d of %d needed)"):format(hv, hn or 0, need or 3), 0.8, 0.7, 0.4, true)
            end
        end
        if m.from == "plan" then
            GameTooltip:AddLine(("Your mark for %s: %s (Marks tab in the dungeon map)."):format(m.planName or "this mob",
                m.skip and "leave it unmarked" or icon(m.sugg)), 0.2, 1, 0.2, true)
        elseif m.sugg then
            GameTooltip:AddLine(m.from == "learned" and "Suggested: what was picked for mobs like this before." or "Suggested: one of the most important mobs here.", 0.2, 1, 0.2, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", 20, 0)
    row.name:SetWidth(150)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.info = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.info:SetPoint("LEFT", 174, 0)
    row.done = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.done:SetPoint("LEFT", 0, 0)
    row.sugg = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.sugg:SetPoint("LEFT", 236, 0)
    row.btns = {}
    for j = 1, BTNS do
        local b = CreateFrame("Button", ("VoidMarkBoard%d_%d"):format(i, j), row, "SecureActionButtonTemplate")
        b:SetSize(BTN, BTN)
        b:SetPoint("RIGHT", row, "RIGHT", -(BTNS - j) * (BTN + 2), 0)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
        b:SetAttribute("useOnKeyDown", false)
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", "")
        b:SetScript("PostClick", function(self, _, down)
            if down then return end
            -- an emptied button (in combat, or its mob gone) marked nothing: show and teach nothing (Sol)
            if (self:GetAttribute("macrotext") or "") == "" then return end
            -- the game hides markers from addons: show what you clicked (a second click toggles it off)
            local set = self.marker ~= 0 and row.mark ~= self.marker
            if self.marker == 0 or row.mark == self.marker then row.mark = nil else row.mark = self.marker end
            row.done:SetText(row.mark and icon(row.mark) or "")
            -- learn it: a marker you set, or "clear" (= leave it unmarked); taking a marker off again teaches nothing
            if set or self.marker == 0 then teach(row.mob, self.marker) end
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.marker == 0 and "Take its marker off" or (self.why or "Mark it"))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        row.btns[j] = b
    end
    row:Hide()
    rows[i] = row
end
VM.BoardRows = rows

-- the markers on offer: Skull and X, then the CC marker of each class in your group, then clear
local function offer()
    local list = { { SKULL, "Skull: kill first" }, { X, "X: kill second" } }
    local have = groupClasses()
    for _, cls in ipairs(CC_ORDER) do
        local c = CC[cls]
        if have[cls] and #list < BTNS - 1 then
            list[#list + 1] = { c[1], ("%s: %s"):format(cls:sub(1, 1) .. cls:sub(2):lower(), c[3]) }
        end
    end
    list[#list + 1] = { 0, "clear" }
    return list
end

-- the pack, out of combat: hostile, alive, not trivial; elites and higher levels first (all the
-- game still shows in a dungeon)
local function pack()
    local list = {}
    local w, sub, inst = where()
    for i = 1, 40 do
        local u = "nameplate" .. i
        if hostileMob(u) and behindWall(u) ~= true then   -- not the next room through a wall
            local cls = readable(UnitClassification(u))
            local lvl = readable(UnitLevel(u)) or 0
            -- critters come back "normal" at level 1 (live 11-14, a crab at the Altar of the Serpent
            -- became a look); no dungeon mob is level 1-5 (skull bosses are -1 and stay)
            if cls ~= "minus" and cls ~= "trivial" and not (lvl >= 1 and lvl <= 5) then
                list[#list + 1] = { unit = u, lvl = lvl,
                    elite = (cls == "elite" or cls == "rareelite" or cls == "worldboss") and 1 or 0,
                    pt = readable(UnitPowerType(u)), where = w, sub = sub, inst = inst }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.elite ~= b.elite then return a.elite > b.elite end
        if a.lvl ~= b.lvl then return a.lvl > b.lvl end
        return a.unit < b.unit
    end)
    return list
end

-- Auto in dungeons (the user, 2026-11-14: "all i have to do is check a checkmark"). Names are
-- hidden there, but a mob's power type isn't: measured in Scarlet Monastery 11-14, 112 of 300 mobs
-- used mana and 188 rage (outside: hounds, bats, scouts all rage). Classic gives caster and healer
-- NPCs mana and fighters rage, so mana = caster (healers among them). Skull and X go on casters
-- (elites, then higher levels, first), then your group's CC markers on the rest (creature type is
-- hidden too, so CC goes on regardless). "~": a mob that already has a marker keeps it.
function VM:AutoMacro()
    if not canMark() then return nil, nil, "in a raid only the leader and assistants can mark (the game's rule)." end
    local list = {}
    for _, m in ipairs(pack()) do
        m.caster = readable(UnitPowerType(m.unit)) == 0
        m.anyType = true
        m.role = m.caster and "caster" or nil
        m.name = readable(UnitName(m.unit))
        m.seed = seedOf(m) or -1   -- the dungeon list's guess (healers on top); -1 = not in it
        list[#list + 1] = m
    end
    if #list == 0 then return nil, nil, "no mobs in view: look at the pack so their nameplates show (V toggles them)." end
    table.sort(list, function(a, b)
        if a.seed ~= b.seed then return a.seed > b.seed end
        if a.caster ~= b.caster then return a.caster end
        if a.elite ~= b.elite then return a.elite > b.elite end
        if a.lvl ~= b.lvl then return a.lvl > b.lvl end
        return a.unit < b.unit
    end)
    while #list > MAX_MOBS do table.remove(list) end
    -- your own marks first (the Marks tab), then learned picks (the board teaches them), the caster
    -- rule for the rest
    local pre, taken = {}, {}
    for _, m in ipairs(list) do
        local p = planOf(m)
        if p == 0 then
            m.marker = 0   -- your plan: leave it unmarked
        elseif p and not taken[p] then
            m.marker, taken[p] = p, true
            pre[#pre + 1] = { mob = m, marker = p, why = "your mark" }
        end
    end
    for _, m in ipairs(list) do
        local s = m.marker == nil and suggest(m)
        if s == 0 then
            m.marker = 0   -- learned: leave it unmarked (Plan skips a mob with a marker)
        elseif s and not taken[s] then
            m.marker, taken[s] = s, true
            pre[#pre + 1] = { mob = m, marker = s, why = "learned" }
        end
    end
    local plan = self:Plan(list, taken)
    for i = #pre, 1, -1 do table.insert(plan, 1, pre[i]) end
    local lines = {}
    for _, p in ipairs(plan) do lines[#lines + 1] = ("/tm [@%s] ~%d"):format(p.mob.unit, p.marker) end
    return table.concat(lines, "\n"), plan
end

-- the checkbox in the board's title bar (saved; account-wide like the board's spot)
local auto = CreateFrame("CheckButton", nil, board, "UICheckButtonTemplate")
board.auto = auto
auto:SetSize(22, 22)
auto:SetPoint("LEFT", board.title, "RIGHT", 10, 0)
auto.label = auto:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
auto.label:SetPoint("LEFT", auto, "RIGHT", 2, 0)
auto.label:SetText("Auto in dungeons")
auto:SetScript("OnShow", function(self) self:SetChecked(db().autoDungeon and true or false) end)
auto:SetScript("OnClick", function(self)
    db().autoDungeon = self:GetChecked() and true or nil
    say(db().autoDungeon and "auto in dungeons on: Mark pack puts Skull and X on the casters and CC on the rest, no board (right-click still opens it)."
        or "auto in dungeons off: Mark pack opens the board in dungeons.")
end)
auto:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Auto in dungeons")
    GameTooltip:AddLine("Mark pack marks right away in dungeons and raids: Skull and X on the casters (mobs that use mana, where the healers are), then your group's crowd-control markers on the rest. Right-click Mark pack still opens this board.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("The game hides mob names there, so it goes by mana, elite and level.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end)
auto:SetScript("OnLeave", function() GameTooltip:Hide() end)
auto:Hide()   -- the board is always up now and its big check marks everything: the box had nothing left to do

-- "learn my picks" (off by default): only then do your clicks teach the board
local learnBox = CreateFrame("CheckButton", nil, board, "UICheckButtonTemplate")
board.learnBox = learnBox
learnBox:SetSize(20, 20)
learnBox:SetPoint("LEFT", board.title, "RIGHT", 8, 0)
learnBox:SetFrameLevel((board.bar:GetFrameLevel() or 1) + 3)
learnBox.label = learnBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
learnBox.label:SetPoint("LEFT", learnBox, "RIGHT", 1, 0)
learnBox.label:SetText("learn my picks")
learnBox:SetScript("OnShow", function(self) self:SetChecked(db().learnPicks and true or false) end)
learnBox:SetScript("OnClick", function(self)
    db().learnPicks = self:GetChecked() and true or nil
    say(db().learnPicks and "learning on: markers you pick on the board become green-check suggestions for mobs that look the same."
        or "learning off: your clicks only mark; green checks come from the dungeon's mob list only.")
    if board:IsShown() and not InCombatLockdown() then board:Fill() end
end)
learnBox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Learn my picks")
    GameTooltip:AddLine("Off: the green checks come only from the dungeon's mob list (healers, mana burn, crowd control, summoners first), and your clicks only mark.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("On: the markers you pick are remembered for mobs that look the same, and win over the list. Leave it off while testing.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
learnBox:SetScript("OnLeave", function() GameTooltip:Hide() end)


function board:Fill()
    if InCombatLockdown() then return false, 0 end
    local mobs, marks = pack(), offer()
    -- suggestions: what was learned first (one marker per mob), then the dungeon list: the two
    -- likeliest important mobs (healer, mana burn, CC, summoner) get Skull and X
    local taken, ranked = {}, {}
    -- your own marks first (the Marks tab), over every row, so a learned pick can't take a marker you planned
    for i = 1, math.min(#mobs, ROWS) do
        local m = mobs[i]
        local p, who = planOf(m)
        m.planName = who
        if p == 0 then
            m.skip, m.from = true, "plan"   -- your plan: leave it unmarked
        elseif p and not taken[p] then
            m.sugg, m.from, taken[p] = p, "plan", true
        end
    end
    for i = 1, math.min(#mobs, ROWS) do
        local m = mobs[i]
        if not m.sugg and not m.skip then
            local s = suggest(m)
            if s == 0 then
                m.skip = true   -- learned: leave it unmarked
            elseif s and not taken[s] then
                m.sugg, m.from, taken[s] = s, "learned", true
            end
        end
        m.seed, m.seedNames, m.seedN, m.known = seedOf(m)
    end
    for i = 1, math.min(#mobs, ROWS) do
        local m = mobs[i]
        if not m.sugg and not m.skip and m.seed and m.seed >= SEED_MIN then ranked[#ranked + 1] = m end
    end
    table.sort(ranked, function(a, b)
        if a.seed ~= b.seed then return a.seed > b.seed end
        return a.unit < b.unit
    end)
    for _, mk in ipairs({ SKULL, X }) do
        if not taken[mk] and ranked[1] then
            local m = table.remove(ranked, 1)
            m.sugg, m.from, taken[mk] = mk, "data", true
        end
    end
    for i, row in ipairs(rows) do
        local m = mobs[i]
        if m then
            -- the name may be a hidden (secret) value in a dungeon: the game still lets us show it
            if not pcall(row.name.SetText, row.name, UnitName(m.unit)) then row.name:SetText("?") end
            row.info:SetText(("%s%s"):format(m.lvl > 0 and m.lvl or "??", m.elite == 1 and " elite" or ""))
            if row.unit ~= m.unit then row.mark = nil; row.done:SetText("") end
            row.unit = m.unit
            row.mob = m
            row.sugg:SetText(m.sugg and (CHECK .. " " .. icon(m.sugg)) or "")
            for j, b in ipairs(row.btns) do
                local mk = marks[j]
                if mk then
                    b.marker, b.why = mk[1], mk[2]
                    b:SetAttribute("macrotext", ("/tm [@%s] %d"):format(m.unit, mk[1]))
                    if mk[1] == 0 then
                        b.tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                        b.tex:SetTexCoord(0, 1, 0, 1)
                    else
                        b.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
                        local k = mk[1] - 1
                        b.tex:SetTexCoord((k % 4) * 0.25, (k % 4 + 1) * 0.25, math.floor(k / 4) * 0.25, (math.floor(k / 4) + 1) * 0.25)
                    end
                    b:Show()
                else
                    b:SetAttribute("macrotext", "")
                    b:Hide()
                end
            end
            row:Show()
        else
            row.unit, row.mark = nil, nil
            row.done:SetText("")
            row.mob = nil
            row.sugg:SetText("")
            for _, b in ipairs(row.btns) do b:SetAttribute("macrotext", ""); b:Hide() end
            row:Hide()
        end
    end
    local n = math.min(#mobs, ROWS)
    board:SetHeight(40 + math.max(1, n) * ROW_H + 50)   -- +50: the "in combat" line and the marker bar at the bottom
    board.empty:SetShown(n == 0)
    -- the big check: every suggestion at once (one marker per mob; a marker suggested twice goes to
    -- the first, most important, row). "~": a mob that already has a marker keeps it.
    local lines, taken, applied = {}, {}, {}
    for i = 1, n do
        local m = mobs[i]
        if m.sugg and not taken[m.sugg] then
            taken[m.sugg] = true
            applied[m.unit] = m.sugg
            lines[#lines + 1] = ("/tm [@%s] ~%d"):format(m.unit, m.sugg)
        end
    end
    board.applied = applied
    board.apply:SetAttribute("macrotext", table.concat(lines, "\n"))
    board.apply:SetShown(#lines > 0)
    return true, n
end

-- after the big check: show on each row what it got (the game hides markers from addons)
apply:SetScript("PostClick", function(self)
    if (self:GetAttribute("macrotext") or "") == "" then return end   -- emptied (combat): marked nothing
    local n = 0
    for _, row in ipairs(rows) do
        local mk = row.unit and board.applied and board.applied[row.unit]
        if mk then row.mark = mk; row.done:SetText(icon(mk)); n = n + 1 end
    end
    say(("marked %d mob%s."):format(n, n == 1 and "" or "s"))
end)

-- The big Mark button (the user, 2026-11-18: "need a better way to click the green checkmark ... almost like a
-- seperate button attached to voidmark i can drag thats a little bigger to auto mark stuff"). Its own box, dragged
-- anywhere and kept (VoidMove), that presses the green check: a secure "click" button (the game's own delegation,
-- SecureTemplates SECURE_ACTIONS.click -> delegate:Click, a release, which is what the check acts on), so it marks
-- exactly what the check would and the check's PostClick says how many. Up whenever the board is (dungeon / raid
-- groups, unless /vmark hide). Bright with the number it will mark; dim when there's nothing to mark, and in combat
-- (the game locks marking for addons then; the marker bar keys still work). Made once at load (secure setup).
local go = CreateFrame("Button", "VoidMarkGo", UIParent, "SecureActionButtonTemplate,BackdropTemplate")
VM.Go = go
go:SetSize(72, 72)
go:SetPoint("CENTER", UIParent, "CENTER", 300, 120)
go:SetFrameStrata("MEDIUM")
go:SetClampedToScreen(true)
look(go, 0.08, 0.08, 0.13, 0.92)
go.tex = go:CreateTexture(nil, "ARTWORK")
go.tex:SetSize(44, 44)
go.tex:SetPoint("TOP", 0, -6)
go.tex:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
go.text = go:CreateFontString(nil, "OVERLAY", "GameFontNormal")
go.text:SetPoint("BOTTOM", 0, 6)
go:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
go:RegisterForClicks("LeftButtonUp")   -- release only, so a drag doesn't mark (like the Mark pack button)
go:SetAttribute("useOnKeyDown", false)
go:SetAttribute("type", "click")
go:SetAttribute("clickbutton", apply)
go:Hide()

-- what it shows: the number of mobs the check would mark, or why it can't
function go:Refresh(fighting)   -- fighting: PLAYER_REGEN_DISABLED (it comes just before the lock)
    fighting = fighting or InCombatLockdown()
    local text = apply:GetAttribute("macrotext") or ""
    local n = 0
    if text ~= "" then n = select(2, text:gsub("\n", "\n")) + 1 end
    self.n = n
    local ready = n > 0 and not fighting
    self.tex:SetDesaturated(not ready)
    self.tex:SetAlpha(ready and 1 or 0.45)
    if fighting then
        self.text:SetText("|cff888888in combat|r")
    elseif n > 0 then
        self.text:SetText(("|cff33ff33Mark %d|r"):format(n))
    else
        self.text:SetText("|cff888888Mark|r")
    end
end
apply:HookScript("OnAttributeChanged", function(_, name)
    if name == "macrotext" then go:Refresh() end
end)
go:HookScript("OnShow", function(self) self:Refresh() end)
go:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Mark the pack")
    if InCombatLockdown() then
        GameTooltip:AddLine("In combat the game locks marking for addons. The marker bar on the board (and its keys) still works; this button is ready again after the fight.", 0.8, 0.8, 0.8, true)
    elseif (self.n or 0) > 0 then
        GameTooltip:AddLine(("Puts the suggested markers on %d mob%s: the same as the green check on the board."):format(self.n, self.n == 1 and "" or "s"), 0.8, 0.8, 0.8, true)
    else
        GameTooltip:AddLine("Nothing to mark yet: look at the next pack (V shows enemy nameplates). It lights up when the board has suggestions.", 0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine("Drag to move it.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
go:SetScript("OnLeave", function() GameTooltip:Hide() end)

function board:Open()
    if InCombatLockdown() then say("in combat the game locks marking for addons: open the board before the pull."); return end
    if not canMark() then say("in a raid only the leader and assistants can mark (the game's rule)."); return end
    self:Fill()
    self:Show()
end

-- Always up in a group (the user, 2026-11-14: "just leave the box up always"): a state driver shows
-- it in a group, also when that changes mid-fight. /vmark hide turns that off, /vmark show back on.
-- Dungeons and raids only (the user, 2026-11-14, merging VoidMark into VoidDungeon: marking matters
-- there, hardly in the open world). Checked at load and on every zone change; in combat it waits.
local function inInstance()
    local i, t = IsInInstance()
    return (i and (t == "party" or t == "raid")) and true or false
end
function board:Sync()
    if InCombatLockdown() then self.syncPending = true; return false end
    self.syncPending = nil
    return self:SetAlways(not db().boardOff and inInstance())
end

function board:SetAlways(on)
    if InCombatLockdown() or not RegisterStateDriver then return false end
    if on then
        RegisterStateDriver(self, "visibility", "[group] show; hide")
        RegisterStateDriver(go, "visibility", "[group] show; hide")   -- the big Mark button comes and goes with it
    else
        UnregisterStateDriver(self, "visibility")
        UnregisterStateDriver(go, "visibility")
        self:Hide()
        go:Hide()
    end
    return true
end
-- whenever it comes up: fill it (not in combat: the buttons lock then)
board:HookScript("OnShow", function(self) if not InCombatLockdown() then self:Fill() end end)
-- the group changed (who can CC): refill
local gev = CreateFrame("Frame")
gev:RegisterEvent("GROUP_ROSTER_UPDATE")
gev:SetScript("OnEvent", function() if board:IsShown() and not InCombatLockdown() then board:Fill() end end)

-- nameplates come and go while it's open: refill (out of combat, at most every 0.2 s)
local refill
local function scheduleFill()
    if refill or not board:IsShown() then return end
    refill = true
    C_Timer.After(0.2, function() refill = nil; if board:IsShown() then board:Fill() end end)
end
-- A mob stepping out from behind a wall (or going behind one) fires no event: twice a second while
-- the board is up, see which plates are in sight, and refill when that changed (out of combat).
local losSig
function VM.SightSig()
    local t = {}
    for i = 1, 40 do
        local u = "nameplate" .. i
        t[i] = hostileMob(u) and (behindWall(u, true) == true and "h" or "s") or "-"
    end
    return table.concat(t)
end
function VM.SightTick()
    if not board:IsShown() or InCombatLockdown() then losSig = nil return end
    local s = VM.SightSig()
    if losSig and s ~= losSig then scheduleFill() end
    losSig = s
end
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(0.5, VM.SightTick) end

local bev = CreateFrame("Frame")
bev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
bev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
bev:SetScript("OnEvent", function(_, event, unit)
    -- a plate gone: its token can go to another mob right away, so that row stops pointing at it now
    -- (and forgets the marker it showed), not at the next refill (Sol review)
    if event == "NAME_PLATE_UNIT_REMOVED" and type(unit) == "string" then
        for _, row in ipairs(rows) do
            if row.unit == unit then
                row.unit, row.mark = nil, nil
                row.done:SetText("")
                if not InCombatLockdown() then
                    for _, b in ipairs(row.btns) do b:SetAttribute("macrotext", ""); b:Hide() end
                end
            end
        end
        -- and the big check stops pointing at it too (Sol: a recycled token marked the wrong mob)
        if board.applied and board.applied[unit] then
            board.applied[unit] = nil
            if not InCombatLockdown() then
                local lines = {}
                for u, mk in pairs(board.applied) do lines[#lines + 1] = ("/tm [@%s] ~%d"):format(u, mk) end
                board.apply:SetAttribute("macrotext", table.concat(lines, "\n"))
                board.apply:SetShown(#lines > 0)
            end
        end
    end
    if not InCombatLockdown() then scheduleFill() end
end)

-- The pull recorder (see "Learning from pulls" above): while a fight in a dungeon or raid goes on,
-- every 2 s the looks of the hostile nameplates in the fight are noted (level, elite and power type
-- stay readable in combat, measured 11-14); 1.5 s after it ends the meter's enemy list is read (out
-- of combat it isn't secret) and creditPull matches the two. No chat, nothing sent.
local pullLooks, pullStart, pullTick, pullSession, pullCombatSeen, pullCombatHidden
local function noteLooks()
    if not pullLooks then return end
    for _, m in ipairs(pack()) do
        local raw = UnitAffectingCombat(m.unit)
        local fighting = readable(raw)
        -- how often the game hid "in combat" (then the mob counts as in the fight): pull stats
        pullCombatSeen = (pullCombatSeen or 0) + 1
        if secret(raw) then pullCombatHidden = (pullCombatHidden or 0) + 1 end
        -- only a clear "in combat" (Sol: a hidden answer let unpulled mobs nearby in; measured
        -- 11-14 it was never hidden)
        if fighting == true and m.lvl and m.lvl > 0 and m.pt ~= nil then
            local k = looksKey(m)
            if not pullLooks[k] then
                pullLooks[k] = { lvl = m.lvl, elite = m.elite, pt = m.pt, where = m.where, sub = m.sub, inst = m.inst }
            end
        end
    end
end
-- The meter's enemies of the fight that just ended: names (nil when the meter isn't there / hidden).
-- THIS fight's session (Sol review: picking by closest length could take an older fight or the
-- whole run): the session id the meter announced during the pull, else the newest session it
-- lists, else "Current"; and its length must fit the fight (the group may pull a little earlier).
local function plausible(d, dur)
    d = readable(d)
    return type(d) == "number" and d > 0 and math.abs(d - dur) <= math.max(15, dur * 0.75)
end
local function meterEnemies(dur, sid)
    local M = C_DamageMeter
    if not M then return nil end
    local kind = Enum and Enum.DamageMeterType and Enum.DamageMeterType.EnemyDamageTaken or 10
    local sess, fp
    -- an id the meter announced during this pull is this fight's: a missing length doesn't rule it
    -- out there (it does for the others, Sol)
    local announced = sid ~= nil
    if not sid and M.GetAvailableCombatSessions then
        local ok, list = pcall(M.GetAvailableCombatSessions)
        if ok and type(list) == "table" then
            local newest
            for _, s in ipairs(list) do
                local id = readable(s.sessionID)
                if type(id) == "number" and (not newest or id > newest.id) then newest = { id = id, d = s.durationSeconds } end
            end
            if newest and plausible(newest.d, dur) then sid = newest.id end
        end
    end
    if sid and M.GetCombatSessionFromID then
        local ok, s = pcall(M.GetCombatSessionFromID, sid, kind)
        if ok and type(s) == "table" and (plausible(s.durationSeconds, dur)
            or (announced and type(readable(s.durationSeconds)) ~= "number")) then sess = s; fp = "id" .. tostring(sid) end
    end
    if not sess and M.GetCombatSessionFromType then
        local st = Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current or 1
        local ok, s = pcall(M.GetCombatSessionFromType, st, kind)
        local okd, d = pcall(M.GetSessionDurationSeconds, st)
        if ok and type(s) == "table" and okd and type(readable(d)) == "number" and plausible(d, dur) then sess = s; fp = "cur" .. tostring(readable(d)) end
    end
    if not (sess and type(sess.combatSources) == "table") then return nil end
    local list = {}
    for _, src in ipairs(sess.combatSources) do
        local ok, nm = pcall(function() return src.name end)
        nm = ok and readable(nm) or nil
        local okd, dmg = pcall(function() return src.totalAmount end)
        if type(nm) == "string" and nm ~= "" then list[#list + 1] = { name = nm, dmg = okd and readable(dmg) or nil } end
    end
    -- the same session as last time (no new one was made for this fight): its names are the last
    -- pull's, not this one's (Sol)
    for _, e in ipairs(list) do fp = fp .. "|" .. e.name .. ":" .. tostring(e.dmg) end
    if fp == VM.lastSession then return nil end
    VM.lastSession = fp
    return VM.MainEnemies(list)
end
-- The pack, without the critters an area attack caught (live 11-14, The Drowned City: Crab, Toad,
-- Snake come back "normal", and the board never shows them, so a pack had more names than looks
-- and nothing could be paired): an enemy that took under 2% of the pack's top damage is left out.
-- (A sheep takes none and isn't on the meter's list at all.)
function VM.MainEnemies(list)
    local top = 0
    for _, e in ipairs(list) do if type(e.dmg) == "number" and e.dmg > top then top = e.dmg end end
    local out = {}
    for _, e in ipairs(list) do
        if type(e.dmg) ~= "number" or top <= 0 or e.dmg >= top * 0.02 then out[#out + 1] = e.name end
    end
    return out
end
VM.MeterEnemies = meterEnemies
local pev = CreateFrame("Frame")
pev:RegisterEvent("PLAYER_REGEN_DISABLED")
pev:RegisterEvent("PLAYER_REGEN_ENABLED")
pev:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
pev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        -- (type, sessionID): the session this pull is being written to
        local id = readable(a2)
        if pullLooks and type(id) == "number" and (not pullSession or id > pullSession) then pullSession = id end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        if pullTick then pullTick:Cancel(); pullTick = nil end
        pullSession = nil
        if not inInstance() then pullLooks = nil; return end
        pullCombatSeen, pullCombatHidden = 0, 0
        pullLooks, pullStart = {}, GetTime()
        pcall(noteLooks)
        pullTick = C_Timer.NewTicker and C_Timer.NewTicker(2, function() pcall(noteLooks) end) or nil
    else
        if pullTick then pullTick:Cancel(); pullTick = nil end
        local looks, dur, sid = pullLooks, pullStart and (GetTime() - pullStart) or 0, pullSession
        -- died in it (a wipe): mobs lived, so a pack can't be told apart by who took damage
        local wiped = UnitIsDeadOrGhost and readable(UnitIsDeadOrGhost("player")) and true or false
        pullLooks, pullStart, pullSession = nil, nil, nil
        if not looks or dur < 3 then return end
        C_Timer.After(1.5, function()
            if InCombatLockdown() then return end   -- the next pull already started: the meter is secret again
            local list = {}
            for _, L in pairs(looks) do list[#list + 1] = L end
            local ok, names = pcall(meterEnemies, dur, sid)
            if ok and names then
                local okc, n = pcall(creditPull, list, names, wiped)
                VM.lastPull = { looks = #list, enemies = #names, credited = okc and n or 0 }
                -- the last 30 pulls, to check learning in the game (VoidMarkDB.pullStats)
                local st = db().pullStats or {}
                db().pullStats = st
                st[#st + 1] = { t = now(), looks = #list, enemies = #names, credited = okc and n or 0,
                    seen = pullCombatSeen, hidden = pullCombatHidden, wiped = wiped or nil }
                while #st > 30 do table.remove(st, 1) end
                if board:IsShown() and not InCombatLockdown() then board:Fill() end
            end
        end)
    end
end)

-- on a restricted map (dungeon, raid) mob names are hidden, so marking by importance can't work
local function restrictedMap()
    local R = C_RestrictedActions
    local t = (Enum and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Map) or 4
    return (R and R.IsAddOnRestrictionActive and safe(R.IsAddOnRestrictionActive, t)) and true or false
end
VM.RestrictedMap = restrictedMap
----------------------------------------------------------------------
-- Hover key (the user, 2026-11-14: "yes add the hover key"): hover a mob (or target it) and press
-- the key: it gets the next marker. Skull, X, the CC markers of the classes in your group, then the
-- other markers. The order starts over after each fight and on a zone change. Pressing again on the
-- same mob gives it the next one. Like the board it's a secure macro button ("/tm [@mouseover] 8"),
-- set in PreClick out of combat only; the game's own raid target keys work in combat.
-- (The game hides markers from addons on restricted maps, so the order can't skip markers someone
-- else already placed; a /tm moves a marker that's on another mob to this one.)
----------------------------------------------------------------------
local hover = CreateFrame("Button", "VoidMarkHover", UIParent, "SecureActionButtonTemplate")
VM.Hover = hover
hover:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
hover:SetAttribute("useOnKeyDown", false)
hover:SetAttribute("type", "macro")
hover:SetAttribute("macrotext", "")
hover:Hide()   -- a binding clicks it; it never shows

local nextIdx = 1
local function sequence()
    local list, used = { SKULL, X }, { [SKULL] = true, [X] = true }
    local have = groupClasses()
    for _, cls in ipairs(CC_ORDER) do
        local m = CC[cls][1]
        if have[cls] and not used[m] then list[#list + 1] = m; used[m] = true end
    end
    for m = 8, 1, -1 do if not used[m] then list[#list + 1] = m; used[m] = true end end
    return list
end

-- the mob to mark: the hostile one under the mouse, else your hostile target
local function hoverUnit()
    if hostileMob("mouseover") then return "mouseover" end
    if hostileMob("target") then return "target" end
end

local hoverPending
hover:SetScript("PreClick", function(self, _, down)
    if down then return end
    hoverPending = nil
    if InCombatLockdown() then
        say("in combat the game locks marking for addons: use the game's own raid target keys.")
        return
    end
    local text, why = "", nil
    local unit = hoverUnit()
    if not canMark() then
        why = "in a raid only the leader and assistants can mark (the game's rule)."
    elseif not unit then
        why = "hover over a mob (or target one), then press the key."
    else
        local seq = sequence()
        if nextIdx > #seq then nextIdx = 1 end
        local m = seq[nextIdx]
        nextIdx = nextIdx + 1
        text = ("/tm [@%s] %d"):format(unit, m)
        hoverPending = { unit = unit, marker = m, nxt = seq[nextIdx] or seq[1] }
    end
    self:SetAttribute("macrotext", text)
    if why then say(why) end
end)
hover:SetScript("PostClick", function(_, _, down)
    if down or not hoverPending then return end
    local p = hoverPending
    hoverPending = nil
    local name = readable(UnitName(p.unit))
    say(("%s on %s · next: %s"):format(icon(p.marker), name or "that mob", icon(p.nxt)))
end)

local hev = CreateFrame("Frame")
hev:RegisterEvent("PLAYER_REGEN_DISABLED")   -- just before the lock: nothing stale to run in combat
hev:RegisterEvent("PLAYER_REGEN_ENABLED")    -- a fight ended: start the order over
hev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
hev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        hover:SetAttribute("macrotext", "")
        hoverPending = nil
    else
        nextIdx = 1
    end
end)
VM.HoverReset = function() nextIdx = 1 end


local pending
btn:SetScript("PreClick", function(self, button, down)
    if down then return end
    pending = nil
    if InCombatLockdown() then
        say("in combat the game won't let an addon change what gets marked: mark before the pull.")
        return
    end
    -- a dungeon or raid hides mob names from addons: the pack board lets you pick. Right-click: the board anywhere
    if button == "RightButton" or restrictedMap() then
        if button ~= "RightButton" and db().autoDungeon then   -- the "Auto in dungeons" box
            local text, plan, why = VM:AutoMacro()
            self:SetAttribute("macrotext", text or "")
            if why then say(why) else pending = plan end
            return
        end
        self:SetAttribute("macrotext", "")
        board:Open()
        return
    end
    local text, plan, why = VM:Macro()
    self:SetAttribute("macrotext", text or "")
    if why then say(why) else pending = plan end
end)
btn:SetScript("PostClick", function(_, button, down)
    if down or not pending then return end
    local plan = pending
    pending = nil
    C_Timer.After(0.3, function()
        local parts = {}
        for _, p in ipairs(plan) do
            local idx = GetRaidTargetIndex(p.mob.unit)   -- always SECRET on Forever (SecretReturns): then trust the macro
            if secret(idx) or idx == p.marker then
                parts[#parts + 1] = ("%s %s (%s)"):format(icon(p.marker), p.mob.name or "?", p.why)
            end
        end
        if #parts == 0 then say("couldn't place a marker (the game refused).") else say(table.concat(parts, ", ")) end
    end)
end)
btn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(A[1], A[2], A[3], 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Mark the pack")
    GameTooltip:AddLine("Out in the world: Skull and X on the two mobs that matter most (healers, mana burn, crowd control first), then a crowd-control marker for each class in your group that has one.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("In a dungeon or raid the game hides mob names from addons: it opens the pack board, where you pick the marker for each mob. Right-click opens the board anywhere.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Before the pull: in combat the game locks marking for addons. Mobs that already have a marker are left alone.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Drag to move · a key: Key Bindings > AddOns > VoidMark", 0.4, 0.8, 1)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(A[1], A[2], A[3], 0.6)
    GameTooltip:Hide()
end)

local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")   -- comes just before the lock: empty the macro
combat:RegisterEvent("PLAYER_REGEN_ENABLED")
combat:RegisterEvent("PLAYER_ENTERING_WORLD")
combat:RegisterEvent("ZONE_CHANGED_NEW_AREA")
combat:RegisterEvent("ADDON_LOADED")
combat:RegisterEvent("PLAYER_LOGIN")
combat:RegisterEvent("UI_SCALE_CHANGED")
combat:RegisterEvent("DISPLAY_SIZE_CHANGED")
combat:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_REGEN_DISABLED" then
        -- comes just before the lock: empty every marker button (a nameplate can change mob mid-fight,
        -- and the game won't let us refill them), keep the board up, say why it's locked
        btn:SetAttribute("macrotext", "")
        for _, row in ipairs(rows) do
            for _, b in ipairs(row.btns) do b:SetAttribute("macrotext", "") end
        end
        board.apply:SetAttribute("macrotext", "")
        go:Refresh(true)
        board.locked:Show()
        board.empty:Hide()   -- an empty board in combat just waits: "No mobs in view" read like a fault (the user, 11-14)
        pending = nil
    elseif event == "PLAYER_REGEN_ENABLED" then
        board.locked:Hide()
        if board.syncPending then board:Sync() end
        if board:IsShown() then board:Fill() end
        go:Refresh()
        -- a pull just ended in a dungeon (credited 1.5 s after it): what it proved goes to the swarm
        local _, kind = IsInInstance()
        if kind == "party" or kind == "raid" then C_Timer.After(4, function() pcall(swReport) end) end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        board:Sync()   -- into or out of a dungeon / raid
        -- into a dungeon: ask 2 players what their pulls proved there (the swarm); out of one: what
        -- you found there may go now (it was held while you were inside)
        local _, kind = IsInInstance()
        if not (kind == "party" or kind == "raid") and VM.swInst then
            local net = swarm()
            if net then net:Release(SW, tostring(VM.swInst)) end
            VM.swInst = nil
        end
        if kind == "party" or kind == "raid" then
            C_Timer.After(5, function()
                local ok, _, _, _, _, _, _, _, id = pcall(GetInstanceInfo)
                id = ok and tonumber(readable(id))
                local net = swarm()
                if id and id > 0 then VM.swInst = id end
                if id and id > 0 and net then net:Interest(SW, tostring(id)) end
            end)
        end
    elseif event == "ADDON_LOADED" and name == ADDON then
        if ns.Move then ns.Move(btn, { db = db, key = "button" }) end
        if ns.Move then ns.Move(board, { db = db, key = "board", handle = board.bar }) end
        if ns.Move then ns.Move(go, { db = db, key = "goButton" }) end
        -- secure setup at load (also after a /reload in combat): up in dungeon and raid groups unless turned off
        board:SyncFade()
        board:Sync()
        -- once: picks learned before learning became opt-in were test clicks (the user, 11-14)
        if (db().learnV or 0) < 2 then db().learned, db().learnV = nil, 2 end
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        look(btn); look(board); look(go)
    elseif event == "PLAYER_LOGIN" then
        look(btn); look(board); look(go)   -- the UI scale is known now
        -- the swarm: the test switch (two test PCs can't reach 3 players), then everything your pulls proved
        if db().swarmTest and VoidSwarm then VoidSwarm.testNeed = 1 end
        swarm()   -- register the dungeon-mob kind before a host appears
        -- no VoidQuest: VoidDungeon runs the swarm's channel itself (VoidSwarmLink.lua)
        if ns.SwarmLink then ns.SwarmLink.Start(db()) end
        C_Timer.After(10, function() pcall(swReport) end)
        -- a key bound to the old binding (it called SetRaidTarget, which the game refuses) moves to the button
        if not InCombatLockdown() and GetBindingKey and SetBinding then
            local moved
            for _, k in ipairs({ GetBindingKey("VOIDMARK_MARK") }) do
                if k then SetBinding(k, "CLICK VoidMarkButton:LeftButton"); moved = true end
            end
            if moved and SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
        end
    end
end)

-- the key binding (Bindings.xml) and /vmark
BINDING_HEADER_VOIDMARK = "VoidDungeon: mark the pack"
_G["BINDING_NAME_CLICK VoidMarkButton:LeftButton"] = "Mark the pack by importance (older key)"
_G["BINDING_NAME_CLICK VoidMarkHover:LeftButton"] = "Mark the mob under your mouse (next marker)"
-- the fast keys (the user, 2026-11-14: "the tank is pulling quicker than i can mark"): the big green
-- check (out of combat), and each marker on the mob under your mouse or your target (in combat too)
_G["BINDING_NAME_CLICK VoidMarkApply:LeftButton"] = "Mark the pack: the green-check suggestions (between pulls)"
for i, n in ipairs({ "Skull", "X (Cross)", "Square", "Moon", "Triangle", "Diamond", "Circle", "Star" }) do
    _G["BINDING_NAME_CLICK VoidMarkBar" .. i .. ":LeftButton"] = n .. " on the mob under your mouse (or your target), in combat too"
end
_G["BINDING_NAME_CLICK VoidMarkBar9:LeftButton"] = "Take the marker off the mob under your mouse (or your target)"

SLASH_VOIDMARK1 = "/vmark"
SlashCmdList.VOIDMARK = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "forget" then
        local n = VM.Forget(false)
        say(("forgot all %d learned look%s (every dungeon)."):format(n, n == 1 and "" or "s"))
        if board:IsShown() and not InCombatLockdown() then board:Fill() end
        return
    elseif msg == "hide" or msg == "show" then
        if InCombatLockdown() then say("not in combat: try again after the fight."); return end
        db().boardOff = (msg == "hide") or nil
        board:Sync()
        say(msg == "hide" and "the board is off. /vmark show brings it back." or "the board is on: it shows in dungeon and raid groups.")
        return
    elseif msg == "swarmtest" then
        -- two test PCs can't reach the 3 players a shared answer needs: this lowers it to 1 on this PC
        db().swarmTest = not db().swarmTest or nil
        if VoidSwarm then VoidSwarm.testNeed = db().swarmTest and 1 or nil end
        say(db().swarmTest and "swarm test mode ON: one other player's answer counts (testing only; /vmark swarmtest again turns it off)."
            or "swarm test mode off: a shared answer needs 3 players again.")
        return
    elseif msg:match("^swarmask ") then
        -- test: ask one named player for a dungeon's looks ("/vmark swarmask 129 Ana Brightwood")
        local id, who = msg:match("^swarmask (%d+) (.+)$")
        local net = swarm()
        if not (id and who and net) then say("/vmark swarmask <dungeon id> <player name>"); return end
        -- the name as the game writes it (the command line was lowercased)
        who = who:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end)
        net:Interest(SW, id, who)
        say(("asked %s about dungeon %s."):format(who, id))
        return
    elseif msg == "swarm" then
        local net = swarm()
        if not net then say("no swarm (VoidSwarm isn't loaded)."); return end
        local reported = swReport()
        local st, pieces, keys, confirmed, pending = net:Stats(), 0, 0, 0, 0
        local spec = net.kinds[SW]
        for piece, p in pairs(spec and spec.store or {}) do
            pieces = pieces + 1
            for key in pairs(p) do
                keys = keys + 1
                local v, _, own = net:Get(SW, piece, key)
                if v and not own then confirmed = confirmed + 1 elseif not v then pending = pending + 1 end
            end
        end
        say(("swarm: %s; %d dungeons, %d looks (%d yours, %d confirmed by others, %d waiting); sent %d, got %d, confirmed %d%s."):format(
            VoidSwarm.net and "on VoidQuest's network" or "this PC only (needs VoidQuest)", pieces, keys, reported, confirmed, pending,
            st.sent, st.got, st.confirmed, VoidSwarm.testNeed and ", TEST MODE (1 player counts)" or ""))
        return
    elseif msg == "why" then
        if not hostileMob("target") then say("target a mob first."); return end
        local s, role, spell = importance("target")
        say(("%s: %s%s (score %d)"):format(UnitName("target") or "?", role or "nothing special seen yet",
            spell and (", seen casting " .. spell) or "", s))
    else
        local n = 0
        for _ in pairs(db().mobs) do n = n + 1 end
        say(("%d mob types learned. Mark with the Mark button (shown in a group) or a key (Key Bindings > AddOns > VoidMark): a typed command can't place markers. /vmark why = why your target ranks where it does."):format(n))
    end
end

----------------------------------------------------------------------
-- Tooltip: what a mob is known for
----------------------------------------------------------------------
local function onUnitTooltip(tt)
    if tt ~= GameTooltip then return end
    local _, unit = tt:GetUnit()
    if not unit or not hostileMob(unit) then return end
    local _, role, spell = importance(unit)
    if not role then return end
    local color = "|cffbbbbff"
    for _, kd in pairs(KIND) do if kd.role == role then color = kd.color end end
    tt:AddLine(("|cff00c7ffVoidMark:|r %s%s|r%s"):format(color, role, spell and (" (" .. spell .. ")") or ""))
    tt:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt) pcall(onUnitTooltip, tt) end)
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED", "NAME_PLATE_UNIT_ADDED" }) do
    ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function(_, event, unit, a2, a3)
    if type(unit) ~= "string" or secret(unit) then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        if hostileMob(unit) then
            local npc = npcOf(unit)
            if npc then pcall(mobRec, npc, unit) end
        end
        return
    end
    if not (unit:find("^nameplate") or unit == "target" or unit == "focus") then return end
    -- START / CHANNEL_START: (unit, castGUID, spellID); SUCCEEDED: the same
    pcall(sawCast, unit, a3)
end)

----------------------------------------------------------------------
-- The Void hub (the user, 2026-11-14: "is voiddungeon built into maps, if not i dont see it in the
-- hub"): VoidDungeon had no hub entry. A launcher opens the dungeon view (/vdungeon), and a switch
-- turns the marking board on or off (the same as /vmark show / hide).
----------------------------------------------------------------------
VoidHubLaunchers = VoidHubLaunchers or {}
VoidHubLaunchers.VoidDungeon = {
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    onClick = function() if SlashCmdList.VOIDDUNGEON then SlashCmdList.VOIDDUNGEON("") end end,
}
VoidHubToggles = VoidHubToggles or {}
table.insert(VoidHubToggles, {
    id = "VoidDungeon.markBoard", group = "Dungeons", label = "Marking board",
    tip = "In dungeon and raid groups: the board of the mobs in front of you, with green checks on the ones that matter and a marker per mob.",
    get = function() return not db().boardOff end,
    set = function(on) db().boardOff = (not on) or nil; board:Sync() end,
    noCombat = true,
})
table.insert(VoidHubToggles, {
    id = "VoidDungeon.share", group = "Dungeons", label = "Share fight results",
    tip = "WoW Forever: which mob each look turned out to be (\"Seen in other players' fights here\") is shared with other Void players, and theirs with you. Off: nothing is sent or taken; only your own pulls count.",
    get = function() return not db().shareOff end,
    set = function(on) db().shareOff = (not on) or nil end,
})
