-- RaidStation :: Core/Advertiser.lua
-- Part of RaidStation by Marfin- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
local Advertiser = {
    isSpamming = false,
    lastSpamTime = 0,
    interval = 25,
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
    if self.patterns.fullMessage and self.patterns.fullMessage ~= "" then
        return self.patterns.fullMessage
    end
    -- Si no, reconstruir automáticamente
    return self:GetLatestAutoHeader()
end

function Advertiser:GetLatestAutoHeader()
    local p = self.patterns
    local parts = {}
    
    -- 1. Header: Armo [Raid] [Size][Diff]
    local raidName = p.raidName or "Raid"
    local raidHeader = "Armo " .. raidName
    
    local totalCount = tostring(p.totalCount or 25)
    local difficulty = p.difficulty or ""
    
    local nameLower = raidName:lower()
    local hasSize = nameLower:find(totalCount)
    local hasDiff = (difficulty ~= "" and nameLower:find(difficulty:lower(), 1, true))

    if not hasSize then raidHeader = raidHeader .. " " .. totalCount end
    if not hasDiff and difficulty ~= "" then
        if not raidHeader:find("%s$") then raidHeader = raidHeader .. " " .. difficulty
        else raidHeader = raidHeader .. difficulty end
    end
    tinsert(parts, raidHeader)
    
    -- 2. Needs
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
    if #needs > 0 then tinsert(parts, "- Need " .. tconcat(needs, ", ")) end
    
    -- 3. Count
    tinsert(parts, strformat("[%d/%d]", p.currentCount or 0, p.totalCount or 25))
    
    return tconcat(parts, " ")
end

function Advertiser:GetHeaderParts()
    local p = self.patterns
    local parts = {}
    
    -- 1. Base Header
    local raidName = p.raidName or "Raid"
    local base = "Armo " .. raidName
    local totalCount = tostring(p.totalCount or 25)
    local difficulty = p.difficulty or ""
    local nameLower = raidName:lower()
    
    if not nameLower:find(totalCount) then base = base .. " " .. totalCount end
    if difficulty ~= "" and not nameLower:find(difficulty:lower(), 1, true) then
        base = base .. " " .. difficulty
    end
    parts.base = base
    
    -- 2. Needs
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
    parts.needs = #needs > 0 and ("- Need " .. tconcat(needs, ", ")) or ""
    
    -- 3. Progress
    parts.progress = strformat("[%d/%d]", p.currentCount or 0, p.totalCount or 25)
    
    return parts
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
        
        -- Send to all selected channels
        for chan, active in pairs(self.channels) do
            if active then
                if chan == "POS" then
                    local posId = GetChannelName("posada")
                    if posId and posId > 0 then
                        SendChatMessage(msg, "CHANNEL", nil, posId)
                    end
                elseif chan == "GLD" then
                    SendChatMessage(msg, "GUILD")
                else
                    local chanNum = tonumber(chan)
                    if chanNum then
                        SendChatMessage(msg, "CHANNEL", nil, chanNum)
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
    print("|cff00ff00Raid Station|r: Patron " .. index .. " guardado con éxito.")
end

function Advertiser:LoadPattern(index)
    if not index or index < 1 or index > 6 then return end
    if not RaidStationDB.patterns or not RaidStationDB.patterns[index] then
        print("|cff00ff00Raid Station|r: El Patron " .. index .. " está vacío.")
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
    
    print("|cff00ff00Raid Station|r: Patron " .. index .. " cargado.")
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
