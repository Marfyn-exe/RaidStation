-- RaidStation :: UI/Widgets.lua
-- Widgets reutilizables: switches, dropdowns, etc.
-- Part of RaidStation by Marfin- | 2026
local addonName, ns = ...
ns.GUI = ns.GUI or {}
local GUI = ns.GUI

local tinsert = table.insert

function GUI.CreateBox(parent, sizeX, sizeY, colorR, colorG, colorB)
    local st = GUI.GetStyleTokens()
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(sizeX, sizeY)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    box:SetBackdropColor(st.panelBg[1], st.panelBg[2], st.panelBg[3], 1)
    box:SetBackdropBorderColor(colorR or st.panelBorder[1], colorG or st.panelBorder[2], colorB or st.panelBorder[3], 1)
    return box
end

-- ==========================================
-- HELPERS DE INTERFAZ ESTILO HYDRAUI (FASE 1)
-- ==========================================
GUI.switches = GUI.switches or {}

function GUI.CreateSwitch(parent, labelText, defaultValue, onClick, width, height)
    width = width or 320
    height = height or 20
    local st = GUI.GetStyleTokens()

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, height)

    local switchHeight = 14
    local switchWidth = 36
    local labelMaxW = math.max(8, width - switchWidth - 10)

    local text = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
    text:SetPoint("LEFT", frame, 4, 0)
    text:SetWidth(labelMaxW)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(labelText or "")
    text:SetTextColor(st.textMuted[1], st.textMuted[2], st.textMuted[3], 1)

    local switch = CreateFrame("Frame", nil, frame)
    switch:SetSize(switchWidth, switchHeight)
    switch:SetPoint("RIGHT", frame, 0, 0)
    switch:SetFrameLevel(frame:GetFrameLevel() + 4)
    switch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    switch:SetBackdropColor(st.switchBg[1], st.switchBg[2], st.switchBg[3], 1)
    switch:SetBackdropBorderColor(st.borderDark[1], st.borderDark[2], st.borderDark[3], 1)

    local trackBg = switch:CreateTexture(nil, "ARTWORK")
    trackBg:SetPoint("TOPLEFT", switch, 1, -1)
    trackBg:SetPoint("BOTTOMRIGHT", switch, -1, 1)
    trackBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    trackBg:SetVertexColor(st.switchTrackOff[1], st.switchTrackOff[2], st.switchTrackOff[3], 1)

    local flavor = switch:CreateTexture(nil, "ARTWORK")
    flavor:SetPoint("TOPLEFT", switch, 1, -1)
    flavor:SetPoint("BOTTOMRIGHT", switch, -1, 1)
    flavor:SetTexture("Interface\\Buttons\\WHITE8X8")

    local knob = CreateFrame("Frame", nil, switch)
    knob:SetSize(switchHeight, switchHeight)
    knob:SetFrameLevel(switch:GetFrameLevel() + 2)
    knob:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    knob:SetBackdropBorderColor(st.borderDark[1], st.borderDark[2], st.borderDark[3], 1)

    local value = not not defaultValue
    local animDuration = 0.12
    local animTimer = 0
    local startPoint = 0
    local endPoint = 0

    local function UpdateVisuals()
        local s = GUI.GetStyleTokens()
        local r, g, b = s.accentR, s.accentG, s.accentB

        switch:SetBackdropColor(s.switchBg[1], s.switchBg[2], s.switchBg[3], 1)
        knob:SetBackdropBorderColor(s.borderDark[1], s.borderDark[2], s.borderDark[3], 1)
        text:SetTextColor(s.textMuted[1], s.textMuted[2], s.textMuted[3], 1)

        knob:ClearAllPoints()
        if value then
            knob:SetPoint("RIGHT", switch, 0, 0)
            knob:SetBackdropColor(s.switchKnobOn[1], s.switchKnobOn[2], s.switchKnobOn[3], 1)
            trackBg:SetVertexColor(s.switchTrackOn[1], s.switchTrackOn[2], s.switchTrackOn[3], 1)
            flavor:SetVertexColor(r, g, b, 0.55)
            flavor:Show()
            switch:SetBackdropBorderColor(r * 0.45, g * 0.45, b * 0.45, 1)
        else
            knob:SetPoint("LEFT", switch, 0, 0)
            knob:SetBackdropColor(s.switchKnobOff[1], s.switchKnobOff[2], s.switchKnobOff[3], 1)
            trackBg:SetVertexColor(s.switchTrackOff[1], s.switchTrackOff[2], s.switchTrackOff[3], 1)
            flavor:Hide()
            switch:SetBackdropBorderColor(s.borderDark[1], s.borderDark[2], s.borderDark[3], 1)
        end
    end
    UpdateVisuals()

    local function SetValue(newValue, fireCallback)
        local want = not not newValue
        if want == value then
            UpdateVisuals()
            return
        end

        value = want
        animTimer = 0

        local maxTravel = switch:GetWidth() - knob:GetWidth()
        local point, _, _, xOfs = knob:GetPoint()
        if point == "RIGHT" then
            startPoint = maxTravel
        elseif point == "LEFT" then
            startPoint = xOfs or 0
        else
            startPoint = value and maxTravel or 0
        end

        endPoint = value and maxTravel or 0
        if value then
            flavor:Show()
        end

        switch:SetScript("OnUpdate", function(self, elapsed)
            animTimer = animTimer + elapsed
            local t = animTimer / animDuration
            if t >= 1 then
                self:SetScript("OnUpdate", nil)
                UpdateVisuals()
            else
                local currentX = startPoint + (endPoint - startPoint) * t
                knob:ClearAllPoints()
                knob:SetPoint("LEFT", switch, "LEFT", currentX, 0)
            end
        end)

        if fireCallback and onClick then
            onClick(value)
        end
    end

    switch:EnableMouse(true)
    switch:SetScript("OnMouseDown", function()
        SetValue(not value, true)
    end)
    switch:SetScript("OnEnter", function(self)
        local s = GUI.GetStyleTokens()
        local r, g, b = s.accentR, s.accentG, s.accentB
        if value then
            self:SetBackdropBorderColor(r * 0.65, g * 0.65, b * 0.65, 1)
        else
            self:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
        end
    end)
    switch:SetScript("OnLeave", function(self)
        UpdateVisuals()
    end)

    frame.GetChecked = function()
        return value
    end
    frame.SetChecked = function(self, v)
        SetValue(v and true or false, false)
    end
    frame.Toggle = function(self)
        SetValue(not value, true)
    end

    frame.trackBg = trackBg
    frame.switch = switch
    frame.knob = knob
    frame.flavor = flavor
    frame.label = text
    frame.RefreshAccent = function()
        switch:SetScript("OnUpdate", nil)
        UpdateVisuals()
    end
    tinsert(GUI.switches, frame)

    return frame
