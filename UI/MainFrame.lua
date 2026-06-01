-- RaidStation :: UI/MainFrame.lua
-- Part of RaidStation by Marfyn- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
ns.GUI = ns.GUI or {}
local GUI = ns.GUI
GUI.rows = GUI.rows or {}
GUI.activeFilter = GUI.activeFilter or "ALL"
GUI.searchPattern = GUI.searchPattern or ""
GUI.COLORS = GUI.COLORS or {
    accent = { 0.36, 0.61, 0.84 }, -- Frost Blue default
    panelBg = { 0.17, 0.17, 0.17 },
    listBg = { 0.13, 0.13, 0.13 },
    border = { 0.10, 0.10, 0.10 },
}
GUI.registeredAccentLabels = GUI.registeredAccentLabels or {}

local ROWS_LIMIT = 20
local ROW_HEIGHT = 18
local IsElvUI = _G.ElvUI ~= nil

local RS_SCROLL_LIST_TRIM = 12

local RAID_CLASS_COLORS = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS

local strlower = string.lower
local strfind = string.find
local tinsert = table.insert
local tsort = table.sort

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
