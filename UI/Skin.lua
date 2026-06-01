-- RaidStation :: UI/Skin.lua
-- Helpers de skinning para botones, editboxes, dropdowns y scrollbars.
-- Parte de RaidStation por Marfin- | 2026
local addonName, ns = ...
ns.GUI = ns.GUI or {}
local GUI = ns.GUI

local strlower = string.lower
local strfind = string.find

local function Clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

function GUI.GetStyleMode()
    return "flat"
end

function GUI.GetStyleTokens()
    local mode = "flat"
    local ar, ag, ab = 0.36, 0.61, 0.84
    if GUI.GetAccentColor then
        local r, g, b = GUI.GetAccentColor()
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then
            ar, ag, ab = r, g, b
        end
    end

    local t = {
        mode = mode,
        accentR = ar,
        accentG = ag,
        accentB = ab,
        textPrimary = { 1, 1, 1 },
        textMuted = { 0.78, 0.78, 0.78 },
        borderDark = { 0, 0, 0 },
        panelBg = { 0.06, 0.06, 0.06 },
        panelBorder = { 0.12, 0.12, 0.12 },
        inputBg = { 0.12, 0.15, 0.18 },
        inputFocusBorder = { ar, ag, ab },
        buttonBg = { 0.12, 0.12, 0.12 },
        buttonBorder = { 0, 0, 0 },
        buttonTex = nil,
        buttonTexColor = { 1, 1, 1 },
        buttonHoverOverlay = { 1, 1, 1, 0.08 },
        switchBg = { 0.06, 0.06, 0.06 },
        switchTrackOff = { 0.12, 0.12, 0.12 },
        switchTrackOn = { Clamp01(ar * 0.62), Clamp01(ag * 0.62), Clamp01(ab * 0.62) },
        switchKnobOff = { 0.35, 0.35, 0.35 },
        switchKnobOn = { ar, ag, ab },
    }

    return t
end

function GUI.SkinButton(btn, strip)
    if not btn then return end

    -- Limpiar texturas antiguas si se solicita
    if strip then
        if btn.SetNormalTexture then btn:SetNormalTexture("") end
        if btn.SetPushedTexture then btn:SetPushedTexture("") end
        if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
        if btn.SetDisabledTexture then btn:SetDisabledTexture("") end

        local name = btn:GetName()
        if name then
            if _G[name .. "Left"] then _G[name .. "Left"]:Hide() end
            if _G[name .. "Right"] then _G[name .. "Right"]:Hide() end
            if _G[name .. "Middle"] then _G[name .. "Middle"]:Hide() end
        end
    end

    -- Estilo flat + borde dinámico
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })

    btn:SetBackdropColor(0.17, 0.17, 0.17, 1)
    btn:SetBackdropBorderColor(0, 0, 0, 0.8)

    if not btn.rsFlatBgTex then
        btn.rsFlatBgTex = btn:CreateTexture(nil, "ARTWORK")
        btn.rsFlatBgTex:SetPoint("TOPLEFT", btn, 1, -1)
        btn.rsFlatBgTex:SetPoint("BOTTOMRIGHT", btn, -1, 1)
        btn.rsFlatBgTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.rsFlatBgTex:SetVertexColor(0.20, 0.20, 0.20)
    end
    btn.rsFlatBgTex:Show()

    btn:SetNormalFontObject("GameFontNormalSmall")
    btn:SetHighlightFontObject("GameFontHighlightSmall")

    if not btn.rsHoverTex then
        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", btn, 1, -1)
        hl:SetPoint("BOTTOMRIGHT", btn, -1, 1)
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetVertexColor(1, 1, 1, 0.1)
        btn:SetHighlightTexture(hl)
        btn.rsHoverTex = hl
    end

    if btn.rsSkinButtonHooks then return end
    btn.rsSkinButtonHooks = true
end

