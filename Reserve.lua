----------------------------------------------------------------------
-- Reserve.lua — soft reserve for WoW Forever raids and dungeons.
--
-- The user, 2026-11-13: a guildie's Classic add-on "where when people raid, they can request what
-- they want to roll on ... to stop people from just grabbing shit that doesn't belong to them,
-- like a tank rolling on a DPS weapon". That's soft reserve (softres.it + Gargul in Classic).
-- Decisions (the user, 2026-11-13): it lives in VoidDungeon; softres.it lists can be imported;
-- an item that doesn't fit the player is flagged and the leader decides.
--
--   * The leader (or an assistant) opens reserves: 1-3 per person. Everyone with VoidDungeon
--     reserves from the Loot tab (right-click an item: main spec or off spec); anyone else
--     whispers the leader "!sr [item]"; a softres.it list can be pasted in.
--   * Fit: each player's own client checks the item against the game's own tooltip (red text =
--     can't use it: armor type, weapon skill, class) and sends that along. No class tables of ours.
--   * Loot: when an item comes up for a roll, everyone sees who reserved it ("press Need" for you,
--     "Greed or pass" for the rest); the leader can call out in group chat anyone who presses
--     Need on an item others reserved. With master loot (if Forever's servers allow it: asked
--     live) the master looter rolls an item among its reservers, main spec first, and gives it.
--   * Gold never comes into it (Forever bans gold-bid raids).
--
-- Addon messages (prefix VDSR, group channel), kept short:
--   S|id|max            leader: reserves are open (or changed)
--   X|id                leader: closed
--   R|id|CLASS|items    a player's whole reserve list (items = 12345m1,23456o0: id, m/o spec, fit 1/0/u)
--   L|id|name|CLASS|items|src   leader: someone's list (whispered / imported), or the list again
--   Q|id                asks the leader for the whole list (after a /reload or joining late)
----------------------------------------------------------------------
local _, ns = ...
local J = ns.J
local R = {}
ns.Reserve = R
J.Reserve = R

local PREFIX = "VDSR"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end

local function cdb()
    VoidDungeonCharDB = VoidDungeonCharDB or {}
    return VoidDungeonCharDB
end
function R:Session() return cdb().sr end

local function realm() return GetNormalizedRealmName and GetNormalizedRealmName() or "" end
-- "alice" (a softres.it list) and "Alice-Tinkerline" are the same player: names are keyed the way
-- the game writes them, first letter up, the rest down, with the realm (Sol review)
local function key(name)
    if not name or name == "" then return nil end
    local n, r = name:match("^([^%-]+)%-(.+)$")
    n, r = n or name, r or realm()
    if n:byte(1) and n:byte(1) < 128 then n = n:sub(1, 1):upper() .. n:sub(2):lower() end
    return n .. "-" .. r
end
local function me()
    local n, r = UnitFullName("player")
    return n .. "-" .. (r and r ~= "" and r or realm())
end
local function short(name) return Ambiguate and Ambiguate(name or "?", "short") or name end
R.short = short

local function changed()
    if ns.Side and ns.Side.Refresh then ns.Side:Refresh() end
end

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end
R.count = count

----------------------------------------------------------------------
-- Sending
----------------------------------------------------------------------
local function groupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end
R.groupChannel = groupChannel

local queue, busy = {}, false
local function pump()
    local m = table.remove(queue, 1)
    if not m then busy = false; return end
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, m[1], m[2], m[3])
    C_Timer.After(0.2, pump)
