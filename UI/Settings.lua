-- RaidStation :: UI/Settings.lua
-- Part of RaidStation by Marfyn- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
local Settings = {}

-- Referencia al accentSwatch para RefreshColors
local _accentSwatch
local _sliderThumbs = {}
local _iconBtns = {}

function Settings.RefreshColors()
    local r, g, b = ns.GUI.GetAccentColor()
    -- Actualizar accentSwatch
    if _accentSwatch then
        _accentSwatch:SetBackdropColor(r, g, b, 1)
    end
    -- Actualizar thumbs de sliders
    for _, thumb in ipairs(_sliderThumbs) do
        if thumb then thumb:SetVertexColor(r, g, b, 0.9) end
    end
    -- Actualizar highlight de iconos seleccionados
    if _iconBtns and #_iconBtns > 0 then
        local cur = RaidStationDB.floatBtnIcon or "circle.blp"
        for _, ib in ipairs(_iconBtns) do
            if ib.border then
                if ib.iconFile == cur then
                    ib.border:SetBackdropBorderColor(r, g, b, 1)
                    ib.border:SetBackdropColor(r * 0.28, g * 0.33, b * 0.42, 1)
                else
                    ib.border:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
                    ib.border:SetBackdropColor(0.06, 0.06, 0.06, 0)
                end
            end
        end
    end
end

