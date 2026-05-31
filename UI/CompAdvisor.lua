-- RaidStation :: UI/CompAdvisor.lua
-- Tooltip informativo de composicion de banda para el tab Anunciador.
-- Lee BuffScanner.cachedState (ya disponible) e infiere rol por subgrupo.
-- Sin inspecciones, sin lag, solo lectura del estado existente.
-- Part of RaidStation by Marfyn- | 2026
local addonName, ns = ...

local CompAdvisor = {}

-- ============================================================
-- CONFIGURACION: que se espera por subgrupo segun raid/size
-- ============================================================

-- Roles esperados por grupo segun convencion del servidor:
-- G1-G2: melee/tank  G3-G4: caster/ranged  G5: healer
local GROUP_ROLE = {
    [1] = "melee",  [2] = "melee",
    [3] = "caster", [4] = "caster",
    [5] = "healer",
}

-- Clases que se consideran melee (para validar G1-G2)
local MELEE_CLASSES = {
    WARRIOR=true, ROGUE=true, DEATHKNIGHT=true,
    PALADIN=true, -- Ret en G1-G2
    DRUID=true,   -- Feral en G1-G2
    SHAMAN=true,  -- Enhancement en G1-G2
}

-- Clases que se consideran caster/ranged (para validar G3-G4)
local CASTER_CLASSES = {
    MAGE=true, WARLOCK=true, PRIEST=true,
    DRUID=true,  -- Boomkin en G3-G4
    SHAMAN=true, -- Elemental en G3-G4
    HUNTER=true,
    DEATHKNIGHT=true, -- Unholy DK a veces va en G3-G4
}

-- Clases que healean (para validar G5)
local HEALER_CLASSES = {
    PALADIN=true, PRIEST=true, DRUID=true, SHAMAN=true,
}

-- ============================================================
-- PERFILES DE COMPOSICION DESEADA
-- clave: raidName .. "_" .. size .. "_" .. diff
-- ============================================================

-- Cada entrada de slot:
--   label    = texto que se muestra en el tooltip
--   classes  = tabla de classTokens que cubren ese slot
--   count    = cuantos se esperan en la banda
--   critical = true si es bloqueante (rojo), false = advertencia (amarillo)
--   note     = nota extra que aparece en el tooltip

local PROFILES = {}

-- Helpers para construir perfiles
local function slot(label, classes, count, critical, note)
    return { label=label, classes=classes, count=count or 1,
             critical=(critical ~= false), note=note }
end

-- ==== ICC 25N ====
PROFILES["ICC_25_N"] = {
    -- Tanks
    slot("Prot Paladin (MT)", {"PALADIN"}, 1, true),
    slot("Tank DK / Warr", {"DEATHKNIGHT","WARRIOR"}, 1, true),

    -- Healers (G5)
    slot("Holy Paladin", {"PALADIN"}, 1, true, "1 obligatorio para tank healing"),
    slot("Healer Comodin (Chaman/Dudu/Sacer)", {"SHAMAN","DRUID","PRIEST"}, 1, false, "Healer extra para soporte de banda"),
    slot("Disc Priest", {"PRIEST"}, 1, true),
    slot("Resto Shaman (Bloodlust)", {"SHAMAN"}, 1, true, "Bloodlust obligatorio"),
    slot("Resto Druid / Holy Priest", {"DRUID","PRIEST"}, 1, false),

    -- Buffs criticos por clase (G1-G4)
    slot("Unholy DK (Ebon Plague +13%)", {"DEATHKNIGHT"}, 1, true,
         "Aumenta todo el dano magico en 13%"),
    slot("Shadow Priest (Replenishment)", {"PRIEST"}, 1, true,
         "Replenishment + 3% spell hit (Misery)"),
    slot("Balance Druid (Spell Haste/Hit)", {"DRUID"}, 1, true,
         "3% haste, 3% spell hit, Faerie Fire"),
    slot("Demo Warlock (Demonic Pact)", {"WARLOCK"}, 1, false,
         "10% SP del lock al grupo"),
    slot("Enhancement/Elemental Shaman", {"SHAMAN"}, 1, true,
         "Windfury Totem / Wrath of Air Totem"),
    slot("Ret Paladin (Vindication)", {"PALADIN"}, 1, true,
         "Replenishment + reduce AP del boss"),
    slot("Mage (Arcane Int)", {"MAGE"}, 1, false),
    slot("Hunter (Trueshot Aura)", {"HUNTER"}, 1, false),
    slot("Feral Druid (Leader of the Pack)", {"DRUID"}, 1, false,
         "5% melee crit + Rebirth extra"),
}

