-- RaidStation :: UI/Rows.lua
-- Part of RaidStation by Marfyn- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
local Rows = {}

local ROW_HEIGHT = 18

-- Columnas fijas (px desde la izquierda de la fila). Evita que el nombre largo empuje "ICC" y "(25N)".
Rows.LAYOUT = {
    ROW_W      = 318,
    NAME_LEFT  = 6,
    NAME_W     = 84,
    SEP_LEFT   = 92,
    RAID_LEFT  = 96,
    RAID_W     = 28,
    COUNT_LEFT = 126,
    COUNT_W    = 40,
    DIFF_LEFT  = 168,
    DIFF_W     = 52,
    GS_RIGHT   = 108,
    NOTE_RIGHT = 4,
}

-- Cache de datos de jugadores obtenidos via LibWho (por sesión)
Rows.playerCache = {}
-- El sender del row que tiene el mouse encima actualmente
Rows.currentHoverSender = nil

local RAID_CLASS_COLORS = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS

local function stripRaidMarkers(text)
    if not text or text == "" then return text or "" end

    -- Formato numérico: {rt1}..{rt8}
    text = text:gsub("%{[Rr][Tt][1-8]%}", " ")

    -- Cualquier {PalabraConocida} con o sin llave de cierre
    -- Cubre: {Estrella} {estrella} {Star} {star} {Luna {luna
    text = text:gsub("%{%a[%a%s]-[%}%s]", " ")

    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

-- Construye y muestra el tooltip para una fila. whoInfo puede ser nil (primera vez)
-- o una tabla con datos de LibWho (una vez que llegó el callback).
function Rows.BuildTooltip(self, whoInfo)
    if not self.data then return end
    local data = self.data
    local match = data.match

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    local classColor = RAID_CLASS_COLORS[data.class] or { r = 1, g = 0.8, b = 0 }

    -- Header: Race Class <Guild>  (combina datos del anuncio + LibWho si disponible)
    local race       = (whoInfo and whoInfo.Race) or data.race or ""
    local locCls     = (whoInfo and whoInfo.Class) or data.locClass or ""
    local guildText  = ""
    if whoInfo then
        -- LibWho result
        if whoInfo.Guild and whoInfo.Guild ~= "" then
            guildText = "|cff00ff00<" .. whoInfo.Guild .. ">|r"
        end
    elseif data.guild and data.guild ~= "" then
        guildText = "|cff00ff00<" .. data.guild .. ">|r"
    end

    local header = ""
    if race ~= "" then header = header .. race .. " " end
    if locCls ~= "" then header = header .. locCls .. " " end
    header = header .. guildText

    -- Si aún no tenemos datos de LibWho, indicamos que se está buscando
    if not whoInfo and not Rows.playerCache[data.sender] then
        if header ~= "" then header = header .. " " end
        header = header .. "|cff888888(buscando...)|r"
    end

    GameTooltip:AddDoubleLine(data.sender, header, classColor.r, classColor.g, classColor.b, 1, 1, 1)
    GameTooltip:AddLine(" ")

    local cleanMsg = stripRaidMarkers(data.message)
    if cleanMsg == "" then cleanMsg = data.message or "" end
    GameTooltip:AddLine(cleanMsg, 1, 1, 1, true)

    if match and match.gs and match.gs ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("GearScore:", "|cff00ff00" .. match.gs .. "|r")
    end

    if match then
        GameTooltip:AddLine(" ")
        local hexColor = ns.GUI and ns.GUI.GetAccentHex and ns.GUI.GetAccentHex() or "5B9BD5"
        GameTooltip:AddDoubleLine("Banda:", "|cff" .. hexColor .. match.raidName .. "|r")
        GameTooltip:AddDoubleLine("Tamaño:", match.size)
        GameTooltip:AddDoubleLine("Dificultad:", (match.mode == 2) and "Heroica" or "Normal")

        local isLocked, reset, lockId = ns.Stats.RaidLockInfo(match.raidId, match.difficultyId)
        if isLocked then
            GameTooltip:AddLine("\n|cffff0000GUARDADO|r ID: |cffffff00" .. (lockId or "???") .. "|r")
            GameTooltip:AddLine("Expira: " .. (reset and SecondsToTime(reset) or "desconocido"))
        else
            GameTooltip:AddLine("\n|cff00ff00DISPONIBLE|r (No guardado)")
        end
    end

    if match and match.countHave then
        GameTooltip:AddLine(" ")
        local confText = match.countConfidence == "high"
            and "|cff00ff00(dato exacto del mensaje)|r"
            or "|cffffff00(estimado del mensaje)|r"
        GameTooltip:AddDoubleLine(
            "Miembros:",
            match.countHave .. "/" .. (match.countTotal or "?") .. " " .. confText
        )
    end

    -- Nota del jugador (si existe)
    local note = RaidStationDB.playerNotes and RaidStationDB.playerNotes[data.sender]
    if note and note ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
        "|TInterface\\ICONS\\INV_Misc_Note_02:14:14:0:0|t |cffffd700Nota:|r |cffdddddd" .. note .. "|r", 1, 1, 1, true)
    end

    GameTooltip:Show()
end

function Rows.OnRowEnter(self)
    if not self.data then return end
    local data = self.data
    local sender = data.sender

    Rows.currentHoverSender = sender

    -- Si ya tenemos datos en cache, úsalos directamente
    local cached = Rows.playerCache[sender]
    Rows.BuildTooltip(self, cached)

    -- Si no tenemos cache Y tenemos LibWho disponible, lanzar query asíncrona
    if not cached then
        local WhoLib = ns.WhoLib
        if WhoLib then
            WhoLib:UserInfo(sender, {
                queue    = WhoLib.WHOLIB_QUEUE_QUIET,
                timeout  = 0,
                callback = function(result)
                    -- Guardar en cache (incluso si offline, para no repetir)
                    Rows.playerCache[sender] = result or false

                    -- Si el mouse sigue sobre este sender, refrescar tooltip
                    if Rows.currentHoverSender == sender
                        and self
                        and self:IsShown()
                        and self:IsMouseOver()
                        and GameTooltip:IsShown()
                        and GameTooltip:GetOwner() == self then
                        if result and result.Online then
                            Rows.BuildTooltip(self, result)
                        end
                    end
                end,
            })
        end
    end
end

function Rows.OnRowClick(self)
    ns.GUI.selectedSender = self.sender
    ns.GUI.UpdateList()
end

function Rows.OnRowDoubleClick(self)
    if not self.sender then return end
    -- Open chat but don't send any message
    ChatFrame_OpenChat("/w " .. self.sender .. " ")
end

function Rows.CreateRow(parent, index)
    local L = Rows.LAYOUT
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(L.ROW_W, ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture(0, 0, 0, 0.4)

    -- Hover overlay (HIGHLIGHT layer, separado del bg)
    row.hoverBg = row:CreateTexture(nil, "HIGHLIGHT")
    row.hoverBg:SetAllPoints()
    row.hoverBg:SetTexture(0, 0.47, 0.78, 0.15) -- azul ElvUI suave
    row.hoverBg:Hide()

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", L.NAME_LEFT, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWidth(L.NAME_W)

    row.colSep = row:CreateTexture(nil, "BORDER")
    row.colSep:SetSize(1, 10)
    row.colSep:SetPoint("LEFT", L.SEP_LEFT, 0)
    row.colSep:SetTexture(ns.GUI.GetAccentColor(), 0.4)

    row.raid = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.raid:SetPoint("LEFT", L.RAID_LEFT, 0)
    row.raid:SetJustifyH("LEFT")
    row.raid:SetWidth(L.RAID_W)
    row.raid:SetTextColor(0.6, 0.6, 0.6)

    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("LEFT", L.COUNT_LEFT, 0)
    row.count:SetJustifyH("LEFT")
    row.count:SetWidth(L.COUNT_W)
    row.count:SetHeight(ROW_HEIGHT)
    row.count:SetText("")

    local fontPath = row.count:GetFont()
    if fontPath then
        row.count:SetFont(fontPath, 11, "")
    end

    row.diff = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.diff:SetPoint("LEFT", L.DIFF_LEFT, 0)
    row.diff:SetJustifyH("LEFT")
    row.diff:SetWidth(L.DIFF_W)
    row.diff:SetTextColor(0.6, 0.6, 0.6)

    row.gs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.gs:SetPoint("RIGHT", row, "RIGHT", -L.GS_RIGHT, 0)
    row.gs:SetTextColor(0, 1, 0)

    -- Role Icons (Smaller and Ultra-Compact)
    local function CreateRoleIcon(parent, coords)
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(14, 14)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(0, 0, 0, 1)

        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")

        -- Apply a 15% crop on all sides to eliminate the circular edge,
        -- leaving a perfect flat colored square with the symbol.
        local w = coords[2] - coords[1]
        local h = coords[4] - coords[3]
        local padW = w * 0.15
        local padH = h * 0.15
        icon:SetTexCoord(coords[1] + padW, coords[2] - padW, coords[3] + padH, coords[4] - padH)

        f:Hide()
        return f
    end

    row.roleTank = CreateRoleIcon(row, { 0, 0.26171875, 0.26171875, 0.5234375 })

    local noteBtn = CreateFrame("Button", nil, row)
    noteBtn:SetSize(14, 14)
    noteBtn:SetPoint("RIGHT", row, "RIGHT", -L.NOTE_RIGHT, 0)
    local noteTex = noteBtn:CreateTexture(nil, "OVERLAY")
    noteTex:SetAllPoints()
    noteTex:SetTexture("Interface\\ICONS\\INV_Misc_Note_02")
    noteTex:SetVertexColor(1, 1, 1)
    noteBtn.tex = noteTex
    noteBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Nota del jugador", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Click derecho sobre el nombre", 1, 1, 1, true)
        GameTooltip:AddLine("para agregar/editar una nota.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    noteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    noteBtn:SetScript("OnClick", function(self)
        if row.sender then
            ns.NoteFrame.Open(row.sender, row)
        end
    end)
    noteBtn:SetAlpha(0.12)
    row.noteBtn = noteBtn

    row.roleTank:SetPoint("RIGHT", noteBtn, "LEFT", -2, 0)

    row.roleHeal = CreateRoleIcon(row, { 0.26171875, 0.5234375, 0, 0.26171875 })
    row.roleHeal:SetPoint("RIGHT", row.roleTank, "LEFT", -2, 0)

    row.roleDPS = CreateRoleIcon(row, { 0.26171875, 0.5234375, 0.26171875, 0.5234375 })
    row.roleDPS:SetPoint("RIGHT", row.roleHeal, "LEFT", -2, 0)

    -- Separator Text (Centered)
    row.sepText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.sepText:SetPoint("CENTER", 0, 0)
    row.sepText:SetText("--Saved Raids--")
    row.sepText:SetTextColor(1, 0.3, 0.3)
    row.sepText:Hide()

    -- Delete/Hide Button (Compact) — icon-only, no SkinButton
    local delete = CreateFrame("Button", nil, row)
    delete:SetSize(16, 16)
    delete:SetPoint("RIGHT", row.roleDPS, "LEFT", 1, 0)
    delete:Hide()
    delete:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    delete:SetHighlightTexture("")
    local delNt = delete:GetNormalTexture()
    if delNt then
        delNt:SetAlpha(0.6)
    end
    delete:SetScript("OnClick", function()
        if row.sender then
            ns.Controller.HideLeader(row.sender)
        end
    end)
    delete:SetScript("OnEnter", function(self)
        local nt = self:GetNormalTexture()
        if nt then
            local r, g, b = ns.GUI.GetAccentColor()
            nt:SetVertexColor(r, g, b)
            nt:SetAlpha(1.0)
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Ocultar anuncio", 1, 0, 0)
        GameTooltip:AddLine("Elimina a este lider de la lista actual.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    delete:SetScript("OnLeave", function(self)
        local nt = self:GetNormalTexture()
        if nt then
            nt:SetVertexColor(1, 1, 1)
            nt:SetAlpha(0.6)
        end
        GameTooltip:Hide()
    end)
    row.deleteBtn = delete

    -- Whisper Button (Discreet) — icon-only, no SkinButton
    local whisper = CreateFrame("Button", nil, row)
    whisper:SetSize(16, 16)
    whisper:SetPoint("RIGHT", delete, "LEFT", 1, 0)
    whisper:Hide()
    whisper:SetNormalTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    whisper:SetHighlightTexture("")
    local whNt = whisper:GetNormalTexture()
    if whNt then
        whNt:SetAlpha(0.6)
    end
    whisper:SetScript("OnClick", function()
        Rows.OnRowDoubleClick(row)
    end)
    whisper:SetScript("OnEnter", function(self)
        local nt = self:GetNormalTexture()
        if nt then
            local r, g, b = ns.GUI.GetAccentColor()
            nt:SetVertexColor(r, g, b)
            nt:SetAlpha(1.0)
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Susurrar", ns.GUI.GetAccentColor())
        GameTooltip:AddLine("Abre el chat para enviar un mensaje privado.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    whisper:SetScript("OnLeave", function(self)
        local nt = self:GetNormalTexture()
        if nt then
            nt:SetVertexColor(1, 1, 1)
            nt:SetAlpha(0.6)
        end
        GameTooltip:Hide()
    end)
    row.whisperBtn = whisper

    row:SetScript("OnEnter", function(self)
        self.hoverBg:Show()
        Rows.OnRowEnter(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.hoverBg:Hide()
        if self.data and Rows.currentHoverSender == self.data.sender then
            Rows.currentHoverSender = nil
        end
        GameTooltip:Hide()
    end)
    row:SetScript("OnHide", function(self)
        self.hoverBg:Hide()
        if self.data and Rows.currentHoverSender == self.data.sender then
            Rows.currentHoverSender = nil
        end
        if GameTooltip:IsShown() and GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.sender then
                ns.NoteFrame.Open(self.sender, self)
            end
        else
            Rows.OnRowClick(self)
        end
    end)
    row:SetScript("OnDoubleClick", Rows.OnRowDoubleClick)

    -- Minimalist thin border
    row.border = row:CreateTexture(nil, "OVERLAY")
    row.border:SetHeight(1)
    row.border:SetPoint("BOTTOMLEFT", 0, 0)
    row.border:SetPoint("BOTTOMRIGHT", 0, 0)
    row.border:SetTexture(1, 1, 1, 0.05)

    row:Hide()
    return row
end

ns.Rows = Rows
