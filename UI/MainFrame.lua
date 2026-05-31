-- RaidStation :: UI/MainFrame.lua
-- Part of RaidStation by Marfyn- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
local GUI = {
    rows = {},
    selectedSender = nil,
    activeFilter = "ALL",
    searchPattern = "",
    COLORS = {
        accent = { 0.36, 0.61, 0.84 }, -- Frost Blue default
        panelBg = { 0.17, 0.17, 0.17 },
        listBg = { 0.13, 0.13, 0.13 },
        border = { 0.10, 0.10, 0.10 },
    },
    registeredAccentLabels = {},
}


local ROWS_LIMIT = 20
local ROW_HEIGHT = 18
local IsElvUI = _G.ElvUI ~= nil

local RAID_CLASS_COLORS = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS

local strlower = string.lower
local strfind = string.find
local tinsert = table.insert
local tsort = table.sort

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

    -- Text Insets adaptativos: inputs pequeÃ±os usan sangrÃ­a mÃ­nima
    local w = edit:GetWidth() or 100
    if w <= 50 then
        edit:SetTextInsets(4, 4, 0, 0)
    else
        edit:SetTextInsets(6, 6, 0, 0)
    end
end

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

GUI.scrollBars = {}

local RS_SCROLL_BAR_W = 15
local RS_SCROLL_BTN_H = 15
local RS_SCROLL_THUMB_H = 18
-- Posicion manual del scrollbar (lista BUSCAR)
local RS_SCROLL_BAR_OFFSET_X = 18 -- + = mas a la derecha
local RS_SCROLL_BAR_OFFSET_Y = 3  -- + = sube toda la barra
local RS_SCROLL_LIST_TRIM = 12    -- + = barra mas corta (px restados al alto de filas)
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

-- ==========================================
-- HELPERS DE INTERFAZ ESTILO HYDRAUI (FASE 1)
-- ==========================================
GUI.switches = {}

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