-- ==== ICC 25H ====
PROFILES["ICC_25_H"] = {
    slot("Prot Paladin (MT)", {"PALADIN"}, 1, true),
    slot("Blood DK (Off-Tank)", {"DEATHKNIGHT"}, 1, true,
         "10% AP + 20% melee haste + Hysteria"),

    slot("Holy Paladin", {"PALADIN"}, 1, true),
    slot("Healer Comodin (Dudu/Chaman/Sacer)", {"DRUID","SHAMAN","PRIEST"}, 1, false, "Soporte de banda flexible"),
    slot("Disc Priest", {"PRIEST"}, 1, true),
    slot("Resto Shaman (Bloodlust)", {"SHAMAN"}, 1, true),
    slot("Resto Druid / Holy Priest", {"DRUID","PRIEST"}, 1, false),

    slot("Unholy DK (Ebon Plague)", {"DEATHKNIGHT"}, 1, true,
         "CRITICO: +13% dano magico raid"),
    slot("Shadow Priest (Replenishment x1)", {"PRIEST"}, 1, true,
         "25H necesita min 2 fuentes de Replen"),
    slot("Ret Paladin (Replenishment x2)", {"PALADIN"}, 1, true,
         "Segunda fuente de Replenishment"),
    slot("Balance Druid", {"DRUID"}, 1, true,
         "3% haste + 3% spell hit + CC Cyclone"),
    slot("Druid extra (Cyclone Lady DW)", {"DRUID"}, 2, true,
         "Lady DW MC 3 targets, necesitas 3 Cyclones"),
    slot("Demo Warlock (Demonic Pact)", {"WARLOCK"}, 1, true),
    slot("Enhancement/Elemental Shaman", {"SHAMAN"}, 1, true),
    slot("Mage", {"MAGE"}, 1, false),
    slot("Hunter", {"HUNTER"}, 1, false),
}

-- ==== ICC 10N ====
PROFILES["ICC_10_N"] = {
    slot("Tank principal", {"PALADIN","DEATHKNIGHT","WARRIOR","DRUID"}, 1, true),
    slot("Off-tank / flex", {"PALADIN","DEATHKNIGHT","WARRIOR","DRUID"}, 1, false),
    slot("Holy Paladin", {"PALADIN"}, 1, true),
    slot("Disc Priest", {"PRIEST"}, 1, true),
    slot("Bloodlust (Shaman)", {"SHAMAN"}, 1, true),
    slot("Replenishment", {"PRIEST","PALADIN","HUNTER","WARLOCK","MAGE"}, 1, true,
         "SPriest / Ret / Surv / Destro / Frost"),
    slot("Unholy DK o Balance Druid", {"DEATHKNIGHT","DRUID"}, 1, false,
         "Ebon Plague o Earth & Moon (+magia)"),
    slot("DPS caster o ranged", {"MAGE","WARLOCK","HUNTER","DRUID","PRIEST"}, 2, false),
    slot("DPS melee", {"WARRIOR","ROGUE","DEATHKNIGHT","PALADIN","SHAMAN","DRUID"}, 2, false),
}

-- ==== SR 25N (Sartharion 0D) ====
PROFILES["SR_25_N"] = {
    slot("Tank principal (Sarth)", {"PALADIN","DEATHKNIGHT","WARRIOR"}, 1, true),
    slot("Off-tank (adds/drakes)", {"PALADIN","DEATHKNIGHT","WARRIOR","DRUID"}, 1, true),
    slot("Bloodlust", {"SHAMAN"}, 1, true),
    slot("Healer", {"PALADIN","PRIEST","DRUID","SHAMAN"}, 3, false),
}

-- ==== SR 25H (Sartharion 3 Drakes) ====
PROFILES["SR_25_H"] = {
    slot("Tank principal (Sarth)", {"PALADIN"}, 1, true,
         "Paladin MT recomendado por CDs"),
    slot("Drake/Add Tank (Paladin)", {"PALADIN"}, 1, true,
         "Consecration para picks multiples"),
    slot("Healer (min 5)", {"PALADIN","PRIEST","DRUID","SHAMAN"}, 5, true,
         "Rotacion CDs: Pain Suppression + Guardian Spirit"),
    slot("Bloodlust", {"SHAMAN"}, 1, true),
    slot("Rogue (dispel enrage Elementales)", {"ROGUE"}, 1, true,
         "OBLIGATORIO: Fan of Knives con veneno"),
    slot("DPS alto burst", {"MAGE","WARLOCK","HUNTER","DRUID"}, 3, false,
         "Matar Tenebron antes del 2do wave de adds"),
}