function GUI.ApplyCustomTexture(btn, texPath, alphaIdle, alphaHover)
    alphaIdle = alphaIdle or 0.85
    alphaHover = alphaHover or 1.0

    -- Limpiar skin ElvUI/Blizzard
    if btn.SetNormalTexture then btn:SetNormalTexture("") end
    if btn.SetPushedTexture then btn:SetPushedTexture("") end
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
    btn:SetBackdrop(nil)

    if btn.rsFlatBgTex then btn.rsFlatBgTex:Hide() end
    if btn.rsHoverTex then btn:SetHighlightTexture(nil) end

    -- Textura custom en BACKGROUND (debajo del texto)
    local bgTex = btn:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints(btn)
    bgTex:SetTexture(texPath)
    bgTex:SetAlpha(alphaIdle)
    btn.bgTex = bgTex -- guardar referencia para cambios futuros

    -- Hover
    btn:HookScript("OnEnter", function(self)
        bgTex:SetAlpha(alphaHover)
        bgTex:SetVertexColor(0.8, 0.9, 1) -- tinte azul suave ElvUI
    end)
    btn:HookScript("OnLeave", function(self)
        bgTex:SetAlpha(alphaIdle)
        bgTex:SetVertexColor(1, 1, 1)
    end)
end

function GUI.ApplyRSButtonStyle(btn, texPath)
    if not btn then return end
    local st = GUI.GetStyleTokens()

    local useTex = st.buttonTex

    if btn.SetNormalTexture then btn:SetNormalTexture("") end
    if btn.SetPushedTexture then btn:SetPushedTexture("") end
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
    if btn.SetDisabledTexture then btn:SetDisabledTexture("") end

    local name = btn:GetName()
    if name then
        if _G[name .. "Left"] then _G[name .. "Left"]:Hide() end
        if _G[name .. "Right"] then _G[name .. "Right"]:Hide() end
        if _G[name .. "Middle"] then _G[name .. "Middle"]:Hide() end
    end

    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    btn:SetBackdropColor(st.buttonBg[1], st.buttonBg[2], st.buttonBg[3], 1)
    btn:SetBackdropBorderColor(st.buttonBorder[1], st.buttonBorder[2], st.buttonBorder[3], 1)

    if not btn.rsStyleInnerBorder then
        local ib = btn:CreateTexture(nil, "ARTWORK")
        ib:SetTexture("Interface\\Buttons\\WHITE8X8")
        ib:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        ib:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        ib:SetVertexColor(0, 0, 0, 0.55)
        btn.rsStyleInnerBorder = ib
    end

    if not btn.rsStyleBgTex then
        local bgTex = btn:CreateTexture(nil, "BORDER")
        bgTex:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        bgTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        btn.rsStyleBgTex = bgTex
    end

    if useTex and not strfind(strlower(useTex), "%.blp") then
        btn.rsStyleBgTex:SetTexture(useTex)
        btn.rsStyleBgTex:SetVertexColor(st.buttonTexColor[1], st.buttonTexColor[2], st.buttonTexColor[3], 1)
        btn.rsStyleBgTex:Show()
    else
        btn.rsStyleBgTex:SetTexture(nil)
        btn.rsStyleBgTex:Hide()
    end

    if not btn.rsStyleHighlight then
        local hl = btn:CreateTexture(nil, "ARTWORK")
        hl:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        hl:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.rsStyleHighlight = hl
    end
    btn.rsStyleHighlight:SetVertexColor(st.buttonHoverOverlay[1], st.buttonHoverOverlay[2], st.buttonHoverOverlay[3],
        st.buttonHoverOverlay[4])
    btn.rsStyleHighlight:SetAlpha(0)

    btn.bgTex = btn.rsStyleBgTex

    local function OffsetButtonText(self, x, y)
        local fs = self:GetFontString()
        if fs then
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", self, "CENTER", x, y)
        end
    end

    if btn.rsStyleHooks then return end
    btn.rsStyleHooks = true

    btn:HookScript("OnEnter", function(self)
        self.rsStyleHighlight:SetAlpha(1)
        if self.rsStyleInnerBorder then
            self.rsStyleInnerBorder:SetVertexColor(0, 0, 0, 0.45)
        end
    end)
    btn:HookScript("OnLeave", function(self)
        self.rsStyleHighlight:SetAlpha(0)
        local s = GUI.GetStyleTokens()
        if self.rsStyleBgTex and self.rsStyleBgTex:IsShown() then
            self.rsStyleBgTex:SetVertexColor(s.buttonTexColor[1], s.buttonTexColor[2], s.buttonTexColor[3], 1)
        end
        if self.rsStyleInnerBorder then
            self.rsStyleInnerBorder:SetVertexColor(0, 0, 0, 0.55)
        end
        self:SetBackdropColor(s.buttonBg[1], s.buttonBg[2], s.buttonBg[3], 1)
        self:SetBackdropBorderColor(s.buttonBorder[1], s.buttonBorder[2], s.buttonBorder[3], 1)
        OffsetButtonText(self, 0, 0)
    end)
    btn:HookScript("OnMouseDown", function(self)
        local s = GUI.GetStyleTokens()
        if self.rsStyleBgTex and self.rsStyleBgTex:IsShown() then
            self.rsStyleBgTex:SetVertexColor(s.buttonTexColor[1] * 0.85, s.buttonTexColor[2] * 0.85,
                s.buttonTexColor[3] * 0.85, 1)
        end
        self:SetBackdropColor(Clamp01(s.buttonBg[1] * 0.85), Clamp01(s.buttonBg[2] * 0.85), Clamp01(s.buttonBg[3] * 0.85),
            1)
        OffsetButtonText(self, 1, -1)
    end)
    btn:HookScript("OnMouseUp", function(self)
        local s = GUI.GetStyleTokens()
        if self.rsStyleBgTex and self.rsStyleBgTex:IsShown() then
            self.rsStyleBgTex:SetVertexColor(s.buttonTexColor[1], s.buttonTexColor[2], s.buttonTexColor[3], 1)
        end
        self:SetBackdropColor(s.buttonBg[1], s.buttonBg[2], s.buttonBg[3], 1)
        OffsetButtonText(self, 0, 0)
    end)
