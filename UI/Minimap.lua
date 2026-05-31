-- RaidStation :: UI/Minimap.lua
-- Part of RaidStation by Marfyn- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
local Minimap = {}

function Minimap.UpdatePosition()
    if not RaidStationDB or not ns.Minimap.Button then return end
    local angle = RaidStationDB.minimapPos or 45
    ns.Minimap.Button:SetPoint(
        "TOPLEFT",
        _G.Minimap,
        "TOPLEFT",
        54 - (78 * math.cos(math.rad(angle))),
        (78 * math.sin(math.rad(angle))) - 55
    )
end

function Minimap.CreateButton()
    local button = CreateFrame("Button", "RaidStationMinimapButton", _G.Minimap)
    button:SetSize(31, 31)
    button:SetFrameLevel(8)
    button:SetToplevel(true)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\AddOns\\RaidStation\\Textures\\minimap.blp")
    icon:SetPoint("TOPLEFT", 7, -6)
    button.icon = icon  -- guardamos referencia para el toggle visual

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", 0, 0)

    -- Drag
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function(self)
            local xpos, ypos = GetCursorPosition()
            local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
            xpos = xmin - xpos / Minimap:GetEffectiveScale() + 70
            ypos = ypos / Minimap:GetEffectiveScale() - ymin - 70
            local angle = math.deg(math.atan2(ypos, xpos))
            if angle < 0 then angle = angle + 360 end
            RaidStationDB.minimapPos = angle
            Minimap.UpdatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)

    -- Clicks: izquierdo = mostrar/ocultar ventana, derecho = ON/OFF addon
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            if ns.GUI.MainFrame:IsShown() then
                ns.GUI.MainFrame:Hide()
            else
                ns.GUI.MainFrame:Show()
            end
        elseif btn == "RightButton" then
            Minimap.ToggleAddonActive()
        end
    end)

    -- Tooltip dinámico
    button:SetScript("OnEnter", function(self)
        local isActive = RaidStationDB and (RaidStationDB.addonActive ~= false)
        local stateColor = isActive and "|cff00ff00" or "|cffff0000"
        local stateLabel = isActive and "ACTIVO" or "INACTIVO"
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local title = ns.GUI and ns.GUI.ColorText and ns.GUI.ColorText("Raid Station") or "|cff5B9BD5Raid Station|r"
        GameTooltip:AddLine(title)
        GameTooltip:AddLine("|cffffff00Click-Izq|r: Mostrar/Ocultar Ventana")
        GameTooltip:AddLine("|cffffff00Click-Der|r: ON/OFF Addon  " .. stateColor .. "(" .. stateLabel .. ")|r")
        GameTooltip:AddLine("|cffffff00Arrastrar|r: Mover Icono")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    ns.Minimap.Button = button
    Minimap.UpdatePosition()

    -- Aplicar estado guardado al iniciar (default = true si no existe)
    local isActive = (RaidStationDB and RaidStationDB.addonActive ~= false)
    RaidStationDB.addonActive = isActive
    Minimap.ApplyVisualState(isActive)

    if not RaidStationDB.showMinimap then
        button:Hide()
    end
end

-- Aplica el look visual ON/OFF al icono
function Minimap.ApplyVisualState(isActive)
    local btn = ns.Minimap and ns.Minimap.Button
    if not btn then return end

    -- ElvUI puede haber reskinneado el botón.
    if isActive then
        btn:SetAlpha(1.0)
        if btn.icon and btn.icon.SetDesaturated then
            btn.icon:SetDesaturated(false)
            btn.icon:SetVertexColor(1, 1, 1, 1)
        end
    else
        btn:SetAlpha(0.5)  -- fallback visual: semitransparente cuando OFF
        if btn.icon and btn.icon.SetDesaturated then
            btn.icon:SetDesaturated(true)
            btn.icon:SetVertexColor(1, 0.2, 0.2, 0.9)
        end
    end

    if ns.GUI.FloatBtn and ns.GUI.FloatBtn.ApplyState then
        ns.GUI.FloatBtn.ApplyState(isActive)
    end
end

-- Toggle ON/OFF global del addon
function Minimap.ToggleAddonActive()
    local current = (RaidStationDB.addonActive ~= false)
    local isActive = not current
    RaidStationDB.addonActive = isActive

    if not isActive then
        -- 1. Detener spam
        if ns.Advertiser then
            ns.Advertiser:Stop()
        end
        -- 2. Resetear botón INICIAR en la UI del Advertiser
        if ns.AdvertiserUI and ns.AdvertiserUI.startBtn then
            ns.AdvertiserUI.startBtn:SetText("INICIAR")
            ns.AdvertiserUI:UpdateStatus()
        end
    end

    Minimap.ApplyVisualState(isActive)

    local stateMsg = isActive and "|cff00ff00ACTIVO|r" or "|cffff0000INACTIVO|r"
    local prefix = ns.GUI and ns.GUI.ColorText and ns.GUI.ColorText("Raid Station") or "|cff5B9BD5Raid Station|r"
    print(prefix .. ": " .. stateMsg)
end

function Minimap.Initialize()
    Minimap.CreateButton()
end

ns.Minimap = Minimap