-- ==== TOC 25N ====
PROFILES["TOC_25_N"] = {
    slot("Tank", {"PALADIN","DEATHKNIGHT","WARRIOR","DRUID"}, 2, true),
    slot("Healer", {"PALADIN","PRIEST","DRUID","SHAMAN"}, 5, false),
    slot("Bloodlust", {"SHAMAN"}, 1, true),
    slot("Replenishment", {"PRIEST","PALADIN","HUNTER","WARLOCK","MAGE"}, 1, true),
    slot("DPS melee", {"WARRIOR","ROGUE","DEATHKNIGHT","PALADIN","SHAMAN","DRUID"}, 4, false),
    slot("DPS ranged", {"MAGE","WARLOCK","HUNTER","DRUID","PRIEST","SHAMAN"}, 4, false),
}

-- ==== TOC 25H ====
PROFILES["TOC_25_H"] = {
    slot("Prot Paladin (MT)", {"PALADIN"}, 1, true),
    slot("Off-tank DK / Warr", {"DEATHKNIGHT","WARRIOR"}, 1, true),
    slot("Holy Paladin x2", {"PALADIN"}, 2, true),
    slot("Disc Priest", {"PRIEST"}, 1, true),
    slot("Resto Shaman (Bloodlust)", {"SHAMAN"}, 1, true),
    slot("Unholy DK (Ebon Plague)", {"DEATHKNIGHT"}, 1, true),
    slot("Shadow Priest / Ret (Replen)", {"PRIEST","PALADIN"}, 1, true),
    slot("Balance Druid", {"DRUID"}, 1, false),
    slot("Demo Warlock", {"WARLOCK"}, 1, false),
}

-- ==== SEMANAL / ULDUAR / generico ====
PROFILES["SEMANAL_10_N"] = {
    slot("Tank", {"PALADIN","DEATHKNIGHT","WARRIOR","DRUID"}, 1, true),
    slot("Healer", {"PALADIN","PRIEST","DRUID","SHAMAN"}, 2, false),
    slot("Bloodlust", {"SHAMAN"}, 1, false),
    slot("DPS", {"WARRIOR","ROGUE","DEATHKNIGHT","MAGE","WARLOCK","HUNTER","DRUID","PRIEST","SHAMAN","PALADIN"}, 7, false),
}

PROFILES["ULDUAR_25_N"] = {
    slot("Tank", {"PALADIN","DEATHKNIGHT","WARRIOR","DRUID"}, 2, true),
    slot("Holy Paladin", {"PALADIN"}, 1, true),
    slot("Disc Priest", {"PRIEST"}, 1, true),
    slot("Bloodlust", {"SHAMAN"}, 1, true),
    slot("Healer extra", {"DRUID","SHAMAN","PRIEST"}, 2, false),
    slot("Unholy DK o Boomkin", {"DEATHKNIGHT","DRUID"}, 1, false),
    slot("DPS melee", {"WARRIOR","ROGUE","DEATHKNIGHT","PALADIN"}, 3, false),
    slot("DPS ranged", {"MAGE","WARLOCK","HUNTER","DRUID","PRIEST"}, 5, false),
}

-- ============================================================
-- LOGICA CENTRAL
-- ============================================================

-- Cuenta cuantos miembros del roster cumplen con la lista de clases
-- Retorna: count_found, lista de nombres que lo cubren
local function countInRoster(rosterByClass, classes)
    local found = 0
    local names = {}
    for _, cls in ipairs(classes) do
        if rosterByClass[cls] then
            for _, name in ipairs(rosterByClass[cls]) do
                found = found + 1
                table.insert(names, name)
            end
        end
    end
    return found, names
end

-- Construye un mapa { classToken = {name1, name2, ...} } desde cachedState
local function buildRosterByClass()
    local byClass = {}
    local state = ns.BuffScanner and ns.BuffScanner.GetRaidBuffState and
                  ns.BuffScanner.GetRaidBuffState()
    if not state or not state.inRaid then return byClass end

    for sg, gdata in pairs(state.groups) do
        for _, p in ipairs(gdata.players) do
            local cls = p.classToken
            if not byClass[cls] then byClass[cls] = {} end
            table.insert(byClass[cls], p.name)
        end
    end
    return byClass
end

-- Resultado del analisis: lista de { label, status, have, need, note }
-- status: "ok" | "warn" | "missing"
function CompAdvisor.Analyze()
    local p   = ns.Advertiser and ns.Advertiser.patterns
    if not p then return {} end

    local raidName = p.raidName or "ICC"
    local size     = tostring(p.totalCount or 25)
    local diff     = p.difficulty or "N"
    local key      = raidName .. "_" .. size .. "_" .. diff

    local profile = PROFILES[key]
    if not profile then
        -- Intentar fallback a N si no hay perfil H especifico
        local fallbackKey = raidName .. "_" .. size .. "_N"
        profile = PROFILES[fallbackKey]
    end
    if not profile then return nil end -- sin perfil para este raid

    local byClass = buildRosterByClass()
    local results = {}

    for _, s in ipairs(profile) do
        local found, _ = countInRoster(byClass, s.classes)
        local status
        if found >= s.count then
            status = "ok"
        elseif found > 0 then
            -- tiene algo pero menos de lo pedido
            status = s.critical and "missing" or "warn"
        else
            status = s.critical and "missing" or "warn"
        end
        table.insert(results, {
            label    = s.label,
            status   = status,
            have     = found,
            need     = s.count,
            note     = s.note,
            critical = s.critical,
        })
    end

    return results
