----------------------------------------------------------------------
-- Handout.lua — BoE drops from your farm runs, handed out to your guild.
--
-- The user, 2026-11-13, farming Deadmines for Cookie's drop: "I do have a lot of BoE drops ...
-- being able to send a message in guild who wants this, and then ... once I get done farming,
-- this goes to this person, this goes to that person."
--
--   * Every bind-on-equip item (uncommon or better) you loot goes on a list (this character).
--   * "Ask the guild" posts them in guild chat with links; guildies with VoidDungeon also get a
--     small box with a Want button per item. A whisper with the item's link (or "want" when only
--     one item is offered) counts too.
--   * You pick who gets each item (the BoE tab: click an item).
--   * At a mailbox VoidDungeon fills one mail per person with their items; you press Send.
--
-- Addon messages (prefix VDBOE): O|id,id,...|zone  (to GUILD: an offer)   W|id  (whisper: I want it)
----------------------------------------------------------------------
local _, ns = ...
local J = ns.J
local H = {}
ns.Handout = H
J.Handout = H

local PREFIX = "VDBOE"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end

local function cdb()
    VoidDungeonCharDB = VoidDungeonCharDB or {}
    VoidDungeonCharDB.boe = VoidDungeonCharDB.boe or {}
    return VoidDungeonCharDB.boe
end
local function short(name) return Ambiguate and Ambiguate(name or "?", "short") or name end
local function changed() if ns.Side and ns.Side.Refresh then ns.Side:Refresh() end end
local function idOf(link) return link and tonumber(link:match("|Hitem:(%d+)")) end

----------------------------------------------------------------------
-- Recording what you loot
----------------------------------------------------------------------
local function pattern(fmt)
    if not fmt then return nil end
    fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    fmt = fmt:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. fmt .. "$"