end

function GUI.ApplyHydraButtonStyle(btn, texPath, alphaIdle, alphaHover)
    GUI.ApplyRSButtonStyle(btn, texPath)
end

function GUI.SkinDropDown(drop)
    if not drop then return end
    local st = GUI.GetStyleTokens()
    local name = drop:GetName()
    if not name then return end

    if _G[name .. "Left"] then _G[name .. "Left"]:SetAlpha(0) end
    if _G[name .. "Right"] then _G[name .. "Right"]:SetAlpha(0) end
    if _G[name .. "Middle"] then _G[name .. "Middle"]:SetAlpha(0) end

    local btn = _G[name .. "Button"]
    if btn then
        btn:ClearAllPoints()
        btn:SetPoint("RIGHT", drop, "RIGHT", -10, 3)
        btn:SetSize(20, 20)

        -- Quitamos el skin individual del boton para que parezca una sola pieza
        if btn.SetBackdrop then btn:SetBackdrop(nil) end

        local tex = btn:GetNormalTexture()
        if tex then
            tex:SetDesaturated(true)
            tex:SetVertexColor(0.65, 0.65, 0.65)
        end
    end

    -- Fondo unico para todo el dropdown
    local bg = drop.mskin or CreateFrame("Frame", nil, drop)
    bg:ClearAllPoints()
    bg:SetPoint("LEFT", 0, 0)
    bg:SetPoint("RIGHT", drop, "RIGHT", 0, 0)
    bg:SetHeight(20)
    bg:SetFrameLevel(drop:GetFrameLevel() - 1)

    bg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    -- Usamos inputBg para diferenciar claramente de los botones (buttonBg)
    bg:SetBackdropColor(st.inputBg[1], st.inputBg[2], st.inputBg[3], 1)
    bg:SetBackdropBorderColor(st.borderDark[1], st.borderDark[2], st.borderDark[3], 1)
    drop.mskin = bg
end

function GUI.SkinEditBox(edit)
    if not edit then return end
    local st = GUI.GetStyleTokens()

    local name = edit:GetName()
    if name then
        if _G[name .. "Left"] then _G[name .. "Left"]:Hide() end
        if _G[name .. "Right"] then _G[name .. "Right"]:Hide() end
        if _G[name .. "Middle"] then _G[name .. "Middle"]:Hide() end
    end

    edit:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })

    edit:SetBackdropColor(st.inputBg[1], st.inputBg[2], st.inputBg[3], 1)
    edit:SetBackdropBorderColor(st.borderDark[1], st.borderDark[2], st.borderDark[3], 1)

    if not edit.rsEditHooks then
        edit.rsEditHooks = true
        edit:HookScript("OnEditFocusGained", function(self)
            local s = GUI.GetStyleTokens()
            self:SetBackdropBorderColor(s.inputFocusBorder[1], s.inputFocusBorder[2], s.inputFocusBorder[3], 1)
        end)

        edit:HookScript("OnEditFocusLost", function(self)
            local s = GUI.GetStyleTokens()
            self:SetBackdropBorderColor(s.borderDark[1], s.borderDark[2], s.borderDark[3], 1)
        end)
    end

    -- Márgenes de texto adaptativos: inputs pequeños usan sangría mínima
    local w = edit:GetWidth() or 100
    if w <= 50 then
        edit:SetTextInsets(4, 4, 0, 0)
    else
        edit:SetTextInsets(6, 6, 0, 0)
    end
