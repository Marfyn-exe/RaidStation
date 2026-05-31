-- RaidStation :: Core/Stats.lua
-- Part of RaidStation by Marfin- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
local Stats = {}

local raidLockoutCache = {}

-- Direct map: game instance name (lowercased) → internal raidId.
-- GetSavedInstanceInfo returns the server's localized instance name,
-- NOT a chat-style abbreviation, so we can't rely on Parser/Matcher.
local INSTANCE_NAME_TO_RAID = {
    -- ICC (English / Spanish)
    ["icecrown citadel"]                 = "icc",
    ["ciudadela de la corona de hielo"]  = "icc",
    -- Ruby Sanctum / Sanctum
    ["the ruby sanctum"]                 = "sr",
    ["el sagrario rubi"]                 = "sr",
    ["el sagrario rubí"]                 = "sr",
    -- Trial of the Crusader
    ["trial of the crusader"]            = "toc",
    ["prueba del cruzado"]               = "toc",
    -- Vault of Archavon
    ["vault of archavon"]                = "archa",
    ["camara de archavon"]               = "archa",
    ["cámara de archavon"]               = "archa",
    -- Onyxia
    ["onyxia's lair"]                    = "weekly",
    ["guarida de onyxia"]                = "weekly",
    -- Naxxramas
    ["naxxramas"]                        = "weekly",
    -- Eye of Eternity (Malygos)
    ["the eye of eternity"]              = "weekly",
    ["el ojo de la eternidad"]           = "weekly",
    -- Obsidian Sanctum (Sartharion)
    ["the obsidian sanctum"]             = "weekly",
    ["el sagrario obsidiana"]            = "weekly",
    -- Ulduar
    ["ulduar"]                           = "weekly",
}

function Stats.RequestRaidLockouts()
    wipe(raidLockoutCache)
    for i = 1, GetNumSavedInstances() do
        -- 3.3.5a API (8 returns): name, id, reset, difficulty, locked, extended, instanceIDMostSig, isRaid
        local name, id, reset, difficulty, locked, _, _, isRaid = GetSavedInstanceInfo(i)
        if name and isRaid and locked then
            local raidId = INSTANCE_NAME_TO_RAID[name:lower()]
            if raidId then
                local key = raidId .. ":" .. difficulty
                raidLockoutCache[key] = { reset = reset, locked = locked, id = id }
            end
        end
    end
end

function Stats.RaidLockInfo(raidId, difficultyId)
    local key = raidId .. ":" .. difficultyId
    local data = raidLockoutCache[key]
    if data then
        return data.locked, data.reset, data.id
    end
    return false, nil, nil
end

function Stats.BuildInvString(raidName)
    local message = "inv "
    local class = UnitClass("player")
    local spec = "DPS" -- Fallback or get from Talent/GS if available
    local gs = 0       -- Fallback
    
    -- Try to get from GearScore if available
    if _G.GearScore_GetScore then
        gs = _G.GearScore_GetScore(UnitName("player"), "player")
    end

    message = message .. (gs > 0 and (gs .. "gs ") or "") .. spec .. " " .. class
    return message
end

ns.Stats = Stats
