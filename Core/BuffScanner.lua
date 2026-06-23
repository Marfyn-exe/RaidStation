-- RaidStation :: Core/BuffScanner.lua
-- Escaneo de buffs de banda con UnitBuff + GetSpellInfo (build 12340 sin spellId en UnitBuff).
-- Throttle 2s, eventos de raid y UNIT_AURA. Anuncios por ChatThrottleLib.
local addonName, ns = ...

local BuffData = ns.BuffData
local SCAN_INTERVAL = 2.0
local ANNOUNCE_COOLDOWN = 2.0
local CHAT_PREFIX = "RSBuff"

local BuffScanner = {
    eventFrame = nil,
    watching = false,
    dirty = true,
    lastFullScan = 0,
    lastAnnounceTime = {}, -- per-category throttle: { [key] = timestamp }
    cachedState = nil,
    _auraSourceCache = {},
    _lastCleanupTime = 0,
}

local tinsert = table.insert
local strformat = string.format
local floor = math.floor

local tablePool = {}
local function acquireTable()
    local t = table.remove(tablePool)
    if t then
        wipe(t)
    else
        t = {}
    end
    return t
end

local function releaseStateTree(t)
    if type(t) ~= "table" then return end
    for k, v in pairs(t) do
        if type(v) == "table" then
            releaseStateTree(v)
        end
    end
    wipe(t)
    tinsert(tablePool, t)
end

local function sysMsg(msg)
    local prefix = (ns.GUI and ns.GUI.ColorText) and ns.GUI.ColorText("[Buffs]") or "|cFF5B9BD5[Buffs]|r"
    print(prefix .. " : " .. tostring(msg))
end

local function strtrim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function dbgPrint(msg)
    if RaidStationDB and RaidStationDB.debug then
        print("[Buffs] : " .. tostring(msg))
    end
end

local function stripColorAndLinks(text)
    if not text then return "" end
    local clean = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    clean = clean:gsub("|H.-|h", "")
    clean = clean:gsub("|h", "")
    clean = clean:gsub("|r", "")
    return clean
end

local function visibleLen(text)
    return stripColorAndLinks(text):len()
end

local function sendChatLine(text, channelOverride)
    local channel = channelOverride or (RaidStationDB and RaidStationDB.buffAnnounceChannel) or "SELF"

    -- Validar que el canal sea apropiado según el contexto:
    if channel == "RAID" or channel == "RAID_WARNING" then
        if GetNumRaidMembers() == 0 then
            -- No esta en raid, forzar a SELF
            channel = "SELF"
        end
    end

    text = tostring(text or "")

    if channel == "SELF" then
        text = stripColorAndLinks(text)
        text = text:gsub("|", "/")
        DEFAULT_CHAT_FRAME:AddMessage(text, 1, 0.8, 0)
    elseif channel == "RAID" then
        SendChatMessage(text, "RAID")
    elseif channel == "RAID_WARNING" then
        SendChatMessage(text, "RAID_WARNING")
    end
end

local function collectUnitAuras(unit)
    local byName = acquireTable()
    local i = 1
    while true do
        local name, rank, icon, count, debuffType, duration, expirationTime = UnitBuff(unit, i)
        if not name then break end
        duration = duration or 0
        expirationTime = expirationTime or 0
        local prev = byName[name]
        if not prev or expirationTime > prev.expirationTime then
            if not prev then
                prev = acquireTable()
                byName[name] = prev
            end
            prev.duration = duration
            prev.expirationTime = expirationTime
        end
        i = i + 1
    end
    return byName
end

-- P-1: Cache de nombres de hechizo por definición.
-- GetSpellInfo es costoso; llamarlo una vez al iniciar y reutilizar el resultado
-- elimina cientos de llamadas por escaneo (25 jugadores × defs × spellIDs cada 2s).
local _spellNameCache = {} -- { [defId] -> { [spellName] -> sid } }

