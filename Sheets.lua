----------------------------------------------------------------------
-- Sheets.lua — the boss card: when a boss fight starts in a WoW Forever dungeon, a small card
-- shows the boss's short version and the tip for your role (the user, 2026-11-15: "fold the
-- sheet part of forever into the dungeon guide with a box for the popup in game dungeon"; it was
-- VoidCheatSheet's pull pop-up, VoidCheatSheet is retail only now).
--   Data: Data/Sheets.lua (ns.Sheets). The full notes are the Tips tab (Side.lua).
--   On / off: the "Boss card when a fight starts" box at the top of the Tips tab
--     (VoidDungeonDB.bossCard, on unless turned off), or the card's own x + "turn off".
--   The card: drag it anywhere (kept, ns.Move); "Tips" opens the dungeon's tips (after the fight
--   when you're in one: the map can't open safely mid-fight); it goes 3 s after the fight.
----------------------------------------------------------------------
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end   -- WoW Forever only
local _, ns = ...
local J = ns.J
local A = J.A
local SH = {}
ns.SheetCard = SH

local function secret(v) return issecretvalue and issecretvalue(v) end
local function key(s) return ((s or ""):lower():gsub("[%s%-']", "")) end

function SH:On() return not (VoidDungeonDB and VoidDungeonDB.bossCard == false) end
function SH:Set(on)
    VoidDungeonDB = VoidDungeonDB or {}
    VoidDungeonDB.bossCard = on and true or false
    J:Print(on and "boss card on: it shows when a boss fight starts." or "boss card off (turn it back on at the top of the Tips tab).")
    if not on and SH.card then SH.card:Hide() end
    if ns.Side and ns.Side.Refresh then ns.Side:Refresh() end
end

-- the sheet of a fight: by the encounter id the game sends, else by its name
function SH:BossOf(encounterID, name)
    local D = ns.Sheets
    if not D then return nil end
    local b = encounterID and not secret(encounterID) and D.byEncounterID[encounterID]
    if b then return b end
    if type(name) ~= "string" or secret(name) then return nil end
    return D.byExactName[name] or D.byName[key(name)]
end

local function role()
    -- WoW Forever: the spec API lies; the group role is what counts ("NONE" = damage)
    local r = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if r == "TANK" then return "tank", "Tank" end
    if r == "HEALER" then return "healer", "Healer" end
    return "dps", "DPS"
end

local function px()   -- one screen pixel (feedback-pixel-perfect-borders)
    local s = UIParent and UIParent:GetEffectiveScale()
    if s and s > 0 and PixelUtil and PixelUtil.GetPixelToUIUnitFactor then return PixelUtil.GetPixelToUIUnitFactor() / s end
    return 1
end

local pendingOpen   -- "Tips" clicked mid-fight: open once it's over

local function openTips()
    if InCombatLockdown() then
        pendingOpen = true
        J:Print("the tips open when the fight is over.")
        return
    end
    pendingOpen = nil
    VoidDungeonDB = VoidDungeonDB or {}
    VoidDungeonDB.tab = "Tips"
    local d = J.CurrentDungeon and J:CurrentDungeon()
    J:Open(d)
end

local function card()
    if SH.card then return SH.card end
    local f = CreateFrame("Frame", "VoidDungeonBossCard", UIParent, "BackdropTemplate")
    f:SetSize(330, 90)
    f:SetPoint("TOP", 0, -120)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = px() })
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.94)
    f:SetBackdropBorderColor(A[1], A[2], A[3], 0.7)
    f.title = J.text(f, 12, "OUTLINE")
    f.title:SetPoint("TOPLEFT", 10, -8)
    f.title:SetPoint("RIGHT", -60, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetTextColor(A[1], A[2], A[3])
    local x = J.button(f, "x", function() f:Hide() end)
    x:SetPoint("TOPRIGHT", -6, -6)
    local tips = J.button(f, "Tips", openTips)
    tips:SetPoint("RIGHT", x, "LEFT", -4, 0)
    f.body = J.text(f, 11)
    f.body:SetPoint("TOPLEFT", 10, -28)
    f.body:SetWidth(310)
    f.body:SetJustifyH("LEFT")
    f.body:SetWordWrap(true)
    f.foot = J.text(f, 10)
    f.foot:SetPoint("BOTTOMLEFT", 10, 7)
    f.foot:SetTextColor(0.5, 0.5, 0.55)
    f.foot:SetText("Drag to move · x: close · the box at the top of Tips turns it off")
    if ns.Move then ns.Move(f, { db = function() return VoidDungeonDB end, key = "bossCard" }) end
    f:Hide()
    SH.card = f
    return f
end

-- the card for a boss sheet (also a test: /vdungeon card)
function SH:Show(b)
    if not b then return false end
    local f = card()
    local rk, rl = role()
    f.title:SetText(b.name or "?")
    local lines = {}
    if b.tldr then lines[#lines + 1] = b.tldr end
    if b[rk] and b[rk] ~= "" then lines[#lines + 1] = ("|cff33ff33%s:|r %s"):format(rl, b[rk]) end
    f.body:SetText(table.concat(lines, "\n\n"))
    -- the game draws more per line than GetStringHeight says (seen in VoidProf): a little room
    f:SetHeight(math.floor((f.body:GetStringHeight() or 40) * 1.15 + 52))
    f:Show()
    return true
end

----------------------------------------------------------------------
-- Fights
----------------------------------------------------------------------
local inFight = 0   -- counts a start, so a quick next pull isn't hidden by the last one's end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ENCOUNTER_START")
ev:RegisterEvent("ENCOUNTER_END")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, encounterID, name)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingOpen then pcall(openTips) end
        return
    end
    local _, kind = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then return end
    if event == "ENCOUNTER_START" then
        inFight = inFight + 1
        if not SH:On() then return end
        local b = SH:BossOf(encounterID, name)
        if b then pcall(SH.Show, SH, b) end
    else
        local mine = inFight + 0
        C_Timer.After(3, function()
            if inFight == mine and SH.card then SH.card:Hide() end
        end)
    end
end)

-- the Void hub's quick box (same switch as the Tips tab's box)
VoidHubToggles = VoidHubToggles or {}
table.insert(VoidHubToggles, {
    id = "VoidDungeon.bossCard", group = "Dungeons", label = "Boss card",
    tip = "When a boss fight starts in a dungeon: a small card with the boss's short version and the tip for your role.",
    get = function() return SH:On() end,
    set = function(on) SH:Set(on) end,
})