end
local SELF = pattern(LOOT_ITEM_SELF or "You receive loot: %s.")
local SELF_N = pattern(LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.")

local function zoneName()
    local name = GetInstanceInfo()
    return name or GetRealZoneText() or "?"
end

-- bind-on-equip and uncommon or better: true / false, or nil while the item isn't loaded
local function isBoE(link)
    local _, _, q, _, _, _, _, _, _, _, _, _, _, bind = C_Item.GetItemInfo(link)
    if not q then return nil end
    return bind == 2 and q >= 2
end

-- an item and its random suffix ("of the Bear" / "of the Owl" share an item id): the item string
-- up to the suffix, so two different greens never merge and the mail takes the one offered (Sol review)
local function linkKey(link)
    local s = link and link:match("|H(item:[^|]+)|h")
    if not s then return nil end
    local f = { strsplit(":", s) }
    return table.concat(f, ":", 1, math.min(#f, 8))
end
H.linkKey = linkKey

local function add(link, n)
    local id, k = idOf(link), linkKey(link)
    if not id then return end
    local list = cdb()
    for _, it in ipairs(list) do
        -- only into a copy still up for grabs: not given, sent or kept (Sol review)
        if (it.key or it.id) == (k or id) and not it.to and not it.sent and not it.keep then
            it.n = it.n + n
            changed()
            return
        end
    end
    -- ref: this entry's own number, so an offer and a Want point at it, suffix and all (Sol review)
    VoidDungeonCharDB.boeRef = (VoidDungeonCharDB.boeRef or 0) + 1
    list[#list + 1] = { id = id, key = k, ref = VoidDungeonCharDB.boeRef, link = link, n = n, at = time(), zone = zoneName(), claims = {} }
    changed()
end

local function onLoot(msg)
    local link, n = msg:match(SELF_N or "^$")
    if not link then link = msg:match(SELF or "^$"); n = 1 end
    if not link then return end
    -- just the link (Forever's line has no period, other locales may add text around it)
    link = link:match("(|c[^|]+|Hitem:[^|]+|h%[.-%]|h|r)") or link
    n = tonumber(n) or 1
    local boe = isBoE(link)
    if boe then
        add(link, n)
    elseif boe == nil then   -- not loaded yet: look again in a moment
        C_Timer.After(1.5, function() if isBoE(link) then add(link, n) end end)
    end
end

----------------------------------------------------------------------
-- Asking the guild
----------------------------------------------------------------------
-- the items still up for grabs (not given, not sent, not kept)
function H:Open()
    local out = {}
    for _, it in ipairs(cdb()) do
        if not it.to and not it.sent and not it.keep then out[#out + 1] = it end
    end
    return out
end

function H:AskGuild()
    if not IsInGuild() then J:Print("You're not in a guild."); return end
    local open = self:Open()
    if #open == 0 then J:Print("Nothing to offer: every BoE on your list has someone (or is kept)."); return end
    local zones, ids = {}, {}
    for _, it in ipairs(open) do
        zones[it.zone] = true
        -- ref:item:suffix (the suffix only when there is one: "of the Owl")
        local suffix = it.key and tonumber(select(8, strsplit(":", it.key)) or "")
        ids[#ids + 1] = (it.ref or 0) .. ":" .. it.id .. ((suffix and suffix ~= 0) and (":" .. suffix) or "")
    end
    local zone = next(zones)
    if next(zones, zone) then zone = "my runs" end
    local lines, line = {}, ("BoE from %s, free to guildies: whisper me the item you want:"):format(zone == "my runs" and zone or ("my " .. zone .. " run"))
    for _, it in ipairs(open) do
        local part = " " .. it.link .. (it.n > 1 and ("x" .. it.n) or "")
        if #line + #part > 250 then lines[#lines + 1] = line; line = "More BoE:" end
        line = line .. part
    end
    lines[#lines + 1] = line
    for i, l in ipairs(lines) do C_Timer.After((i - 1) * 0.5, function() SendChatMessage(l, "GUILD") end) end
    -- guildies with VoidDungeon get a box with Want buttons (ids only: the box shows names itself)
    -- whole ids only: a cut one would be a different item (Sol review)
    local list = ""
    for _, id in ipairs(ids) do
        local add1 = (list == "" and "" or ",") .. id
        if #list + #add1 > 225 then break end
        list = list .. add1
    end
    local msg = "O|" .. list .. "|" .. zone:sub(1, 20)
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD")
    for _, it in ipairs(open) do it.asked = time() end
    changed()
end

-- a claim from someone: by item id
-- match: function(it) -> this is the one wanted (by its ref, or by a whispered link's suffix)
local function claim(match, who)
    for _, it in ipairs(cdb()) do
        -- the copy still up for grabs, not one already given or kept (Sol review)
        if match(it) and not it.sent and not it.to and not it.keep then
            if not it.claims[who] then
                it.claims[who] = time()
                J:Print(("%s wants %s. Pick who gets it on the BoE tab."):format(short(who), it.link))
            end
            changed()
            return true
        end
    end
end

local function onWhisper(msg, sender)
    local open = H:Open()
    local asked = false
    for _, it in ipairs(open) do if it.asked then asked = true end end
    if not asked then return end   -- only after you asked
    local any = false
    -- a whispered link: the copy with that very suffix ("of the Owl", not "of the Bear")
    for link in msg:gmatch("|c[^|]+|Hitem:[^|]+|h.-|h|r") do
        local id, k = idOf(link), linkKey(link)
        if claim(function(it) return it.id == id and (not it.key or not k or it.key == k) end, sender) then any = true end
    end
    if not any and #open == 1 and (" " .. msg:lower() .. " "):find("[^%a]want[^%a]") then
        local only = open[1]
        claim(function(it) return it == only end, sender)
    end
end

----------------------------------------------------------------------
-- Guildies' side: an offer box with Want buttons
----------------------------------------------------------------------
local offerBox
local function showOffer(from, ids, zone)
    if not offerBox then
        local f = CreateFrame("Frame", "VoidDungeonOffer", UIParent, "BackdropTemplate")
        f:SetSize(300, 60)
        f:SetPoint("TOP", 0, -160)
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.07, 0.07, 0.09, 0.96)
        f:SetBackdropBorderColor(J.A[1], J.A[2], J.A[3], 0.7)
        f.title = J.text(f, 11, "OUTLINE")
        f.title:SetPoint("TOPLEFT", 10, -8)
        f.title:SetPoint("RIGHT", -28, 0)
        f.title:SetTextColor(J.A[1], J.A[2], J.A[3])
        local x = J.button(f, "x", function() f:Hide() end)
        x:SetPoint("TOPRIGHT", -6, -6)
        f.rows = {}
        f:EnableMouse(true)
        if ns.Move then ns.Move(f, { db = function() return VoidDungeonDB end, key = "boeOffer" }) end
        offerBox = f
    end
    local f = offerBox
    f.title:SetText(("%s offers BoE from %s"):format(short(from), zone))
    for _, r in ipairs(f.rows) do r:Hide() end
    local shown = 0
    for i, o in ipairs(ids) do
        local id = o.id
        if i > 10 then break end
        local r = f.rows[i]
        if not r then
            r = CreateFrame("Button", nil, f)
            r:SetHeight(20)
            r:SetPoint("TOPLEFT", 8, -28 - (i - 1) * 22)
            r:SetPoint("RIGHT", -8, 0)
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(16, 16)
            r.icon:SetPoint("LEFT")
            r.name = J.text(r, 11)
            r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
            r.name:SetPoint("RIGHT", -64, 0)
            r.name:SetWordWrap(false)
            r.want = J.button(r, "Want", function(b)
                pcall(C_ChatInfo.SendAddonMessage, PREFIX, "W|" .. b.ref, "WHISPER", b.from)
                b:SetLabel("Asked")
            end)
            r.want:SetPoint("RIGHT")
            r:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                -- with its suffix: "of the Owl" shows the Owl stats (Sol review)
                if self.itemString then GameTooltip:SetHyperlink(self.itemString) else GameTooltip:SetItemByID(self.id) end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.rows[i] = r
        end
        local name, q, icon = J:Item(id)
        -- the suffixed name ("Green Sword of the Owl") when the offer carried a suffix
        local itemString = o.suffix and o.suffix ~= 0 and ("item:" .. id .. ":0:0:0:0:0:" .. o.suffix) or nil
        local sName = itemString and C_Item.GetItemInfo(itemString)
        if sName then name = sName end
        local c = ITEM_QUALITY_COLORS[q or 1] or { r = 1, g = 1, b = 1 }
        r.id, r.itemString, r.want.ref, r.want.from = id, itemString, o.ref, from
        r.icon:SetTexture(icon)
        r.name:SetText(name or ("item " .. id))
        r.name:SetTextColor(c.r, c.g, c.b)
        r.want:SetLabel("Want")
        r:Show()
        shown = i
    end
    f:SetHeight(36 + shown * 22)
    f:Show()
end

----------------------------------------------------------------------
-- Picking who gets it
----------------------------------------------------------------------
function H:Menu(owner, it)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(it.link)
        local names = {}
        for who, t in pairs(it.claims) do names[#names + 1] = { who, t } end
        table.sort(names, function(a, b) return a[2] < b[2] end)
        if #names == 0 then root:CreateTitle("Nobody asked for it yet") end
        for _, w in ipairs(names) do
            root:CreateButton("Give to " .. short(w[1]) .. (it.to == w[1] and "  (chosen)" or ""), function()
                it.to, it.keep = w[1], nil
                changed()
            end)
        end
        root:CreateButton("Give to someone else...", function() H:AskName(it) end)
        if it.to then root:CreateButton("Not decided yet", function() it.to = nil; changed() end) end
        root:CreateButton(it.keep and "Offer it again" or "Keep it (off the list)", function()
            it.keep = not it.keep or nil
            if it.keep then it.to = nil end
            changed()
        end)
        root:CreateButton("Remove from the list", function()
            for i, x in ipairs(cdb()) do if x == it then table.remove(cdb(), i); break end end
            changed()
        end)
    end)
end

StaticPopupDialogs["VOIDDUNGEON_BOE_NAME"] = {
    text = "Who gets %s?",
    button1 = OKAY, button2 = CANCEL,
    hasEditBox = true,
    OnAccept = function(self, it)
        local eb = self.editBox or self.EditBox
        local name = eb and strtrim(eb:GetText() or "")
        if name and name ~= "" then it.to = name; it.keep = nil; changed() end
    end,
    EditBoxOnEnterPressed = function(self)
        local p = self:GetParent()
        StaticPopupDialogs["VOIDDUNGEON_BOE_NAME"].OnAccept(p, p.data)
        p:Hide()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
function H:AskName(it) StaticPopup_Show("VOIDDUNGEON_BOE_NAME", it.link, nil, it) end

----------------------------------------------------------------------
-- The mailbox: one mail per person, you press Send
----------------------------------------------------------------------
-- who still has items to be sent: { [name] = { it, ... } } in list order
local function toMail()
    local per, order = {}, {}
    for _, it in ipairs(cdb()) do
        if it.to and not it.sent then
            if not per[it.to] then per[it.to] = {}; order[#order + 1] = it.to end
            table.insert(per[it.to], it)
        end
    end
    return per, order
end

-- the bag slot of this very item (same suffix as offered), not one already picked for this mail
local function findInBags(it, skip)
    for bag = 0, tonumber(NUM_BAG_SLOTS) or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == it.id and not (skip[bag .. ":" .. slot]) and not info.isLocked then
                local link = C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)
                if not it.key or not link or linkKey(link) == it.key then return bag, slot end
            end
        end
    end
end

local pendingMail   -- { name, items = { it, ... } } waiting for MAIL_SEND_SUCCESS
local mailBox
local function refreshMailBox()
    if not mailBox then return end
    local per, order = toMail()
    local name = order[1]
    if not name then
        mailBox.text:SetText("Every BoE on your list has been sent.")
        mailBox.go:Hide()
        return
    end
    local n = 0
    for _, it in ipairs(per[name]) do n = n + it.n end
    mailBox.text:SetText(("%d to mail. Next: %s, %d item%s."):format(#order, short(name), n, n == 1 and "" or "s"))
    mailBox.go.name = name
    mailBox.go:Show()
end

function H:FillMail(name)
    if InCombatLockdown() then return end
    local per = toMail()
    local items = per[name]
    if not items then return end
    if MailFrameTab_OnClick then MailFrameTab_OnClick(nil, 2) end
    -- a mail you were already writing: never send its items, gold or C.O.D. along (Sol review)
    local max = tonumber(ATTACHMENTS_MAX_SEND) or 12
    for i = 1, max do
        if HasSendMailItem and HasSendMailItem(i) then
            J:Print("The mail you're writing already has items in it: take them out (or send it) first.")
            return
        end
    end
    if SendMailFrame_Reset then SendMailFrame_Reset() end   -- name, subject, gold, C.O.D.
    ClearCursor()
    SendMailNameEditBox:SetText(name)
    local zone = items[1].zone or "my run"
    SendMailSubjectEditBox:SetText(("BoE from %s"):format(zone):sub(1, 60))
    if SendMailNameEditBox.ClearFocus then SendMailNameEditBox:ClearFocus() end
    -- what really went in, per list entry (one over the 12 slots or not in the bags stays on the list)
    local slot, used, attached = 1, {}, {}
    for _, it in ipairs(items) do
        local got = 0
        for _ = 1, it.n do
            if slot > max then break end
            local bag, bs = findInBags(it, used)
            if bag then
                used[bag .. ":" .. bs] = true
                C_Container.PickupContainerItem(bag, bs)
                ClickSendMailItemButton(slot)
                slot = slot + 1
                got = got + 1
            end
        end
        if got > 0 then attached[#attached + 1] = { it = it, n = got } end
    end
    ClearCursor()
    if slot == 1 then
        J:Print("Those items aren't in your bags (sold, banked or already sent?). Clear them on the BoE tab.")
        return
    end
    pendingMail = { name = name, items = attached }
    J:Print(("Mail to %s is ready: check it and press Send."):format(short(name)))
end

-- What really went out: the recipient and attachments at the moment Send was pressed. A mail
-- changed by hand (another name, an item taken out) only marks what it really carried (Sol review).
local sentNow
if hooksecurefunc and SendMail then
    hooksecurefunc("SendMail", function(recipient)
        -- counted by item + suffix when the game gives the attachment's link, else by item id
        local ids = {}
        for i = 1, tonumber(ATTACHMENTS_MAX_SEND) or 12 do
            if HasSendMailItem and HasSendMailItem(i) then
                local _, id = GetSendMailItem(i)
                local link = GetSendMailItemLink and GetSendMailItemLink(i)
                local k = link and linkKey(link)
                if k then ids[k] = (ids[k] or 0) + 1 end
                if id then ids["id:" .. id] = (ids["id:" .. id] or 0) + 1 end
            end
        end
        sentNow = { name = recipient, ids = ids, byLink = GetSendMailItemLink ~= nil }
    end)
end
local function sameName(a, b)
    return a and b and short(a):lower() == short(b):lower()
end
local function markSent()
    local p, s = pendingMail, sentNow
    pendingMail, sentNow = nil, nil
    if not (p and s) then return end
    if not sameName(p.name, s.name) then
        J:Print(("That mail went to %s, not %s: nothing marked as sent."):format(tostring(s.name), short(p.name)))
        return
    end
    local done = {}
    for _, a in ipairs(p.items) do
        local k = (s.byLink and a.it.key) or ("id:" .. a.it.id)
        local n = math.min(a.n, s.ids[k] or 0)
        s.ids[k] = (s.ids[k] or 0) - n
        if n >= a.it.n then
            a.it.sent = time()
        elseif n > 0 then
            a.it.n = a.it.n - n   -- the rest still has to go
        end
        if n > 0 then done[#done + 1] = a.it.link .. (n > 1 and ("x" .. n) or "") end
    end
    J:Print(("Sent to %s: %s."):format(short(p.name), #done > 0 and table.concat(done, ", ") or "nothing from the list"))
end

local function buildMailBox()
    if mailBox or not MailFrame then return end
    local f = CreateFrame("Frame", "VoidDungeonMailBoE", MailFrame, "BackdropTemplate")
    f:SetSize(260, 64)
    f:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 6, -40)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.07, 0.07, 0.09, 0.96)
    f:SetBackdropBorderColor(J.A[1], J.A[2], J.A[3], 0.7)
    local t = J.text(f, 11, "OUTLINE")
    t:SetPoint("TOPLEFT", 8, -6)
    t:SetTextColor(J.A[1], J.A[2], J.A[3])
    t:SetText("VoidDungeon: BoE to mail")
    f.text = J.text(f, 10)
    f.text:SetPoint("TOPLEFT", 8, -22)
    f.text:SetPoint("RIGHT", -8, 0)
    f.text:SetWordWrap(true)
    f.go = J.button(f, "Fill the next mail", function(b) H:FillMail(b.name) end)
    f.go:SetPoint("BOTTOMLEFT", 8, 6)
    f:EnableMouse(true)
    if ns.Move then ns.Move(f, { db = function() return VoidDungeonDB end, key = "boeMail" }) end
    mailBox = f
end

----------------------------------------------------------------------
-- The BoE tab (Side.lua draws the rows)
----------------------------------------------------------------------
local A = J.A
function H:Entries(out)
    local list = cdb()
    out[#out + 1] = { head = "BoE from your runs" }
    if #list == 0 then
        out[#out + 1] = { text = "Bind-on-equip items you loot (green or better) show up here. Then ask your guild who wants them, pick who gets each, and mail them from any mailbox in a few clicks.", r = 0.7, g = 0.7, b = 0.75, wrap = true }
        return
    end
    local open = #self:Open()
    if open > 0 then
        out[#out + 1] = { text = ("Ask the guild who wants them (%d item%s)"):format(open, open == 1 and "" or "s"), r = A[1], g = A[2], b = A[3], click = function() H:AskGuild() end }
    end
    for _, it in ipairs(list) do
        local name, q, icon = J:Item(it.id)
        local c = ITEM_QUALITY_COLORS[q or 2] or { r = 1, g = 1, b = 1 }
        local wants = 0
        for _ in pairs(it.claims) do wants = wants + 1 end
        local right = it.sent and "|cff33ff33sent|r" or it.to and ("|cffffd200-> " .. short(it.to) .. "|r")
            or it.keep and "|cff8c8c9ekept|r" or (wants > 0 and ("|cff00c7ff" .. wants .. " want|r")) or (it.asked and "|cff8c8c9easked|r" or "")
        out[#out + 1] = { text = (name or it.link) .. (it.n > 1 and (" x" .. it.n) or ""), r = c.r, g = c.g, b = c.b, icon = icon, item = it.id,
            right = right, menu = function(owner) H:Menu(owner, it) end, click = function(owner) H:Menu(owner, it) end }
    end
    local _, order = toMail()
    if #order > 0 then
        out[#out + 1] = { text = ("%d to mail: at a mailbox, VoidDungeon fills one mail per person; you press Send."):format(#order), r = 0.7, g = 0.7, b = 0.75, wrap = true }
    end
    out[#out + 1] = { text = "Clear sent and kept items", r = 0.7, g = 0.7, b = 0.75, click = function()
        local keep = {}
        for _, it in ipairs(list) do if not (it.sent or it.keep) then keep[#keep + 1] = it end end
        VoidDungeonCharDB.boe = keep
        changed()
    end }
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_LOOT")
ev:RegisterEvent("CHAT_MSG_WHISPER")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("MAIL_SHOW")
ev:RegisterEvent("MAIL_CLOSED")
ev:RegisterEvent("MAIL_SEND_SUCCESS")
ev:RegisterEvent("MAIL_FAILED")
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
    if event == "CHAT_MSG_LOOT" then
        if type(a1) == "string" then onLoot(a1) end
    elseif event == "CHAT_MSG_WHISPER" then
        if type(a1) == "string" and type(a2) == "string" then onWhisper(a1, a2) end
    elseif event == "CHAT_MSG_ADDON" then
        if a1 ~= PREFIX or type(a2) ~= "string" or not a4 then return end
        local mine = UnitName("player")
        if short(a4) == mine then return end
        local kind, b, c = strsplit("|", a2)
        if kind == "O" and a3 == "GUILD" then
            local ids = {}
            for part in (b or ""):gmatch("[^,]+") do
                local ref, id, suffix = part:match("^(%d+):(%d+):?(%-?%d*)$")
                if ref then ids[#ids + 1] = { ref = tonumber(ref), id = tonumber(id), suffix = tonumber(suffix) } end
            end
            if #ids > 0 then showOffer(a4, ids, c or "a run") end
        elseif kind == "W" then
            local ref = tonumber(b)
            if ref then claim(function(it) return it.ref == ref end, a4) end
        end
    elseif event == "MAIL_SHOW" then
        local _, order = toMail()
        if #order > 0 then
            buildMailBox()
            refreshMailBox()
            mailBox:Show()
        elseif mailBox then
            mailBox:Hide()
        end
    elseif event == "MAIL_CLOSED" then
        pendingMail = nil
        if mailBox then mailBox:Hide() end
    elseif event == "MAIL_SEND_SUCCESS" then
        if pendingMail then
            markSent()
            changed()
            refreshMailBox()
        end
    elseif event == "MAIL_FAILED" then
        -- the draft and its attachments stay: a retry that goes through still counts (Sol review)
        sentNow = nil
    end
end)
