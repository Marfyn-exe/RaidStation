-- RaidStation :: Core/Matcher.lua
-- Part of RaidStation by Marfin- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
local Matcher = {}

local strfind = string.find
local tinsert = table.insert

function Matcher.FindRaid(tokens)
    for _, token in ipairs(tokens) do
        local raidId = ns.Config.PATTERN_TO_ID[token]
        if raidId then
            -- Find the full raid info from Config
            for _, raid in ipairs(ns.Config.RAID_LIST) do
                if raid.id == raidId then
                    return raid
                end
            end
        end
    end
    return nil
end

function Matcher.FindMode(tokens)
    local size = 10
    local mode = 1 -- 1: Normal, 2: Heroic
    
    local foundSize = false
    local foundMode = false

    -- 1. Check for joined tokens first (e.g., "25h", "10hc") - HIGH PRIORITY
    for _, token in ipairs(tokens) do
        if token == "25h" or token == "25hc" or token == "25heroic" then
            size = 25
            mode = 2
            foundSize = true
            foundMode = true
            break
        elseif token == "25n" or token == "25nm" or token == "25normal" then
            size = 25
            mode = 1
            foundSize = true
            foundMode = true
            break
        elseif token == "10h" or token == "10hc" or token == "10heroic" then
            size = 10
            mode = 2
            foundSize = true
            foundMode = true
            break
        elseif token == "10n" or token == "10nm" or token == "10normal" then
            size = 10
            mode = 1
            foundSize = true
            foundMode = true
            break
        end
    end

    -- 2. Only check separate tokens if joined ones weren't found
    if not foundSize or not foundMode then
        for _, token in ipairs(tokens) do
            if not foundSize then
                if token == "25" then 
                    size = 25
                    foundSize = true
                elseif token == "10" then 
                    size = 10
                    foundSize = true
                end
            end
            
            if not foundMode then
                -- Only accept standalone 'h' or 'n' if we already found a size 
                -- or if the token is specifically difficulty shorthand (hc, nm)
                if token == "hc" or token == "hero" or token == "heroic" then 
                    mode = 2
                    foundMode = true
                elseif token == "nm" or token == "normal" then
                    mode = 1
                    foundMode = true
                elseif (token == "h" or token == "n") and foundSize then
                    -- If we have a size, 'h' or 'n' following it is likely difficulty
                    mode = (token == "h") and 2 or 1
                    foundMode = true
                end
            end
        end
    end

    -- Difficulty ID calculation for 3.3.5a
    -- 1: 10N, 2: 25N, 3: 10H, 4: 25H
    local diff = 1
    if size == 10 then
        diff = (mode == 2) and 3 or 1
    else
        diff = (mode == 2) and 4 or 2
    end
    
    return size, mode, diff
end

function Matcher.FindRoles(tokens)
    local roles = { tank = false, healer = false, dps = false }
    for _, token in ipairs(tokens) do
        for role, patterns in pairs(ns.Config.ROLE_PATTERNS) do
            for _, p in ipairs(patterns) do
                if token == p then
                    roles[role] = true
                end
            end
        end
    end
    return roles
end

local TRADE_KEYWORDS = {
    "compro", "vendo", "stack", "cardeno", "zircon", "ambar", "ojo", "gemas", "joyeria", "oro", "gold",
    "saronita", "titanio", "menas", "barra", "pizca", "loto", "vial", "frasco", "pocion", "elixir",
    "wts", "wtb", "vende", "compra", "precio", "disponible", "ofrecer", "ofrezcan"
}

function Matcher.IsTradeAd(tokens)
    local count = 0
    for _, token in ipairs(tokens) do
        for _, word in ipairs(TRADE_KEYWORDS) do
            if token == word then
                count = count + 1
            end
        end
    end
    -- If it has multiple trade keywords, it's likely an ad
    return count >= 2
end

function Matcher.IsFalsePositive(tokens, raidId)
    -- Sell/Buy filter
    if Matcher.IsTradeAd(tokens) then return true end

    if raidId == "sr" then
        -- Check for gem-related trade keywords specifically for SR
        local hasCardeno = false
        for _, token in ipairs(tokens) do
            if token == "cardeno" then hasCardeno = true end
        end
        
        if hasCardeno then return true end
    end
    return false
end

function Matcher.Match(parsed)
    if not parsed then return nil end
    
    local raid = Matcher.FindRaid(parsed.tokens)
    if not raid then return nil end
    
    if Matcher.IsFalsePositive(parsed.tokens, raid.id) then return nil end
    
    local size, mode, diff = Matcher.FindMode(parsed.tokens)
    local roles = Matcher.FindRoles(parsed.tokens)
    
    -- Deteccion de conteo (nueva)
    local have, total, confidence = ns.Parser.FindCount(parsed.clean, parsed.original, size)
    
    return {
        raidId       = raid.id,
        raidName     = raid.name,
        size         = size,
        mode         = mode,
        difficultyId = diff,
        roles        = roles,
        priority     = raid.priorities or 0,
        -- Nuevos campos:
        countHave       = have,
        countTotal      = total,
        countConfidence = confidence,  -- "high" | "medium" | nil
    }
end

ns.Matcher = Matcher
