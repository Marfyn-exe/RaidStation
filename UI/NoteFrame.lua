-- RaidStation :: UI/NoteFrame.lua
-- Part of RaidStation by Marfyn- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
local NoteFrame = {}

-- Frame flotante para editar notas de jugador
-- Se posiciona en el cursor al abrirse, sin tocar ningún layout existente.

local frame = CreateFrame("Frame", "RaidStationNoteFrame", UIParent)
frame:SetSize(220, 110)
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
frame:SetClampedToScreen(true)
frame:Hide()

-- Backdrop estilo ElvUI
frame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile     = false,
    tileSize = 0,
    edgeSize = 1,
    insets   = { left = 0, right = 0, top = 0, bottom = 0 }
})
frame:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

-- Línea de acento dorado en el top
local accentLine = frame:CreateTexture(nil, "OVERLAY")
accentLine:SetSize(220, 1)
accentLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
local _defR, _defG, _defB = 0.36, 0.61, 0.84
if ns.GUI and ns.GUI.GetAccentColor then
    _defR, _defG, _defB = ns.GUI.GetAccentColor()
end
accentLine:SetTexture(_defR, _defG, _defB, 0.8)

-- Título dinámico
local titleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
titleLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
titleLabel:SetTextColor(_defR, _defG, _defB)
frame.titleLabel = titleLabel

-- Botón cerrar (X) — ícono custom encima del flat style
local closeBtn = CreateFrame("Button", nil, frame)
closeBtn:SetSize(14, 14)
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
if ns.GUI and ns.GUI.SkinButton then
    ns.GUI.SkinButton(closeBtn, true)
end
-- Textura en OVERLAY para que quede sobre la capa ARTWORK del SkinButton
local closeTex = closeBtn:CreateTexture(nil, "OVERLAY")
closeTex:SetAllPoints()
closeTex:SetTexture("Interface\\AddOns\\RaidStation\\Textures\\exis2.blp")
closeBtn:SetScript("OnClick", function() frame:Hide() end)

-- EditBox para escribir la nota
local editBox = CreateFrame("EditBox", nil, frame)
editBox:SetSize(202, 58)
editBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -24)
editBox:SetMultiLine(true)
editBox:SetAutoFocus(false)
editBox:SetFontObject("ChatFontNormal")
editBox:SetMaxLetters(200)
ns.GUI.SkinEditBox(editBox)
editBox:SetBackdropColor(0.03, 0.03, 0.03, 1)
editBox:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
editBox:SetTextInsets(6, 6, 4, 4)

-- Contador de caracteres
local charCount = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
charCount:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 20)
charCount:SetText("0/200")
frame.charCount = charCount

editBox:SetScript("OnTextChanged", function(self)
    local len = strlen(self:GetText())
    local color = (len > 180) and "|cffff8800" or "|cff555555"
    charCount:SetText(color .. len .. "|r/200")
end)

-- Tab para mover el foco (evita que Tab inserte caracteres)
editBox:SetScript("OnTabPressed", function(self) self:ClearFocus() end)
editBox:SetScript("OnEscapePressed", function() frame:Hide() end)

-- Botón Guardar
local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
saveBtn:SetSize(90, 16)
saveBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 4)
saveBtn:SetText("Guardar")
if ns.GUI and ns.GUI.SkinButton then
    ns.GUI.SkinButton(saveBtn, true)
end
saveBtn:SetScript("OnClick", function()
    local sender = frame.currentSender
    if not sender then return end
    local text = strtrim(editBox:GetText())
    if not RaidStationDB.playerNotes then RaidStationDB.playerNotes = {} end
    if text == "" then
        RaidStationDB.playerNotes[sender] = nil
    else
        RaidStationDB.playerNotes[sender] = text
    end
    frame:Hide()
    -- Refrescar la lista para actualizar el indicador ✎
    if ns.GUI and ns.GUI.UpdateList then
        ns.GUI.UpdateList()
    end
end)

-- Botón Borrar
local deleteBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
deleteBtn:SetSize(90, 16)
deleteBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 4)
deleteBtn:SetText("Borrar nota")
if ns.GUI and ns.GUI.SkinButton then
    ns.GUI.SkinButton(deleteBtn, true)
end
deleteBtn:SetScript("OnClick", function()
    local sender = frame.currentSender
    if not sender then return end
    if RaidStationDB.playerNotes then
        RaidStationDB.playerNotes[sender] = nil
    end
    editBox:SetText("")
    frame:Hide()
    if ns.GUI and ns.GUI.UpdateList then
        ns.GUI.UpdateList()
    end
end)

-- API pública
function NoteFrame.Open(sender, anchorFrame)
    if not sender then return end
    frame.currentSender = sender

    local hexColor = ns.GUI and ns.GUI.GetAccentHex and ns.GUI.GetAccentHex() or "5B9BD5"
    titleLabel:SetText("|TInterface\\ICONS\\INV_Misc_Note_02:14:14:0:0|t Nota: |cff" .. hexColor .. sender .. "|r")

    local note = RaidStationDB.playerNotes and RaidStationDB.playerNotes[sender] or ""
    editBox:SetText(note)

    if ns.GUI and ns.GUI.GetAccentColor then
        local r, g, b = ns.GUI.GetAccentColor()
        accentLine:SetTexture(r, g, b, 0.8)
        titleLabel:SetTextColor(r, g, b)
    end

    -- Fijar posicion en la parte inferior derecha tal como lo mostraste
    frame:ClearAllPoints()
    if ns.GUI and ns.GUI.MainFrame then
        -- Se solapa un poco con el borde derecho del addon y queda abajo
        frame:SetPoint("BOTTOMLEFT", ns.GUI.MainFrame, "BOTTOMRIGHT", -80, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    frame:Show()
    editBox:SetFocus()
    editBox:SetCursorPosition(#note)
end

function NoteFrame.HasNote(sender)
    return RaidStationDB.playerNotes
        and RaidStationDB.playerNotes[sender]
        and RaidStationDB.playerNotes[sender] ~= ""
end

ns.NoteFrame = NoteFrame