end
local function send(msg, chan, target)
    chan = chan or groupChannel()
    if not chan then return end
    queue[#queue + 1] = { msg, chan, target }
    if not busy then busy = true; pump() end
end

-- a visible line in group chat (announcements the leader asked for)
local function say(text)
    local chan = groupChannel()
    if chan then SendChatMessage(text, chan) else J:Print(text) end
end

local function isLeader()
    if not IsInGroup() then return true end
    return UnitIsGroupLeader("player") or (IsInRaid() and UnitIsGroupAssistant("player")) or false
end
R.isLeader = isLeader
function R:IAmLeader()
    local s = self:Session()
    return s and s.leader == me() or false
end

----------------------------------------------------------------------
-- Items: encode / decode, fit
----------------------------------------------------------------------
local function encode(items)
    local t = {}
    for id, it in pairs(items or {}) do
        t[#t + 1] = id .. (it.spec == "os" and "o" or "m") .. (it.fit == true and "1" or it.fit == false and "0" or "u")
    end
    table.sort(t)
    return table.concat(t, ",")
end
local function decode(s)
    local out = {}
    for id, sp, fit in (s or ""):gmatch("(%d+)([mo])([01u])") do
        local f   -- ("0" and false) or nil would be nil: "can't use" got lost (Sol review)
        if fit == "1" then f = true elseif fit == "0" then f = false end
        out[tonumber(id)] = { spec = sp == "o" and "os" or "ms", fit = f }
    end
    return out
end

-- Can I use it? The game's own tooltip: a red line or red right-hand text (armor type, weapon
-- skill not learned, class, level) = no. nil = the tooltip isn't loaded yet.
local function isRed(c)
    return c and type(c.r) == "number" and not (issecretvalue and issecretvalue(c.r))
        and c.r > 0.9 and c.g < 0.25 and c.b < 0.25
end
function R:FitsMe(id)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    if not (ok and data and data.lines and #data.lines > 1) then return nil end
    for _, line in ipairs(data.lines) do
        if isRed(line.leftColor) or isRed(line.rightColor) then return false end
    end
    return true
end

----------------------------------------------------------------------
-- The session
----------------------------------------------------------------------
local function entry(s, name, class, src)
    local e = s.list[name]
    if not e then
        e = { class = class, items = {}, src = src or "addon" }
        s.list[name] = e
    end
    if class and class ~= "" and class ~= "?" then e.class = class end
    if src then e.src = src end
    return e
end

function R:Start(max)
    if not isLeader() then
        J:Print("Only the group leader or a raid assistant can open reserves.")
        return
    end
    local d = cdb()
    d.sr = { id = tostring(time()), leader = me(), max = max or 2, list = {}, callout = true }
    send(("S|%s|%d"):format(d.sr.id, d.sr.max))
    if IsInGroup() then
        say(("Soft reserve is open: %d per person. With VoidDungeon: right-click an item on its Loot tab. Without it: whisper me !sr [item link] (add os for off spec)."):format(d.sr.max))
    end
    changed()
end

function R:SetMax(max)
    local s = self:Session()
    if not (s and self:IAmLeader()) then return end
    s.max = max
    send(("S|%s|%d"):format(s.id, s.max))
    changed()
end

function R:Close()
    local s = self:Session()
    if not s then return end
    if self:IAmLeader() then send("X|" .. s.id) end
    cdb().sr = nil
    changed()
end

-- My own reserve: spec "ms" / "os", or nil to remove it.
function R:Set(id, spec)
    local s = self:Session()
    if not s then
        J:Print("No reserve is open. The group leader opens one on VoidDungeon's Reserve tab.")
        return
    end
    local e = entry(s, me(), select(2, UnitClass("player")), "addon")
    if spec then
        if not e.items[id] and count(e.items) >= (s.max or 1) then
            J:Print(("You've used all %d of your reserves: remove one first (right-click it again)."):format(s.max or 1))
            return
        end
        e.items[id] = { spec = spec, fit = self:FitsMe(id) }
        if e.items[id].fit == false then
            local _, link = C_Item.GetItemInfo(id)
            J:Print((link or ("item " .. id)) .. ": the game says you can't use it (yet). Reserved anyway; your leader sees that.")
        end
    else
        e.items[id] = nil
    end
    send(("R|%s|%s|%s"):format(s.id, e.class or "?", encode(e.items)))
    changed()
end

-- Who reserved an item: { { name, spec, fit, src, class }, ... } main spec first, then by name.
function R:Who(id)
    local s = self:Session()
    local out = {}
    if not (s and id) then return out end
    for name, e in pairs(s.list) do
        local it = e.items[id]
        if it then out[#out + 1] = { name = name, spec = it.spec, fit = it.fit, src = e.src, class = e.class } end
    end
    table.sort(out, function(a, b)
        if a.spec ~= b.spec then return a.spec == "ms" end
        return a.name < b.name
    end)
    return out
end
function R:Mine(id)
    local s = self:Session()
    local e = s and s.list[me()]
    return e and e.items[id] or nil
end

-- in my group right now (by full name)
local function inGroup(name)
    local u = short(name)
    return UnitInParty(u) or UnitInRaid(u) or name == me()
end

-- "A (MS), B (OS, can't use)"
function R:WhoText(id, onlyHere)
    local parts = {}
    for _, w in ipairs(self:Who(id)) do
        if not onlyHere or inGroup(w.name) then
            local bits = { w.spec == "os" and "OS" or "MS" }
            if w.fit == false then bits[#bits + 1] = "|cffff6060can't use|r" end
            parts[#parts + 1] = short(w.name) .. " (" .. table.concat(bits, ", ") .. ")"
        end
    end
    return table.concat(parts, ", "), #parts
end

-- Right-hand tag for a Loot-tab row: "|cff33ff33SR 2|r" (+ a star when it's yours)
function R:Tag(id)
    local s = self:Session()
    if not s then return "" end
    local n = #self:Who(id)
    local mine = self:Mine(id)
    if n == 0 then return "" end
    return (mine and "|cffffd200*|r" or "") .. "|cff33ff33SR " .. n .. "|r  "
end

----------------------------------------------------------------------
-- Receiving
----------------------------------------------------------------------
local function fromLeader(s, sender) return s and sender == s.leader end

-- in my group, and its leader or a raid assistant: only they open / close reserves (Sol review: an
-- addon whisper from outside the group could replace the session)
local function memberOf(sender)
    local u = short(sender)
    return UnitInParty(u) or UnitInRaid(u) or false
end
local function canLead(sender)
    local u = short(sender)
    return memberOf(sender) and (UnitIsGroupLeader(u) or (IsInRaid() and UnitIsGroupAssistant(u))) or false
end

local function handle(msg, sender)
    local kind, a, b, c, d, e = strsplit("|", msg)
    local d0 = cdb()
    local s = d0.sr
    if kind ~= "Q" and not memberOf(sender) then return end
    if kind == "S" then
        if not canLead(sender) then return end
        local max = tonumber(b) or 2
        if not s or s.id ~= a then
            d0.sr = { id = a, leader = sender, max = max, list = {} }
            J:Print(("%s opened soft reserve: %d per person. Right-click an item on the Loot tab to reserve it."):format(short(sender), max))
            send("Q|" .. a)
        else
            s.max, s.leader = max, sender
        end
    elseif kind == "X" then
        if s and s.id == a and fromLeader(s, sender) then
            d0.sr = nil
            J:Print(short(sender) .. " closed soft reserve.")
        end
    elseif kind == "R" then
        if s and s.id == a and sender ~= me() then
            local en = entry(s, sender, b, "addon")
            en.items = decode(c)
            if R:IAmLeader() and count(en.items) > (s.max or 1) then
                J:Print(("%s reserved %d items (limit %d)."):format(short(sender), count(en.items), s.max or 1))
            end
        end
    elseif kind == "L" then
        if s and s.id == a and fromLeader(s, sender) and b then
            if b == me() then
                -- what the leader has for me (a softres.it list, a whisper, "!sr clear", a spec
                -- change) is my list: so my next change neither wipes nor brings back anything (Sol)
                local mine = entry(s, me(), select(2, UnitClass("player")), "addon")
                mine.items = decode(d)
            else
                local en = entry(s, b, c, e)
                en.items = decode(d)
                if not next(en.items) then s.list[b] = nil end
            end
        end
    elseif kind == "Q" then
        -- "Q|?" = someone who joined late asks whether a reserve is open; an old id (a reserve
        -- saved from another night) gets the current one too (Sol review)
        if s and R:IAmLeader() and memberOf(sender) then
            send(("S|%s|%d"):format(s.id, s.max), "WHISPER", sender)
            for name, en in pairs(s.list) do
                send(("L|%s|%s|%s|%s|%s"):format(s.id, name, en.class or "?", encode(en.items), en.src or "addon"), "WHISPER", sender)
            end
        end
    end
    changed()
end

-- the leader passes on a list that didn't come from the player's own add-on
local function relay(s, name)
    local en = s.list[name]
    send(("L|%s|%s|%s|%s|%s"):format(s.id, name, en and en.class or "?", en and encode(en.items) or "", en and en.src or "addon"))
end

----------------------------------------------------------------------
-- Whispers to the leader: "!sr [item]" (os = off spec), "!sr clear", "!sr" = what I have
----------------------------------------------------------------------
local function whisper(msg, sender)
    local s = R:Session()
    if not (s and R:IAmLeader()) then return end
    local body = msg:match("^%s*!sr(.*)$")
    if not body then return end
    local who = key(sender)
    local unit = short(who)
    local class = (UnitExists(unit) and select(2, UnitClass(unit))) or (s.list[who] and s.list[who].class) or "?"
    local e = entry(s, who, class, "whisper")
    if body:lower():find("clear", 1, true) then
        e.items = {}
    else
        local spec = (" " .. body:lower() .. " "):find("[^%a]os[^%a]") and "os" or "ms"
        for id in body:gmatch("|Hitem:(%d+)") do
            id = tonumber(id)
            if e.items[id] or count(e.items) < (s.max or 1) then
                e.items[id] = { spec = spec }
            end
        end
    end
    relay(s, who)
    local parts = {}
    for id, it in pairs(e.items) do
        local _, link = C_Item.GetItemInfo(id)
        parts[#parts + 1] = (link or ("item " .. id)) .. (it.spec == "os" and " (off spec)" or "")
    end
    local reply = #parts > 0 and ("Your reserves (%d/%d): %s"):format(#parts, s.max or 1, table.concat(parts, ", "))
        or ("No reserves. Whisper !sr [item link] (up to %d; add os for off spec)."):format(s.max or 1)
    if #reply > 250 then reply = ("Your reserves: %d of %d."):format(#parts, s.max or 1) end
    SendChatMessage(reply, "WHISPER", nil, sender)
    changed()
end

----------------------------------------------------------------------
-- softres.it import (the leader): its "Gargul export" (Base64 -> zlib -> JSON, decoded by the
-- game's own C_EncodingUtil) or its older CSV (header ItemId,Name,Class,Note,Plus). Format
-- checked 2026-11-13 against softres.it's open-source importer.
----------------------------------------------------------------------
local function classToken(c)
    c = (c or ""):upper():gsub("%s+", "")
    return c ~= "" and c or "?"
end

function R:Import(text)
    text = strtrim(text or "")
    if text == "" then return nil, "Paste the export from softres.it first." end
    local s = self:Session()
    if not s then
        if not isLeader() then return nil, "Only the group leader or a raid assistant can do that." end
        self:Start(2)
        s = self:Session()
    end
    local got = {}
    if text:find(",", 1, true) then
        local cols
        for line in text:gmatch("[^\r\n]+") do
            local seg = { strsplit(",", line) }
            if not cols then
                cols = {}
                for i, v in ipairs(seg) do cols[strtrim(v)] = i end
            else
                local id = tonumber(seg[cols.ItemId or 0] or "")
                local name = strtrim(seg[cols.Name or 0] or "")
                if id and id > 0 and name ~= "" then
                    got[#got + 1] = { name = key(name), class = classToken(seg[cols.Class or 0]), id = id }
                end
            end
        end
    else
        local E = C_EncodingUtil
        if not (E and E.DecodeBase64 and E.DecompressString and E.DeserializeJSON) then
            return nil, "This game client can't read that export; use softres.it's CSV export instead."
        end
        local zlib = (Enum.CompressionMethod and Enum.CompressionMethod.Zlib) or 1
        local ok, data = pcall(function()
            return E.DeserializeJSON(E.DecompressString(E.DecodeBase64(text), zlib))
        end)
        if not (ok and type(data) == "table" and type(data.softreserves) == "table") then
            return nil, "That isn't a softres.it export. On softres.it, click the Gargul export button and paste all of it."
        end
        for _, sr in pairs(data.softreserves) do
            if type(sr) == "table" and type(sr.items) == "table" and sr.name then
                for _, it in pairs(sr.items) do
                    local id = type(it) == "table" and tonumber(it.id) or tonumber(it)
                    if id and id > 0 then got[#got + 1] = { name = key(sr.name), class = classToken(sr.class), id = id } end
                end
            end
        end
    end
    if #got == 0 then return nil, "No reserves found in that text." end
    local people = {}
    for _, g in ipairs(got) do
        local e = entry(s, g.name, g.class, (s.list[g.name] and s.list[g.name].src == "addon") and "addon" or "softres")
        if not e.items[g.id] then e.items[g.id] = { spec = "ms" } end
        people[g.name] = true
    end
    for name in pairs(people) do relay(s, name) end
    changed()
    return #got, count(people)
end

----------------------------------------------------------------------
-- Loot
----------------------------------------------------------------------
local function idOf(link) return link and tonumber(link:match("|Hitem:(%d+)")) end
R.idOf = idOf
-- the item and its random suffix ("of the Owl" / "of the Bear" share an id): the item string up
-- to the suffix
local function linkKey(link)
    local str = link and link:match("|H(item:[^|]+)|h")
    if not str then return nil end
    local f = { strsplit(":", str) }
    return table.concat(f, ":", 1, math.min(#f, 8))
end

-- "A, B, C +4": names joined, cut to fit a chat line (255 characters) with room for `room` more
local function capped(names, room)
    local out, len = {}, 0
    for i, n in ipairs(names) do
        if len + #n + 2 > 250 - (room or 0) then
            return table.concat(out, ", ") .. " +" .. (#names - i + 1)
        end
        out[#out + 1] = n
        len = len + #n + 2
    end
    return table.concat(out, ", ")
end
R.capped = capped

-- "%s has selected Need for: %s" -> a pattern (the game's own string, so it works in any language)
local function pattern(fmt)
    if not fmt then return nil end
    fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    fmt = fmt:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. fmt .. "$"
end
local NEED = pattern(LOOT_ROLL_NEED or "%s has selected Need for: %s")
local ROLL = pattern(RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)")

local calledOut = {}   -- [rollKey] = true: one call-out per player and item

local function onRollStart(rollID)
    local s = R:Session()
    if not s then return end
    local link = GetLootRollItemLink and GetLootRollItemLink(rollID)
    local id = idOf(link)
    if not id then return end
    local text, n = R:WhoText(id, true)
    if n == 0 then return end
    if R:Mine(id) then
        J:Print("|cff33ff33You reserved " .. link .. ": press Need.|r" .. (n > 1 and (" Also reserved by: " .. text) or ""))
    else
        J:Print(link .. " is reserved by " .. text .. ": Greed or pass.")
    end
    if R:IAmLeader() and s.callout ~= false then
        local line = ("SR %s: %s. Only they press Need."):format(link, (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
        if #line > 250 then line = ("SR %s: reserved by %d players. Only they press Need."):format(link, n) end
        say(line)
    end
end

local function onLootMsg(msg)
    local s = R:Session()
    if not (s and NEED and R:IAmLeader()) then return end
    local who, link = msg:match(NEED)
    local id = idOf(link)
    if not (who and id) then return end
    local list = R:Who(id)
    local here, reserved = 0, false
    for _, w in ipairs(list) do
        if inGroup(w.name) then here = here + 1 end
        if short(w.name) == short(who) then reserved = true end
    end
    if here == 0 or reserved then return end
    local k = who .. "|" .. id
    if calledOut[k] then return end
    calledOut[k] = true
    local text = R:WhoText(id, true):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    J:Print(("|cffff8040%s pressed Need on %s, reserved by %s.|r"):format(who, link, text))
    if s.callout ~= false then
        local names = {}
        for _, w in ipairs(list) do if inGroup(w.name) then names[#names + 1] = short(w.name) end end
        say(("%s is soft reserved by %s. %s, please pass."):format(link, capped(names, #link + #who + 40), who))
    end
end

-- Master loot (only if the server allows it; asked live): the master looter rolls an item among its
-- reservers in group chat, main spec first, and gives it to the winner.
R.ml = nil   -- { { slot, link, id }, ... } while the loot window is open and I'm the master looter
local function iAmMasterLooter()
    if not (C_PartyInfo and C_PartyInfo.GetLootMethod and Enum.LootMethod) then return false end
    local method, party, raid = C_PartyInfo.GetLootMethod()
    if method ~= Enum.LootMethod.Masterlooter then return false end
    if party == 0 then return true end
    if raid and UnitIsUnit("raid" .. raid, "player") then return true end
    return false
end
R.iAmMasterLooter = iAmMasterLooter

local function onLootOpened()
    R.ml = nil
    if not iAmMasterLooter() then return end
    local list = {}
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local _, _, _, _, q = GetLootSlotInfo(slot)
        if link and (q or 0) >= (GetLootThreshold and GetLootThreshold() or 2) then
            list[#list + 1] = { slot = slot, link = link, id = idOf(link), key = linkKey(link) }
        end
    end
    if #list > 0 then R.ml = list end
    changed()
end

R.rolling = nil
-- each roll's own timer finishes only that roll (a second roll started early mustn't be cut short
-- by the first one's timer); a tie at the top rolls again among the tied (Sol review)
local function finishRoll(r)
    if not r or r ~= R.rolling or r.done then return end
    r.done = true
    local bestScore, tied = nil, {}
    for name, v in pairs(r.rolls) do
        local w = r.eligible and r.eligible[name]
        local score = v + ((w and w.spec == "ms") and 1000 or 0)
        if not bestScore or score > bestScore then bestScore, tied = score, { name }
        elseif score == bestScore then tied[#tied + 1] = name end
    end
    if #tied > 1 then
        table.sort(tied)
        local again = {}
        for _, n in ipairs(tied) do again[n] = (r.eligible and r.eligible[n]) or { spec = "ms" } end
        say(("Tie for %s: %s. Roll again."):format(r.link, capped(tied, #r.link + 30)))
        R:Roll({ link = r.link, id = r.id, slot = r.slot, key = r.key }, again)
        return
    elseif tied[1] then
        r.winner = tied[1]
        say(("%s goes to %s (rolled %d)."):format(r.link, tied[1], r.rolls[tied[1]]))
    else
        say(("Nobody rolled for %s."):format(r.link))
    end
    changed()
end

-- only: { [short name] = { spec } } to roll among (a tie), else the item's reservers in the group
function R:Roll(entryML, only)
    local eligible = only
    if not eligible then
        for _, w in ipairs(self:Who(entryML.id)) do
            if inGroup(w.name) then
                eligible = eligible or {}
                eligible[short(w.name)] = w
            end
        end
    end
    local text
    if eligible then
        local names = {}
        for n, w in pairs(eligible) do names[#names + 1] = n .. (w.spec == "os" and " (OS)" or "") end
        table.sort(names)
        text = ("Roll for %s, reserved by %s: /roll now (main spec wins over off spec)."):format(entryML.link, capped(names, #entryML.link + 75))
    else
        text = ("Roll for %s: /roll now, 20 seconds."):format(entryML.link)
    end
    local r = { link = entryML.link, id = entryML.id, key = entryML.key or linkKey(entryML.link), slot = entryML.slot,
        eligible = eligible, rolls = {}, ends = GetTime() + 20 }
    self.rolling = r
    say(text)
    C_Timer.After(20, function() finishRoll(r) end)
    changed()
end

local function onSystem(msg)
    local r = R.rolling
    if not (r and not r.done and ROLL) then return end
    local who, roll, lo, hi = msg:match(ROLL)
    roll, lo, hi = tonumber(roll), tonumber(lo), tonumber(hi)
    if not (who and roll and lo == 1 and hi == 100) then return end
    who = short(who)
    if r.eligible and not r.eligible[who] then return end
    if r.rolls[who] then return end
    r.rolls[who] = roll
    changed()
end

function R:Give()
    local r = self.rolling
    if not (r and r.winner and r.slot) then return end
    -- the loot window must still be open on that item, in that slot (another corpse's loot can
    -- sit in the same slot: Sol review)
    local slot
    if self.ml then
        for i = 1, GetNumLootItems() do
            -- the same item with the same suffix as the one rolled for (Sol review)
            local l = GetLootSlotLink(i)
            if idOf(l) == r.id and (not r.key or linkKey(l) == r.key) then slot = i; break end
        end
    end
    if not slot then
        J:Print("Open the loot window with " .. r.link .. " in it again, then give it.")
        return
    end
    r.slot = slot
    for i = 1, 40 do
        local name = GetMasterLootCandidate(r.slot, i)
        if name and short(name) == short(r.winner) then
            GiveMasterLoot(r.slot, i)
            self.rolling = nil
            changed()
            return
        end
    end
    J:Print(r.winner .. " can't be given that item (not eligible for this loot).")
end

----------------------------------------------------------------------
-- Announce the whole list in group chat (leader)
----------------------------------------------------------------------
function R:Announce()
    local s = self:Session()
    if not s then return end
    local byItem = {}
    for name, e in pairs(s.list) do
        for id in pairs(e.items) do
            byItem[id] = byItem[id] or {}
            table.insert(byItem[id], short(name))
        end
    end
    local lines, line = {}, "SR:"
    for id, names in pairs(byItem) do
        table.sort(names)
        local _, link = C_Item.GetItemInfo(id)
        local item = " " .. (link or ("item " .. id)) .. " "
        local part = item .. table.concat(names, ", ") .. ";"
        if #part > 240 then   -- one item with a long list: as many names as fit, then "+N" (Sol review)
            local shown = {}
            for i, nm in ipairs(names) do
                if #item + #table.concat(shown, ", ") + #nm + 8 > 240 then
                    part = item .. table.concat(shown, ", ") .. " +" .. (#names - i + 1) .. ";"
                    break
                end
                shown[#shown + 1] = nm
            end
        end
        if #line + #part > 250 then lines[#lines + 1] = line; line = "SR:" end
        line = line .. part
    end
    if line ~= "SR:" then lines[#lines + 1] = line end
    if #lines == 0 then say("Soft reserve: nothing reserved yet."); return end
    for i, l in ipairs(lines) do C_Timer.After((i - 1) * 0.4, function() say(l) end) end
end

----------------------------------------------------------------------
-- Right-click menu on a Loot-tab item
----------------------------------------------------------------------
function R:ItemMenu(owner, id)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local s = self:Session()
    local _, link = C_Item.GetItemInfo(id)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(link or ("item " .. id))
        if not s then
            root:CreateButton("No reserve open: the leader opens one on the Reserve tab", function() end)
            return
        end
        local mine = self:Mine(id)
        if not mine or mine.spec ~= "ms" then root:CreateButton("Reserve: main spec", function() R:Set(id, "ms") end) end
        if not mine or mine.spec ~= "os" then root:CreateButton("Reserve: off spec", function() R:Set(id, "os") end) end
        if mine then root:CreateButton("Remove my reserve", function() R:Set(id, nil) end) end
        local text, n = self:WhoText(id)
        if n > 0 then root:CreateTitle("Reserved by: " .. text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    end)
end

----------------------------------------------------------------------
-- Import box (movable, kept where it's left: VoidMove.lua)
----------------------------------------------------------------------
local importBox
function R:ShowImport()
    if not importBox then
        local f = CreateFrame("Frame", "VoidDungeonImport", UIParent, "BackdropTemplate")
        f:SetSize(420, 230)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.07, 0.07, 0.09, 0.97)
        f:SetBackdropBorderColor(J.A[1], J.A[2], J.A[3], 0.7)
        local t = J.text(f, 12, "OUTLINE")
        t:SetPoint("TOPLEFT", 10, -8)
        t:SetTextColor(J.A[1], J.A[2], J.A[3])
        t:SetText("Import from softres.it")
        local hint = J.text(f, 10)
        hint:SetPoint("TOPLEFT", 10, -28)
        hint:SetPoint("RIGHT", -10, 0)
        hint:SetWordWrap(true)
        hint:SetTextColor(0.7, 0.7, 0.75)
        hint:SetText("On softres.it, click the Gargul export button (or the CSV export), copy all of it and paste it here.")
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 10, -58)
        sf:SetPoint("BOTTOMRIGHT", -30, 40)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(370)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
        sf:SetScrollChild(eb)
        f.eb = eb
        local status = J.text(f, 10)
        status:SetPoint("BOTTOMLEFT", 10, 14)
        status:SetPoint("RIGHT", -170, 0)
        status:SetWordWrap(true)
        f.status = status
        local ok = J.button(f, "Import", function()
            local n, people = R:Import(eb:GetText())
            if n then
                status:SetTextColor(0.4, 1, 0.4)
                status:SetText(("Imported %d reserves from %d players."):format(n, people))
                eb:SetText("")
                eb:ClearFocus()
            else
                status:SetTextColor(1, 0.4, 0.4)
                status:SetText(people)
            end
        end)
        ok:SetPoint("BOTTOMRIGHT", -70, 10)
        local close = J.button(f, "Close", function() eb:ClearFocus(); f:Hide() end)
        close:SetPoint("BOTTOMRIGHT", -10, 10)
        f:EnableMouse(true)
        if ns.Move then ns.Move(f, { db = function() return VoidDungeonDB end, key = "srImport" }) end
        importBox = f
    end
    importBox.status:SetText("")
    importBox:Show()
    importBox.eb:SetFocus()
end

----------------------------------------------------------------------
-- The Reserve tab (Side.lua draws the rows)
----------------------------------------------------------------------
local A = J.A
local function act(text, fn, r, g, b)
    return { text = text, r = r or A[1], g = g or A[2], b = b or A[3], click = fn }
end

function R:Entries(out)
    local s = self:Session()
    out[#out + 1] = { head = "Soft reserve" }
    if not s then
        out[#out + 1] = { text = "No reserve is open. With one open, everyone reserves the items they'll roll on, and only they press Need.", r = 0.75, g = 0.75, b = 0.8, wrap = true }
        if isLeader() then
            for _, n in ipairs({ 1, 2, 3 }) do
                out[#out + 1] = act(("Open reserves: %d per person"):format(n), function() R:Start(n) end)
            end
            out[#out + 1] = act("Import a softres.it list", function() R:ShowImport() end)
        else
            out[#out + 1] = { text = "Your group leader opens it (they need VoidDungeon), or uses softres.it.", r = 0.6, g = 0.6, b = 0.65, wrap = true }
        end
        return
    end
    local leaderMe = self:IAmLeader()
    out[#out + 1] = { text = ("%d per person · leader %s"):format(s.max or 1, short(s.leader)), r = 0.8, g = 0.8, b = 0.85 }
    -- mine
    local mine = s.list[me()]
    local n = mine and count(mine.items) or 0
    out[#out + 1] = { head = ("Your reserves (%d/%d)"):format(n, s.max or 1) }
    if n == 0 then
        out[#out + 1] = { text = "Right-click an item on the Loot tab: main spec or off spec.", r = 0.6, g = 0.6, b = 0.65, wrap = true }
    else
        for id, it in pairs(mine.items) do
            local name, q, icon = J:Item(id)
            local c = ITEM_QUALITY_COLORS[q or 1] or { r = 1, g = 1, b = 1 }
            out[#out + 1] = { text = name or ("item " .. id), r = c.r, g = c.g, b = c.b, icon = icon, item = id,
                right = (it.spec == "os" and "OS" or "MS") .. (it.fit == false and " |cffff6060can't use|r" or ""),
                menu = function(owner) R:ItemMenu(owner, id) end }
        end
    end
    -- master loot: roll and give
    if self.ml then
        out[#out + 1] = { head = "Loot window (you're the master looter)" }
        for _, m in ipairs(self.ml) do
            local text, k = self:WhoText(m.id, true)
            out[#out + 1] = act(("Roll %s%s"):format(m.link, k > 0 and (" (" .. text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. ")") or ""), function() R:Roll(m) end, 0.95, 0.95, 0.95)
        end
        local r = self.rolling
        if r then
            local names = {}
            for name, v in pairs(r.rolls) do names[#names + 1] = name .. " " .. v end
            table.sort(names)
            out[#out + 1] = { text = (r.done and "Rolled: " or "Rolling: ") .. (#names > 0 and table.concat(names, ", ") or "waiting for /roll"), r = 0.8, g = 0.8, b = 0.85, wrap = true }
            if r.winner then out[#out + 1] = act("Give " .. r.link .. " to " .. r.winner, function() R:Give() end, 0.4, 1, 0.4) end
        end
    end
    -- everyone's, by item
    local byItem, order = {}, {}
    for name, e in pairs(s.list) do
        for id in pairs(e.items) do
            if not byItem[id] then byItem[id] = true; order[#order + 1] = id end
        end
    end
    table.sort(order)
    out[#out + 1] = { head = ("Everyone's reserves (%d items)"):format(#order) }
    for _, id in ipairs(order) do
        local name, q, icon = J:Item(id)
        local c = ITEM_QUALITY_COLORS[q or 1] or { r = 1, g = 1, b = 1 }
        local text = self:WhoText(id)
        out[#out + 1] = { text = name or ("item " .. id), r = c.r, g = c.g, b = c.b, icon = icon, item = id, right = "|cff33ff33" .. #self:Who(id) .. "|r",
            menu = function(owner) R:ItemMenu(owner, id) end }
        out[#out + 1] = { text = "   " .. text, r = 0.75, g = 0.75, b = 0.8, wrap = true }
    end
    -- who hasn't reserved yet (in the group)
    if IsInGroup() then
        local missing = {}
        for i = 1, GetNumGroupMembers() do
            local unit = IsInRaid() and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
            local nm, rl = UnitName(unit)
            if nm then
                local full = nm .. "-" .. (rl and rl ~= "" and rl or realm())
                if not (s.list[full] and next(s.list[full].items)) then missing[#missing + 1] = nm end
            end
        end
        if #missing > 0 then
            table.sort(missing)
            out[#out + 1] = { text = "No reserve yet: " .. table.concat(missing, ", "), r = 0.6, g = 0.6, b = 0.65, wrap = true }
        end
    end
    if leaderMe then
        out[#out + 1] = { head = "Leader" }
        out[#out + 1] = act("Post the list in group chat", function() R:Announce() end)
        out[#out + 1] = act("Call out Need on others' reserves: " .. (s.callout ~= false and "on" or "off"), function()
            s.callout = s.callout == false
            changed()
        end)
        out[#out + 1] = act("Import a softres.it list", function() R:ShowImport() end)
        for _, k in ipairs({ 1, 2, 3 }) do
            if k ~= s.max then out[#out + 1] = act(("Change to %d per person"):format(k), function() R:SetMax(k) end) end
        end
        out[#out + 1] = act("Close reserves", function() R:Close() end, 1, 0.5, 0.4)
    else
        out[#out + 1] = act("Leave this reserve (forget it here)", function() cdb().sr = nil; changed() end, 0.7, 0.7, 0.75)
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("CHAT_MSG_WHISPER")
ev:RegisterEvent("START_LOOT_ROLL")
ev:RegisterEvent("CHAT_MSG_LOOT")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:RegisterEvent("LOOT_OPENED")
ev:RegisterEvent("LOOT_CLOSED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GROUP_LEFT")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
    if event == "CHAT_MSG_ADDON" then
        if a1 == PREFIX and type(a2) == "string" and a4 and key(a4) ~= me() then handle(a2, key(a4)) end
    elseif event == "CHAT_MSG_WHISPER" then
        if type(a1) == "string" and type(a2) == "string" then whisper(a1, a2) end
    elseif event == "START_LOOT_ROLL" then
        onRollStart(a1)
    elseif event == "CHAT_MSG_LOOT" then
        if type(a1) == "string" then onLootMsg(a1) end
    elseif event == "CHAT_MSG_SYSTEM" then
        if type(a1) == "string" then onSystem(a1) end
    elseif event == "LOOT_OPENED" then
        onLootOpened()
    elseif event == "LOOT_CLOSED" then
        R.ml = nil
        changed()
    elseif event == "PLAYER_LOGIN" or event == "GROUP_ROSTER_UPDATE" then
        -- back after a /reload in a group, or just joined one: ask whether a reserve is open, once
        -- per group (a late joiner found nothing before: Sol review)
        if not IsInGroup() then R.askedGroup = nil; return end
        if R.askedGroup then return end
        R.askedGroup = true
        local s = R:Session()
        if s and R:IAmLeader() then return end
        C_Timer.After(3, function() send("Q|" .. (s and s.id or "?")) end)
    elseif event == "GROUP_LEFT" then
        -- left the group: a reserve that wasn't ours ends here
        R.askedGroup = nil
        local s = R:Session()
        if s and not R:IAmLeader() then cdb().sr = nil; changed() end
    end
end)