local function buildSpellNameCache()
    wipe(_spellNameCache)
    for _, def in ipairs(BuffData.DEFINITIONS) do
        local nameToSid = {}
        for _, sid in ipairs(def.spellIDs or {}) do
            local spellName = select(1, GetSpellInfo(sid))
            if spellName and spellName ~= "" then
                nameToSid[spellName] = sid
            end
        end
        _spellNameCache[def.id] = nameToSid
    end
end

local function auraMatchesDefinition(def, byName)
    local nameToSid = _spellNameCache[def.id]
    if nameToSid then
        for spellName, sid in pairs(nameToSid) do
            if byName[spellName] then
                return true, sid, byName[spellName]
            end
        end
        return false, nil, nil
    end
    -- Fallback si el cache aún no fue construido (no debería ocurrir en uso normal)
    for _, sid in ipairs(def.spellIDs) do
        local spellName = select(1, GetSpellInfo(sid))
        if spellName and spellName ~= "" and byName[spellName] then
            return true, sid, byName[spellName]
        end
    end
    return false, nil, nil
end

local function paladinAssignmentRows()
    local list = RaidStationDB and RaidStationDB.paladinAssignmentList
    if type(list) == "table" then
        return list
    end
    local flat = {}
    local t = RaidStationDB and RaidStationDB.paladinAssignments
    if type(t) == "table" then
        for pname, rows in pairs(t) do
            if type(rows) == "table" then
                for _, row in ipairs(rows) do
                    if type(row) == "table" and row.spellID then
                        tinsert(flat, {
                            paladin = pname,
                            spellID = row.spellID,
                            clases = row.clases or row.classes or { "ALL" },
                        })
                    end
                end
            end
        end
    end
    return flat
end

local function findAssignedPaladinName(classToken, def)
    if def.tipo ~= "paladin" or not def.paladinFamily then return nil end
    for _, row in ipairs(paladinAssignmentRows()) do
        if type(row) == "table" and row.spellID and strtrim(row.paladin or "") ~= "" then
            local fam = BuffData.SpellIdToPaladinFamily(row.spellID)
            if fam == def.paladinFamily then
                local cl = row.clases or row.classes or {}
                local ok = false
                for _, c in ipairs(cl) do
                    if c == "ALL" or c == classToken then
                        ok = true
                        break
                    end
                end
                if ok then
                    return row.paladin
                end
            end
        end
    end
    return nil
end

local function isEligible(def, classToken)
    if not def.neverFor then return true end
    for _, c in ipairs(def.neverFor) do
        if c == classToken then return false end
    end
    return true
end

local function evaluateBuffForPlayer(def, byName, classToken, playerName)
    if not isEligible(def, classToken) then
        local t = acquireTable()
        t.skip = true
        t.present = false
        t.urgent = false
        return t
    end
    local threshold = tonumber(RaidStationDB and RaidStationDB.buffTab_threshold) or 600
    local present, matchedSid, auraInfo = auraMatchesDefinition(def, byName)
    local assignedPaladin = findAssignedPaladinName(classToken, def)

    if not present then
        local resp
        if def.tipo == "paladin" and assignedPaladin then
            resp = strformat("Responsable: %s — FALTA", assignedPaladin)
        elseif def.tipo == "paladin" then
            resp = def.responsableLinea .. " — sin asignacion en Ajustes"
        else
            resp = def.responsableLinea
        end
        local t = acquireTable()
        t.present = false
        t.quality = nil
        t.urgent = false
        t.remaining = nil
        t.expirationTime = nil
        t.matchedSpellId = nil
        t.assignedPaladin = assignedPaladin
        t.responsableTooltip = resp
        return t
    end

    local quality = "minor"
    if type(def.superiorSpellID) == "table" then
        for _, id in ipairs(def.superiorSpellID) do
            if matchedSid == id then
                quality = "superior"
                break
            end
        end
    elseif matchedSid == def.superiorSpellID then
        quality = "superior"
    end
    local exp = auraInfo.expirationTime or 0
    local now = GetTime()
    local remaining = (exp > 0) and (exp - now) or nil
    local urgent = false
    if exp > 0 and remaining and remaining > 0 and remaining < threshold then
        urgent = true
    end

    -- Detectar si el buff (paladin) fue dado por alguien diferente al asignado usando CLEU
    local wrongCaster = false
    local wrongCasterName = nil
    if def.tipo == "paladin" and present == true then
        local destCache = BuffScanner._auraSourceCache[playerName]
        local entry = destCache and destCache[def.paladinFamily]
        if entry and entry.caster then
            if assignedPaladin and entry.caster ~= assignedPaladin then
                wrongCaster = true
                wrongCasterName = entry.caster
            end
        else
            wrongCaster = false
        end
    end

    local resp
    if def.tipo == "paladin" and assignedPaladin then
        resp = strformat("Responsable: %s (Paladin)", assignedPaladin)
    else
        resp = def.responsableLinea
    end

    local t = acquireTable()
    t.present = true
    t.quality = quality
    t.urgent = urgent
    t.remaining = remaining
    t.expirationTime = exp
    t.matchedSpellId = matchedSid
    t.assignedPaladin = assignedPaladin
    t.responsableTooltip = resp
    t.wrongCaster = wrongCaster
    t.wrongCasterName = wrongCasterName
    return t
