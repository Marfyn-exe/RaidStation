-- RaidStation :: UI/BuffTab.lua
-- Pestaña Buffs: lista por grupos, iconos de estado y anuncios.
local addonName, ns = ...
local BuffData = ns.BuffData
local BuffScanner = ns.BuffScanner

local BuffTab = {
    panel = nil,
    scroll = nil,
    content = nil,
    lines = {},
    assignmentHost = nil,
}

local RAID_CLASS_COLORS = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
local tinsert = table.insert
local tsort = table.sort
local floor = math.floor

local function sysMsg(msg)
    local prefix = ns.GUI and ns.GUI.ColorText and ns.GUI.ColorText("[Buffs]") or "|cFF5B9BD5[Buffs]|r"
    print(prefix .. ": " .. tostring(msg))
end
local ceil = math.ceil

local function skinBtn(btn)
    if ns.GUI and ns.GUI.SkinButton then
        ns.GUI.SkinButton(btn, true)
    end
end

local function fmtMinutos(sec)
    if not sec or sec <= 0 then return "0" end
    return tostring(ceil(sec / 60))
end

local function estadoLinea(st, def)
    if not st.present then
        return "Estado: FALTA"
    end
    if st.urgent and st.remaining and st.remaining > 0 then
        return "Estado: URGENTE — expira en menos de " .. fmtMinutos(st.remaining) .. " min"
    end
    if st.expirationTime and st.expirationTime > 0 and st.remaining and st.remaining > 0 then
        local q = (st.quality == "superior") and "superior" or "menor"
        return "Estado: Activo (" .. q .. ") — expira en " .. fmtMinutos(st.remaining) .. " min"
    end
    local q = (st.quality == "superior") and "superior" or "menor"
    return "Estado: Activo (" .. q .. ") — sin temporizador en el juego"
end

local function categoriasActivas()
    local db = RaidStationDB or {}
    return db.buffTab_checkRaid ~= false,
        db.buffTab_checkPaladin ~= false,
        db.buffTab_checkConsumables == true
end

local function defVisible(def, raid, pala, cons)
    if def.tipo == "raid" then return raid end
    if def.tipo == "paladin" then return pala end
    if def.tipo == "consumible" then return cons end
    return false
end

local function listaDefsVisibles()
    local raid, pala, cons = categoriasActivas()
    local out = {}
    for _, def in ipairs(BuffData.DEFINITIONS) do
        if defVisible(def, raid, pala, cons) then
            tinsert(out, def)
        end
    end
    return out
end

local function cuentaFaltantesJugador(p, defs)
    local n = 0
    for _, def in ipairs(defs) do
        -- Respetar neverFor: si el buff no aplica a esta clase, no contar como faltante
        if BuffScanner.isEligible(def, p.classToken) then
            local st = p.buffs[def.id]
            if st and not st.present then
                n = n + 1
            end
        end
    end
    return n
end

local function jugadorTieneAlgoQueMostrar(p, defs, soloFaltantes)
    if not soloFaltantes then return true end
    return cuentaFaltantesJugador(p, defs) > 0
end

local function hideLinePool()
    for _, w in ipairs(BuffTab.lines) do
        w:Hide()
    end
end

local function acquireLine()
    for _, w in ipairs(BuffTab.lines) do
        if not w:IsShown() then return w end
    end
    local parent = BuffTab.content
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)
    row.icons = {}
    row.nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameFs:SetPoint("LEFT", 18, 0)
    row.nameFs:SetWidth(64)
    row.nameFs:SetJustifyH("LEFT")
    row:SetWidth(332)
    tinsert(BuffTab.lines, row)
    return row
end

local function ensureIconButtons(row, nIcons)
    for i = 1, nIcons do
        if not row.icons[i] then
            local btn = CreateFrame("Button", nil, row)
            btn:SetSize(18, 18)

            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
                edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            btn:SetBackdropColor(0, 0, 0, 1)
            btn:SetBackdropBorderColor(0, 0, 0, 1)

            local t = btn:CreateTexture(nil, "ARTWORK")
            t:SetPoint("TOPLEFT", 1, -1)
            t:SetPoint("BOTTOMRIGHT", -1, 1)
            t:SetTexCoord(0.15, 0.85, 0.15, 0.85)
            btn.icon = t

            -- No llamar SkinButton aquí: estos botones manejan su propio
            -- backdrop negro e ícono ARTWORK. SkinButton inyectaría otra
            -- textura ARTWORK gris encima que taparía el ícono del buff.
            local border = CreateFrame("Frame", nil, btn)
            border:SetPoint("TOPLEFT", -1, 1)
            border:SetPoint("BOTTOMRIGHT", 1, -1)
            border:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
                edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            border:SetBackdropBorderColor(1, 0.9, 0.2, 1)
            border:Hide()
            btn.border = border
            row.icons[i] = btn
        end
    end
    for i = nIcons + 1, #row.icons do
        row.icons[i]:Hide()
    end