local function CreateMainFrame()
    local frame = CreateFrame("Frame", "RaidStationMainFrame", UIParent)
    GUI.MainFrame = frame

    -- Registrar en UISpecialFrames para que ESC cierre la ventana
    -- (igual que la mochila o WeakAuras â€” no interfiere con el menÃº del juego)
    tinsert(UISpecialFrames, "RaidStationMainFrame")

    frame:SetSize(400, 530)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    -- Capa visual estilo HydraUI: fondo + "gutter" (banda gris alrededor) + panel interior con su propio borde.
    -- El toggle "mostrar borde" en Config solo afecta el backdrop del frame raiz (legacy), no estas capas.
    local RS_FLAT = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    }
    -- Paleta inspirada en ElvUI: rellenos azul/gris oscuros; bordes casi negros (no celeste en el trazo).
    local GUTTER = 5                                                     -- ancho visible del "marco" entre borde exterior y el panel
    local WIN_R, WIN_G, WIN_B = 0.26, 0.26, 0.26                         -- #424242 gutter/chrome (HydraUI)
    local MAIN_R, MAIN_G, MAIN_B = 0.17, 0.17, 0.17                      -- #2B2B2B panel interior (HydraUI)
    local EDGE_OUT_R, EDGE_OUT_G, EDGE_OUT_B = 0.07, 0.07, 0.07          -- borde exterior
    local EDGE_IN_R, EDGE_IN_G, EDGE_IN_B = 0.10, 0.10, 0.10             -- bordes de panel y cuerpo
    local WELL_R, WELL_G, WELL_B = 0.13, 0.13, 0.13                      -- pozo de lista (body)
    local HEADER_FILL_R, HEADER_FILL_G, HEADER_FILL_B = 0.17, 0.17, 0.17 -- header fill

    local rsHydraChrome = CreateFrame("Frame", nil, frame)
    rsHydraChrome:SetAllPoints()
    rsHydraChrome:SetBackdrop(RS_FLAT)
    rsHydraChrome:SetBackdropColor(WIN_R, WIN_G, WIN_B, 1)
    rsHydraChrome:SetBackdropBorderColor(EDGE_OUT_R, EDGE_OUT_G, EDGE_OUT_B, 1)
    frame.rsHydraChrome = rsHydraChrome

    local rsHydraInset = CreateFrame("Frame", nil, frame)
    rsHydraInset:SetPoint("TOPLEFT", rsHydraChrome, "TOPLEFT", GUTTER, -GUTTER)
    rsHydraInset:SetPoint("BOTTOMRIGHT", rsHydraChrome, "BOTTOMRIGHT", -GUTTER, GUTTER)
    rsHydraInset:SetBackdrop(RS_FLAT)
    rsHydraInset:SetBackdropColor(MAIN_R, MAIN_G, MAIN_B, 1)
    rsHydraInset:SetBackdropBorderColor(EDGE_IN_R, EDGE_IN_G, EDGE_IN_B, 1)
    frame.rsHydraInset = rsHydraInset

    local rsHydraHeader = CreateFrame("Frame", nil, rsHydraInset)
    rsHydraHeader:SetHeight(24)
    rsHydraHeader:SetPoint("TOPLEFT", rsHydraInset, "TOPLEFT", 1, -1)
    rsHydraHeader:SetPoint("TOPRIGHT", rsHydraInset, "TOPRIGHT", -1, -1)
    rsHydraHeader:SetBackdrop(RS_FLAT)
    rsHydraHeader:SetBackdropColor(HEADER_FILL_R, HEADER_FILL_G, HEADER_FILL_B, 1)
    rsHydraHeader:SetBackdropBorderColor(EDGE_IN_R, EDGE_IN_G, EDGE_IN_B, 1)
    frame.rsHydraHeader = rsHydraHeader

    local rsHeaderTex = rsHydraHeader:CreateTexture(nil, "ARTWORK")
    rsHeaderTex:SetPoint("TOPLEFT", rsHydraHeader, 1, -1)
    rsHeaderTex:SetPoint("BOTTOMRIGHT", rsHydraHeader, -1, 1)
    rsHeaderTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    rsHeaderTex:SetVertexColor(0.1, 0.1, 0.1)
    frame.rsHydraHeaderTex = rsHeaderTex

    -- Footer bar (mirror of header, bottom of inset)
    local rsHydraFooter = CreateFrame("Frame", nil, rsHydraInset)
    rsHydraFooter:SetHeight(24)
    rsHydraFooter:SetPoint("BOTTOMLEFT", rsHydraInset, "BOTTOMLEFT", 1, 1)
    rsHydraFooter:SetPoint("BOTTOMRIGHT", rsHydraInset, "BOTTOMRIGHT", -1, 1)
    rsHydraFooter:SetBackdrop(RS_FLAT)
    rsHydraFooter:SetBackdropColor(HEADER_FILL_R, HEADER_FILL_G, HEADER_FILL_B, 1)
    rsHydraFooter:SetBackdropBorderColor(0, 0, 0, 0.8)
    frame.rsHydraFooter = rsHydraFooter

    local rsFooterTex = rsHydraFooter:CreateTexture(nil, "ARTWORK")
    rsFooterTex:SetPoint("TOPLEFT", rsHydraFooter, 1, -1)
    rsFooterTex:SetPoint("BOTTOMRIGHT", rsHydraFooter, -1, 1)
    rsFooterTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    rsFooterTex:SetVertexColor(0.20, 0.20, 0.20)

    local rsHydraBody = CreateFrame("Frame", nil, rsHydraInset)
    rsHydraBody:SetPoint("TOPLEFT", rsHydraHeader, "BOTTOMLEFT", 0, 0)
    rsHydraBody:SetPoint("BOTTOMRIGHT", rsHydraFooter, "TOPRIGHT", 0, 0)
    rsHydraBody:SetBackdrop(RS_FLAT)
    rsHydraBody:SetBackdropColor(WELL_R, WELL_G, WELL_B, 1)
    rsHydraBody:SetBackdropBorderColor(EDGE_IN_R, EDGE_IN_G, EDGE_IN_B, 1)
    frame.rsHydraBody = rsHydraBody


    function GUI.SaveWindowPosition()
        if not GUI.MainFrame then return end

        local point, _, relativePoint, xOfs, yOfs = GUI.MainFrame:GetPoint()
        if not point then return end

        RaidStationDB.windowPoint = point
        RaidStationDB.windowRelativePoint = relativePoint or point
        RaidStationDB.windowX = xOfs or 0
        RaidStationDB.windowY = yOfs or 0
    end

    function GUI.RestoreWindowPosition()
        local point = RaidStationDB.windowPoint or "CENTER"
        local relativePoint = RaidStationDB.windowRelativePoint or point
        local xOfs = tonumber(RaidStationDB.windowX) or 0
        local yOfs = tonumber(RaidStationDB.windowY) or 0

        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
    end

    function GUI.ApplyWindowLock(locked)
        locked = locked and true or false
        RaidStationDB.windowLocked = locked
        frame:SetMovable(not locked)
    end

    frame:SetScript("OnDragStart", function(self)
        if RaidStationDB.windowLocked then return end
        if ns.BuffTab and ns.BuffTab.scroll then
            ns.BuffTab.scroll:Hide()
        end
        self:StartMoving()
        self.isMoving = true
    end)
    frame:SetScript("OnDragStop", function(self)
        if not self.isMoving then return end
        self:StopMovingOrSizing()
        self.isMoving = nil
        if ns.BuffTab and ns.BuffTab.scroll then
            ns.BuffTab.scroll:Show()
        end
        GUI.SaveWindowPosition()
    end)

    -- RaÃ­z transparente: el relleno y el marco viven en rsHydraChrome / rsHydraInset (menos choque con ElvUI que retoca el padre).
    frame:SetBackdrop(RS_FLAT)
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)

    local clearBtn -- pre-declare for GUI.ApplyBackground

    -- Textura de fondo custom (layer BORDER, encima del backdrop)
    local bgTexture = frame:CreateTexture(nil, "BORDER")
    bgTexture:SetPoint("TOPLEFT", frame.rsHydraBody, "TOPLEFT", 1, -1)
    bgTexture:SetPoint("BOTTOMRIGHT", frame.rsHydraBody, "BOTTOMRIGHT", -1, 1)
    bgTexture:SetTexture(nil)
    bgTexture:Hide()
    bgTexture:SetAlpha(RaidStationDB.bgAlpha or 0.85)
    frame.bgTexture = bgTexture

    local BG_TEXTURES = {
        -- [1] = "Interface\\AddOns\\RaidStation\\Textures\\fondo1.blp",
        -- [2] = "Interface\\AddOns\\RaidStation\\Textures\\fondo2.blp",
    }

    function GUI.ApplyBackground(choiceIndex)
        choiceIndex = choiceIndex or 0
        RaidStationDB.bgChoice = choiceIndex

        -- Recrear bgTexture si fue destruida por SetBackdrop previo
        if not frame.bgTexture or not frame.bgTexture:IsObjectType("Texture") then
            local tex = frame:CreateTexture(nil, "BORDER")
            if frame.rsHydraBody then
                tex:SetPoint("TOPLEFT", frame.rsHydraBody, "TOPLEFT", 1, -1)
                tex:SetPoint("BOTTOMRIGHT", frame.rsHydraBody, "BOTTOMRIGHT", -1, 1)
            elseif frame.rsHydraInset and frame.rsHydraHeader then
                tex:SetPoint("TOPLEFT", frame.rsHydraHeader, "BOTTOMLEFT", 0, 0)
                tex:SetPoint("BOTTOMRIGHT", frame.rsHydraInset, "BOTTOMRIGHT", -1, 1)
            else
                tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
                tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
            end
            frame.bgTexture = tex
        end

        local tex = frame.bgTexture

        if choiceIndex == 0 then
            tex:SetTexture(nil)
            tex:Hide()
            return
        end

        local path = BG_TEXTURES[choiceIndex]
        if not path then
            tex:SetTexture(nil)
            tex:Hide()
            return
        end

        tex:SetTexture(path)
        local alpha = tonumber(RaidStationDB.bgAlpha) or 1.0
        if alpha <= 0 or alpha > 1 then alpha = 1.0 end
        tex:SetAlpha(alpha)
        tex:Show()
    end

    function GUI.ApplyBodyColor(r, g, b, a)
        local bc = RaidStationDB.bodyColor or { 0.13, 0.13, 0.13 }
        r = r or bc[1] or 0.13
        g = g or bc[2] or 0.13
        b = b or bc[3] or 0.13
        a = a or RaidStationDB.bodyAlpha or 1.0
        RaidStationDB.bodyColor = { r, g, b }
        RaidStationDB.bodyAlpha = a
        if frame.rsHydraBody then
            frame.rsHydraBody:SetBackdropColor(r, g, b, a)
            frame.rsHydraBody:SetBackdropBorderColor(EDGE_IN_R, EDGE_IN_G, EDGE_IN_B, a)
        end
        -- Propagate alpha to chrome and inset for true transparency
        if frame.rsHydraInset then
            frame.rsHydraInset:SetBackdropColor(MAIN_R, MAIN_G, MAIN_B, a)
            frame.rsHydraInset:SetBackdropBorderColor(EDGE_IN_R, EDGE_IN_G, EDGE_IN_B, a)
        end
        if frame.rsHydraChrome then
            frame.rsHydraChrome:SetBackdropColor(WIN_R, WIN_G, WIN_B, a)
            frame.rsHydraChrome:SetBackdropBorderColor(EDGE_OUT_R, EDGE_OUT_G, EDGE_OUT_B, a)
        end
    end

    -- Color de acento (fuente/interfaz)
    function GUI.GetAccentColor()
        local ac = RaidStationDB.accentColor or { 0.36, 0.61, 0.84 }
        return ac[1] or 0.36, ac[2] or 0.61, ac[3] or 0.84
    end

    function GUI.GetAccentHex()
        local r, g, b = GUI.GetAccentColor()
        return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
            math.floor(b * 255 + 0.5))
    end

    function GUI.ColorText(text)
        return "|cff" .. GUI.GetAccentHex() .. text .. "|r"
    end

    function GUI.RegisterAccentLabel(fs, textOrFunc)
        if not fs then return end
        GUI.registeredAccentLabels[fs] = textOrFunc or true
        GUI.UpdateAccentLabel(fs)
    end

    function GUI.UpdateAccentLabel(fs)
        local val = GUI.registeredAccentLabels[fs]
        if not val then return end
        local r, g, b = GUI.GetAccentColor()
        if val == true then
            fs:SetTextColor(r, g, b)
        elseif type(val) == "function" then
            fs:SetText(val())
        elseif type(val) == "string" then
            fs:SetText(GUI.ColorText(val))
        end
    end

    function GUI.ApplyAccentColor(r, g, b)
        r = r or 0.36; g = g or 0.61; b = b or 0.84
        RaidStationDB.accentColor = { r, g, b }

        -- Title
        if GUI.title then GUI.title:SetTextColor(r, g, b) end
        -- Signature
        if GUI.signature then GUI.signature:SetTextColor(r, g, b) end
        -- Sort header labels
        if GUI.sortHeaderLabels then
            for _, lbl in ipairs(GUI.sortHeaderLabels) do
                lbl:SetTextColor(r, g, b, 1)
            end
        end
        -- Sort header line
        if GUI.sortHeaderLine then GUI.sortHeaderLine:SetTexture(r, g, b, 0.3) end
        -- Active tab + filter buttons (selected state uses accent backdrop)
        if GUI.RefreshTabHighlight then
            GUI.RefreshTabHighlight()
        end
        if GUI.UpdateFilterHighlight then
            GUI.UpdateFilterHighlight()
        end

        -- Update all registered labels
        if GUI.registeredAccentLabels then
            for fs in pairs(GUI.registeredAccentLabels) do
                GUI.UpdateAccentLabel(fs)
            end
        end

        -- Column separators and hover backgrounds in rows
        if GUI.rows then
            for _, row in ipairs(GUI.rows) do
                if row.colSep then row.colSep:SetTexture(r, g, b, 0.4) end
                if row.hoverBg then row.hoverBg:SetTexture(r, g, b, 0.15) end
            end
        end

        -- Actualizar switches (estado ON/OFF + color de acento actual)
        if GUI.switches then
            for _, sw in ipairs(GUI.switches) do
                if sw.RefreshAccent then
                    sw:RefreshAccent()
                end
            end
        end

        -- Flechas de scrollbars (thumb gris estilo Hydra; acento solo en flechas)
        if GUI.scrollBars then
            for _, bar in ipairs(GUI.scrollBars) do
                GUI.RefreshScrollBarAccent(bar)
            end
        end

        -- Actualizar todos los checkbox verificado color dinámicamente
        if GUI.checkBoxes then
            for _, cb in ipairs(GUI.checkBoxes) do
                local checkedTex = cb:GetCheckedTexture()
                if checkedTex then
                    checkedTex:SetVertexColor(r, g, b, 0.8)
                end
            end
        end

        -- Dynamic real-time refreshes in sub-panels if loaded
        if ns.Settings and ns.Settings.RefreshColors then
            ns.Settings.RefreshColors()
        end
        if ns.BuffTab and ns.BuffTab.RefreshColors then
            ns.BuffTab.RefreshColors()
        end
        if ns.AdvertiserUI and ns.AdvertiserUI.RefreshColors then
            ns.AdvertiserUI.RefreshColors()
        end
    end

    local function RecursivelyApplyFont(f, path, outline)
        if not f then return end
        if f.GetRegions then
            local regions = { f:GetRegions() }
            for _, r in ipairs(regions) do
                if r:IsObjectType("FontString") then
                    local _, size = r:GetFont()
                    if size and size > 0 then
                        r:SetFont(path, size, outline)
                    end
                end
            end
        end
        if f.GetChildren then
            local children = { f:GetChildren() }
            for _, c in ipairs(children) do
                RecursivelyApplyFont(c, path, outline)
            end
        end
    end

    function GUI.ApplyGlobalFont()
        local face = RaidStationDB.fontFace or "SFUIDisplayCondensed-Semibold"
        local outline = "" -- Removido por el usuario
        local path = "Fonts\\SFUIDisplayCondensed-Semibold.ttf"

        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        if LSM then
            local lsmPath = LSM:Fetch("font", face)
            if lsmPath then path = lsmPath end
        else
            if face == "Arial Narrow" then
                path = "Fonts\\ARIALN.TTF"
            elseif face == "Skurri" then
                path = "Fonts\\skurri.ttf"
            elseif face == "Morpheus" then
                path = "Fonts\\MORPHEUS.ttf"
            end
        end

        RecursivelyApplyFont(GUI.MainFrame, path, outline)
        -- Si hubiera otros marcos principales que no son hijos de MainFrame, aplicar aqui
        if GUI.MinimapButton then RecursivelyApplyFont(GUI.MinimapButton, path, outline) end
        if GUI.FloatingButton then RecursivelyApplyFont(GUI.FloatingButton, path, outline) end
    end

    local RS_BACKDROP_BORDER = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    }
    local RS_BACKDROP_NOBORDER = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", -- textura salida = borde invisible
        tile = true,
        tileSize = 32,
        edgeSize = 1, -- edgeSize=1 miÃ‚Â­nimo
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    }

    local function SyncHydraChromeLayout()
        if GUI.title then
            if frame.rsHydraHeader then
                GUI.title:ClearAllPoints()
                GUI.title:SetPoint("CENTER", frame.rsHydraHeader, "CENTER", 0, 0)
                GUI.title:SetTextColor(0.56, 0.79, 0.90) -- dorado legible sobre cabecera oscura
            else
                GUI.title:ClearAllPoints()
                GUI.title:SetPoint("TOP", frame, "TOP", 0, -17)
                GUI.title:SetTextColor(0.56, 0.79, 0.90)
            end
        end

        if GUI.mainCloseBtn then
            GUI.mainCloseBtn:ClearAllPoints()
            if frame.rsHydraHeader then
                GUI.mainCloseBtn:SetPoint("TOPRIGHT", frame.rsHydraHeader, "TOPRIGHT", -3, -3)
            else
                GUI.mainCloseBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -11, -11)
            end
        end
    end

    function GUI.ApplyBorder(show)
        if show == nil then show = (RaidStationDB.showBorder ~= false) end
        RaidStationDB.showBorder = show

        -- Marco anidado (Hydra-style): siempre visible; independiente del checkbox de Config.
        if frame.rsHydraChrome then
            frame.rsHydraChrome:ClearAllPoints()
            if show then
                -- Deja un hueco para que se vea el borde tooltip clasico del padre (opcion legacy).
                frame.rsHydraChrome:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
                frame.rsHydraChrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
            else
                frame.rsHydraChrome:SetAllPoints()
            end
            frame.rsHydraChrome:Show()
            frame.rsHydraInset:Show()
            if frame.rsHydraHeader then frame.rsHydraHeader:Show() end
            if frame.rsHydraFooter then frame.rsHydraFooter:Show() end
            if frame.rsHydraBody then frame.rsHydraBody:Show() end
        end

        if show then
            frame:SetBackdrop(RS_BACKDROP_BORDER)
            local a = RaidStationDB.bodyAlpha or 1.0
            frame:SetBackdropColor(0.04, 0.04, 0.06, 0.85 * a)
            frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        else
            frame:SetBackdrop(RS_BACKDROP_NOBORDER)
            frame:SetBackdropColor(0, 0, 0, 0)
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        end

        GUI.ApplyBackground(RaidStationDB.bgChoice or 0)
        local tex = frame.bgTexture
        if tex and tex:IsObjectType("Texture") then
            tex:ClearAllPoints()
            if frame.rsHydraBody then
                tex:SetPoint("TOPLEFT", frame.rsHydraBody, "TOPLEFT", 1, -1)
                tex:SetPoint("BOTTOMRIGHT", frame.rsHydraBody, "BOTTOMRIGHT", -1, 1)
            elseif frame.rsHydraInset and frame.rsHydraHeader then
                tex:SetPoint("TOPLEFT", frame.rsHydraHeader, "BOTTOMLEFT", 0, 0)
                tex:SetPoint("BOTTOMRIGHT", frame.rsHydraInset, "BOTTOMRIGHT", -1, 1)
            else
                tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
                tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
            end
        end
        SyncHydraChromeLayout()
        GUI.FixMainFrameShellLayering()
    end

    -- Posicion / lock (el borde visual se aplica tras crear titulo y botones)
    GUI.RestoreWindowPosition()
    GUI.ApplyWindowLock(RaidStationDB.windowLocked)

    -- Declare local freezeBtn variable to be used/initialized later when sortHeader is created
    local freezeBtn

    local title = frame.rsHydraHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    title:SetPoint("CENTER", frame.rsHydraHeader, "CENTER", 0, 0)
    title:SetText("RAID STATION")
    title:SetTextColor(ns.GUI.GetAccentColor())
    GUI.title = title


    -- Clear Button (Header)
    clearBtn = CreateFrame("Button", nil, frame)
    clearBtn:SetSize(56, 22)
    clearBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -37, -87)

    clearBtn:SetBackdrop(RS_FLAT)
    clearBtn:SetBackdropColor(0.17, 0.17, 0.17, 1)
    clearBtn:SetBackdropBorderColor(0, 0, 0, 0.8)

    local clearBtnTex = clearBtn:CreateTexture(nil, "ARTWORK")
    clearBtnTex:SetPoint("TOPLEFT", clearBtn, 1, -1)
    clearBtnTex:SetPoint("BOTTOMRIGHT", clearBtn, -1, 1)
    clearBtnTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    clearBtnTex:SetVertexColor(0.20, 0.20, 0.20)

    clearBtn:SetNormalFontObject("GameFontNormalSmall")
    clearBtn:SetHighlightFontObject("GameFontHighlightSmall")
    clearBtn:SetText("Limpiar")

    local hl = clearBtn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", clearBtn, 1, -1)
    hl:SetPoint("BOTTOMRIGHT", clearBtn, -1, 1)
    hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    hl:SetVertexColor(1, 1, 1, 0.1)
    clearBtn:SetHighlightTexture(hl)

    clearBtn:SetScript("OnClick", function()
        if ns.Advertiser and ns.AdvertiserUI then
            ns.Advertiser:ResetPatterns()
            ns.AdvertiserUI:RefreshAllInputs()
            ns.Advertiser.patterns.fullMessage = ""
            ns.Advertiser.patterns.message = ""
        end
    end)
    clearBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Limpiar formulario", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Resetea todos los campos del anunciador de banda.", 1, 1, 1, true)
        GameTooltip:AddLine("No detiene el spam si esta activo.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    clearBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Close Button (Header)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(14, 14)
    closeBtn:SetText("")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    GUI.SkinButton(closeBtn, true)
    GUI.ApplyCustomTexture(closeBtn, "Interface\\AddOns\\RaidStation\\Textures\\exis2.blp")

    GUI.freezeBtn = freezeBtn
    GUI.mainCloseBtn = closeBtn
    GUI.ApplyBorder(RaidStationDB.showBorder)

    local signature = frame.rsHydraBody:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    signature:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 35)
    signature:SetText("|cffb8860b by Marfyn-|r")
    signature:SetTextColor(ns.GUI.GetAccentColor()) -- color de acento
    signature:SetAlpha(1.0)
    local fontPath, fontSize = signature:GetFont()
    if fontPath then
        signature:SetFont(fontPath, fontSize, "OUTLINE")
    end

    -- Search EditBox
    local search = CreateFrame("EditBox", "RaidStationSearch", frame, "InputBoxTemplate")
    search:SetSize(318, 22) -- Ajustado al tamaño de los filtros y filas para coherencia total
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", 34, -38)
    search:SetAutoFocus(false)


    GUI.SkinEditBox(search)

    local searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", 5, 0)
    searchHint:SetText("Buscar (ej: 'icc 25h')...")
    search:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
    search:SetScript("OnEditFocusLost", function(self) if self:GetText() == "" then searchHint:Show() end end)
    search:SetScript("OnTextChanged", function(self)
        GUI.searchPattern = self:GetText()
        GUI.UpdateList()
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    -- Botón X para limpiar el campo de búsqueda (Hijo de search para quedar al frente)
    local searchClearBtn = CreateFrame("Button", nil, search)
    searchClearBtn:SetSize(18, 18)
    searchClearBtn:SetPoint("RIGHT", search, "RIGHT", -2, 0)
    searchClearBtn:SetFrameLevel(search:GetFrameLevel() + 5)
    searchClearBtn:SetAlpha(0) -- empieza invisible (sin texto)

    local clearBtnTex = searchClearBtn:CreateTexture(nil, "OVERLAY")
    clearBtnTex:SetAllPoints()
    clearBtnTex:SetTexture("Interface\\Buttons\\UI-StopButton")
    clearBtnTex:SetVertexColor(0.8, 0.2, 0.2)
    searchClearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")

    searchClearBtn:SetScript("OnClick", function()
        search:SetText("")
        search:ClearFocus()
        searchHint:Show()
    end)
    searchClearBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("|cffff4444Limpiar busqueda|r", 1, 1, 1)
        GameTooltip:Show()
    end)
    searchClearBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Mostrar/ocultar el boton X segun haya texto o no
    hooksecurefunc(search, "SetText", function(self, text)
        if text and text ~= "" then
            searchClearBtn:SetAlpha(1)
        else
            searchClearBtn:SetAlpha(0)
        end
    end)


    -- Filter Bar (misma apariencia que el footer)
    local filterBar = CreateFrame("Frame", nil, frame)
    filterBar:SetSize(318, 22)
    filterBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 34, -63)
    filterBar:SetBackdrop(RS_FLAT)
    filterBar:SetBackdropColor(0.17, 0.17, 0.17, 1)
    filterBar:SetBackdropBorderColor(0, 0, 0, 0.8)

    local filterBarTex = filterBar:CreateTexture(nil, "ARTWORK")
    filterBarTex:SetPoint("TOPLEFT", filterBar, 1, -1)
    filterBarTex:SetPoint("BOTTOMRIGHT", filterBar, -1, 1)
    filterBarTex:SetTexture("Interface\\Buttons\\WHITE8X8")
    filterBarTex:SetVertexColor(0.20, 0.20, 0.20)

    local filters = { "ALL", "ICC", "SR", "TOC", "ARCHA" }
    local filterTooltips = {
        ALL   = "Mostrar todas las raids disponibles.",
        ICC   = "Filtrar: Icecrown Citadel (ICC).",
        SR    = "Filtrar: Sartharion / Ruby Sanctum (SR).",
        TOC   = "Filtrar: Trial of the Crusader (TOC).",
        ARCHA = "Filtrar: Archavon / Vault of Archavon (ARCHA).",
    }
    GUI.filterButtons = {}
    local numFilters = #filters
    local btnW = 316 / numFilters -- 318 - 2px (bordes laterales)

    for i, name in ipairs(filters) do
        local btn = CreateFrame("Button", nil, filterBar)
        btn:SetSize(btnW, 20) -- Altura 20 para encajar dentro del borde
        if i == 1 then
            btn:SetPoint("LEFT", filterBar, "LEFT", 1, 0)
        else
            btn:SetPoint("LEFT", GUI.filterButtons[i - 1], "RIGHT", 0, 0)
        end

        btn:SetNormalFontObject("GameFontNormalSmall")
        btn:SetHighlightTexture("")
        btn:SetPushedTexture("")

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetAllPoints()
        label:SetText(name)
        btn.label = label
        btn.filterName = name

        btn:SetScript("OnClick", function()
            GUI.activeFilter = name
            GUI.UpdateFilterHighlight()
            GUI.UpdateList()
        end)

        btn:SetScript("OnEnter", function(self)
            local r, g, b = ns.GUI.GetAccentColor()
            self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            self:SetBackdropColor(r, g, b, 0.20)
            self.label:SetTextColor(r, g, b)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(name, r, g, b)
            local tip = filterTooltips[name]
            if tip then GameTooltip:AddLine(tip, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            GUI.UpdateFilterHighlight()
            GameTooltip:Hide()
        end)

        -- Separador vertical entre botones
        if i < numFilters then
            local sep = btn:CreateTexture(nil, "OVERLAY")
            sep:SetSize(1, 14)
            sep:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
            sep:SetTexture("Interface\\Buttons\\WHITE8X8")
            sep:SetVertexColor(0.12, 0.12, 0.12, 1) -- Sutil
        end

        GUI.filterButtons[i] = btn
    end

    -- Highlight de acento
    function GUI.UpdateFilterHighlight()
        local r, g, b = ns.GUI.GetAccentColor()
        for _, b in ipairs(GUI.filterButtons) do
            if b.filterName == GUI.activeFilter then
                b.label:SetTextColor(r, g, b)
                b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
                b:SetBackdropColor(r, g, b, 0.15)
            else
                b.label:SetTextColor(0.7, 0.7, 0.7)
                b:SetBackdrop(nil)
            end
        end
    end

    GUI.UpdateFilterHighlight()

    -- Scroll Frame
    local scrollFrame = CreateFrame("ScrollFrame", "RaidStationScroll", frame, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 35, -105)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -52, 42)

    local scrollListHeight = (ROWS_LIMIT * ROW_HEIGHT) - RS_SCROLL_LIST_TRIM
    GUI.SkinScrollBar(scrollFrame, { listHeight = scrollListHeight })
    scrollFrame:HookScript("OnShow", function(self)
        GUI.ApplyScrollBarLayout(self)
    end)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, GUI.UpdateList)
        ns.Controller.SetInteracting(true)
        GUI.ApplyScrollBarLayout(self)
    end)

    -- Sort header row (encima del scrollFrame)
    local sortHeader = CreateFrame("Frame", nil, frame)
    sortHeader:SetSize(318, 16)
    sortHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 35, -87)

    local sortHeaderBg = sortHeader:CreateTexture(nil, "BACKGROUND")
    sortHeaderBg:SetAllPoints()
    sortHeaderBg:SetTexture(0, 0, 0, 0.7)

    local sortHeaderLine = sortHeader:CreateTexture(nil, "OVERLAY")
    sortHeaderLine:SetHeight(1)
    sortHeaderLine:SetPoint("BOTTOMLEFT", 0, 0)
    sortHeaderLine:SetPoint("BOTTOMRIGHT", 0, 0)
    local _ar, _ag, _ab = GUI.GetAccentColor()
    sortHeaderLine:SetTexture(_ar, _ag, _ab, 0.3)
    GUI.sortHeaderLine = sortHeaderLine

    -- Columna labels — registered for dynamic accent color
    local rowLayout = ns.Rows and ns.Rows.LAYOUT
    local lblNombre = sortHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblNombre:SetPoint("LEFT", sortHeader, "LEFT", rowLayout and rowLayout.NAME_LEFT or 6, 0)
    lblNombre:SetText("Nombre")
    GUI.RegisterAccentLabel(lblNombre, true)

    local lblBanda = sortHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblBanda:SetPoint("LEFT", sortHeader, "LEFT", 165, 0)
    lblBanda:SetText("Banda")
    GUI.RegisterAccentLabel(lblBanda, true)

    local lblRol = sortHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblRol:SetPoint("LEFT", sortHeader, "LEFT", 245, 0)
    lblRol:SetText("Rol+")
    GUI.RegisterAccentLabel(lblRol, true)

    freezeBtn = ns.GUI.CreateSwitch(sortHeader, "", ns.Controller.isFrozen, function(value)
        ns.Controller.isFrozen = value
    end, 36, 14)
    freezeBtn:SetPoint("LEFT", sortHeader, "LEFT", 95, 0)
    freezeBtn.switch:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText("Congelar lista", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Pausa la actualizacion automatica de la lista.", 1, 1, 1, true)
        GameTooltip:AddLine("Util cuando quieres leer un anuncio sin que desaparezca.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    freezeBtn.switch:HookScript("OnLeave", function() GameTooltip:Hide() end)

    GUI.freezeBtn = freezeBtn
    GUI.sortHeaderLabels = { lblNombre, lblBanda, lblRol }
    GUI.sortHeader = sortHeader

    -- Row Creation
    for i = 1, ROWS_LIMIT do
        local row = ns.Rows.CreateRow(frame, i)
        if i == 1 then
            row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", GUI.rows[i - 1], "BOTTOMLEFT", 0, 0)
        end
        GUI.rows[i] = row
    end

    frame:SetScript("OnHide", function()
        GameTooltip:Hide()
        if ns.Rows then
            ns.Rows.currentHoverSender = nil
        end
        if frame.isMoving then
            frame:StopMovingOrSizing()
            frame.isMoving = nil
            GUI.SaveWindowPosition()
        end
        ns.Controller.SetInteracting(false)
        if ns.BuffTab and ns.BuffTab.popout and ns.BuffTab.popout:IsShown() then
            ns.BuffTab.popout:Hide()
        end
    end)
    frame:SetScript("OnShow", function()
        ns.Stats.RequestRaidLockouts()
        GUI.UpdateList()
    end)

    frame.scrollFrame = scrollFrame

    -- View Selection Logic
    GUI.selectedTab = 1

    -- Tab Bar (BOTTOM) — Ajustada exactamente al estilo de la barra de filtros
    local tabDefs = {
        { label = "BUSCAR",   id = 1 },
        { label = "ANUNCIAR", id = 2 },
        { label = "BUFFS",    id = 3 },
        { label = "CONFIG",   id = 4 },
    }
    local tabTooltips = {
        [1] = "Buscar raids.",
        [2] = "Anunciador de banda.",
        [3] = "Buffs Monitor.",
        [4] = "Ajustes.",
    }

    local numTabs = #tabDefs
    local tabW = 388 / numTabs -- 390 - 2px (bordes laterales)
    local tabs = {}

    -- Dejamos que rsHydraFooter mantenga su fondo y borde original para coherencia total

    for i, def in ipairs(tabDefs) do
        local tab = CreateFrame("Button", nil, frame.rsHydraFooter)
        tab:SetSize(tabW, 22) -- Altura 22 para encajar perfectamente dentro del footer (altura 24)
        if i == 1 then
            tab:SetPoint("LEFT", frame.rsHydraFooter, "LEFT", 1, 0)
        else
            tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 0, 0)
        end

        tab:SetNormalFontObject("GameFontNormalSmall")
        tab:SetHighlightTexture("")
        tab:SetPushedTexture("")

        local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetAllPoints()
        label:SetText(def.label)
        tab.label = label

        tab:SetScript("OnEnter", function(self)
            local r, g, b = ns.GUI.GetAccentColor()
            self:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            self:SetBackdropColor(r, g, b, 0.20)
            self.label:SetTextColor(r, g, b)

            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(def.label, r, g, b)
            local tip = tabTooltips[def.id]
            if tip then GameTooltip:AddLine(tip, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function(self)
            GUI.RefreshTabHighlight()
            GameTooltip:Hide()
        end)

        tab:SetScript("OnClick", function()
            GUI.SelectTab(def.id)
        end)

        -- Separador vertical sutil entre pestañas (idéntico a filtros)
        if i < numTabs then
            local sep = tab:CreateTexture(nil, "OVERLAY")
            sep:SetSize(1, 14)
            sep:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
            sep:SetTexture("Interface\\Buttons\\WHITE8X8")
            sep:SetVertexColor(0.12, 0.12, 0.12, 1) -- Sutil
        end

        tabs[def.id] = tab
    end

    GUI.tabs = tabs

    function GUI.RefreshTabHighlight()
        if not GUI.tabs or not GUI.selectedTab then return end
        local r, g, b = ns.GUI.GetAccentColor()
        for k, t in pairs(GUI.tabs) do
            if k == GUI.selectedTab then
                t.label:SetTextColor(r, g, b)
                t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
                t:SetBackdropColor(r, g, b, 0.15)
            else
                t.label:SetTextColor(0.7, 0.7, 0.7)
                t:SetBackdrop(nil)
            end
        end
    end

    -- Función de selección actualizada para usar mismo estilo que filtros
    function GUI.SelectTab(id)
        GUI.selectedTab = id
        if GUI.title then GUI.title:SetText(id == 3 and "BUFF MONITOR" or "RAID STATION") end

        GUI.RefreshTabHighlight()
        -- ... resto lógica ...
        if freezeBtn then if id == 1 then freezeBtn:Show() else freezeBtn:Hide() end end
        if clearBtn then if id == 2 then clearBtn:Show() else clearBtn:Hide() end end
        if signature then if id == 4 then signature:Show() else signature:Hide() end end
        if ns.BuffTab then if id == 3 then ns.BuffTab.Show() else ns.BuffTab.Hide() end end

        if id == 1 then
            search:Show()
            if search:GetText() == "" then searchHint:Show() else searchHint:Hide() end
            filterBar:Show()
            if GUI.sortHeader then GUI.sortHeader:Show() end
        else
            search:Hide()
            searchHint:Hide()
            filterBar:Hide()
            if GUI.sortHeader then GUI.sortHeader:Hide() end
        end
        if ns.Settings and ns.Settings.Panel then if id == 4 then ns.Settings.Panel:Show() else ns.Settings.Panel:Hide() end end
        if ns.AdvertiserUI and ns.AdvertiserUI.Panel then
            if id == 2 then
                ns.AdvertiserUI.Panel:Show()
            else
                ns
                    .AdvertiserUI.Panel:Hide()
            end
        end
        GUI.RefreshView()
        if id == 3 and ns.BuffTab and ns.BuffTab.Refresh then ns.BuffTab.Refresh() end
    end

    GUI.SelectTab(1)

    GUI.FixMainFrameShellLayering()

    -- Aplicar color guardado del body
    local bc = RaidStationDB.bodyColor
    if bc then
        GUI.ApplyBodyColor(bc[1], bc[2], bc[3])
    end

    local ac = RaidStationDB.accentColor
    if ac then
        GUI.ApplyAccentColor(ac[1], ac[2], ac[3])
    else
        GUI.ApplyAccentColor()
    end

    GUI.ApplyGlobalFont()

    return frame
end

-- Orden de dibujo: el shell (chrome/inset/body/header) debe quedar por debajo del contenido (lista, pestaÃ±as, etc.).
function GUI.FixMainFrameShellLayering()
    local f = GUI.MainFrame
    if not f or not f.rsHydraChrome then return end

    local base = 1
    f.rsHydraChrome:SetFrameLevel(base)
    if f.rsHydraInset then f.rsHydraInset:SetFrameLevel(base + 1) end
    if f.rsHydraBody then f.rsHydraBody:SetFrameLevel(base + 2) end
    if f.rsHydraHeader then f.rsHydraHeader:SetFrameLevel(base + 3) end
    if f.rsHydraFooter then f.rsHydraFooter:SetFrameLevel(base + 3) end

    f.rsHydraChrome:EnableMouse(false)
    if f.rsHydraInset then f.rsHydraInset:EnableMouse(false) end
    if f.rsHydraBody then f.rsHydraBody:EnableMouse(false) end
    if f.rsHydraHeader then f.rsHydraHeader:EnableMouse(false) end
    if f.rsHydraFooter then f.rsHydraFooter:EnableMouse(false) end

    local contentLevel = 25
    for _, child in ipairs({ f:GetChildren() }) do
        if child and child ~= f.rsHydraChrome and child ~= f.rsHydraInset then
            child:SetFrameLevel(contentLevel)
        end
    end
end

function GUI.TokenizedSearch(data, pattern)
    if not pattern or pattern == "" then return true end
    local cleanPattern = ns.Parser.Normalize(pattern)
    local searchTokens = ns.Parser.Tokenize(cleanPattern)

    -- We'll check against tokens and metadata for better accuracy
    local messageTokens = data.parsed.tokens
    local senderLower = strlower(data.sender)

    for _, sToken in ipairs(searchTokens) do
        local found = false

        -- Check if it matches raid metadata specifically (10, 25, h, n, etc.)
        local sLower = strlower(sToken)
        local isMetaToken = false

        if sLower == "10" or sLower == "25" then
            isMetaToken = true
            if tostring(data.match.size) == sLower then found = true end
        elseif sLower == "h" or sLower == "hc" or sLower == "heroic" then
            isMetaToken = true
            if data.match.mode == 2 then found = true end
        elseif sLower == "n" or sLower == "nm" or sLower == "normal" then
            isMetaToken = true
            if data.match.mode == 1 then found = true end
        elseif sLower == "10h" or sLower == "10hc" then
            isMetaToken = true
            if data.match.size == 10 and data.match.mode == 2 then found = true end
        elseif sLower == "25h" or sLower == "25hc" then
            isMetaToken = true
            if data.match.size == 25 and data.match.mode == 2 then found = true end
        elseif sLower == "10n" or sLower == "10nm" then
            isMetaToken = true
            if data.match.size == 10 and data.match.mode == 1 then found = true end
        elseif sLower == "25n" or sLower == "25nm" then
            isMetaToken = true
            if data.match.size == 25 and data.match.mode == 1 then found = true end
        end

        -- Fallback to literal search in message tokens or sender name
        -- ONLY if it's not a strict meta-token that already failed to match metadata
        if not found and not isMetaToken then
            if strfind(senderLower, sToken, 1, true) then
                found = true
            else
                for _, mToken in ipairs(messageTokens) do
                    if strfind(mToken, sToken, 1, true) then
                        found = true
                        break
                    end
                end
            end
        end

        if not found then return false end
    end
    return true
end

-- Pintar el contador con nivel de confianza
local function SetRowCount(row, match)
    if not match then
        row.count:SetText(""); return
    end

    local have       = match.countHave
    local total      = match.countTotal
    local confidence = match.countConfidence

    if not have then
        row.count:SetText("")
        return
    end

    local text
    local r, g, b

    if confidence == "high" then
        -- Dato exacto: color segun llenado
        local pct = have / (total or have)
        if pct >= 0.85 then
            r, g, b = 0.2, 1.0, 0.2  -- casi lleno: verde
        elseif pct >= 0.5 then
            r, g, b = 1.0, 0.75, 0.1 -- a mitad: amarillo
        else
            r, g, b = 0.6, 0.6, 0.6  -- pocas personas: gris
        end
        text = have .. "/" .. (total or "?")
    elseif confidence == "medium" then
        -- Estimado: siempre amarillo apagado con tilde ~
        r, g, b = 0.9, 0.7, 0.1
        text = "~" .. have .. "/" .. (total or "?")
    end

    row.count:SetText(text or "")
    row.count:SetTextColor(r or 1, g or 1, b or 1)
end

function GUI.UpdateList()
    if not GUI.MainFrame or not GUI.MainFrame:IsShown() then return end
    if GUI.selectedTab ~= 1 then return end

    local search = GUI.searchPattern
    local cat = GUI.activeFilter

    local source = (cat == "ALL") and ns.Controller.messages or {}
    if cat ~= "ALL" then
        local catLower = strlower(cat)
        if ns.Controller.buckets[catLower] then
            for sender, _ in pairs(ns.Controller.buckets[catLower]) do
                source[sender] = ns.Controller.messages[sender]
            end
        else
            source = ns.Controller.messages
        end
    end

    local available = {}
    local locked = {}

    for sender, data in pairs(source) do
        local isHidden = ns.Controller.hiddenLeaders[sender]
        local catMatch = (cat == "ALL") or (data.match.raidId == strlower(cat))

        if catMatch and not isHidden and GUI.TokenizedSearch(data, search) then
            local isLocked = ns.Stats.RaidLockInfo(data.match.raidId, data.match.difficultyId)
            if isLocked then
                tinsert(locked, data)
            else
                tinsert(available, data)
            end
        end
    end

    local sortFunc = function(a, b)
        if a.match.priority ~= b.match.priority then
            return a.match.priority > b.match.priority
        end
        return a.lastSeenTimestamp > b.lastSeenTimestamp
    end

    tsort(available, sortFunc)
    tsort(locked, sortFunc)

    -- Build Final List with Separator
    local finalResults = {}
    for _, v in ipairs(available) do tinsert(finalResults, v) end
    if #available > 0 and #locked > 0 then
        tinsert(finalResults, { isSeparator = true })
    end
    for _, v in ipairs(locked) do tinsert(finalResults, v) end

    local numResults = #finalResults
    FauxScrollFrame_Update(GUI.MainFrame.scrollFrame, numResults, ROWS_LIMIT, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(GUI.MainFrame.scrollFrame)

    for i = 1, ROWS_LIMIT do
        local row = GUI.rows[i]
        local idx = i + offset
        if idx <= numResults then
            local data = finalResults[idx]

            if data.isSeparator then
                row.sender = nil
                row.data = nil
                row.name:SetText("")
                row.raid:SetText("")
                row.diff:SetText("")
                row.gs:SetText("")
                row.count:SetText("")
                row.roleTank:Hide()
                row.roleHeal:Hide()
                row.roleDPS:Hide()
                row.noteBtn:SetAlpha(0)
                row.whisperBtn:Hide()
                row.deleteBtn:Hide()
                row.sepText:Show()
                row.bg:SetTexture(1, 1, 1, 0.09)
                row:SetAlpha(1)
            else
                row.sender = data.sender
                row.data = data
                row.sepText:Hide()
                row.roleTank:Show()
                row.roleHeal:Show()
                row.roleDPS:Show()
                row.whisperBtn:Show()
                row.deleteBtn:Show()

                local isLocked, _, lockId = ns.Stats.RaidLockInfo(data.match.raidId, data.match.difficultyId)
                local lockIcon = "|TInterface\\PetBattles\\BattleKings:10:10:0:0|t"

                -- Class Coloring / Red for Locked
                local classColor = RAID_CLASS_COLORS[data.class] or { r = 1, g = 0.8, b = 0 }
                local hasNote = ns.NoteFrame and ns.NoteFrame.HasNote(data.sender) or false
                if isLocked then
                    row:SetAlpha(0.6)                  -- Option B: Opacity
                    row.bg:SetTexture(0.5, 0, 0, 0.15) -- Option A: Red Background
                    row.name:SetText(lockIcon .. "|cffff0000" .. data.sender .. "|r")
                    row.raid:SetText("|cffff0000" .. data.match.raidName .. "|r")
                    row.diff:SetText("|cffff0000(" .. data.match.size .. (data.match.mode == 2 and "H" or "N") .. ")|r")
                    row.gs:SetText("")
                    row.count:SetText("")
                else
                    row:SetAlpha(1)
                    row.name:SetText(data.sender .. (data.guild and " |cff4cff4c(" .. data.guild .. ")|r" or ""))
                    row.name:SetTextColor(classColor.r, classColor.g, classColor.b)
                    row.raid:SetText(data.match.raidName)
                    row.diff:SetText("(" .. data.match.size .. (data.match.mode == 2 and "H" or "N") .. ")")
                    row.gs:SetText(data.match.gs or "")



                    SetRowCount(row, data.match)

                    -- Selection
                    if GUI.selectedSender == data.sender then
                        row.bg:SetTexture(1, 1, 1, 0.15)
                    else
                        if i % 2 == 0 then
                            row.bg:SetTexture(0, 0, 0, 0.55) -- fila par: oscura
                        else
                            row.bg:SetTexture(1, 1, 1, 0.03) -- fila impar: levemente clara
                        end
                    end
                end

                -- Role Icons
                row.roleTank:SetAlpha(data.match.roles.tank and 1 or 0.1)
                row.roleHeal:SetAlpha(data.match.roles.healer and 1 or 0.1)
                row.roleDPS:SetAlpha(data.match.roles.dps and 1 or 0.1)

                if hasNote then
                    row.noteBtn:SetAlpha(1.0)
                else
                    row.noteBtn:SetAlpha(0.12)
                end
            end
            row:Show()
        else
            row:Hide()
        end
    end
end

function GUI.RefreshView()
    if not GUI.MainFrame then return end
    local tab = GUI.selectedTab
    if tab == 1 then
        GUI.MainFrame.scrollFrame:Show()
        GUI.UpdateList()
    elseif tab == 3 then
        GUI.MainFrame.scrollFrame:Hide()
        for i = 1, ROWS_LIMIT do GUI.rows[i]:Hide() end
    else
        GUI.MainFrame.scrollFrame:Hide()
        for i = 1, ROWS_LIMIT do GUI.rows[i]:Hide() end
        -- Show Settings
    end
end

function GUI.Initialize()
    if GUI.MainFrame then return end
    CreateMainFrame()

    -- == BOTÃ“N FLOTANTE (estilo PallyPower) ==
    local floatBtn = CreateFrame("Button", "RaidStationFloatBtn", UIParent)
    floatBtn:SetSize(24, 24)
    floatBtn:SetFrameStrata("MEDIUM")
    floatBtn:SetToplevel(true)
    floatBtn:SetMovable(true)
    floatBtn:SetClampedToScreen(true)

    -- POSICIÃ“N INICIAL (persistente)
    local db = RaidStationDB or {}
    local x = db.floatBtnX or 200
    local y = db.floatBtnY or -200
    floatBtn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)

    -- ÃCONO (usar el icono guardado en DB, por defecto circle.blp)
    local icon = floatBtn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local savedIconFile = (db.floatBtnIcon and db.floatBtnIcon ~= "") and db.floatBtnIcon or "circle.blp"
    icon:SetTexture("Interface\\AddOns\\RaidStation\\Textures\\" .. savedIconFile)
    floatBtn.icon = icon

    -- ESTADO VISUAL (igual que el minimap)
    local function ApplyFloatBtnState(isActive)
        if isActive then
            floatBtn.icon:SetDesaturated(false)
            floatBtn.icon:SetVertexColor(1, 1, 1, 1) -- color normal
        else
            floatBtn.icon:SetDesaturated(true)
            floatBtn.icon:SetVertexColor(0.5, 0.5, 0.5, 0.7) -- gris apagado
        end
    end
    floatBtn.ApplyState = ApplyFloatBtnState

    -- Aplicar estado inicial al crear
    local isActive = (db.addonActive ~= false)
    ApplyFloatBtnState(isActive)

    -- DRAG (click derecho arrastra)
    floatBtn:RegisterForDrag("RightButton")
    floatBtn:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    floatBtn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, xOfs, yOfs = self:GetPoint()
        RaidStationDB.floatBtnX = xOfs
        RaidStationDB.floatBtnY = yOfs
    end)

    -- CLICK IZQUIERDO (mostrar/ocultar ventana principal)
    floatBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    floatBtn:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            if ns.GUI.MainFrame:IsShown() then
                ns.GUI.MainFrame:Hide()
            else
                ns.GUI.MainFrame:Show()
                if ns.Minimap and ns.Minimap.ApplyVisualState then
                    ns.Minimap.ApplyVisualState(true)
                end
                if ns.GUI.FloatBtn.ApplyState then
                    ns.GUI.FloatBtn.ApplyState(true)
                end
            end
        end
    end)

    -- TOOLTIP
    floatBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.GUI.ColorText and ns.GUI.ColorText("Raid Station") or "Raid Station")
        GameTooltip:AddLine("|cffffff00Click-Izq|r: Mostrar/Ocultar ventana")
        GameTooltip:AddLine("|cffffff00Click-Der|r: Mover boton")
        GameTooltip:Show()
    end)
    floatBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- VISIBILIDAD (controlada por Settings)
    if db.showFloatBtn ~= true then
        floatBtn:Hide()
    end

    ns.GUI.FloatBtn = floatBtn
end

ns.GUI = GUI

-- Slash Command
SLASH_RAIDSTATION1 = "/rs"
SLASH_RAIDSTATION2 = "/raidstation"
SlashCmdList["RAIDSTATION"] = function(msg)
    if GUI.MainFrame:IsShown() then GUI.MainFrame:Hide() else GUI.MainFrame:Show() end
end