end

function BuffScanner.PerformFullScan()
    if BuffScanner.cachedState then
        releaseStateTree(BuffScanner.cachedState)
        BuffScanner.cachedState = nil
    end

    -- Limpiar cache vieja de auras (cada 300 segundos)
    local now = GetTime()
    if not BuffScanner._lastCleanupTime then
        BuffScanner._lastCleanupTime = 0
    end
    if now - BuffScanner._lastCleanupTime > 300 then
        BuffScanner._lastCleanupTime = now
        for destName, families in pairs(BuffScanner._auraSourceCache) do
            for family, entry in pairs(families) do
                if now - entry.time > 3600 then
                    families[family] = nil
                end
            end
            if not next(families) then
                BuffScanner._auraSourceCache[destName] = nil
            end
        end
    end

    local state = acquireTable()
    state.inRaid = false
    state.groups = acquireTable()
    state.timestamp = GetTime()

    local nRaid = GetNumRaidMembers()
    if nRaid == 0 then
        state.inRaid = false
        BuffScanner.cachedState = state
        return state
    end

    state.inRaid = true

    for i = 1, math.min(nRaid, 25) do
        local name, rank, subgroup, level, localizedClass, fileName, zone, online, isDead = GetRaidRosterInfo(i)
        if not name or name == "" then
            -- vacio
        else
            local skip = false
            if online == false or online == 0 then skip = true end
            if isDead == true or isDead == 1 then skip = true end
            if (subgroup or 0) < 1 or (subgroup or 0) > 5 then skip = true end
            if not skip then
                local unit = "raid" .. i
                if UnitExists(unit) then
                    subgroup = subgroup or 1
                    if not state.groups[subgroup] then
                        state.groups[subgroup] = acquireTable()
                        state.groups[subgroup].players = acquireTable()
                    end
                    local classToken = select(2, UnitClass(unit)) or fileName or "UNKNOWN"
                    local byName = collectUnitAuras(unit)
                    local playerEntry = acquireTable()
                    playerEntry.name = name
                    playerEntry.unit = unit
                    playerEntry.classToken = classToken
                    playerEntry.subgroup = subgroup
                    playerEntry.buffs = acquireTable()
                    for _, def in ipairs(BuffData.DEFINITIONS) do
                        playerEntry.buffs[def.id] = evaluateBuffForPlayer(def, byName, classToken, name)
                    end
                    tinsert(state.groups[subgroup].players, playerEntry)

                    releaseStateTree(byName)
                end
            end
        end
    end

    BuffScanner.cachedState = state
    return state
end

function BuffScanner.RequestScan(force)
    BuffScanner.dirty = true
    if force then
        BuffScanner.lastFullScan = 0
    end
end

function BuffScanner.Tick()
    if not BuffScanner.watching then return end
    local now = GetTime()
    if BuffScanner.dirty or (now - BuffScanner.lastFullScan >= SCAN_INTERVAL) then
        BuffScanner.PerformFullScan()
        BuffScanner.lastFullScan = now
        BuffScanner.dirty = false
        if ns.BuffTab and ns.BuffTab.OnScannerUpdated then
            ns.BuffTab.OnScannerUpdated()
        end
    end