end

GUI.scrollBars = {}

local RS_SCROLL_BAR_W = 15
local RS_SCROLL_BTN_H = 15
local RS_SCROLL_THUMB_H = 18
-- Posicion manual del scrollbar (lista BUSCAR)
local RS_SCROLL_BAR_OFFSET_X = 18 -- + = mas a la derecha
local RS_SCROLL_BAR_OFFSET_Y = 3  -- + = sube toda la barra
-- Flechas empaquetadas en RaidStation
local RS_ARROW_UP_TEX = "Interface\\AddOns\\RaidStation\\Textures\\UI\\ArrowUp.tga"
local RS_ARROW_DOWN_TEX = "Interface\\AddOns\\RaidStation\\Textures\\UI\\ArrowDown.tga"

local function GetScrollArrowTexture(isUp)
    return isUp and RS_ARROW_UP_TEX or RS_ARROW_DOWN_TEX
end

local function SkinScrollArrowButton(btn, isUp)
    if not btn or btn.rsHydraSkinned then return end
    btn.rsHydraSkinned = true

    btn:SetAlpha(1)
    btn:SetSize(RS_SCROLL_BAR_W, RS_SCROLL_BTN_H)
    btn:SetNormalTexture("")
    btn:SetPushedTexture("")
    btn:SetDisabledTexture("")
    btn:SetHighlightTexture("")
    for _, region in ipairs({ btn:GetRegions() }) do
        if region:IsObjectType("Texture") then
            region:Hide()
        end
    end

    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    btn:SetBackdropColor(0.17, 0.17, 0.17, 1)
    btn:SetBackdropBorderColor(0, 0, 0, 1)

    local ar, ag, ab = GUI.GetAccentColor()
    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(16, 16)
    arrow:SetPoint("CENTER")
    arrow:SetTexture(GetScrollArrowTexture(isUp))
    arrow:SetVertexColor(ar, ag, ab, 1)
    btn.rsArrow = arrow

    btn:HookScript("OnEnter", function(self)
        if self.rsArrow then
            self.rsArrow:SetVertexColor(0.85, 0.95, 1, 1)
        end
        self:SetBackdropColor(0.22, 0.22, 0.22, 1)
    end)
    btn:HookScript("OnLeave", function(self)
        local r, g, b = GUI.GetAccentColor()
        if self.rsArrow then
            self.rsArrow:SetVertexColor(r, g, b, 1)
        end
        self:SetBackdropColor(0.17, 0.17, 0.17, 1)
    end)
    btn:HookScript("OnMouseDown", function(self)
        if self.rsArrow then
            local r, g, b = GUI.GetAccentColor()
            self.rsArrow:SetVertexColor(r * 0.85, g * 0.85, b * 0.85, 1)
        end
    end)
    btn:HookScript("OnMouseUp", function(self)
        local r, g, b = GUI.GetAccentColor()
        if self.rsArrow then
            self.rsArrow:SetVertexColor(r, g, b, 1)
        end
    end)
end

local function ApplyScrollBarLayout(scrollFrame, scrollBar, listHeight)
    if not scrollFrame or not scrollBar or not listHeight then return end
    local trackHeight = listHeight - RS_SCROLL_BAR_OFFSET_Y
    if trackHeight < 40 then trackHeight = 40 end

    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", RS_SCROLL_BAR_OFFSET_X, RS_SCROLL_BAR_OFFSET_Y)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "TOPRIGHT", RS_SCROLL_BAR_OFFSET_X, -trackHeight)
    scrollBar.rsListHeight = listHeight
end

