-- RaidStation :: UI/BuffSettings.lua
-- Seccion Buffs dentro de Ajustes: asignaciones, umbral, canal, alertas.
local addonName, ns = ...

local BuffScanner = ns.BuffScanner

local BuffSettings = {
    sectionRoot = nil,
    assignmentRows = {},
    alertEdits = {},
    _listHost = nil,
}

local tinsert = table.insert
local strupper = string.upper
local strlen = string.len
local floor = math.floor

local function sysMsg(msg)
    local prefix = ns.GUI and ns.GUI.ColorText and ns.GUI.ColorText("[Buffs]") or "|cFF5B9BD5[Buffs]|r"
    print(prefix .. " : " .. tostring(msg))
end

local function strtrim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function wipeTable(t)
    for k in pairs(t) do t[k] = nil end
end

local PALADIN_CHOICES = {
    { id = 25898, short = "Reyes" },
    { id = 48938, short = "Sabiduria" },
    { id = 48932, short = "Poderio" },
    { id = 25899, short = "Salva" },
}

local function ensureAlerts()
    if not RaidStationDB.buffTab_alerts or type(RaidStationDB.buffTab_alerts) ~= "table" then
        RaidStationDB.buffTab_alerts = {}
    end
    for i = 1, 2 do
        if type(RaidStationDB.buffTab_alerts[i]) ~= "table" then
            RaidStationDB.buffTab_alerts[i] = { shortName = "", message = "", channel = "DEFAULT" }
        end
    end
end

local function flattenAssignments()
    local list = {}
    local arr = RaidStationDB.paladinAssignmentList
    if type(arr) == "table" then
        for _, row in ipairs(arr) do
            if type(row) == "table" and row.spellID then
                tinsert(list, {
                    paladin = row.paladin or "",
                    spellID = row.spellID,
                    clases = row.clases or row.classes or { "ALL" },
                })
            end
        end
        return list
    end
    local t = RaidStationDB.paladinAssignments
    if type(t) ~= "table" then return list end
    for pname, rows in pairs(t) do
        if type(rows) == "table" then
            for _, row in ipairs(rows) do
                if type(row) == "table" and row.spellID then
                    tinsert(list, {
                        paladin = pname,
                        spellID = row.spellID,
                        clases = row.clases or row.classes or { "ALL" },
                    })
                end
            end
        end
    end
    return list
end

local function normalizeAssignments(list, keepBlank)
    local out = {}
    local seen = {}
    for _, row in ipairs(list or {}) do
        if type(row) == "table" and row.spellID then
            local pname = strtrim(row.paladin or "")
            local classes = row.clases or row.classes or { "ALL" }
            local key = pname .. "|" .. tostring(row.spellID) .. "|" .. table.concat(classes, ",")
            if (keepBlank or pname ~= "") and not seen[key] then
                seen[key] = true
                tinsert(out, {
                    paladin = pname,
                    spellID = row.spellID,
                    clases = classes,
                })
            end
        end
    end
    return out
end

local function persistAssignmentsFromRows()
    -- No longer overwrites the whole DB. Handled by AddAssignmentRow.
end

local function destroyAssignmentRows()
    for _, r in ipairs(BuffSettings.assignmentRows) do
        if r.frame then
            r.frame:Hide()
        end
    end
    wipeTable(BuffSettings.assignmentRows)
end

function BuffSettings.SetAssignmentHost(host)
    BuffSettings._listHost = host
    BuffSettings.RebuildAssignmentRows()
end

function BuffSettings.PersistAssignments()
    persistAssignmentsFromRows()
end

function BuffSettings.AddAssignmentRow()
    local row = BuffSettings.assignmentRows[1]
    if row and row.palaEdit then
        local pname = strtrim(row.palaEdit:GetText())
        if pname ~= "" then
            local list = normalizeAssignments(flattenAssignments(), false)
            tinsert(list, { paladin = pname, spellID = row.spellId, clases = { "ALL" } })
            RaidStationDB.paladinAssignmentList = normalizeAssignments(list, false)
            row.palaEdit:SetText("")
            row.spellId = 25898
            if row.updateBuffBtns then row.updateBuffBtns() end
        end
    end