end

function BuffScanner.GetRaidBuffState()
    if not BuffScanner.cachedState then
        BuffScanner.PerformFullScan()
    end
    return BuffScanner.cachedState
end

function BuffScanner.AnnounceMissingForCategories(includeRaid, includePaladin, includeConsume)
    local now = GetTime()
    -- Per-category throttle key based on selected filters
    local throttleKey = (includeRaid and "R" or "") .. (includePaladin and "P" or "") .. (includeConsume and "C" or "")
    if now - (BuffScanner.lastAnnounceTime[throttleKey] or 0) < ANNOUNCE_COOLDOWN then
        sysMsg("Espera unos segundos antes de volver a anunciar faltantes.")
        return
    end

    local channel = RaidStationDB and RaidStationDB.buffAnnounceChannel or "SELF"
    if channel == "RAID" or channel == "RAID_WARNING" then
        if GetNumRaidMembers() == 0 then
            sysMsg("No estas en una banda de raid.")
            return
        end
    end

    -- Set throttle timestamp at the START, before sending
    BuffScanner.lastAnnounceTime[throttleKey] = now
    local state = BuffScanner.GetRaidBuffState()
    if not state.inRaid then
        sysMsg("No estas en una banda de raid.")
        return
    end

    -- Contar cuántos jugadores elegibles faltan cada buff
    local buffCount = {} -- defId -> count
    local buffJerga = {} -- defId -> jerga

    for _, def in ipairs(BuffData.DEFINITIONS) do
        local use = false
        if def.tipo == "raid" and includeRaid then use = true end
        if def.tipo == "paladin" and includePaladin then use = true end
        if def.tipo == "consumible" and includeConsume then use = true end
        if use then
            buffCount[def.id] = 0
            buffJerga[def.id] = def.jerga or def.nombre
        end
    end

    -- Build a map of defs by ID for quick lookup
    local defsById = {}
    for _, def in ipairs(BuffData.DEFINITIONS) do
        if buffCount[def.id] then
            defsById[def.id] = def
        end
    end

    for sg, gdata in pairs(state.groups) do
        for _, p in ipairs(gdata.players) do
            for defId, _ in pairs(buffCount) do
                local def = defsById[defId]
                -- Respetar neverFor: si el buff no aplica a esta clase, no contar como faltante
                if def and isEligible(def, p.classToken) then
                    local st = p.buffs[defId]
                    if st and not st.present then
                        buffCount[defId] = buffCount[defId] + 1
                    end
                end
            end
        end
    end

    -- Agrupar rezos de sacerdote si todos faltan
    local raidDefs = { "raid_fort", "raid_spirit", "raid_shadow" }
    local allRezosMissing = true
    for _, id in ipairs(raidDefs) do
        if buffCount[id] and buffCount[id] == 0 then
            allRezosMissing = false
        end
    end

    local partsLink = {}
    local partsJerga = {}
    local skipIds = {}

    if allRezosMissing and includeRaid
        and buffCount["raid_fort"] and buffCount["raid_spirit"] and buffCount["raid_shadow"] then
        -- Tomar el mayor de los tres como representativo
        local maxCount = math.max(
            buffCount["raid_fort"] or 0,
            buffCount["raid_spirit"] or 0,
            buffCount["raid_shadow"] or 0
        )
        tinsert(partsLink, "Rezos : " .. maxCount)
        tinsert(partsJerga, "Rezos : " .. maxCount)
        skipIds["raid_fort"] = true
        skipIds["raid_spirit"] = true
        skipIds["raid_shadow"] = true
    end

    -- Resto de buffs ordenados por defID para consistencia
    local orderedIds = {}
    for defId, count in pairs(buffCount) do
        if not skipIds[defId] and count > 0 then
            tinsert(orderedIds, defId)
        end
    end
    table.sort(orderedIds)

    for _, defId in ipairs(orderedIds) do
        local def = defsById[defId]
        local link = def and BuffData.GetSpellLink(def)
        local jerga = buffJerga[defId]

        tinsert(partsLink, (link or jerga) .. " : " .. buffCount[defId])
        tinsert(partsJerga, jerga .. " : " .. buffCount[defId])
    end

    if #partsLink == 0 then
        sysMsg("No hay faltantes visibles con los filtros actuales.")
        return
    end

    local msgLink = "[Buffs] Faltan : " .. table.concat(partsLink, " - ")
    local msgJerga = "[Buffs] Faltan : " .. table.concat(partsJerga, " - ")

    local msgToSend
    if msgLink:len() <= 255 then
        msgToSend = msgLink
    else
        if msgJerga:len() > 255 then
            msgToSend = msgJerga:sub(1, 252) .. "..."
        else
            msgToSend = msgJerga
        end
    end

    sendChatLine(msgToSend, nil)