end

-- ============================================================
-- UI: boton pequeño + GameTooltip en hover
-- ============================================================

function CompAdvisor.CreateButton(parent)
    -- Boton de 18x18 con icono de lupa/estrella
    local btn = CreateFrame("Button", "RaidStationCompAdvisorBtn", parent)
    btn:SetSize(18, 18)

    -- Icono: usamos el icono de buff de raid (estrella dorada)
    -- Interface\Icons\Spell_Holy_MindVision es una lupa conocida en 3.3.5a
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Icons\\Spell_Holy_MindVision")
    btn.tex = tex

    -- Borde sutil al hacer hover
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    -- Tooltip en hover
    btn:SetScript("OnEnter", function(self)
        CompAdvisor.ShowTooltip(self)
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click: fuerza un re-scan y refresca el tooltip
    btn:SetScript("OnClick", function(self)
        if ns.BuffScanner then
            ns.BuffScanner.RequestScan(true)
        end
        CompAdvisor.ShowTooltip(self)
    end)

    CompAdvisor.btn = btn
    return btn
end

function CompAdvisor.ShowTooltip(anchor)
    local results = CompAdvisor.Analyze()

    GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    local p = ns.Advertiser and ns.Advertiser.patterns
    local raidName = (p and p.raidName) or "Raid"
    local size     = tostring((p and p.totalCount) or 25)
    local diff     = (p and p.difficulty) or "N"

    -- Titulo
    GameTooltip:AddLine(raidName .. " " .. size .. diff .. " — Composicion", 1, 0.82, 0)

    if not results then
        GameTooltip:AddLine("Sin perfil para esta configuracion.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
        return
    end

    -- Verificar si hay algo que reportar
    local hayFaltantes = false
    for _, r in ipairs(results) do
        if r.status ~= "ok" then hayFaltantes = true; break end
    end

    if not hayFaltantes then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Composicion completa.", 0.2, 1, 0.2)
        GameTooltip:Show()
        return
    end

    -- Separador
    GameTooltip:AddLine(" ")

    -- Primero: faltantes criticos (rojo)
    local hayCriticos = false
    for _, r in ipairs(results) do
        if r.status == "missing" and r.critical then
            if not hayCriticos then
                GameTooltip:AddLine("Faltantes:", 1, 0.2, 0.2)
                hayCriticos = true
            end
            local label = r.label
            local detail = r.have .. "/" .. r.need
            GameTooltip:AddDoubleLine(
                "  " .. label,
                detail,
                1, 0.3, 0.3,   -- rojo izquierda
                1, 0.4, 0.4    -- rojo derecha
            )
            if r.note then
                GameTooltip:AddLine("    " .. r.note, 0.6, 0.4, 0.4)
            end
        end
    end

    -- Luego: advertencias (amarillo) — faltantes no criticos
    local hayWarn = false
    for _, r in ipairs(results) do
        if r.status == "warn" or (r.status == "missing" and not r.critical) then
            if not hayWarn then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Recomendados:", 1, 0.82, 0)
                hayWarn = true
            end
            local label = r.label
            local detail = r.have .. "/" .. r.need
            GameTooltip:AddDoubleLine(
                "  " .. label,
                detail,
                1, 0.82, 0.2,  -- amarillo izquierda
                1, 0.82, 0.2   -- amarillo derecha
            )
            if r.note then
                GameTooltip:AddLine("    " .. r.note, 0.6, 0.6, 0.3)
            end
        end
    end

    -- Footer
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click para re-escanear la banda.", 0.4, 0.4, 0.4)
    GameTooltip:Show()
end

-- ============================================================
-- AUTO-REFRESH: escucha RAID_ROSTER_UPDATE para invalidar
-- ============================================================

function CompAdvisor.Initialize()
    local f = CreateFrame("Frame", "RaidStationCompAdvisorEvents", UIParent)
    f:RegisterEvent("RAID_ROSTER_UPDATE")
    f:RegisterEvent("PARTY_MEMBERS_CHANGED")
    f:SetScript("OnEvent", function()
        -- Si el tooltip esta visible y anclado a nuestro boton, refrescarlo
        if GameTooltip:IsVisible() and CompAdvisor.btn and
           GameTooltip:GetOwner() == CompAdvisor.btn then
            CompAdvisor.ShowTooltip(CompAdvisor.btn)
        end
    end)
end

ns.CompAdvisor = CompAdvisor