end

local function spellChoiceLabel(id)
    for _, c in ipairs(PALADIN_CHOICES) do
        if c.id == id then return c.short end
    end
    return "?"
end

local function updateBuffButtons(row)
    for _, b in ipairs(row.buffBtns) do
        if b.choiceId == row.spellId then
            b:SetBackdropBorderColor(1, 0.2, 0.2, 1)
        else
            b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
    end
    if row.previewBtn then
        local pname = strtrim(row.palaEdit:GetText())
        if pname ~= "" then
            local spellName = spellChoiceLabel(row.spellId) or "?"
            row.previewBtn.previewText = "[" .. pname .. ": " .. spellName .. "]"
            row.previewBtn.icon:SetDesaturated(false)
            row.previewBtn.icon:SetVertexColor(0.2, 1, 0.2)
        else
            row.previewBtn.previewText = "Sin nombre de paladin"
            row.previewBtn.icon:SetDesaturated(true)
            row.previewBtn.icon:SetVertexColor(0.4, 0.4, 0.4)
        end
    end
end

function BuffSettings.RebuildAssignmentRows()
    local listHost = BuffSettings._listHost
    if not listHost then return end
    destroyAssignmentRows()

    local y = 0
    local rowF = CreateFrame("Frame", nil, listHost)
    rowF:SetSize(350, 28)
    rowF:SetPoint("TOPLEFT", listHost, "TOPLEFT", 0, -y)

    local rowRef = { spellId = 25898 }

    local checkBtn = CreateFrame("Button", nil, rowF)
    checkBtn:SetSize(22, 22)
    checkBtn:SetPoint("LEFT", 20, 0)
    -- El ícono se crea en OVERLAY para quedar sobre cualquier textura de fondo
    local checkTex = checkBtn:CreateTexture(nil, "OVERLAY")
    checkTex:SetAllPoints()
    checkTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkTex:SetAlpha(0.85)
    checkBtn.icon = checkTex
    if ns.GUI and ns.GUI.SkinButton then ns.GUI.SkinButton(checkBtn, true) end
    checkBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Asignaciones Guardadas", ns.GUI.GetAccentColor())
        local currentList = normalizeAssignments(flattenAssignments(), false)
        if #currentList == 0 then
            GameTooltip:AddLine("No hay paladines asignados.", 0.6, 0.6, 0.6, true)
        else
            for _, r in ipairs(currentList) do
                local sname = spellChoiceLabel(r.spellID) or "?"
                GameTooltip:AddLine(r.paladin .. " - " .. sname, 1, 1, 1, true)
            end
        end
        GameTooltip:Show()
    end)
    checkBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rowRef.previewBtn = checkBtn

    local pe = CreateFrame("EditBox", nil, rowF)
    pe:SetSize(108, 20)
    pe:SetPoint("LEFT", checkBtn, "RIGHT", 4, 0)
    pe:SetAutoFocus(false)
    rowRef.palaEdit = pe

    local suggestFrame = CreateFrame("Frame", nil, rowF)
    suggestFrame:SetSize(120, 0)
    suggestFrame:SetFrameStrata("TOOLTIP")
    suggestFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    suggestFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    suggestFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    suggestFrame:Hide()
    suggestFrame.buttons = {}
    rowRef.suggestFrame = suggestFrame

    local function hideSuggestions()
        suggestFrame:Hide()
        for _, b in ipairs(suggestFrame.buttons) do b:Hide() end
    end

    local function showSuggestions(matches)
        if #matches == 0 then
            hideSuggestions(); return
        end
        local btnH = 16
        local yOff = 0
        for i, name in ipairs(matches) do
            local b = suggestFrame.buttons[i]
            if not b then
                b = CreateFrame("Button", nil, suggestFrame)
                b:SetHeight(btnH)
                b:SetPoint("LEFT", 4, 0)
                b:SetPoint("RIGHT", -4, 0)
                if ns.GUI and ns.GUI.SkinButton then ns.GUI.SkinButton(b, true) end
                local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetAllPoints()
                fs:SetJustifyH("LEFT")
                b.fs = fs
                b:SetScript("OnEnter", function(self)
                    if self.SetBackdropBorderColor then
                        self:SetBackdropBorderColor(0, 0.5, 1, 1)
                    end
                end)
                b:SetScript("OnLeave", function(self)
                    if self.SetBackdropBorderColor then
                        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                    end
                end)
                suggestFrame.buttons[i] = b
            end
            b.fs:SetText(name)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", suggestFrame, "TOPLEFT", 4, -yOff - 2)
            b:SetPoint("TOPRIGHT", suggestFrame, "TOPRIGHT", -4, -yOff - 2)
            b:SetHeight(btnH)
            b:SetScript("OnClick", function()
                rowRef.palaEdit:SetText(name)
                rowRef.palaEdit:ClearFocus()
                hideSuggestions()
                if rowRef.updateBuffBtns then rowRef.updateBuffBtns() end
            end)
            b:Show()
            yOff = yOff + btnH + 2
        end
        for i = #matches + 1, #suggestFrame.buttons do
            suggestFrame.buttons[i]:Hide()
        end
        suggestFrame:SetHeight(yOff + 4)
        suggestFrame:ClearAllPoints()
        suggestFrame:SetPoint("TOPLEFT", rowRef.palaEdit, "BOTTOMLEFT", 0, -2)
        suggestFrame:Show()
    end

    local buffBtns = {}
    rowRef.buffBtns = buffBtns
    local xb = 162
    for _, ch in ipairs(PALADIN_CHOICES) do
        local b = CreateFrame("Button", nil, rowF)
        b:SetSize(20, 20)
        b:SetPoint("LEFT", rowF, "LEFT", xb, 0)
        if ns.GUI and ns.GUI.SkinButton then ns.GUI.SkinButton(b, true) end
        -- El ícono en OVERLAY queda sobre la textura ARTWORK del SkinButton
        local tex = b:CreateTexture(nil, "OVERLAY")
        tex:SetPoint("TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", -1, 1)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local _, _, iconTex = GetSpellInfo(ch.id)
        tex:SetTexture(iconTex or "Interface\\Icons\\INV_Misc_QuestionMark")
        b.icon = tex
        b.choiceId = ch.id
        b:SetScript("OnClick", function()
            rowRef.spellId = ch.id
            updateBuffButtons(rowRef)
            persistAssignmentsFromRows()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(ch.short, ns.GUI.GetAccentColor())
            GameTooltip:AddLine("Selecciona la bendicion asignada a este paladin.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tinsert(buffBtns, b)
        xb = xb + 22
    end
    rowRef.buffBtns = buffBtns
    updateBuffButtons(rowRef)

    local addAssignBtn = CreateFrame("Button", nil, rowF, "UIPanelButtonTemplate")
    addAssignBtn:SetSize(52, 20)
    addAssignBtn:SetPoint("LEFT", rowF, "LEFT", xb + 4, 0)
    addAssignBtn:SetText("Anadir")
    addAssignBtn:SetScript("OnClick", function()
        BuffSettings.AddAssignmentRow()
    end)
    addAssignBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Anadir asignacion", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Escribe el nombre del paladin, selecciona el buff y pulsa Anadir.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    addAssignBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if ns.GUI and ns.GUI.SkinButton then
        ns.GUI.SkinButton(addAssignBtn, true)
    end
    rowRef.addAssignBtn = addAssignBtn

    local rm = CreateFrame("Button", nil, rowF, "UIPanelButtonTemplate")
    rm:SetSize(22, 20)
    rm:SetPoint("LEFT", addAssignBtn, "RIGHT", 4, 0)
    rm:SetText("X")
    rm:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Limpiar asignaciones", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Si hay nombre escrito, elimina ese paladin. Si esta vacio, borra todo.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    rm:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rm:SetScript("OnClick", function()
        local pname = strtrim(pe:GetText())
        if pname ~= "" then
            local newList = {}
            for _, r in ipairs(flattenAssignments()) do
                if strtrim(r.paladin or "") ~= pname then
                    tinsert(newList, r)
                end
            end
            RaidStationDB.paladinAssignmentList = newList
            pe:SetText("")
            sysMsg("Asignacion eliminada para " .. pname)
        else
            RaidStationDB.paladinAssignmentList = {}
            sysMsg("Todas las asignaciones han sido eliminadas.")
        end
    end)
    if ns.GUI and ns.GUI.SkinButton then
        ns.GUI.SkinButton(rm, true)
    end

    rowRef.frame = rowF
    tinsert(BuffSettings.assignmentRows, rowRef)
    rowRef.updateBuffBtns = function() updateBuffButtons(rowRef) end

    pe:SetScript("OnTextChanged", function()
        updateBuffButtons(rowRef)
    end)
    rowRef.palaEdit:HookScript("OnTextChanged", function(self)
        local txt = strtrim(self:GetText()):lower()
        if txt == "" then
            hideSuggestions(); return
        end
        local matches = {}
        for i = 1, GetNumRaidMembers() do
            local rname = GetRaidRosterInfo(i)
            if rname and rname:lower():find(txt, 1, true) then
                tinsert(matches, rname)
                if #matches >= 5 then break end
            end
        end
        showSuggestions(matches)
    end)
    rowRef.palaEdit:HookScript("OnEditFocusLost", function()
        ns.Utils.NewTimer(0.15, hideSuggestions
    end)
    pe:SetText("")
    pe:SetFontObject("ChatFontNormal")
    if ns.GUI and ns.GUI.SkinEditBox then ns.GUI.SkinEditBox(pe) end


    y = y + 30
    listHost:SetHeight(math.max(y, 30))
end

function BuffSettings.CreateSection(panel, yOffset)
    if BuffSettings.sectionRoot then return end
    ensureAlerts()

    local root = CreateFrame("Frame", nil, panel)
    local topOffset = yOffset or -360
    root:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, topOffset)
    root:SetSize(222, 290)
    root:SetBackdropColor(0, 0, 0, 0)
    root:SetBackdropBorderColor(0, 0, 0, 0)
    BuffSettings.sectionRoot = root

    local child = root
    local y = 4

    -- Umbral
    local t2 = child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t2:SetPoint("TOPLEFT", 4, -y)
    t2:SetText("Umbral re-buff (URGENTE):")
    y = y + 14

    local thrLabel = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    thrLabel:SetPoint("TOPLEFT", 4, -y)
    y = y + 12

    local thrSlider = CreateFrame("Slider", "RSBuffThrSlider", child, "OptionsSliderTemplate")
    thrSlider:SetPoint("TOPLEFT", 4, -y)
    thrSlider:SetMinMaxValues(5, 30)
    thrSlider:SetValueStep(1)
    thrSlider:SetWidth(200)
    local function thrMin()
        return floor((tonumber(RaidStationDB.buffTab_threshold) or 600) / 60 + 0.5)
    end
    thrSlider:SetScript("OnValueChanged", function(self, v)
        v = floor(v + 0.5)
        if v < 5 then v = 5 end
        if v > 30 then v = 30 end
        RaidStationDB.buffTab_threshold = v * 60
        thrLabel:SetText("Menos de " .. tostring(v) .. " min = URGENTE")
    end)
    thrSlider:SetValue(thrMin())
    thrLabel:SetText("Menos de " .. tostring(thrMin()) .. " min = URGENTE")
    _G[thrSlider:GetName() .. "Low"]:SetText("5")
    _G[thrSlider:GetName() .. "High"]:SetText("30")
    y = y + 36

    -- Separador
    local sep = child:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 4, -y)
    sep:SetWidth(210)
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetVertexColor(0.25, 0.25, 0.25, 1)
    y = y + 8

    -- Alertas rapidas
    local t4 = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t4:SetPoint("TOPLEFT", 4, -y)
    ns.GUI.RegisterAccentLabel(t4, "ALERTAS RAPIDAS")
    y = y + 20

    local rwCheck = CreateFrame("CheckButton", "RSBuffAlertToRW", child, "ChatConfigCheckButtonTemplate")
    rwCheck:SetPoint("TOPLEFT", 4, -y)
    rwCheck:SetScale(0.9)
    if ns.GUI and ns.GUI.SkinCheckBox then ns.GUI.SkinCheckBox(rwCheck) end
    _G[rwCheck:GetName() .. "Text"]:SetText("Alerta de banda (/rw)")
    _G[rwCheck:GetName() .. "Text"]:SetTextColor(0.78, 0.78, 0.78)
    rwCheck:SetChecked(RaidStationDB.buffTab_alertToRaidWarning ~= false)
    y = y + 18

    local raidCheck = CreateFrame("CheckButton", "RSBuffAlertToRaid", child, "ChatConfigCheckButtonTemplate")
    raidCheck:SetPoint("TOPLEFT", 4, -y)
    raidCheck:SetScale(0.9)
    if ns.GUI and ns.GUI.SkinCheckBox then ns.GUI.SkinCheckBox(raidCheck) end
    _G[raidCheck:GetName() .. "Text"]:SetText("Raid (/raid)")
    _G[raidCheck:GetName() .. "Text"]:SetTextColor(0.78, 0.78, 0.78)
    raidCheck:SetChecked(RaidStationDB.buffTab_alertToRaid == true)
    y = y + 20

    local function setAlertChannel(mode)
        RaidStationDB.buffTab_alertToRaidWarning = (mode == "rw")
        RaidStationDB.buffTab_alertToRaid = (mode == "raid")
        rwCheck:SetChecked(mode == "rw")
        raidCheck:SetChecked(mode == "raid")
    end
    rwCheck:SetScript("OnClick", function() setAlertChannel("rw") end)
    raidCheck:SetScript("OnClick", function() setAlertChannel("raid") end)
    if RaidStationDB.buffTab_alertToRaid == true then
        setAlertChannel("raid")
    else
        setAlertChannel("rw")
    end

    -- Separador
    local sep2 = child:CreateTexture(nil, "ARTWORK")
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT", 4, -y)
    sep2:SetWidth(210)
    sep2:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep2:SetVertexColor(0.25, 0.25, 0.25, 1)
    y = y + 8

    wipeTable(BuffSettings.alertEdits)

    for i = 1, 2 do
        ensureAlerts()
        local slot = RaidStationDB.buffTab_alerts[i]

        local lbl = child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        lbl:SetPoint("TOPLEFT", 4, -y)
        lbl:SetText("Alerta " .. i .. ":")
        y = y + 16

        local msgE = CreateFrame("EditBox", "RSBuffAlMsg" .. i, child)
        msgE:SetSize(210, 90)
        msgE:SetPoint("TOPLEFT", 4, -y)
        msgE:SetAutoFocus(false)
        msgE:SetMultiLine(true)
        msgE:SetText(slot.message or "")
        msgE:SetMaxLetters(255)
        msgE:SetFontObject("ChatFontNormal")
        if ns.GUI and ns.GUI.SkinEditBox then ns.GUI.SkinEditBox(msgE) end
        msgE:SetTextInsets(6, 6, 6, 6)

        msgE:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        local cnt = child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        cnt:SetPoint("TOPRIGHT", msgE, "BOTTOMRIGHT", -4, -2)
        local function updCnt()
            cnt:SetText(tostring(strlen(msgE:GetText() or "")) .. "/255")
        end
        msgE:SetScript("OnTextChanged", function(self)
            slot.message = self:GetText()
            updCnt()
            if ns.BuffTab and ns.BuffTab.SyncFromDB then ns.BuffTab.SyncFromDB() end
        end)
        updCnt()

        tinsert(BuffSettings.alertEdits, { msg = msgE, slot = slot })
        y = y + 150
    end
end

function BuffSettings.Initialize()
end

ns.BuffSettings = BuffSettings
