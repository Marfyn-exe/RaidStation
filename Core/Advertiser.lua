-- RaidStation :: Core/Advertiser.lua
-- Part of RaidStation by Marfin- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
local DEBUG = false  -- Activar en desarrollo: imprime eventos de patron al chat -- fix C-10

-- fix S-1: helper de envío vía ChatThrottleLib si está disponible
local function SafeSendChat(msg, chatType, chanNum)
    local CTL = _G.ChatThrottleLib
    if CTL then
        CTL:SendChatMessage("NORMAL", "RaidStation", msg, chatType, nil, chanNum)
    else
        SendChatMessage(msg, chatType, nil, chanNum)
    end
end
local Advertiser = {
    isSpamming = false,
    lastSpamTime = 0,
    interval = math.max(15, 25), -- fix S-1: mínimo 15 segundos
    channels = {}, -- { [id] = true }
    patterns = {}, -- Current form data
}

local strformat = string.format
local tinsert = table.insert
local tconcat = table.concat

-- Default pattern data
function Advertiser:ResetPatterns()
    self.patterns = {
        raidName = "ICC",
        roles = {
            tank = { need = 0, class = "" },
            healer = { need = 0, class = "" },
            melee = { need = 0, class = "" },
            caster = { need = 0, class = "" },
        },
        message = "", -- For the editbox
        fullMessage = "", -- Source of truth for spam
        currentCount = 0,
        totalCount = 10,
        difficulty = "N",
        extraHeader = "", -- For symbols at start
    }
end

function Advertiser:GetFormattedMessage()
    -- Siempre reconstruir desde los campos del formulario
    return self:GetLatestAutoHeader()
end

function Advertiser:GetSpamMessage()
    -- Si el usuario editó manualmente la Vista Previa, usar ese valor
    local msg
    if self.patterns.fullMessage and self.patterns.fullMessage ~= "" then
        msg = self.patterns.fullMessage
    else
        -- Si no, reconstruir automáticamente
        msg = self:GetLatestAutoHeader()
    end
    msg = msg:gsub("|", "||") -- fix S-2: escapar "|" para evitar secuencias de color rotas
    return msg
end

-- fix C-7
local function BuildHeaderData(p)
    local raidName = p.raidName or "Raid"
    local base = "Armo " .. raidName
    local totalCount = tostring(p.totalCount or 25)
    local difficulty = p.difficulty or ""
    local nameLower = raidName:lower()

    if not nameLower:find(totalCount) then base = base .. " " .. totalCount end
    if difficulty ~= "" and not nameLower:find(difficulty:lower(), 1, true) then
        base = base .. " " .. difficulty
    end

    local needs = {}
    local roles = {"tank", "healer", "melee", "caster"}
    for _, role in ipairs(roles) do
        local data = p.roles[role]
        if data.need > 0 then
            local s = data.need .. " " .. role:sub(1,1):upper() .. role:sub(2)
            if data.class ~= "" then s = s .. " (" .. data.class .. ")" end
            tinsert(needs, s)
        end
    end
    local needsStr = #needs > 0 and ("- Need " .. tconcat(needs, ", ")) or ""

    local progress = strformat("[%d/%d]", p.currentCount or 0, p.totalCount or 25)

    return { base = base, needs = needsStr, progress = progress }
end

function Advertiser:GetLatestAutoHeader()
    local d = BuildHeaderData(self.patterns) -- fix C-7
    return d.base .. (d.needs ~= "" and " " .. d.needs or "") .. " " .. d.progress -- fix C-7
end

function Advertiser:GetHeaderParts()
    return BuildHeaderData(self.patterns) -- fix C-7
end

function Advertiser:Start()
    if self.isSpamming then return end
    self.isSpamming = true
    self.lastSpamTime = 0 -- Trigger immediately
end

function Advertiser:Stop()
    self.isSpamming = false
    self.lastSpamTime = 0
end

function Advertiser:OnUpdate()
    if not self.isSpamming then return end
    
    local now = GetTime()
    if now - self.lastSpamTime >= self.interval then
        local msg = self:GetSpamMessage()
        if msg == "" then return end
        
        -- fix S-1: enviar a todos los canales activos vía SafeSendChat
        for chan, active in pairs(self.channels) do
            if active then
                if chan == "POS" then
                    local posId = GetChannelName("posada")
                    if posId and posId > 0 then
                        SafeSendChat(msg, "CHANNEL", posId) -- fix S-1
                    end
                elseif chan == "GLD" then
                    SafeSendChat(msg, "GUILD") -- fix S-1
                else
                    local chanNum = tonumber(chan)
                    if chanNum then
                        SafeSendChat(msg, "CHANNEL", chanNum) -- fix S-1
                    end
                end
            end
        end
        
        self.lastSpamTime = now
    end
end

function Advertiser:SavePattern(index)
    if not index or index < 1 or index > 6 then return end
    if not RaidStationDB.patterns then RaidStationDB.patterns = {} end
    RaidStationDB.patterns[index] = ns.Utils.CopyTable(self.patterns)
    if DEBUG then -- fix C-10
        print("|cff00ff00Raid Station|r: Patron " .. index .. " guardado con éxito.") -- fix C-6
    end
end

function Advertiser:LoadPattern(index)
    if not index or index < 1 or index > 6 then return end
    if not RaidStationDB.patterns or not RaidStationDB.patterns[index] then
        if DEBUG then -- fix C-10
            print("|cff00ff00Raid Station|r: El Patron " .. index .. " está vacío.") -- fix C-6
        end
        return
    end
    self.patterns = ns.Utils.CopyTable(RaidStationDB.patterns[index])
    self.patterns.fullMessage = ""
    self.patterns.message = ""
    
    -- Robust Migration & Integrity Check
    if not self.patterns.roles then self.patterns.roles = {} end
    
    -- ranged -> caster
    if self.patterns.roles.ranged and not self.patterns.roles.caster then
        self.patterns.roles.caster = self.patterns.roles.ranged
        self.patterns.roles.ranged = nil
    end
    
    -- Ensure all required role keys exist to prevent Lua errors
    local requiredRoles = {"tank", "healer", "melee", "caster"}
    for _, r in ipairs(requiredRoles) do
        if not self.patterns.roles[r] then
            self.patterns.roles[r] = { need = 0, class = "" }
        end
    end
    
    -- Ensure extraMessage exists
    if self.patterns.extraMessage == nil then self.patterns.extraMessage = "" end
    
    if DEBUG then -- fix C-10
        print("|cff00ff00Raid Station|r: Patron " .. index .. " cargado.") -- fix C-6
    end
    return true
end

-- Item Link Handling (Hooked from Global)
hooksecurefunc("ChatEdit_InsertLink", function(text)
    if ns.GUI.activeEditBox and ns.GUI.activeEditBox:IsVisible() then
        ns.GUI.activeEditBox:Insert(text)
    end
end)

-- Initialize
Advertiser:ResetPatterns()

-- Global Ticker for Advertiser
ns.AdvertiserTicker = ns.Utils.NewTicker(1, function()
    Advertiser:OnUpdate()
end)

ns.Advertiser = Advertiser