end

function GUI.CreateTextBox(parent, labelText, defaultText, onEnterPressed, width, height)
    width = width or 320
    height = height or 24

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, height)

    -- Texto descriptivo
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", frame, 4, 0)
    text:SetText("|cffc7c7c7" .. labelText .. "|r")

    -- Contenedor del EditBox (borde negro + fondo mate)
    local ebContainer = CreateFrame("Frame", nil, frame)
    ebContainer:SetSize(130, 20)
    ebContainer:SetPoint("RIGHT", frame, 0, 0)
    ebContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    ebContainer:SetBackdropColor(0.06, 0.06, 0.06, 1)
    ebContainer:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- EditBox real
    local eb = CreateFrame("EditBox", nil, ebContainer)
    eb:SetSize(122, 18)
    eb:SetPoint("CENTER", ebContainer, 0, 0)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetAutoFocus(false)
    eb:SetText(defaultText or "")
    eb:SetTextInsets(2, 2, 0, 0)

    -- Feedback interactivo (Celeste al ganar foco)
    eb:SetScript("OnEditFocusGained", function()
        local r, g, b = GUI.GetAccentColor()
        ebContainer:SetBackdropBorderColor(r, g, b, 1)
    end)
    eb:SetScript("OnEditFocusLost", function()
        ebContainer:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if onEnterPressed then onEnterPressed(self:GetText()) end
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    frame.editBox = eb
    frame.container = ebContainer
    return frame
end

function GUI.CreatePopupDropdown(parent, width, height, options, initialValue, onSelect)
    width = width or 80
    height = height or 20

    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, height)
    -- Omitimos GUI.ApplyRSButtonStyle aquí para no aplicar textura de botón estándar,
    -- lo manejaremos con el nuevo skin manual.
    if btn.SetNormalTexture then btn:SetNormalTexture("") end
    if btn.SetPushedTexture then btn:SetPushedTexture("") end
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
    if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
    btn:SetBackdrop(nil)

    -- Fondo del dropdown (estilo input)
    local st = GUI.GetStyleTokens()
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    btn:SetBackdropColor(st.inputBg[1], st.inputBg[2], st.inputBg[3], 1)
    btn:SetBackdropBorderColor(st.borderDark[1], st.borderDark[2], st.borderDark[3], 1)

    local txt = btn:GetFontString()
    if txt then
        txt:ClearAllPoints()
        txt:SetPoint("LEFT", btn, "LEFT", 6, 0)
        txt:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
        txt:SetJustifyH("LEFT")
    end

    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    popup:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    popup:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    popup:Hide()
    btn.popup = popup

    local closeDetect = CreateFrame("Frame", nil, UIParent)
    closeDetect:SetAllPoints()
    closeDetect:SetFrameStrata("DIALOG")
    closeDetect:Hide()
    closeDetect:SetScript("OnMouseDown", function()
        popup:Hide()
        closeDetect:Hide()
    end)
    popup:HookScript("OnShow", function() closeDetect:Show() end)
    popup:HookScript("OnHide", function() closeDetect:Hide() end)

    local value, label
    local currentOptions = options or {}

    local function applySelection(v, text, fire)
        value = v
        label = text or ""
        btn:SetText(label)
        if fire and onSelect then
            onSelect(v, text)
        end
    end

    local function rebuildPopup()
        local n = #currentOptions
        local itemH = 16
        popup:SetSize(width, math.max(18, n * 17 + 4))

        for i = 1, n do
            local opt = currentOptions[i]
            local ob = popup.buttons and popup.buttons[i]
            if not ob then
                ob = CreateFrame("Button", nil, popup)
                ob:SetHeight(itemH)
                if ns.GUI and ns.GUI.SkinButton then ns.GUI.SkinButton(ob, true) end
                local fs = ob:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetAllPoints()
                fs:SetJustifyH("LEFT")
                ob.fs = fs
                popup.buttons = popup.buttons or {}
                popup.buttons[i] = ob
            end

            ob:ClearAllPoints()
            ob:SetPoint("TOPLEFT", popup, "TOPLEFT", 4, -(i - 1) * 17 - 2)
            ob:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -4, -(i - 1) * 17 - 2)
            ob.fs:SetText(opt.text or tostring(opt.value or ""))
            ob.fs:SetTextColor(0.8, 0.8, 0.8)
            ob:SetScript("OnClick", function()
                applySelection(opt.value, opt.text, true)
                popup:Hide()
            end)
            ob:SetScript("OnEnter", function() ob.fs:SetTextColor(1, 1, 1) end)
            ob:SetScript("OnLeave", function() ob.fs:SetTextColor(0.8, 0.8, 0.8) end)
            ob:Show()
        end

        if popup.buttons then
            for i = n + 1, #popup.buttons do
                popup.buttons[i]:Hide()
            end
        end
    end

    function btn:SetOptions(opts)
        currentOptions = opts or {}
        rebuildPopup()
        if #currentOptions > 0 then
            local keep
            for _, opt in ipairs(currentOptions) do
                if opt.value == value then
                    keep = opt
                    break
                end
            end
            if keep then
                applySelection(keep.value, keep.text, false)
            else
                applySelection(currentOptions[1].value, currentOptions[1].text, false)
            end
        else
            applySelection(nil, "", false)
        end
    end

    function btn:SetValue(v, fire)
        for _, opt in ipairs(currentOptions) do
            if opt.value == v then
                applySelection(opt.value, opt.text, fire and true or false)
                return
            end
        end
    end

    function btn:GetValue()
        return value
    end

    btn:SetScript("OnClick", function(self)
        if popup:IsShown() then
            popup:Hide()
        else
            popup:ClearAllPoints()
            popup:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)
            popup:Show()
        end
    end)

    btn:SetOptions(currentOptions)
    if initialValue ~= nil then
        btn:SetValue(initialValue, false)
    end

    return btn
end