end

local function describeAssignmentRow(palaName, rows)
    local chunks = {}
    for _, row in ipairs(rows) do
        if type(row) == "table" and row.spellID then
            local defId = BuffData.SpellIdToDefinitionId(row.spellID)
            local def = defId and BuffData.GetDefinitionById(defId)
            local link
            if def then
                link = BuffData.GetSpellLink(def)
            else
                link = GetSpellLink(row.spellID)
            end
            local bname = link or (def and def.nombre) or ("ID " .. tostring(row.spellID))
            tinsert(chunks, bname)
        end
    end
    return "[" .. palaName .. " : " .. table.concat(chunks, ", ") .. "]"
end

function BuffScanner.AnnouncePaladinAssignments()
    local channel = RaidStationDB and RaidStationDB.buffAnnounceChannel or "SELF"
    if channel == "RAID" or channel == "RAID_WARNING" then
        if GetNumRaidMembers() == 0 then
            sysMsg("No estas en una banda de raid.")
            return
        end
    end

    local rows = paladinAssignmentRows()
    if #rows == 0 then
        sysMsg("No hay asignaciones de paladines guardadas.")
        return
    end
    local byPala = {}
    for _, row in ipairs(rows) do
        local pname = strtrim(row.paladin or "")
        if pname ~= "" then
            if not byPala[pname] then byPala[pname] = {} end
            tinsert(byPala[pname], row)
        end
    end
    local segments = {}
    local seen = {}
    for palaName, prows in pairs(byPala) do
        if #prows > 0 then
            local seg = describeAssignmentRow(palaName, prows)
            if not seen[seg] then
                seen[seg] = true
                tinsert(segments, seg)
            end
        end
    end
    if #segments == 0 then
        sysMsg("No hay filas de asignacion validas.")
        return
    end
    local joined = table.concat(segments, " ")
    if joined:len() <= 180 then
        sendChatLine("Buffs de Palas: " .. joined, nil)
        return
    end
    for _, seg in ipairs(segments) do
        sendChatLine("Buffs de Palas: " .. seg, nil)
    end
end

function BuffScanner.SendPredefinedAlert(slotIndex)
    local alerts = RaidStationDB and RaidStationDB.buffTab_alerts
    if type(alerts) ~= "table" then return end
    local slot = alerts[slotIndex]
    if type(slot) ~= "table" then return end
    local msg = slot.message or slot.msg or ""
    if msg == "" then
        sysMsg("Ese slot de alerta esta vacio. Configuralo en Ajustes.")
        return
    end
    local toRW = RaidStationDB and RaidStationDB.buffTab_alertToRaidWarning
    local toRaid = RaidStationDB and RaidStationDB.buffTab_alertToRaid
    if toRW then
        sendChatLine(msg, "RAID_WARNING")
    elseif toRaid then
        sendChatLine(msg, "RAID")
    else
        sysMsg("No hay canal seleccionado para alertas rapidas. Activa /rw o /raid en Ajustes.")
    end
end

-- Permite reconstruir el cache externamente si BuffData cambia en caliente
BuffScanner.RebuildSpellCache = buildSpellNameCache