end

local function layoutRowIcons(row, defs, p, startX)
    local x = startX
    for i, def in ipairs(defs) do
        local btn = row.icons[i]
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", row, "LEFT", x, 0)

        local eligible = ns.BuffScanner.isEligible(def, p.classToken)
        if not eligible then
            btn:SetAlpha(0)
            btn:Show()
            btn:EnableMouse(false)
        else
            btn:SetAlpha(1)
            btn:EnableMouse(true)
            btn:Show()
            local st = p.buffs[def.id]
            local tex
            if st and st.present and st.matchedSpellId then
                tex = select(3, GetSpellInfo(st.matchedSpellId))
            end
            tex = tex or BuffData._iconCache[def.id] or "Interface\\Icons\\INV_Misc_QuestionMark"
            btn.icon:SetTexture(tex)
            if st.present then
                btn.icon:SetDesaturated(false)
                if st.wrongCaster then
                    -- Buff presente pero dado por jugador no asignado
                    btn.icon:SetVertexColor(1, 0.65, 0)
                    btn.border:SetBackdropBorderColor(1, 0.5, 0, 1)
                    btn.border:Show()
                elseif st.urgent then
                    -- URGENTE: rojo (no usado por otra funcion en esta pestaña)
                    btn.icon:SetVertexColor(1, 0.35, 0.35)
                    btn.border:SetBackdropBorderColor(1, 0.25, 0.25, 1)
                    btn.border:Show()
                else
                    btn.icon:SetVertexColor(1, 1, 1)
                    btn.border:Hide()
                end
            else
                btn.icon:SetDesaturated(true)
                btn.icon:SetVertexColor(0.45, 0.45, 0.45)
                btn.border:Hide()
            end
            btn.defId = def.id
            btn.buffState = st
            btn:SetScript("OnEnter", function(self)
                local eligible = ns.BuffScanner.isEligible(def, p.classToken)
                if not eligible then
                    return
                end
                local d = BuffData.GetDefinitionById(self.defId)
                if not d then return end
                local pst = self.buffState
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(d.nombre, ns.GUI.GetAccentColor())

                if pst then
                    GameTooltip:AddLine(pst.responsableTooltip or "", 0.85, 0.85, 1, true)
                    GameTooltip:AddLine(estadoLinea(pst, d), 0.7, 1, 0.7, true)
                    if pst.wrongCaster and pst.wrongCasterName then
                        GameTooltip:AddLine("Buff dado por: " .. pst.wrongCasterName .. " (no el asignado)", 1, 0.4, 0.4, true)
                    end
                end

                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            btn:SetScript("OnClick", function(self)
                if not st or st.present or st.skip then return end
                local link = BuffData.GetSpellLink(def) or def.jerga or def.nombre
                BuffScanner.SendChatLine("[Buffs] " .. p.name .. " le falta: " .. link)
            end)
        end
        x = x + 20
    end
end

function BuffTab.Refresh()
    if not BuffTab.panel or not BuffTab.panel:IsShown() then return end
    hideLinePool()
    local defs = listaDefsVisibles()
    local soloFaltantes = RaidStationDB and (RaidStationDB.buffTab_showAll == false)
    local state = BuffScanner.GetRaidBuffState()
    local y = 4
    if #defs == 0 then
        local row = acquireLine()
        row:Show()
        row:SetPoint("TOPLEFT", BuffTab.content, "TOPLEFT", 0, -y)
        row:SetHeight(36)
        row.nameFs:SetWidth(320)
        row.nameFs:SetText("Activa al menos una categoria arriba (Banda / Paladin / Consumibles).")
        row.nameFs:SetTextColor(ns.GUI.GetAccentColor())
        for _, ic in ipairs(row.icons) do ic:Hide() end
        BuffTab.content:SetHeight(44)
        return
    end
    if not state.inRaid then
        local row = acquireLine()
        row:Show()
        row:SetPoint("TOPLEFT", BuffTab.content, "TOPLEFT", 0, -y)
        row:SetHeight(40)
        row.nameFs:SetWidth(320)
        row.nameFs:SetText("No estas en banda. Entra a una raid para ver buffs.")
        row.nameFs:SetTextColor(ns.GUI.GetAccentColor())
        for _, ic in ipairs(row.icons) do ic:Hide() end
        BuffTab.content:SetHeight(48)
        return
    end
    local subs = {}
    for sg, _ in pairs(state.groups) do
        tinsert(subs, sg)
    end
    tsort(subs)
    local anyLine = false
    for _, sg in ipairs(subs) do
        if sg >= 1 and sg <= 5 then
            local gdata = state.groups[sg]
            local visiblePlayers = {}
            for _, p in ipairs(gdata.players) do
                if jugadorTieneAlgoQueMostrar(p, defs, soloFaltantes) then
                    tinsert(visiblePlayers, p)
                end
            end
            if #visiblePlayers == 0 then
                -- ocultar grupo entero en modo solo faltantes
            else
                anyLine = true
                local missGrp = 0
                for _, p in ipairs(visiblePlayers) do
                    missGrp = missGrp + cuentaFaltantesJugador(p, defs)
                end
                local hdr = acquireLine()
                hdr:Show()
                hdr:SetPoint("TOPLEFT", BuffTab.content, "TOPLEFT", 0, -y)
                hdr:SetHeight(18)
                hdr.nameFs:SetWidth(320)
                hdr.nameFs:SetText("Grupo " .. tostring(sg) .. " — Buffs faltan (" .. tostring(missGrp) .. ")")
                hdr.nameFs:SetTextColor(ns.GUI.GetAccentColor())
                for _, ic in ipairs(hdr.icons) do ic:Hide() end
                y = y + 18
                for _, p in ipairs(visiblePlayers) do
                    local row = acquireLine()
                    row:Show()
                    row:SetPoint("TOPLEFT", BuffTab.content, "TOPLEFT", 0, -y)
                    ensureIconButtons(row, #defs)
                    local col = RAID_CLASS_COLORS[p.classToken]
                    if col then
                        row.nameFs:SetTextColor(col.r, col.g, col.b)
                    else
                        row.nameFs:SetTextColor(1, 1, 1)
                    end
                    row.nameFs:SetWidth(64)
                    row.nameFs:SetText(p.name)
                    layoutRowIcons(row, defs, p, 82)
                    y = y + 18
                end
            end
        end
    end
    if state.inRaid and not anyLine and #defs > 0 then
        local row = acquireLine()
        row:Show()
        row:SetPoint("TOPLEFT", BuffTab.content, "TOPLEFT", 0, -y)
        row:SetHeight(28)
        row.nameFs:SetWidth(320)
        row.nameFs:SetText("OK: no faltan buffs con las categorias y el filtro actuales.")
        row.nameFs:SetTextColor(0.7, 1, 0.7)
        for _, ic in ipairs(row.icons) do ic:Hide() end
        y = y + 30
    end
    BuffTab.content:SetHeight(math.max(y + 8, 80))
end

function BuffTab.OnScannerUpdated()
    BuffTab.Refresh()
end

function BuffTab.Initialize()
    if BuffTab.panel then return end
    local parent = ns.GUI and ns.GUI.MainFrame
    if not parent then return end

    local p = CreateFrame("Frame", "RaidStationBuffTabPanel", parent)
    -- Ajustado para encajar bien dentro del shell principal
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, -60)
    p:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -15, 36)

    -- Aplicar marco oscuro para resaltar el contenido (estilo panel interno)
    p:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    p:SetBackdropColor(0.08, 0.08, 0.08, 0.6)
    p:SetBackdropBorderColor(0, 0, 0, 1)

    p:Hide()
    BuffTab.panel = p

    local function setConsumeFlag(value)
        RaidStationDB.buffTab_checkConsumables = value and true or false
    end

    local function createCompactCheck(name, label, anchorTo, x, y, tipTitle, tipBody, defaultValue, onClick)
        local cb

        if ns.GUI and ns.GUI.CreateSwitch then
            cb = ns.GUI.CreateSwitch(p, label, defaultValue, function(v)
                if onClick then onClick(cb, v and true or false) end
            end, 104, 20)
        else
            cb = CreateFrame("CheckButton", name, p, "UICheckButtonTemplate")
            cb:SetSize(16, 16)
            cb:SetHitRectInsets(0, 0, 0, 0)
            cb.text = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            cb.text:SetText("|cffc7c7c7" .. label .. "|r")
            cb:SetScript("OnClick", function(self)
                if onClick then onClick(self, self:GetChecked() and true or false) end
            end)
            if ns.GUI and ns.GUI.SkinCheckBox then
                ns.GUI.SkinCheckBox(cb)
            end
            cb:SetChecked(defaultValue and true or false)
        end

        if anchorTo then
            cb:SetPoint("LEFT", anchorTo, "RIGHT", x, y)
        else
            cb:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
        end
        cb:SetFrameLevel(p:GetFrameLevel() + 12)

        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(tipTitle or label, ns.GUI.GetAccentColor())
            if tipBody then
                GameTooltip:AddLine(tipBody, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return cb
    end

    local y0 = 20
    local cbRaid = createCompactCheck(
        "RSBuffTabCBRaid",
        "Raid Buffs",
        nil,
        25,
        y0,
        "Raid Buffs",
        "Muestra e incluye en el anuncio de rezos, don salvaje e intelecto.",
        RaidStationDB.buffTab_checkRaid ~= false,
        function(self, v)
            RaidStationDB.buffTab_checkRaid = v and true or false
            BuffTab.Refresh()
        end
    )

    local cbPala = createCompactCheck(
        "RSBuffTabCBPala",
        "Paladin Buffs",
        cbRaid,
        12,
        0,
        "Paladin Buffs",
        "Muestra bendiciones y respeta las asignaciones del bloque inferior de esta pestana.",
        RaidStationDB.buffTab_checkPaladin ~= false,
        function(self, v)
            RaidStationDB.buffTab_checkPaladin = v and true or false
            BuffTab.Refresh()
        end
    )

    local cbCons = createCompactCheck(
        "RSBuffTabCBCons",
        "Consumibles",
        cbPala,
        12,
        0,
        "Consumibles",
        "Muestra frasco y comida en la lista de iconos.",
        (RaidStationDB.buffTab_checkConsumables == true),
        function(self, v)
            setConsumeFlag(v and true or false)
            BuffTab.Refresh()
        end
    )

    local row2y = -30
    local btnScan = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnScan:SetSize(72, 22)
    btnScan:SetPoint("TOPLEFT", 35, row2y)
    btnScan:SetText("Escanear")
    btnScan:SetScript("OnClick", function()
        BuffScanner.RequestScan(true)
        BuffScanner.PerformFullScan()
        sysMsg("Escaneo actualizado.")
        BuffTab.Refresh()
    end)
    btnScan:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Escanear", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Fuerza una lectura inmediata de auras del raid (respeta el motor de eventos).", 1, 1, 1,
            true)
        GameTooltip:Show()
    end)
    btnScan:SetScript("OnLeave", function() GameTooltip:Hide() end)
    skinBtn(btnScan)

    local btnAnn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnAnn:SetSize(70, 22)
    btnAnn:SetPoint("LEFT", btnScan, "RIGHT", 6, 0)
    btnAnn:SetText("Anunciar")
    btnAnn:SetScript("OnClick", function()
        local r, pa, c = categoriasActivas()
        BuffScanner.AnnounceMissingForCategories(r, pa, c)
    end)
    btnAnn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Anunciar seleccionados", ns.GUI.GetAccentColor())
        GameTooltip:AddLine(
            "Envia al canal configurado la lista de jugadores con FALTA segun las casillas de categoria.", 1, 1, 1, true)
        GameTooltip:AddLine("Hay un enfriamiento de 10 segundos entre anuncios.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    btnAnn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    skinBtn(btnAnn)

    -- Botón principal del selector de canal
    local chanBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    chanBtn:SetSize(70, 20)
    chanBtn:SetPoint("LEFT", btnAnn, "RIGHT", 4, 0)
    if ns.GUI and ns.GUI.SkinButton then ns.GUI.SkinButton(chanBtn, true) end

    -- Popup con las 3 opciones (parented al panel p, ajustamos posición)
    local chanPopup
    if ns.GUI and ns.GUI.CreateBox then
        chanPopup = ns.GUI.CreateBox(p, 80, 52)
        chanPopup:SetFrameStrata("TOOLTIP")
        chanPopup:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
        chanPopup:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        chanPopup:Hide()
    else
        chanPopup = CreateFrame("Frame", nil, p)
        chanPopup:SetSize(80, 52)
        chanPopup:SetFrameStrata("TOOLTIP")
        chanPopup:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        chanPopup:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
        chanPopup:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        chanPopup:Hide()
    end

    local chanOptions = {
        { text = "Solo yo", value = "SELF" },
        { text = "Banda",   value = "RAID" },
        { text = "Alerta",  value = "RAID_WARNING" },
    }

    local function setChannel(value, text)
        RaidStationDB.buffAnnounceChannel = value
        chanBtn:SetText(text)
        chanPopup:Hide()
    end

    -- Crear los 3 botones del popup
    for i, opt in ipairs(chanOptions) do
        local ob = CreateFrame("Button", nil, chanPopup)
        ob:SetHeight(16)
        ob:SetPoint("TOPLEFT", chanPopup, "TOPLEFT", 4, -(i - 1) * 17 - 2)
        ob:SetPoint("TOPRIGHT", chanPopup, "TOPRIGHT", -4, -(i - 1) * 17 - 2)
        if ns.GUI and ns.GUI.SkinButton then ns.GUI.SkinButton(ob, true) end
        local fs = ob:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetAllPoints()
        fs:SetJustifyH("LEFT")
        fs:SetText(opt.text)
        ob:SetScript("OnClick", function()
            setChannel(opt.value, opt.text)
        end)
        ob:SetScript("OnEnter", function(self)
            fs:SetTextColor(1, 1, 1)
        end)
        ob:SetScript("OnLeave", function(self)
            fs:SetTextColor(0.8, 0.8, 0.8)
        end)
        fs:SetTextColor(0.8, 0.8, 0.8)
    end

    -- Toggle del popup
    chanBtn:SetScript("OnClick", function(self)
        if chanPopup:IsShown() then
            chanPopup:Hide()
        else
            chanPopup:ClearAllPoints()
            -- Anclamos el popup al botón de forma dinámica
            chanPopup:SetPoint("BOTTOMLEFT", chanBtn, "TOPLEFT", 3, 15) -- +3 x, +15 y
            chanPopup:Show()
        end
    end)

    -- Cerrar popup al hacer click fuera
    chanPopup:SetScript("OnHide", function() end)
    local closeDetect = CreateFrame("Frame", nil, UIParent)
    closeDetect:SetAllPoints()
    closeDetect:SetFrameStrata("DIALOG")
    closeDetect:Hide()
    closeDetect:SetScript("OnMouseDown", function()
        chanPopup:Hide()
        closeDetect:Hide()
    end)
    chanPopup:HookScript("OnShow", function()
        closeDetect:Show()
    end)
    chanPopup:HookScript("OnHide", function()
        closeDetect:Hide()
    end)

    -- Aplicar valor guardado al inicializar
    local saved = (RaidStationDB and RaidStationDB.buffAnnounceChannel) or "SELF"
    for _, opt in ipairs(chanOptions) do
        if opt.value == saved then
            chanBtn:SetText(opt.text)
            break
        end
    end

    -- Guardar referencia para SyncFromDB
    BuffTab.chanBtn = chanBtn

    local btnMode = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    btnMode:SetSize(80, 22)
    btnMode:SetPoint("LEFT", chanBtn, "RIGHT", 4, 0)
    local function updateModeLabel()
        local all = RaidStationDB.buffTab_showAll ~= false
        btnMode:SetText(all and "Todos" or "Faltantes")
    end
    btnMode:SetScript("OnClick", function()
        RaidStationDB.buffTab_showAll = not (RaidStationDB.buffTab_showAll ~= false)
        updateModeLabel()
        BuffTab.Refresh()
    end)
    btnMode:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Filtro de lista", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Todos: muestra todo el raid. Solo faltantes: oculta jugadores completos y grupos vacios.", 1,
            1, 1, true)
        GameTooltip:Show()
    end)
    btnMode:SetScript("OnLeave", function() GameTooltip:Hide() end)
    skinBtn(btnMode)

    BuffTab._btnMode = btnMode
    BuffTab._updateModeLabel = updateModeLabel

    local function isDBMAvailable()
        return (
            _G["DBM"] ~= nil or
            SlashCmdList["DEADLYBOSSMODS"] ~= nil or
            SlashCmdList["DBM"] ~= nil or
            SlashCmdList["Dbm"] ~= nil
        )
    end

    -- NUEVA FILA: Controles de raid (Reposicionada arriba, bajo checkboxes)
    local raidBar = CreateFrame("Frame", nil, p)
    raidBar:SetHeight(26)
    raidBar:SetPoint("TOPLEFT", p, "TOPLEFT", 35, -10)
    raidBar:SetPoint("TOPRIGHT", p, "TOPRIGHT", -35, -10)
    BuffTab.raidBar = raidBar

    -- 1. Boton "Listos?" (Ready Check Real)
    local btnReady = CreateFrame("Button", nil, raidBar, "UIPanelButtonTemplate")
    btnReady:SetSize(60, 20)
    btnReady:SetPoint("LEFT", 0, 0)
    btnReady:SetText("Listos?")
    btnReady:SetScript("OnClick", function()
        if GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 then
            DoReadyCheck()
        else
            local prefix = ns.GUI and ns.GUI.ColorText and ns.GUI.ColorText("[Buffs]") or "|cFF5B9BD5[Buffs]|r"
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. ": Debes estar en banda para usar Ready Check.", 1, 0.4, 0.4)
        end
    end)
    btnReady:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Ready Check", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Envia un Ready Check a toda la banda.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnReady:SetScript("OnLeave", function() GameTooltip:Hide() end)
    skinBtn(btnReady)

    -- 2. Boton "Pull"
    local btnPull = CreateFrame("Button", nil, raidBar, "UIPanelButtonTemplate")
    btnPull:SetSize(40, 20)
    btnPull:SetPoint("LEFT", btnReady, "RIGHT", 4, 0)
    btnPull:SetText("Pull")
    btnPull:SetScript("OnClick", function()
        if not isDBMAvailable() then
            sysMsg("DBM no esta instalado o activo.")
            return
        end
        local n = tonumber(BuffTab.ebSeconds:GetText()) or 10
        DEFAULT_CHAT_FRAME.editBox:SetText("/dbm pull " .. n)
        ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
    end)
    btnPull:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Pull", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Inicia Pull de DBM con el tiempo indicado.\nRequiere DBM activo.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnPull:SetScript("OnLeave", function() GameTooltip:Hide() end)
    skinBtn(btnPull)

    -- 3. EditBox numerico
    local ebSeconds = CreateFrame("EditBox", nil, raidBar)
    ebSeconds:SetSize(30, 20)
    ebSeconds:SetPoint("LEFT", btnPull, "RIGHT", 4, 0)
    ebSeconds:SetAutoFocus(false)
    ebSeconds:SetNumeric(true)
    ebSeconds:SetMaxLetters(2)
    ebSeconds:SetFontObject("GameFontHighlightSmall")
    ebSeconds:SetText(tostring(RaidStationDB and RaidStationDB.dbmPullSeconds or 10))
    ebSeconds:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText())
        if val and RaidStationDB then
            RaidStationDB.dbmPullSeconds = val
        end
    end)
    ebSeconds:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Segundos", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Tiempo en segundos para el contador de Pull.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    ebSeconds:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if ns.GUI and ns.GUI.SkinEditBox then ns.GUI.SkinEditBox(ebSeconds) end
    BuffTab.ebSeconds = ebSeconds

    -- 4. Etiqueta "seg"
    local fsSeg = raidBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fsSeg:SetPoint("LEFT", ebSeconds, "RIGHT", 2, 0)
    fsSeg:SetText("")
    fsSeg:SetTextColor(0.7, 0.7, 0.7)

    -- 5. Boton "Break" (Fijo 5 min)
    local btnBreak = CreateFrame("Button", nil, raidBar, "UIPanelButtonTemplate")
    btnBreak:SetSize(50, 20)
    btnBreak:SetPoint("LEFT", fsSeg, "RIGHT", 0, 0)
    btnBreak:SetText("Break")
    btnBreak:SetScript("OnClick", function()
        if not isDBMAvailable() then
            sysMsg("DBM no esta instalado o activo.")
            return
        end
        DEFAULT_CHAT_FRAME.editBox:SetText("/dbm break 5")
        ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
    end)
    btnBreak:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Break", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Inicia un Break (descanso) con DBM de 5 minutos.\nRequiere DBM activo.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btnBreak:SetScript("OnLeave", function() GameTooltip:Hide() end)
    skinBtn(btnBreak)

    local btnCancel = CreateFrame("Button", nil, raidBar, "UIPanelButtonTemplate")
    btnCancel:SetSize(55, 20)
    btnCancel:SetPoint("LEFT", btnBreak, "RIGHT", 6, 0)
    btnCancel:SetText("Cancel")
    btnCancel:SetScript("OnClick", function()
        if not isDBMAvailable() then
            sysMsg("DBM no esta instalado o activo.")
            return
        end
        DEFAULT_CHAT_FRAME.editBox:SetText("/dbm pull 0")
        ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
    end)
    btnCancel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Cancelar countdown", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Cancela el contador de Pull o Break activo en DBM.", 1, 1, 1, true)
        GameTooltip:AddLine("Requiere DBM activo.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    btnCancel:SetScript("OnLeave", function() GameTooltip:Hide() end)
    skinBtn(btnCancel)

    -- RE-ANCLAR botones existentes debajo de raidBar
    btnScan:ClearAllPoints()
    btnScan:SetPoint("TOPLEFT", raidBar, "BOTTOMLEFT", 0, -5)


    local assignBox = CreateFrame("Frame", nil, p)
    assignBox:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 20, 20)
    assignBox:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -20, 20)
    assignBox:SetHeight(52)

    local assignTitle = assignBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    assignTitle:SetPoint("TOPLEFT", 0, -2)
    ns.GUI.RegisterAccentLabel(assignTitle, "ASIGNACIONES")
    BuffTab._assignTitle = assignTitle

    local assignHint = assignBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    assignHint:SetPoint("TOPLEFT", assignTitle, "BOTTOMLEFT", 0, -2)
    assignHint:SetText("Paladin buffs")

    local popoutBtn = CreateFrame("Button", nil, assignBox, "UIPanelButtonTemplate")
    popoutBtn:SetSize(22, 20)
    popoutBtn:SetPoint("TOPRIGHT", assignBox, "TOPRIGHT", 0, -1)
    popoutBtn:SetText(">")
    popoutBtn:SetScript("OnClick", function()
        BuffTab.TogglePopout()
    end)
    popoutBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Ajustes de Buffs", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Abre el panel de configuracion de buffs de raid.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    popoutBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    skinBtn(popoutBtn)
    BuffTab.popoutBtn = popoutBtn

    local annAssignBtn = CreateFrame("Button", nil, assignBox, "UIPanelButtonTemplate")
    annAssignBtn:SetSize(72, 20)
    -- SetPoint se aplica después del bucle alertBtns (alertBtns[1] aún no existe aquí)
    annAssignBtn:SetText("Anunciar")
    annAssignBtn:SetScript("OnClick", function()
        if ns.BuffSettings and ns.BuffSettings.PersistAssignments then
            ns.BuffSettings.PersistAssignments()
        end
        BuffScanner.AnnouncePaladinAssignments()
    end)
    annAssignBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Anunciar asignaciones", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Envia al canal configurado las asignaciones de paladines guardadas.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    annAssignBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    skinBtn(annAssignBtn)

    local alertBtns = {}
    for i = 2, 1, -1 do
        local ab = CreateFrame("Button", nil, assignBox, "UIPanelButtonTemplate")
        ab:SetSize(34, 20)
        local anchor = (i == 2) and popoutBtn or alertBtns[2]
        ab:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
        ab.slotIndex = i
        local alerts = RaidStationDB and RaidStationDB.buffTab_alerts
        local slot = alerts and alerts[i]
        local short = slot and (slot.shortName or slot.short) or ""
        ab:SetText(short ~= "" and short:sub(1, 4) or ("A" .. i))
        ab:SetScript("OnClick", function(self)
            BuffScanner.SendPredefinedAlert(self.slotIndex)
        end)
        ab:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            local s = RaidStationDB and RaidStationDB.buffTab_alerts and RaidStationDB.buffTab_alerts[self.slotIndex]
            local sname = s and (s.shortName or s.short) or ""
            GameTooltip:SetText(sname ~= "" and sname or ("Alerta " .. self.slotIndex), ns.GUI.GetAccentColor())
            GameTooltip:AddLine("Clic para enviar mensaje de alerta rapida al canal configurado.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        ab:SetScript("OnLeave", function() GameTooltip:Hide() end)
        skinBtn(ab)
        alertBtns[i] = ab
    end
    BuffTab.alertButtons = alertBtns
    -- Anclar Anunciar a la izquierda de A1 (orden visual: [Anunciar][A1][A2][>])
    annAssignBtn:SetPoint("RIGHT", alertBtns[1], "LEFT", -4, 0)

    -- Sin scrollbar, frame directo
    local assignContent = CreateFrame("Frame", nil, assignBox)
    assignContent:SetPoint("TOPLEFT", assignBox, "TOPLEFT", 5, -32)
    assignContent:SetPoint("BOTTOMRIGHT", assignBox, "BOTTOMRIGHT", 0, 0)
    BuffTab.assignmentHost = assignContent
    if ns.BuffSettings and ns.BuffSettings.SetAssignmentHost then
        ns.BuffSettings.SetAssignmentHost(assignContent)
    end

    local scroll = CreateFrame("ScrollFrame", "RaidStationBuffScroll", p, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 15, -65)
    scroll:SetPoint("BOTTOMLEFT", assignBox, "TOPLEFT", -15, 2)
    scroll:SetWidth(p:GetWidth() - 45)
    if ns.GUI and ns.GUI.SkinScrollBar then
        ns.GUI.SkinScrollBar(scroll, { listHeight = 280 })
    end
    BuffTab.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(332)
    content:SetHeight(400)
    scroll:SetScrollChild(content)
    BuffTab.content = content



    BuffTab._cbRaid = cbRaid
    BuffTab._cbPala = cbPala
    BuffTab._cbCons = cbCons

    function BuffTab.SyncFromDB()
        cbRaid:SetChecked(RaidStationDB.buffTab_checkRaid ~= false)
        cbPala:SetChecked(RaidStationDB.buffTab_checkPaladin ~= false)
        cbCons:SetChecked(RaidStationDB.buffTab_checkConsumables == true)
        if BuffTab.ebSeconds then
            BuffTab.ebSeconds:SetText(tostring(RaidStationDB.dbmPullSeconds or 10))
        end
        updateModeLabel()
        if ns.BuffSettings and ns.BuffSettings.RebuildAssignmentRows and BuffTab.assignmentHost then
            ns.BuffSettings.SetAssignmentHost(BuffTab.assignmentHost)
        end
    end

    scroll:HookScript("OnScrollRangeChanged", function(self, xrange, yrange)
        local sb = _G[self:GetName() .. "ScrollBar"]
        if sb and yrange and yrange > 0 then sb:Show() else if sb then sb:Hide() end end
    end)
    p:HookScript("OnHide", function()
        if ns.BuffSettings and ns.BuffSettings.PersistAssignments then
            ns.BuffSettings.PersistAssignments()
        end
    end)
end

function BuffTab.Show()
    if BuffTab.panel then
        BuffTab.SyncFromDB()
        BuffTab.panel:Show()
        BuffTab.Refresh()
    end
end

function BuffTab.Hide()
    if BuffTab.panel then BuffTab.panel:Hide() end
    if BuffTab.popout and BuffTab.popout:IsShown() then
        BuffTab.popout:Hide()
    end
end

-- Panel popout anclado a la derecha del MainFrame (boton ">" en ASIGNACIONES).
-- Nota: chanPopup (lineas ~502-568) es otro menu (Solo yo / Banda / Alerta), no este panel.
local POPOUT_OFFSET_X = 0 -- + derecha, - izquierda (respecto al borde derecho del MainFrame)
local POPOUT_OFFSET_Y = 0 -- + arriba, - abajo (respecto al borde superior del MainFrame)

local function positionPopout(popout)
    local mainFrame = ns.GUI and ns.GUI.MainFrame
    if not mainFrame or not popout then return end
    popout:ClearAllPoints()
    popout:SetHeight(mainFrame:GetHeight())
    popout:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", POPOUT_OFFSET_X, POPOUT_OFFSET_Y)
end

local function buildPopout()
    if BuffTab.popout then return BuffTab.popout end
    -- Resetear sectionRoot para permitir montaje dentro del popout
    if ns.BuffSettings then
        ns.BuffSettings.sectionRoot = nil
    end
    local mainFrame = ns.GUI.MainFrame
    local popout = CreateFrame("Frame", "RaidStationBuffPopout", UIParent)
    popout:SetWidth(240)
    positionPopout(popout)
    popout:SetFrameStrata("HIGH")
    popout:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
    popout:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    local bc = RaidStationDB.bodyColor or { 0.13, 0.13, 0.13 }
    local ba = RaidStationDB.bodyAlpha or 1.0
    popout:SetBackdropColor(bc[1], bc[2], bc[3], ba)
    popout:SetBackdropBorderColor(0.10, 0.10, 0.10, 1)
    popout:Hide()

    -- Título
    local title = popout:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 8, -8)
    ns.GUI.RegisterAccentLabel(title, "BUFF - AJUSTES DE RAID")
    BuffTab._popoutTitle = title

    -- Separador
    local sep = popout:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 6, -22)
    sep:SetPoint("TOPRIGHT", -6, -22)
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetVertexColor(0.3, 0.3, 0.3, 1)

    -- Montar sección de ajustes dentro del popout
    -- yOffset -28 para dejar espacio al título
    if ns.BuffSettings and ns.BuffSettings.CreateSection then
        ns.BuffSettings.CreateSection(popout, -28)
    end

    BuffTab.popout = popout
    tinsert(UISpecialFrames, "RaidStationBuffPopout")
    return popout
end

function BuffTab.TogglePopout()
    local pop = buildPopout()
    if pop:IsShown() then
        pop:Hide()
    else
        positionPopout(pop)
        pop:Show()
    end
end

-- Refresh accent colors on all registered labels + live rows
function BuffTab.RefreshColors()
    -- RegisteredAccentLabel handles titles; we also need to refresh live row text colors
    if not BuffTab.content then return end
    local r, g, b = ns.GUI.GetAccentColor()
    -- refresh any visible group-header rows that were colored at render time
    BuffTab.Refresh()
end

ns.BuffTab = BuffTab
