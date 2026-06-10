-- RaidStation :: UI/Advertiser.lua
-- Parte de RaidStation por Marfyn- | 2026
-- Queda prohibida la redistribución no autorizada sin crédito.
local addonName, ns = ...
local DEBUG = false -- Activar en desarrollo: imprime eventos de patron al chat -- fix C-10
local AdvertiserUI = {}

local function SkinRoleEditBox(eb)
    ns.GUI.SkinEditBox(eb)
end

-- Helpers para preservar raid marks ({rtN}) durante sync reactivo
local function stripRT(s)
    if not s then return "" end
    -- Las llaves {} no son mágicas en Lua, solo se busca el patrón directo.
    return s:gsub("{rt%d}", "")
end
-- Obtiene el encabezado automático puro (Raid + Necesidades + Progreso) SIN las notas
local function GetCleanAutoHeader()
    local parts = ns.Advertiser:GetHeaderParts()
    return parts.base .. (parts.needs ~= "" and " " .. parts.needs or "") .. " " .. parts.progress
end
-- Busca `needle` en `haystack` ignorando marcadores {rtN}
-- Retorna posición inicio/fin en el string ORIGINAL (con marcadores)
local function findIgnoringRT(haystack, needle)
    if not needle or needle == "" or not haystack or haystack == "" then return nil end
    local cleanNeedle = stripRT(needle)
    if cleanNeedle == "" then return nil end

    -- Creamos una tabla limpia de caracteres y sus posiciones reales en bytes
    local cleanChars = {}
    local posMap = {}
    local i = 1
    local len = #haystack

    while i <= len do
        -- Evaluamos si los próximos 5 bytes corresponden a una raid mark {rt1} a {rt8}
        if i + 4 <= len and haystack:sub(i, i + 4):match("{rt%d}") then
            i = i + 5 -- Saltamos la marca completa para ignorarla en el texto limpio
        else
            local n = #cleanChars + 1
            cleanChars[n] = haystack:sub(i, i)
            posMap[n] = i -- Guardamos qué byte del string original corresponde a esta posición limpia
            i = i + 1
        end
    end

    local cleanHay = table.concat(cleanChars)
    -- Buscamos el texto plano (usando plain search = true)
    local s, e = cleanHay:find(cleanNeedle, 1, true)

    if not s or not e then return nil end
    -- Devolvemos los índices reales mapeados perfectamente
    return posMap[s], posMap[e]
end

local function math_round(num)
    return math.floor(num + 0.5)
end