function BuffScanner.Initialize()
    if BuffScanner.eventFrame then return end
    buildSpellNameCache() -- P-1: construir cache una vez al iniciar
    local f = CreateFrame("Frame", "RaidStationBuffScannerEventFrame", UIParent)
    BuffScanner.eventFrame = f
    f:SetSize(1, 1)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    f:Hide()
    f:SetScript("OnUpdate", function(self, elapsed)
        self._acc = (self._acc or 0) + elapsed
        if self._acc >= 0.25 then
            self._acc = 0
            BuffScanner.Tick()
        end
    end)
end

function BuffScanner.StartWatching()
    if BuffScanner.watching then return end
    BuffScanner.watching = true
    local f = BuffScanner.eventFrame
    if not f then
        BuffScanner.Initialize(); f = BuffScanner.eventFrame
    end
    f:RegisterEvent("RAID_ROSTER_UPDATE")
    f:RegisterEvent("UNIT_AURA")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    f:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            -- P-2: filtrar subevent PRIMERO con select(), cero allocaciones en eventos irrelevantes
            local subevent = select(2, ...)
            if subevent ~= "SPELL_AURA_APPLIED"
                and subevent ~= "SPELL_AURA_REFRESH"
                and subevent ~= "SPELL_AURA_REMOVED" then
                return
            end

            -- Buscador de GUIDs: recorre con select() en lugar de empaquetar {...}
            -- para mantener robustez ante variaciones de firma de 3.3.5a (hideCaster, etc.)
            local sourceGUID_idx, destGUID_idx
            local nArgs = select("#", ...)
            for idx = 3, nArgs do
                local val = (select(idx, ...))
                if type(val) == "string" and val:find("^0x") then
                    if not sourceGUID_idx then
                        sourceGUID_idx = idx
                    elseif not destGUID_idx then
                        destGUID_idx = idx
                        break
                    end
                end
            end

            if sourceGUID_idx and destGUID_idx then
                local sourceName = (select(sourceGUID_idx + 1, ...))
                local destName   = (select(destGUID_idx + 1, ...))
                local spellId    = (select(destGUID_idx + 3, ...))

                -- Validar tipos según restricciones (no strings con 0x como nombre de jugador)
                if type(sourceName) == "string" and not sourceName:find("0x") and
                    type(destName) == "string" and not destName:find("0x") and
                    type(spellId) == "number" then
                    local family = BuffData.paladinSpellToFamily[spellId]
                    if family then
                        if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
                            if not BuffScanner._auraSourceCache[destName] then
                                BuffScanner._auraSourceCache[destName] = {}
                            end
                            local entry = BuffScanner._auraSourceCache[destName][family]
                            if not entry then
                                entry = {}
                                BuffScanner._auraSourceCache[destName][family] = entry
                            end
                            entry.caster = sourceName
                            entry.spellId = spellId
                            entry.time = GetTime()
                        elseif subevent == "SPELL_AURA_REMOVED" then
                            if BuffScanner._auraSourceCache[destName] then
                                BuffScanner._auraSourceCache[destName][family] = nil
                                if not next(BuffScanner._auraSourceCache[destName]) then
                                    BuffScanner._auraSourceCache[destName] = nil
                                end
                            end
                        end
                    end
                end
            end
        elseif event == "RAID_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
            BuffScanner.dirty = true
            if event == "PLAYER_ENTERING_WORLD" then
                -- El roster de raid tarda unos segundos en llegar tras el login/zone.
                -- Forzar re-scan diferido para no depender solo de RAID_ROSTER_UPDATE.
                ns.Utils.NewTimer(4, function()
                    BuffScanner.lastFullScan = 0
                    BuffScanner.dirty = true
                end)
            end
        elseif event == "UNIT_AURA" then
            local unit = ...
            if unit and (unit == "player" or unit:match("^raid%d+") or unit:match("^party%d+")) then
                BuffScanner.dirty = true
            end
        end
    end)
    f:Show()
    BuffScanner.dirty = true
    dbgPrint("Monitoreo de buffs activo.")
    BuffScanner.Tick()
end

-- Export isEligible and SendChatLine for use in other modules
BuffScanner.isEligible = isEligible
BuffScanner.SendChatLine = sendChatLine

ns.BuffScanner = BuffScanner
