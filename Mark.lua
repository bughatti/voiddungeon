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
        if hostileMob(u) then
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

-- The dungeon list (Seed.lua, tools/cmd/vmark-seed from the CMaNGOS classic database; the user,
-- 2026-11-14: "its just data to mark high importance mobs over others"): every mob of this dungeon
-- with the same elite flag and power type whose level range holds this level. -> average score of
-- those (healer 100, mana burn 85, CC 60, summoner 50, caster 20...), their names, how many.
local function seedOf(m)
    local list = VM.Seed and m and m.inst and VM.Seed[m.inst]
    if not list or not m.lvl or m.lvl <= 0 then return nil end
    local sum, n, names = 0, 0, {}
    for _, e in ipairs(list) do
        if e[3] == m.elite and e[4] == m.pt and m.lvl >= e[1] and m.lvl <= e[2] then
            sum, n = sum + e[5], n + 1
            if #names < 4 then names[#names + 1] = e[8] .. (e[7] ~= "" and (" (" .. e[7] .. ")") or "") end
        end
    end
    if n == 0 then return nil end
    return math.floor(sum / n + 0.5), names, n
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
        if m.seedNames then
            GameTooltip:AddLine(("Probably: %s%s"):format(table.concat(m.seedNames, ", "),
                (m.seedN or 0) > #m.seedNames and (" (+%d more)"):format(m.seedN - #m.seedNames) or ""), 1, 1, 1, true)
            GameTooltip:AddLine("From the dungeon's mob list, by level, elite and mana / rage (the game hides the name from addons).", 0.6, 0.6, 0.6, true)
        else
            GameTooltip:AddLine("Not in the dungeon list (a new WoW Forever dungeon, or a level we don't know).", 0.6, 0.6, 0.6, true)
        end
        if m.sugg then
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
        if hostileMob(u) then
            local cls = readable(UnitClassification(u))
            if cls ~= "minus" and cls ~= "trivial" then
                list[#list + 1] = { unit = u, lvl = readable(UnitLevel(u)) or 0,
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
    -- learned picks first (the board teaches them), the caster rule for the rest
    local pre, taken = {}, {}
    for _, m in ipairs(list) do
        local s = suggest(m)
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
    for i = 1, math.min(#mobs, ROWS) do
        local m = mobs[i]
        local s = suggest(m)
        if s == 0 then
            m.skip = true   -- learned: leave it unmarked
        elseif s and not taken[s] then
            m.sugg, m.from, taken[s] = s, "learned", true
        end
        m.seed, m.seedNames, m.seedN = seedOf(m)
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
    say(("marked %d mob%s as learned."):format(n, n == 1 and "" or "s"))
end)

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
    else
        UnregisterStateDriver(self, "visibility")
        self:Hide()
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
        board.locked:Show()
        board.empty:Hide()   -- an empty board in combat just waits: "No mobs in view" read like a fault (the user, 11-14)
        pending = nil
    elseif event == "PLAYER_REGEN_ENABLED" then
        board.locked:Hide()
        if board.syncPending then board:Sync() end
        if board:IsShown() then board:Fill() end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        board:Sync()   -- into or out of a dungeon / raid
    elseif event == "ADDON_LOADED" and name == ADDON then
        if ns.Move then ns.Move(btn, { db = db, key = "button" }) end
        if ns.Move then ns.Move(board, { db = db, key = "board", handle = board.bar }) end
        -- secure setup at load (also after a /reload in combat): up in dungeon and raid groups unless turned off
        board:SyncFade()
        board:Sync()
        -- once: picks learned before learning became opt-in were test clicks (the user, 11-14)
        if (db().learnV or 0) < 2 then db().learned, db().learnV = nil, 2 end
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        look(btn); look(board)
    elseif event == "PLAYER_LOGIN" then
        look(btn); look(board)   -- the UI scale is known now
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