function AdvertiserUI.CreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()
    local styleBoxes = {}

    -- Banda e intervalo
    local raidLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    raidLabel:SetPoint("TOPLEFT", 35, -50)
    ns.GUI.RegisterAccentLabel(raidLabel, "Banda")

    local raids = { "ICC", "SR", "TOC", "ARCHA", "SEMANAL", "ULDUAR", "VIAJEROS" }
    local raidOpts = {}
    for _, r in ipairs(raids) do
        raidOpts[#raidOpts + 1] = { text = r, value = r }
    end
    local raidDrop = ns.GUI.CreatePopupDropdown(panel, 65, 20, raidOpts, raids[1], function(v)
        ns.Advertiser.patterns.raidName = v
        if v == "ARCHA" then
            ns.Advertiser.patterns.difficulty = "N"
            if AdvertiserUI.diffDrop and AdvertiserUI.diffDrop.SetValue then
                AdvertiserUI.diffDrop:SetValue("N", false)
            end
        end
        if AdvertiserUI.RebuildDiffDrop then
            AdvertiserUI:RebuildDiffDrop(v)
        end
        if RaidStationDB.reactiveSync then
            AdvertiserUI:ActualizarHeader(true)
        end
    end)
    raidDrop:SetPoint("LEFT", raidLabel, "RIGHT", 4, 0)
    AdvertiserUI.raidDrop = raidDrop

    local intervalLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    intervalLabel:SetPoint("LEFT", raidDrop, "RIGHT", 8, 0)
    ns.GUI.RegisterAccentLabel(intervalLabel, "Int (s)")

    local intervalInput = CreateFrame("EditBox", nil, panel)
    intervalInput:SetSize(30, 20)
    intervalInput:SetPoint("LEFT", intervalLabel, "RIGHT", 4, 0)
    intervalInput:SetAutoFocus(false)
    intervalInput:SetFontObject("ChatFontNormal")
    intervalInput:SetText("25")
    intervalInput:SetNumeric(true)
    ns.GUI.SkinEditBox(intervalInput)
    intervalInput:SetScript("OnEditFocusGained", function(self)
        self:SetText("") -- limpia el campo al entrar
        self:HighlightText()
    end)
    intervalInput:SetScript("OnEditFocusLost", function(self)
        local val = math.max(15, tonumber(self:GetText()) or 15)
        ns.Advertiser.interval = val
        self:SetText(tostring(val)) -- corrige y muestra el valor real
        self:HighlightText(0, 0)
    end)
    intervalInput:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText()) or 15
        ns.Advertiser.interval = math.max(15, val)
    end)
    AdvertiserUI.intervalInput = intervalInput

    -- Botón Iniciar/Parar
    local startBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    startBtn:SetSize(60, 20)
    startBtn:SetPoint("LEFT", intervalInput, "RIGHT", 4, 0)
    startBtn:SetText("INICIAR")
    if ns.GUI and ns.GUI.SkinButton then
        ns.GUI.SkinButton(startBtn, true)
    end
    startBtn:SetScript("OnClick", function(self)
        if ns.Advertiser.isSpamming then
            ns.Advertiser:Stop()
            self:SetText("INICIAR")
        else
            ns.Advertiser:Start()
            self:SetText("PARAR")
        end
        AdvertiserUI:UpdateStatus()
    end)
    AdvertiserUI.startBtn = startBtn

    -- Visualización del temporizador de cuenta atrás
    local countdownText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countdownText:SetPoint("LEFT", startBtn, "RIGHT", 5, 0)
    countdownText:SetText("")
    AdvertiserUI.countdownText = countdownText

    -- Sección: Título de composición
    local compTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    compTitle:SetPoint("TOP", 0, -80)
    ns.GUI.RegisterAccentLabel(compTitle, "COMPOSICIÓN")

    -- Configuración de cuadrícula de roles 2x2
    local roleData = {
        { id = "tank",   label = "Tank",   row = 0, col = 0, coords = { 0, 0.26171875, 0.26171875, 0.5234375 } },
        { id = "healer", label = "Healer", row = 0, col = 1, coords = { 0.26171875, 0.5234375, 0, 0.26171875 } },
        { id = "melee",  label = "Melee",  row = 1, col = 0, coords = { 0.26171875, 0.5234375, 0.26171875, 0.5234375 } },
        { id = "caster", label = "Caster", row = 1, col = 1, coords = { 0.26171875, 0.5234375, 0.26171875, 0.5234375 } }
    }

    AdvertiserUI.roleInputs = {}

    for _, r in ipairs(roleData) do
        local card = ns.GUI.CreateBox(panel, 166, 54)
        local xOffset = (r.col == 0) and -84 or 84
        local yOffset = (r.row == 0) and -15 or -75
        card:SetPoint("TOP", compTitle, "BOTTOM", xOffset, yOffset)
        styleBoxes[#styleBoxes + 1] = card

        -- Icono de rol recortado un 15%
        local iconFrame = CreateFrame("Frame", nil, card)
        iconFrame:SetSize(14, 14)
        iconFrame:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -6)

        local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
        iconBg:SetAllPoints()
        iconBg:SetTexture(0, 0, 0, 1)

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")

        local coords = r.coords
        local w = coords[2] - coords[1]
        local h = coords[4] - coords[3]
        local padW = w * 0.15
        local padH = h * 0.15
        icon:SetTexCoord(coords[1] + padW, coords[2] - padW, coords[3] + padH, coords[4] - padH)

        -- Etiqueta
        local label = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
        label:SetText("|cffffd904" .. r.label .. "|r")

        -- Contenedor del Spin Box (tamaño 32x20)
        local spinner = CreateFrame("Frame", nil, card)
        spinner:SetSize(32, 20)
        spinner:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -5)

        -- EditBox de cantidad (izquierda, tamaño 20x18)
        local needInput = CreateFrame("EditBox", nil, spinner)
        needInput:SetSize(20, 18)
        needInput:SetPoint("LEFT", spinner, "LEFT", 0, 0)
        needInput:SetNumeric(true)
        needInput:SetAutoFocus(false)
        needInput:SetFontObject("ChatFontNormal")
        needInput:SetText("0")
        SkinRoleEditBox(needInput)
        needInput:SetScript("OnTextChanged", function(self)
            ns.Advertiser.patterns.roles[r.id].need = tonumber(self:GetText()) or 0
            if RaidStationDB.reactiveSync then
                AdvertiserUI:ActualizarHeader(true)
            end
        end)
        needInput:SetScript("OnEditFocusGained", function(self)
            AdvertiserUI.lastFocusedEB = self
            self:HighlightText()
        end)
        needInput:SetScript("OnEditFocusLost", function(self)
            self:HighlightText(0, 0)
        end)

        -- Botón Incremento (arriba a la derecha, tamaño 12x10)
        local upBtn = CreateFrame("Button", nil, spinner)
        upBtn:SetSize(12, 10)
        upBtn:SetPoint("TOPRIGHT", spinner, "TOPRIGHT", 0, 0)
        if ns.GUI and ns.GUI.SkinButton then ns.GUI.SkinButton(upBtn, true) end
        upBtn:SetScale(0.85)
        local upFs = upBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        upFs:SetAllPoints()
        upFs:SetText("+")

        -- Botón Decremento (abajo a la derecha, tamaño 12x10)
        local downBtn = CreateFrame("Button", nil, spinner)
        downBtn:SetSize(12, 10)
        downBtn:SetPoint("BOTTOMRIGHT", spinner, "BOTTOMRIGHT", 0, 0)
        if ns.GUI and ns.GUI.SkinButton then ns.GUI.SkinButton(downBtn, true) end
        downBtn:SetScale(0.85)
        local downFs = downBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        downFs:SetAllPoints()
        downFs:SetText("-")

        -- Comportamiento interactivo de incremento/decremento
        upBtn:SetScript("OnClick", function()
            local val = tonumber(needInput:GetText()) or 0
            needInput:SetText(tostring(val + 1))
        end)

        downBtn:SetScript("OnClick", function()
            local val = tonumber(needInput:GetText()) or 0
            if val > 0 then
                needInput:SetText(tostring(val - 1))
            end
        end)

        -- Cuadro de clases (150x18)
        local classInput = CreateFrame("EditBox", nil, card)
        classInput:SetSize(150, 18)
        classInput:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 6, 6)
        classInput:SetAutoFocus(false)
        classInput:SetFontObject("ChatFontNormal")
        SkinRoleEditBox(classInput)
        classInput:SetScript("OnTextChanged", function(self)
            ns.Advertiser.patterns.roles[r.id].class = self:GetText()
            if RaidStationDB.reactiveSync then
                AdvertiserUI:ActualizarHeader(true)
            end
        end)
        classInput:SetScript("OnEditFocusGained", function(self)
            AdvertiserUI.lastFocusedEB = self
        end)

        AdvertiserUI.roleInputs[r.id] = { need = needInput, class = classInput }
    end

    -- Sección: Notas (334x30, Y = -252)
    local noteBox = ns.GUI.CreateBox(panel, 334, 30)
    noteBox:SetPoint("TOP", 0, -223)
    styleBoxes[#styleBoxes + 1] = noteBox

    local noteLabel = noteBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteLabel:SetPoint("LEFT", 12, 0)
    noteLabel:SetText("|cffffd904Notas|r")

    local noteInput = CreateFrame("EditBox", nil, noteBox)
    noteInput:SetSize(260, 20)
    noteInput:SetPoint("LEFT", noteLabel, "RIGHT", 10, 0)
    noteInput:SetAutoFocus(false)
    noteInput:SetFontObject("ChatFontNormal")
    SkinRoleEditBox(noteInput)
    noteInput:SetScript("OnTextChanged", function(self)
        ns.Advertiser.patterns.message = self:GetText()
        if RaidStationDB.reactiveSync then
            AdvertiserUI:ActualizarHeader(true)
        end
    end)
    noteInput:SetScript("OnEditFocusGained", function(self)
        AdvertiserUI.lastFocusedEB = self
        self:HighlightText()
    end)
    noteInput:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)

    AdvertiserUI.roleInputs["message"] = { class = noteInput }

    -- Sección: Canales (334x38, Y = -4 desde noteBox)
    local chanBox = ns.GUI.CreateBox(panel, 334, 38)
    chanBox:SetPoint("TOP", noteBox, "BOTTOM", 0, -6)
    styleBoxes[#styleBoxes + 1] = chanBox

    local channels = { "1", "2", "POS", "GLD" }
    local chanLabels = {
        ["1"] = "1",
        ["2"] = "2",
        ["POS"] = "POS",
        ["GLD"] = "GLD",
    }
    AdvertiserUI.chanChecks = {}
    local colWidth = 310 / 4
    local xStart = 10

    for i, chan in ipairs(channels) do
        local chanKey = chan
        local x = xStart + (i - 1) * colWidth
        local labelText = chanLabels[chanKey]

        if ns.GUI and ns.GUI.CreateSwitch then
            local sw = ns.GUI.CreateSwitch(chanBox, labelText, ns.Advertiser.channels and ns.Advertiser.channels
                [chanKey],
                function(v)
                    ns.Advertiser.channels[chanKey] = v and true or false
                    if AdvertiserUI.chanChecks then
                        for _, chSw in ipairs(AdvertiserUI.chanChecks) do
                            if chSw and chSw.RefreshAccent then
                                chSw:RefreshAccent()
                            end
                        end
                    end
                end, colWidth - 4, 18)
            sw:SetPoint("LEFT", chanBox, "LEFT", x, 0)
            sw:SetFrameLevel(chanBox:GetFrameLevel() + 20 + i)
            sw:SetChecked(ns.Advertiser.channels and ns.Advertiser.channels[chanKey])
            AdvertiserUI.chanChecks[i] = sw
        else
            local check = CreateFrame("CheckButton", "RaidStationChanCheck" .. i, chanBox,
                "ChatConfigCheckButtonTemplate")
            check:SetPoint("LEFT", chanBox, "LEFT", x, 0)
            check:SetScale(0.8)
            if ns.GUI and ns.GUI.SkinCheckBox then
                ns.GUI.SkinCheckBox(check)
            end

            local checkText = _G[check:GetName() .. "Text"]
            checkText:SetText(labelText)
            checkText:SetFontObject("GameFontHighlightSmall")
            checkText:SetTextColor(0.78, 0.78, 0.78)
            check:SetChecked(ns.Advertiser.channels and ns.Advertiser.channels[chanKey])

            check:SetScript("OnClick", function(self)
                ns.Advertiser.channels[chanKey] = self:GetChecked()
            end)
            AdvertiserUI.chanChecks[i] = check
        end
    end

    for _, chSw in ipairs(AdvertiserUI.chanChecks) do
        if chSw and chSw.RefreshAccent then
            chSw:RefreshAccent()
        end
    end

    -- Sección: Progreso y recuento (334x34)
    local progBox = ns.GUI.CreateBox(panel, 334, 34)
    progBox:SetPoint("TOP", chanBox, "BOTTOM", 0, -6)
    styleBoxes[#styleBoxes + 1] = progBox

    local countLabel = progBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countLabel:SetPoint("LEFT", 12, 0)
    ns.GUI.RegisterAccentLabel(countLabel, "Progreso")

    local currentInput = CreateFrame("EditBox", nil, progBox)
    currentInput:SetSize(30, 22)
    currentInput:SetPoint("LEFT", countLabel, "RIGHT", 15, 0)
    currentInput:SetNumeric(true)
    currentInput:SetAutoFocus(false)
    currentInput:SetFontObject("ChatFontNormal")
    currentInput:SetText("0")
    ns.GUI.SkinEditBox(currentInput)
    currentInput:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    currentInput:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
    end)
    currentInput:SetScript("OnTextChanged", function(self)
        ns.Advertiser.patterns.currentCount = tonumber(self:GetText()) or 0
        if RaidStationDB.reactiveSync then
            AdvertiserUI:ActualizarHeader(true)
        end
    end)
    AdvertiserUI.currentCountInput = currentInput

    -- Desplegable de tamaño
    local sizeDrop = ns.GUI.CreatePopupDropdown(progBox, 30, 20, {
        { text = "10", value = 10 },
        { text = "25", value = 25 },
    }, 10, function(v)
        ns.Advertiser.patterns.totalCount = v
        if RaidStationDB.reactiveSync then
            AdvertiserUI:ActualizarHeader(true)
        end
    end)
    sizeDrop:SetPoint("LEFT", currentInput, "RIGHT", 4, 0)
    ns.Advertiser.patterns.totalCount = 10
    AdvertiserUI.sizeDrop = sizeDrop

    -- Desplegable de dificultad
    local diffDrop = ns.GUI.CreatePopupDropdown(progBox, 25, 20, {}, "N", function(v)
        ns.Advertiser.patterns.difficulty = v
        if RaidStationDB.reactiveSync then
            AdvertiserUI:ActualizarHeader(true)
        end
    end)
    diffDrop:SetPoint("LEFT", sizeDrop, "RIGHT", 4, 0)
    function AdvertiserUI:RebuildDiffDrop(raidName)
        local opts = { { text = "N", value = "N" } }
        if raidName ~= "ARCHA" then
            opts[#opts + 1] = { text = "H", value = "H" }
        end
        self.diffDrop:SetOptions(opts)
        local cur = ns.Advertiser.patterns.difficulty or "N"
        local allowH = (raidName ~= "ARCHA")
        if cur == "H" and not allowH then
            cur = "N"
            ns.Advertiser.patterns.difficulty = "N"
        end
        self.diffDrop:SetValue(cur, false)
    end

    AdvertiserUI.diffDrop = diffDrop
    AdvertiserUI:RebuildDiffDrop(ns.Advertiser.patterns.raidName or raids[1])
    ns.Advertiser.patterns.difficulty = "N"

    -- Botón SYNC
    local syncBtn = CreateFrame("Button", nil, progBox, "UIPanelButtonTemplate")
    syncBtn:SetSize(45, 18)
    syncBtn:SetPoint("LEFT", diffDrop, "RIGHT", 4, 0)
    syncBtn:SetText("SYNC")
    if ns.GUI and ns.GUI.SkinButton then
        ns.GUI.SkinButton(syncBtn, true)
    end
    syncBtn:SetScript("OnClick", function()
        AdvertiserUI:SyncRosterCount()
    end)
    AdvertiserUI.syncBtn = syncBtn

    -- Texto de estado de sincronización
    local syncStatus = progBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    syncStatus:SetPoint("LEFT", syncBtn, "RIGHT", 0, 0)
    syncStatus:SetText("|cff555555××|r")
    AdvertiserUI.syncStatus = syncStatus

    -- Sección: Vista previa (334x85)
    local prevBox = ns.GUI.CreateBox(panel, 334, 105)
    prevBox:SetPoint("TOP", progBox, "BOTTOM", 0, -6)
    styleBoxes[#styleBoxes + 1] = prevBox

    local prevLabel = prevBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prevLabel:SetPoint("TOPLEFT", 10, -5)
    ns.GUI.RegisterAccentLabel(prevLabel, "Vista Previa")

    -- Cuadrícula de símbolos
    local symbolsGrid = CreateFrame("Frame", nil, prevBox)
    symbolsGrid:SetSize(150, 20)
    symbolsGrid:SetPoint("LEFT", prevLabel, "RIGHT", 10, 0)

    for i = 1, 8 do
        local btn = CreateFrame("Button", nil, symbolsGrid)
        btn:SetSize(16, 16)
        if i == 1 then
            btn:SetPoint("LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", symbolsGrid.btns[i - 1], "RIGHT", 4, 0)
        end
        btn:SetNormalTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i)
        btn:SetScript("OnClick", function()
            local rt = "{rt" .. i .. "}"
            local target = ns.GUI.activeEditBox or AdvertiserUI.previewEdit
            if target then
                target:Insert(rt)
            else
                if DEBUG then                                                                                           -- fix C-10
                    print("|cff00ff00Raid Station|r: Primero haz clic en un cuadro de texto para insertar el símbolo.") -- fix C-6
                end
            end
        end)
        symbolsGrid.btns = symbolsGrid.btns or {}
        symbolsGrid.btns[i] = btn
    end

    local previewCount = prevBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    previewCount:SetPoint("TOPRIGHT", -10, -7)
    previewCount:SetText("0/255")
    AdvertiserUI.previewCount = previewCount

    if ns.CompAdvisor then
        local compBtn = ns.CompAdvisor.CreateButton(prevBox)
        compBtn:SetPoint("RIGHT", prevBox, "RIGHT", -2, -42)
    end

    local previewEdit = CreateFrame("EditBox", nil, prevBox)
    previewEdit:SetPoint("TOPLEFT", 1, -22)
    previewEdit:SetPoint("BOTTOMRIGHT", -1, 16)
    previewEdit:SetTextInsets(8, 8, 8, 8)
    previewEdit:SetMultiLine(true)
    previewEdit:SetAutoFocus(false)
    previewEdit:SetFontObject("ChatFontNormal")
    previewEdit:SetMaxLetters(255)
    ns.GUI.SkinEditBox(previewEdit)

    if previewEdit.SetBackdropColor then
        previewEdit:SetBackdropColor(0, 0, 0, 0)
        previewEdit:SetBackdropBorderColor(0, 0, 0, 0)
    end

    local _updatingPreview = false

    previewEdit:SetScript("OnTextChanged", function(self, userInput)
        if _updatingPreview then return end
        local p = ns.Advertiser.patterns
        if userInput then
            local currentText = self:GetText()
            p.fullMessage = currentText
            -- Guardar lo que el usuario escribió ANTES del contenido auto-generado
            local autoBase = p.lastAutoGenerated or ""
            if autoBase ~= "" then
                local aStart = findIgnoringRT(currentText, autoBase)
                if aStart and aStart > 1 then
                    p.extraHeader = currentText:sub(1, aStart - 1)
                elseif aStart == 1 then
                    p.extraHeader = ""
                end
                -- Si no encuentra autoBase, no tocar extraHeader (usuario editó todo)
            end
        end
        AdvertiserUI:UpdatePreviewCount()
    end)

    previewEdit:SetScript("OnEditFocusGained", function(self)
        ns.GUI.activeEditBox = self
    end)

    AdvertiserUI.previewEdit = previewEdit

    -- Desplegable de patrones
    local patternOpts = {}
    for i = 1, 6 do
        patternOpts[#patternOpts + 1] = { text = "Patron " .. i, value = i }
    end
    local patternsDrop = ns.GUI.CreatePopupDropdown(panel, 65, 20, patternOpts, 1, function(v)
        if ns.Advertiser:LoadPattern(v) then
            AdvertiserUI:RefreshAllInputs()
        end
    end)
    patternsDrop:SetPoint("TOPLEFT", prevBox, "BOTTOMLEFT", 0, -10)
    AdvertiserUI.patternsDrop = patternsDrop

    local savePatternBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    savePatternBtn:SetSize(60, 20)
    savePatternBtn:SetPoint("LEFT", patternsDrop, "RIGHT", -3, 0)
    savePatternBtn:SetText("Guardar")
    if ns.GUI and ns.GUI.SkinButton then
        ns.GUI.SkinButton(savePatternBtn, true)
    end
    savePatternBtn:SetScript("OnClick", function()
        local idx = patternsDrop.GetValue and patternsDrop:GetValue() or nil
        if idx and idx >= 1 and idx <= 6 then
            local p = ns.Advertiser.patterns
            local mensajeReal = p.fullMessage or ""
            if mensajeReal == "" and AdvertiserUI.previewEdit then
                mensajeReal = AdvertiserUI.previewEdit:GetText() or ""
            end
            p.fullMessage = mensajeReal
            ns.Advertiser:SavePattern(idx)
        else
            if DEBUG then                                                                   -- fix C-10
                print("|cff00ff00Raid Station|r: Selecciona un slot (Patron 1-6) primero.") -- fix C-6
            end
        end
    end)
    AdvertiserUI.savePatternBtn = savePatternBtn

    -- Texto de estado (pie)
    local statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPRIGHT", prevBox, "BOTTOMRIGHT", 0, -14)
    statusText:SetText("Estado: |cffff0000OFF|r")
    AdvertiserUI.statusText = statusText

    function AdvertiserUI:ActualizarHeader(isSilent)
        local p = ns.Advertiser.patterns
        local newAuto = GetCleanAutoHeader()
        local newNotes = p.message or ""

        -- Variables de control
        p.lastAutoGenerated = newAuto
        p.lastSyncNotes = newNotes

        -- 1. Si no hay un mensaje previo con marcas, inicializamos una estructura limpia
        local currentFull = p.fullMessage or ""
        if currentFull == "" or not currentFull:find("{rt%d}") then
            local notesPart = (newNotes ~= "") and (" " .. newNotes) or ""
            p.fullMessage = newAuto .. notesPart

            _updatingPreview = true
            self.previewEdit:SetText(p.fullMessage)
            _updatingPreview = false
            AdvertiserUI:UpdatePreviewCount()
            return
        end

        -- 2. Extraer TODAS las marcas del string actual y mapear el texto plano limpio
        local savedMarks = {}
        local cleanChars = {}
        local i = 1
        local len = #currentFull
        local plainIdx = 1

        while i <= len do
            if i + 4 <= len and currentFull:sub(i, i + 4):match("{rt%d}") then
                local mark = currentFull:sub(i, i + 4)
                table.insert(savedMarks, { pos = plainIdx, token = mark })
                i = i + 5
            else
                cleanChars[#cleanChars + 1] = currentFull:sub(i, i)
                plainIdx = plainIdx + 1
                i = i + 1
            end
        end
        local currentPlain = table.concat(cleanChars)

        -- Generamos el nuevo cuerpo de texto plano combinando la base actualizada con la nota fresca
        local cleanNewAuto = stripRT(newAuto)
        local cleanNewNotes = stripRT(newNotes)

        -- Construimos el nuevo esqueleto plano puro
        local newPlain = cleanNewAuto .. (cleanNewNotes ~= "" and (" " .. cleanNewNotes) or "")
        newPlain = newPlain:gsub("%s+", " ")

        -- 3. Identificar el prefijo y sufijo común más largo para alinear las marcas con precisión
        local lenOld, lenNew = #currentPlain, #newPlain
        local lcp = 0
        while lcp < lenOld and lcp < lenNew do
            if currentPlain:sub(lcp + 1, lcp + 1) == newPlain:sub(lcp + 1, lcp + 1) then
                lcp = lcp + 1
            else
                break
            end
        end

        local lcs = 0
        local maxLcs = math.min(lenOld - lcp, lenNew - lcp)
        while lcs < maxLcs do
            local oldChar = currentPlain:sub(lenOld - lcs, lenOld - lcs)
            local newChar = newPlain:sub(lenNew - lcs, lenNew - lcs)
            if oldChar == newChar then
                lcs = lcs + 1
            else
                break
            end
        end

        -- 4. Re-inyectar las marcas basándonos en el mapeo de alineación
        local finalChars = {}
        local markMap = {}

        for _, m in ipairs(savedMarks) do
            local targetPos = m.pos
            local mappedPos

            if targetPos <= lcp + 1 then
                -- Si está dentro o inmediatamente después del prefijo común, mantiene su posición exacta
                mappedPos = targetPos
            elseif targetPos >= lenOld - lcs + 1 then
                -- Si está dentro o inmediatamente antes del sufijo común, se ajusta al desfase del nuevo tamaño
                mappedPos = targetPos - lenOld + lenNew
            else
                -- Si está en la zona editada, se escala proporcionalmente dentro del rango modificado
                local midOld = lenOld - lcp - lcs
                local midNew = lenNew - lcp - lcs
                if midOld > 0 then
                    local ratio = (targetPos - 1 - lcp) / midOld
                    mappedPos = lcp + 1 + math.floor(ratio * midNew + 0.5)
                else
                    mappedPos = lcp + 1
                end
            end

            -- Asegurar que la posición mapeada esté dentro de los límites válidos de newPlain
            mappedPos = math.max(1, math.min(lenNew + 1, mappedPos))
            markMap[mappedPos] = (markMap[mappedPos] or "") .. m.token
        end

        -- Ensamblado final intercalado el nuevo texto con las marcas alineadas
        for idx = 1, lenNew + 1 do
            if markMap[idx] then
                finalChars[#finalChars + 1] = markMap[idx]
            end
            if idx <= lenNew then
                finalChars[#finalChars + 1] = newPlain:sub(idx, idx)
            end
        end

        local txt = table.concat(finalChars)
        p.fullMessage = txt
        -- 5. Actualizar interfaz de forma segura
        _updatingPreview = true
        self.previewEdit:SetText("")
        self.previewEdit:SetText(txt)
        _updatingPreview = false

        AdvertiserUI:UpdatePreviewCount()

        if not isSilent and DEBUG then
            print("|cff00ff00Raid Station|r: Vista previa actualizada preservando iconos.")
        end

        if self.syncStatus then
            self.syncStatus:SetText("|cff00ff00××|r")
            self.syncTime = GetTime()
        end
    end

    function AdvertiserUI:SyncRosterCount()
        local count = 0
        local numRaid = GetNumRaidMembers()
        if numRaid > 0 then
            for i = 1, numRaid do
                local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
                if name and online then
                    count = count + 1
                end
            end
        else
            local numParty = GetNumPartyMembers()
            if numParty > 0 then
                count = numParty + 1
            end
        end

        if count ~= ns.Advertiser.patterns.currentCount then
            ns.Advertiser.patterns.currentCount = count
            AdvertiserUI.currentCountInput:SetText(tostring(count))
            AdvertiserUI:ActualizarHeader(true)
        end
    end

    function AdvertiserUI:UpdatePreview()
        self:UpdatePreviewCount()
    end

    function AdvertiserUI:UpdatePreviewCount()
        local msg = self.previewEdit:GetText()
        local len = strlen(msg)
        local color = (len > 255) and "|cffff0000" or "|cff00ff00"
        self.previewCount:SetText(color .. len .. "|r/255")
    end

    function AdvertiserUI:UpdateStatus()
        if ns.Advertiser.isSpamming then
            self.statusText:SetText("Estado: |cff00ff00ON|r (Enviando...)")
        else
            self.statusText:SetText("Estado: |cffff0000OFF|r")
        end
    end

    function AdvertiserUI:RefreshAllInputs()
        local p = ns.Advertiser.patterns
        if self.raidDrop and self.raidDrop.SetValue then
            self.raidDrop:SetValue(p.raidName, false)
        end
        self.intervalInput:SetText(tostring(ns.Advertiser.interval))
        if self.RebuildDiffDrop then
            self:RebuildDiffDrop(p.raidName)
        end
        if self.diffDrop and self.diffDrop.SetValue then
            self.diffDrop:SetValue(p.difficulty, false)
        end

        for id, inputs in pairs(self.roleInputs) do
            if id == "message" then
                inputs.class:SetText(p.message or "")
            else
                if inputs.need then inputs.need:SetText(tostring(p.roles[id].need)) end
                inputs.class:SetText(p.roles[id].class or "")
            end
        end

        self.currentCountInput:SetText(tostring(p.currentCount))
        if self.sizeDrop and self.sizeDrop.SetValue then
            self.sizeDrop:SetValue(p.totalCount, false)
        end
        if p.fullMessage and p.fullMessage ~= "" then
            self.previewEdit:SetText(p.fullMessage)
            p.lastAutoGenerated = GetCleanAutoHeader()
            p.lastSyncNotes = p.message or ""
        else
            p.extraHeader = "" -- resetear prefijo manual al cargar patrón
            local base = GetCleanAutoHeader()
            local combined = base
            if p.message and p.message ~= "" then
                combined = combined .. " " .. p.message
            end
            p.lastAutoGenerated = base -- fix: actualizar referencia
            p.lastSyncNotes = ""
            p.fullMessage = combined
            self.previewEdit:SetText(combined)
        end
    end

    -- Recopilar todos los editboxes para que ApplyStyle() les aplique el skin correctamente
    local styleEdits = { intervalInput, currentInput, previewEdit, noteInput }
    for id, inputs in pairs(AdvertiserUI.roleInputs) do
        if id ~= "message" then
            if inputs.need then table.insert(styleEdits, inputs.need) end
            if inputs.class then table.insert(styleEdits, inputs.class) end
        end
    end

    AdvertiserUI.Panel = panel
    AdvertiserUI._styleRefs = {
        boxes = styleBoxes,
        buttons = { startBtn, syncBtn, savePatternBtn },
        switches = AdvertiserUI.chanChecks,
        edits = styleEdits,
        drops = { raidDrop, sizeDrop, diffDrop, patternsDrop },
    }

    function AdvertiserUI:ApplyStyle()
        if not ns.GUI or not ns.GUI.GetStyleTokens then return end
        local st = ns.GUI.GetStyleTokens()
        local refs = self._styleRefs
        if not refs then return end

        for _, bx in ipairs(refs.boxes or {}) do
            if bx and bx.SetBackdropColor and bx.SetBackdropBorderColor then
                bx:SetBackdropColor(st.panelBg[1], st.panelBg[2], st.panelBg[3], 1)
                bx:SetBackdropBorderColor(st.panelBorder[1], st.panelBorder[2], st.panelBorder[3], 1)
            end
        end

        for _, eb in ipairs(refs.edits or {}) do
            if eb then
                ns.GUI.SkinEditBox(eb)
            end
        end

        for _, dd in ipairs(refs.drops or {}) do
            -- Desplegables estilizados por su helper de creación
        end

        for _, sw in ipairs(refs.switches or {}) do
            if sw and sw.RefreshAccent then
                sw:RefreshAccent()
            end
        end

        for _, btn in ipairs(refs.buttons or {}) do
            if btn and ns.GUI.SkinButton then
                ns.GUI.SkinButton(btn, true)
            end
        end
    end

    local p = ns.Advertiser.patterns
    local base = GetCleanAutoHeader()
    local combined = base
    if p.message and p.message ~= "" then
        combined = combined .. " " .. p.message
    end

    p.lastAutoGenerated = base
    p.lastSyncNotes = p.message
    p.fullMessage = combined
    AdvertiserUI.previewEdit:SetText(combined)

    AdvertiserUI:UpdatePreview()

    panel:RegisterEvent("RAID_ROSTER_UPDATE")
    panel:RegisterEvent("PARTY_MEMBERS_CHANGED")
    panel:SetScript("OnEvent", function(self, event)
        if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
            AdvertiserUI:SyncRosterCount()
        end
    end)

    local lastCountdown = -1
    panel:SetScript("OnUpdate", function(self, elapsed)
        if AdvertiserUI.syncTime and AdvertiserUI.syncTime > 0 then
            if (GetTime() - AdvertiserUI.syncTime) > 3 then
                AdvertiserUI.syncStatus:SetText("|cff555555××|r")
                AdvertiserUI.syncTime = 0
            end
        end

        if not ns.Advertiser.isSpamming then
            if AdvertiserUI.countdownText:GetText() ~= "" then
                AdvertiserUI.countdownText:SetText("")
            end
            return
        end

        local now = GetTime()
        local remaining = math.ceil(ns.Advertiser.interval - (now - ns.Advertiser.lastSpamTime))
        if remaining < 0 then remaining = 0 end

        if remaining ~= lastCountdown then
            lastCountdown = remaining
            if remaining == 0 then
                AdvertiserUI.countdownText:SetText("|cff00ff00Enviando...|r")
            else
                AdvertiserUI.countdownText:SetText("|cffffff00" .. remaining .. "s|r")
            end
        end
    end)
    -- Configurar navegación por tecla TAB (Soporta Shift+TAB para retroceder)
    local editboxes = {
        AdvertiserUI.roleInputs["tank"].class,
        AdvertiserUI.roleInputs["healer"].class,
        AdvertiserUI.roleInputs["melee"].class,
        AdvertiserUI.roleInputs["caster"].class,
        AdvertiserUI.roleInputs["message"].class,
        AdvertiserUI.currentCountInput,
        AdvertiserUI.intervalInput
    }

    for i, eb in ipairs(editboxes) do
        if eb then
            eb:SetScript("OnTabPressed", function(self)
                -- print("Tecla TAB presionada en la casilla: " .. i) -- (Opcional: Descomenta esta línea para probar si el juego detecta la tecla)
                local nextIndex
                if IsShiftKeyDown() then
                    nextIndex = (i == 1) and #editboxes or (i - 1)
                else
                    nextIndex = (i == #editboxes) and 1 or (i + 1)
                end

                local nextEb = editboxes[nextIndex]
                if nextEb then
                    nextEb:SetFocus()
                    nextEb:HighlightText() -- Selecciona el texto automáticamente para facilitar la edición
                end
            end)
        end
    end
    AdvertiserUI:ApplyStyle()
    return panel
end

function AdvertiserUI.Initialize()
    AdvertiserUI.CreatePanel(ns.GUI.MainFrame)
    if ns.CompAdvisor then
        ns.CompAdvisor.Initialize()
    end
end

function AdvertiserUI.RefreshColors()
    if AdvertiserUI.Panel then
        AdvertiserUI:ApplyStyle()
    end
end

ns.AdvertiserUI = AdvertiserUI