function GUI.ApplyScrollBarLayout(scrollFrame)
    if not scrollFrame or not scrollFrame.rsListHeight then return end
    local name = scrollFrame:GetName()
    if not name then return end
    local scrollBar = _G[name .. "ScrollBar"]
    if scrollBar then
        ApplyScrollBarLayout(scrollFrame, scrollBar, scrollFrame.rsListHeight)
    end
end

function GUI.SkinScrollBar(scrollFrame, opts)
    if not scrollFrame then return end
    opts = opts or {}
    local name = scrollFrame:GetName()
    if not name then return end

    local scrollBar = _G[name .. "ScrollBar"]
    if not scrollBar then return end

    local listHeight = opts.listHeight
    if listHeight then
        scrollFrame.rsListHeight = listHeight
        ApplyScrollBarLayout(scrollFrame, scrollBar, listHeight)
    end

    if scrollBar.rsHydraSkinned then
        GUI.RefreshScrollBarAccent(scrollBar)
        return
    end
    scrollBar.rsHydraSkinned = true

    scrollBar:SetWidth(RS_SCROLL_BAR_W)

    local upBtn = _G[name .. "ScrollBarScrollUpButton"]
    local downBtn = _G[name .. "ScrollBarScrollDownButton"]
    SkinScrollArrowButton(upBtn, true)
    SkinScrollArrowButton(downBtn, false)

    scrollBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    scrollBar:SetBackdropColor(0.13, 0.13, 0.13, 1)
    scrollBar:SetBackdropBorderColor(0, 0, 0, 1)

    local thumb = scrollBar:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetWidth(RS_SCROLL_BAR_W - 2)
        thumb:SetHeight(RS_SCROLL_THUMB_H)
        thumb:SetVertexColor(0.50, 0.50, 0.52, 0.95)
    end

    scrollBar.rsUpBtn = upBtn
    scrollBar.rsDownBtn = downBtn
    table.insert(GUI.scrollBars, scrollBar)
end

function GUI.RefreshScrollBarAccent(scrollBar)
    if not scrollBar then return end
    local ar, ag, ab = GUI.GetAccentColor()
    if scrollBar.rsUpBtn and scrollBar.rsUpBtn.rsArrow then
        scrollBar.rsUpBtn.rsArrow:SetVertexColor(ar, ag, ab, 1)
    end
    if scrollBar.rsDownBtn and scrollBar.rsDownBtn.rsArrow then
        scrollBar.rsDownBtn.rsArrow:SetVertexColor(ar, ag, ab, 1)
    end
end

GUI.checkBoxes = {}

function GUI.SkinCheckBox(checkBox)
    if not checkBox then return end

    -- Forzar tamaÃ±o compacto como los switches de Config
    checkBox:SetSize(14, 14)
    checkBox:SetScale(1)

    checkBox:SetNormalTexture("")
    checkBox:SetPushedTexture("")
    checkBox:SetHighlightTexture("")

    checkBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    checkBox:SetBackdropColor(0.12, 0.15, 0.18, 1)
    checkBox:SetBackdropBorderColor(0, 0, 0, 1)

    local checkedTex = checkBox:GetCheckedTexture()
    if checkedTex then
        checkedTex:SetTexture("Interface\\Buttons\\WHITE8X8")
        checkedTex:SetAllPoints(checkBox)
        local ar, ag, ab = GUI.GetAccentColor()
        checkedTex:SetVertexColor(ar, ag, ab, 0.8)
    end

    checkBox:HookScript("OnEnter", function(self)
        local ar, ag, ab = GUI.GetAccentColor()
        self:SetBackdropBorderColor(ar, ag, ab, 1)
    end)
    checkBox:HookScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0, 0, 0, 1)
    end)

    table.insert(GUI.checkBoxes, checkBox)
end

function GUI.SetStyleMode(mode)
    if not RaidStationDB then return end
    RaidStationDB.uiStyleMode = "flat"

    for _, sw in ipairs(GUI.switches or {}) do
        if sw and sw.RefreshAccent then
            sw:RefreshAccent()
        end
    end
    for _, sb in ipairs(GUI.scrollBars or {}) do
        GUI.RefreshScrollBarAccent(sb)
    end

    if ns.AdvertiserUI and ns.AdvertiserUI.ApplyStyle then
        ns.AdvertiserUI:ApplyStyle()
    end
end