function Settings.CreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints()
    panel:Hide()

    -- TTL Slider
    local ttlSlider = CreateFrame("Slider", "RaidStationTTLSlider", panel, "OptionsSliderTemplate")
    ttlSlider:SetPoint("TOPLEFT", 36, -45)
    ttlSlider:SetMinMaxValues(35, 600)
    ttlSlider:SetValueStep(8)
    ttlSlider:SetSize(200, 16)
    _G[ttlSlider:GetName() .. "Low"]:SetText("30s")
    _G[ttlSlider:GetName() .. "High"]:SetText("600s")
    _G[ttlSlider:GetName() .. "Text"]:SetText("Tiempo de Vida (segundos): " .. (RaidStationDB.ttl or 120))
    ttlSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        _G[self:GetName() .. "Text"]:SetText("TTL del Mensaje (segundos): " .. value)
        RaidStationDB.ttl = value
        ns.Config.DEFAULTS.ttl = value
    end)
    ttlSlider:SetValue(RaidStationDB.ttl or 120)

    -- Switches estilo HydraUI para opciones generales (Fase 2)
    local settingsSwitches = {}
    local switchBaseLevel = panel:GetFrameLevel() + 40

    local function RefreshSettingsSwitches()
        for _, sw in ipairs(settingsSwitches) do
            if sw.RefreshAccent then
                sw:RefreshAccent()
            end
            sw:SetFrameLevel(switchBaseLevel)
            if sw.switch then
                sw.switch:SetFrameLevel(switchBaseLevel + 2)
            end
            if sw.knob then
                sw.knob:SetFrameLevel(switchBaseLevel + 4)
            end
        end
    end
    panel.RefreshSettingsSwitches = RefreshSettingsSwitches

    local mergeToggle = ns.GUI.CreateSwitch(panel, "Agrupar mensajes por Líder", RaidStationDB.mergeByLeader, function(value)
        RaidStationDB.mergeByLeader = value
        ns.Config.DEFAULTS.mergeByLeader = value
        RefreshSettingsSwitches()
    end, 320, 20)
    mergeToggle:SetPoint("TOPLEFT", 35, -75)
    settingsSwitches[#settingsSwitches + 1] = mergeToggle

    local debugToggle = ns.GUI.CreateSwitch(panel, "Habilitar Modo Debug", RaidStationDB.debug, function(value)
        RaidStationDB.debug = value
        ns.Config.DEFAULTS.debug = value
        RefreshSettingsSwitches()
    end, 320, 20)
    debugToggle:SetPoint("TOPLEFT", 35, -98)
    settingsSwitches[#settingsSwitches + 1] = debugToggle

    local minimapToggle = ns.GUI.CreateSwitch(panel, "Mostrar icono del Minimapa", RaidStationDB.showMinimap, function(value)
        RaidStationDB.showMinimap = value
        ns.Config.DEFAULTS.showMinimap = value
        if ns.Minimap and ns.Minimap.Button then
            if value then ns.Minimap.Button:Show() else ns.Minimap.Button:Hide() end
        end
        RefreshSettingsSwitches()
    end, 320, 20)
    minimapToggle:SetPoint("TOPLEFT", 35, -121)
    settingsSwitches[#settingsSwitches + 1] = minimapToggle

    local floatToggle = ns.GUI.CreateSwitch(panel, "Mostrar boton flotante de acceso rapido", RaidStationDB.showFloatBtn == true, function(value)
        RaidStationDB.showFloatBtn = value
        if ns.GUI.FloatBtn then
            if value then ns.GUI.FloatBtn:Show() else ns.GUI.FloatBtn:Hide() end
        end
        RefreshSettingsSwitches()
    end, 320, 20)
    floatToggle:SetPoint("TOPLEFT", 35, -144)
    settingsSwitches[#settingsSwitches + 1] = floatToggle

    local windowLockToggle = ns.GUI.CreateSwitch(panel, "Anclar ventana a la pantalla", RaidStationDB.windowLocked, function(value)
        if ns.GUI and ns.GUI.ApplyWindowLock then
            ns.GUI.ApplyWindowLock(value)
        end
        RefreshSettingsSwitches()
    end, 320, 20)
    windowLockToggle:SetPoint("TOPLEFT", 35, -167)
    settingsSwitches[#settingsSwitches + 1] = windowLockToggle

    RefreshSettingsSwitches()

    -- =========================================================
    -- SECCIÓN: APARIENCIA
    -- =========================================================
    local bgSectionTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bgSectionTitle:SetPoint("TOPLEFT", 35, -200)
    ns.GUI.RegisterAccentLabel(bgSectionTitle, "APARIENCIA")

    -- Fila: Color swatch + label + Reset
    local colorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colorLabel:SetPoint("TOPLEFT", 35, -216)
    colorLabel:SetText("Color del panel:")
    ns.GUI.RegisterAccentLabel(colorLabel, true)

    local colorSwatch = CreateFrame("Button", nil, panel)
    colorSwatch:SetSize(18, 18)
    colorSwatch:SetPoint("TOPLEFT", 35, -230)
    colorSwatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    colorSwatch:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    local bc = RaidStationDB.bodyColor or { 0.13, 0.13, 0.13 }
    colorSwatch:SetBackdropColor(bc[1], bc[2], bc[3], 1)

    local colorBtnText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colorBtnText:SetPoint("LEFT", colorSwatch, "RIGHT", 6, 0)
    colorBtnText:SetText("Color")
    colorBtnText:SetTextColor(1, 1, 1)

    colorSwatch:SetScript("OnClick", function()
        local cur = RaidStationDB.bodyColor or { 0.13, 0.13, 0.13 }
        ColorPickerFrame:SetColorRGB(cur[1], cur[2], cur[3])
        ColorPickerFrame.previousValues = { cur[1], cur[2], cur[3] }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            ns.GUI.ApplyBodyColor(r, g, b)
            colorSwatch:SetBackdropColor(r, g, b, 1)
        end
        ColorPickerFrame.cancelFunc = function(prev)
            local pr, pg, pb = prev[1], prev[2], prev[3]
            ns.GUI.ApplyBodyColor(pr, pg, pb)
            colorSwatch:SetBackdropColor(pr, pg, pb, 1)
        end
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end)
    colorSwatch:SetScript("OnEnter", function(self)
        local r, g, b = ns.GUI.GetAccentColor()
        self:SetBackdropBorderColor(r, g, b, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Color del panel", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Click para abrir el selector de colores.", 1, 1, 1)
        GameTooltip:Show()
    end)
    colorSwatch:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        GameTooltip:Hide()
    end)

    -- Botón de reset (aplicar skin)
    local resetBtn = CreateFrame("Button", nil, panel)
    resetBtn:SetSize(50, 20)
    resetBtn:SetPoint("LEFT", colorBtnText, "RIGHT", 8, 0)
    if ns.GUI and ns.GUI.SkinButton then
        ns.GUI.SkinButton(resetBtn, true)
    end
    local resetLabel = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetLabel:SetAllPoints()
    resetLabel:SetJustifyH("CENTER")
    resetLabel:SetText("[Reset]")
    resetLabel:SetTextColor(0.5, 0.5, 0.5)
    resetBtn:SetScript("OnClick", function()
        ns.GUI.ApplyBodyColor(0.13, 0.13, 0.13)
        colorSwatch:SetBackdropColor(0.13, 0.13, 0.13, 1)
    end)
    resetBtn:SetScript("OnEnter", function() resetLabel:SetTextColor(1, 0.3, 0.3) end)
    resetBtn:SetScript("OnLeave", function() resetLabel:SetTextColor(0.5, 0.5, 0.5) end)

    -- Opacity  (-256)
    local savedAlpha = math.floor((RaidStationDB.bodyAlpha or 1.0) * 100)
    local opacLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    opacLabel:SetPoint("TOPLEFT", 35, -256)
    opacLabel:SetText("Opacidad del panel: " .. savedAlpha .. "%")
    ns.GUI.RegisterAccentLabel(opacLabel, true)

    local opacSlider = CreateFrame("Slider", "RSBodyAlphaSlider", panel, "OptionsSliderTemplate")
    opacSlider:SetPoint("TOPLEFT", 36, -270)
    opacSlider:SetMinMaxValues(0, 100)
    opacSlider:SetValueStep(5)
    opacSlider:SetSize(200, 16)
    _G[opacSlider:GetName() .. "Low"]:SetText("0%")
    _G[opacSlider:GetName() .. "High"]:SetText("100%")
    _G[opacSlider:GetName() .. "Text"]:SetText("")
    local opacReady = false
    opacSlider:SetScript("OnValueChanged", function(self, value)
        if not opacReady then return end
        value = math.floor(value / 5) * 5
        local alpha = value / 100
        RaidStationDB.bodyAlpha = alpha
        opacLabel:SetText("Opacidad del panel: " .. value .. "%")
        ns.GUI.ApplyBodyColor(nil, nil, nil, alpha)
    end)
    opacSlider:SetValue(savedAlpha)
    opacReady = true

    -- Fila: Borde  (-305)
    local borderToggle = ns.GUI.CreateSwitch(panel, "Borde clasico", RaidStationDB.showBorder ~= false, function(value)
        ns.GUI.ApplyBorder(value)
        RefreshSettingsSwitches()
    end, 320, 20)
    borderToggle:SetPoint("TOPLEFT", 35, -305)
    settingsSwitches[#settingsSwitches + 1] = borderToggle

    -- Tooltip interactivo para el switch de Borde clásico
    borderToggle.switch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Solo el marco", 1, 1, 1)
        GameTooltip:AddLine("", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    borderToggle.switch:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Accent color swatch — se posiciona junto al dropdown de fuente (ver más abajo, tras fontDrop)
    local ac = RaidStationDB.accentColor or { 0.36, 0.61, 0.84 }
    local accentSwatch = CreateFrame("Button", nil, panel)
    accentSwatch:SetSize(14, 14)
    accentSwatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    accentSwatch:SetBackdropColor(ac[1], ac[2], ac[3], 1)
    accentSwatch:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    _accentSwatch = accentSwatch  -- save reference for RefreshColors

    local accentLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    accentLabel:SetPoint("LEFT", accentSwatch, "RIGHT", 5, 0)
    accentLabel:SetText("Color de fuente")
    accentLabel:SetTextColor(1, 1, 1)

    accentSwatch:SetScript("OnClick", function()
        local prev = RaidStationDB.accentColor or { 0.36, 0.61, 0.84 }
        local prevR, prevG, prevB = prev[1], prev[2], prev[3]
        ColorPickerFrame:SetColorRGB(prevR, prevG, prevB)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { prevR, prevG, prevB }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            accentSwatch:SetBackdropColor(r, g, b, 1)
            ns.GUI.ApplyAccentColor(r, g, b)
        end
        ColorPickerFrame.cancelFunc = function(oldValues)
            local pr = (type(oldValues) == "table") and oldValues[1] or prevR
            local pg = (type(oldValues) == "table") and oldValues[2] or prevG
            local pb = (type(oldValues) == "table") and oldValues[3] or prevB
            accentSwatch:SetBackdropColor(pr, pg, pb, 1)
            ns.GUI.ApplyAccentColor(pr, pg, pb)
        end
        ColorPickerFrame:Show()
    end)
    accentSwatch:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Color de fuente", 1, 1, 1)
        GameTooltip:AddLine("Cambia el color principal del texto y acentos.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    accentSwatch:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        GameTooltip:Hide()
    end)

    -- =========================================================
    -- SECCIÓN: ICONO FLOTANTE  (-336)
    -- =========================================================
    local iconSectionTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconSectionTitle:SetPoint("TOPLEFT", 35, -336)
    ns.GUI.RegisterAccentLabel(iconSectionTitle, "ICONO FLOTANTE")

    local iconHint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconHint:SetPoint("TOPLEFT", 35, -350)
    iconHint:SetText("Selecciona el icono del boton flotante:")
    iconHint:SetTextColor(0.75, 0.75, 0.75)

    local FLOAT_ICONS = {
        { file = "circle.blp",  label = "Por defecto" },
        { file = "1circle.blp", label = "Variante 1"  },
        { file = "2circle.blp", label = "Variante 2"  },
        { file = "3circle.blp", label = "Variante 3"  },
        { file = "4circle.blp", label = "Variante 4"  },
        { file = "5circle.blp", label = "Variante 5"  },
    }
    local ICON_BASE_PATH = "Interface\\AddOns\\RaidStation\\Textures\\"
    local ICON_BTN_SIZE  = 28
    local ICON_SPACING   = 5

    local iconBtns = {}

    local function UpdateIconHighlight()
        local r, g, b = ns.GUI.GetAccentColor()
        local cur = RaidStationDB.floatBtnIcon or "circle.blp"
        for _, ib in ipairs(iconBtns) do
            if ib.iconFile == cur then
                ib.border:SetBackdropBorderColor(r, g, b, 1)
                ib.border:SetBackdropColor(r * 0.28, g * 0.33, b * 0.42, 1)
            else
                ib.border:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
                ib.border:SetBackdropColor(0.06, 0.06, 0.06, 0)
            end
        end
    end

    for i, iconDef in ipairs(FLOAT_ICONS) do
        local btn = CreateFrame("Button", nil, panel)
        btn:SetSize(ICON_BTN_SIZE, ICON_BTN_SIZE)

        if i == 1 then
            btn:SetPoint("TOPLEFT", 35, -366)
        else
            btn:SetPoint("LEFT", iconBtns[i - 1], "RIGHT", ICON_SPACING, 0)
        end

        local border = CreateFrame("Frame", nil, btn)
        border:SetAllPoints()
        border:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        border:SetBackdropColor(0.06, 0.06, 0.06, 0)
        border:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
        border:SetFrameLevel(btn:GetFrameLevel())
        btn.border = border

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(ICON_BASE_PATH .. iconDef.file)
        tex:SetAlpha(0.85)
        btn.tex = tex

        btn.iconFile = iconDef.file

        btn:SetScript("OnClick", function()
            RaidStationDB.floatBtnIcon = iconDef.file
            UpdateIconHighlight()
            if panel.RefreshSettingsSwitches then
                panel:RefreshSettingsSwitches()
            end
        end)

        btn:SetScript("OnEnter", function(self)
            self.tex:SetAlpha(1.0)
            local r, g, b = ns.GUI.GetAccentColor()
            self.border:SetBackdropBorderColor(r * 1.4 < 1 and r * 1.4 or 1, g * 1.4 < 1 and g * 1.4 or 1, b * 1.4 < 1 and b * 1.4 or 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(iconDef.label, ns.GUI.GetAccentColor())
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffff4444Requiere /reload|r para aplicarse al boton flotante.", 1, 1, 1, true)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            self.tex:SetAlpha(0.85)
            GameTooltip:Hide()
            UpdateIconHighlight()
            if panel.RefreshSettingsSwitches then
                panel:RefreshSettingsSwitches()
            end
        end)

        iconBtns[i] = btn
    end
    _iconBtns = iconBtns  -- save reference for RefreshColors

    UpdateIconHighlight()

    local reloadNote = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reloadNote:SetPoint("TOPLEFT", 35, -400)
    reloadNote:SetText("|cffff4444* /reload para aplicar el icono.|r")

    -- =========================================================
    -- SECCIÓN: FUENTE  (-418)
    -- =========================================================
    local fontLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontLabel:SetPoint("TOPLEFT", 35, -418)
    fontLabel:SetText("Fuente")
    fontLabel:SetTextColor(1, 0.82, 0)

    local fontDrop = ns.GUI.CreatePopupDropdown(panel, 140, 20, {}, "SFUIDisplayCondensed-Semibold", function(v)
        RaidStationDB.fontFace = v
        ns.GUI.ApplyGlobalFont()
    end)
    fontDrop:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -4)

    -- Anclar accentSwatch a la derecha del dropdown de fuente
    accentSwatch:SetPoint("LEFT", fontDrop, "RIGHT", 6, 0)

    local function InitializeFontDropdowns()
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        local fonts = {}
        if LSM then
            for _, f in ipairs(LSM:List("font")) do
                table.insert(fonts, f)
            end
        else
            fonts = { "SFUIDisplayCondensed-Semibold", "Friz Quadrata TT", "Arial Narrow", "Skurri", "Morpheus" }
        end
        table.sort(fonts)
        local opts = {}
        for _, f in ipairs(fonts) do
            opts[#opts + 1] = { text = f, value = f }
        end
        fontDrop:SetOptions(opts)
        local savedFont = RaidStationDB.fontFace or "SFUIDisplayCondensed-Semibold"
        fontDrop:SetValue(savedFont, false)
    end

    panel:SetScript("OnShow", function()
        InitializeFontDropdowns()
        RefreshSettingsSwitches()
    end)

    -- =========================================================
    -- Referencias externas
    -- =========================================================
    panel.ttlSlider        = ttlSlider
    panel.mergeToggle      = mergeToggle
    panel.debugToggle      = debugToggle
    panel.windowLockToggle = windowLockToggle

    -- === SKIN ===
    local function SkinSlider(slider)
        if not slider then return end
        local name = slider:GetName()
        if name then
            if _G[name .. "Low"]  then _G[name .. "Low"]:SetTextColor(0.7, 0.7, 0.7)   end
            if _G[name .. "High"] then _G[name .. "High"]:SetTextColor(0.7, 0.7, 0.7)  end
            if _G[name .. "Text"] then _G[name .. "Text"]:SetTextColor(0.9, 0.7, 0.2)  end
        end
        local thumb = slider:GetThumbTexture()
        if thumb then
            local ar, ag, ab = ns.GUI.GetAccentColor()
            thumb:SetWidth(8)
            thumb:SetHeight(16)
            thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
            thumb:SetVertexColor(ar, ag, ab, 0.9)
            _sliderThumbs[#_sliderThumbs + 1] = thumb  -- track for refresh
        end
        slider:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, tileSize = 0, edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        slider:SetBackdropColor(0.1, 0.1, 0.1, 1)
        slider:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end

    SkinSlider(ttlSlider)
    SkinSlider(opacSlider)
    -- === FIN SKIN ===

    Settings.Panel = panel
    return panel
end

function Settings.Initialize()
    Settings.CreatePanel(ns.GUI.MainFrame)
end

ns.Settings = Settings
