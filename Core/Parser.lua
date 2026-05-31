-- RaidStation :: Core/Parser.lua
-- Part of RaidStation by Marfin- | 2026
-- Unauthorized redistribution without credit is prohibited.

local addonName, ns = ...
local Parser = {}

local strlower = string.lower
local strgsub = string.gsub
local strfind = string.find

-- Accent mapping for normalization
local ACCENT_MAP = {
    ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u",
    ["ñ"] = "n", ["ü"] = "u", ["Á"] = "a", ["É"] = "e", ["Í"] = "i",
    ["Ó"] = "o", ["Ú"] = "u", ["Ñ"] = "n", ["Ü"] = "u"
}

function Parser.Normalize(text)
    if not text then return "" end
    text = strlower(text)
    -- Remove accents
    for accent, sub in pairs(ACCENT_MAP) do
        text = strgsub(text, accent, sub)
    end
    -- Remove punctuation except spacers
    text = strgsub(text, "[%p%c]", " ")
    
    -- Preserve common raid shorthand before splitting others
    -- This ensures "25h", "10n", etc. stay as single tokens
    text = strgsub(text, "(%d+)([hn])", " %1%2 ")
    
    -- Separate other numbers from letters
    text = strgsub(text, "([%a])([%d])", "%1 %2")
    text = strgsub(text, "([%d])([%a])", "%1 %2")
    
    -- Collapse spaces
    text = strgsub(text, "%s+", " ")
    return strtrim(text)
end

function Parser.Tokenize(text)
    local tokens = {}
    for token in string.gmatch(text, "%S+") do
        -- Check synonym map
        local syn = ns.Config.SYNONYM_MAP[token]
        table.insert(tokens, syn or token)
    end
    return tokens
end

-- Production-grade wrapper
function Parser.SafeParse(sender, message)
    local ok, result = pcall(function()
        local clean = Parser.Normalize(message)
        local tokens = Parser.Tokenize(clean)
        return {
            clean = clean,
            tokens = tokens,
            sender = sender,
            original = message
        }
    end)
    
    if ok then
        return result
    else
        if ns.Config.DEFAULTS.debug then
            print("|cffff0000Parser Error:|r", result)
        end
        return nil
    end
end

-- ============================================================
-- DETECCION DE CONTEO DE BANDA
-- Retorna: have, total, confidence
--   confidence: "high" | "medium" | "low" | nil
-- ============================================================

-- Patrones de alta confianza: el lider dice exactamente cuantos son
local COUNT_PATTERNS_HIGH = {
    "%[(%d+)/(%d+)%]",      -- [13/25]  (formato RS)
    "%((%d+)/(%d+)%)",      -- (13/25)
    "(%d+)%s*/+%s*(%d+)",   -- 13/25 suelto
    "(%d+)%s+de%s+(%d+)",   -- 13 de 25
    "(%d+)%s+of%s+(%d+)",   -- 13 of 25
}

-- Patrones de confianza media: se infiere el total desde el tamaño del raid
-- "faltan N cupos", "somos N", "tenemos N"
local COUNT_PATTERNS_MEDIUM_FALTANTES = {
    "faltan%s+(%d+)%s+cupos?",    -- faltan 3 cupos / falta 1 cupo
    "faltan%s+(%d+)",              -- faltan 3
    "falta%s+(%d+)%s+cupos?",
    "falta%s+(%d+)",
    "nos%s+faltan%s+(%d+)",
    "quedan%s+(%d+)%s+cupos?",
    "quedan%s+(%d+)",
    "(%d+)%s+cupos?%s+libres?",   -- 3 cupos libres
    "(%d+)%s+spots?%s+left",
    "lf(%d+)%s+more",             -- lf3more (estilo EN)
    "lf%s+(%d+)%s+more",
}

local COUNT_PATTERNS_MEDIUM_SOMOS = {
    "somos%s+(%d+)",
    "tenemos%s+(%d+)",
    "ya%s+somos%s+(%d+)",
    "ya%s+tenemos%s+(%d+)",
    "llevamos%s+(%d+)",
}



function Parser.FindCount(cleanText, originalText, raidSize)
    -- cleanText: texto ya normalizado (minusculas, sin acentos)
    -- raidSize: 10 o 25 (ya detectado por Matcher), puede ser nil

    -- Totales que corresponden a conteos de BOSSES, no jugadores
    -- ICC=12, TOC=5, SR=1, Ulduar=14, Naxx=15, VoA=4
    local BOSS_COUNTS = {
        [1]=true, [4]=true, [5]=true, [6]=true,
        [12]=true, [14]=true, [15]=true
    }

    -- 1. Alta confianza: buscar en el texto ORIGINAL (preserva [N/M])
    local origLower = originalText and originalText:lower() or cleanText
    for _, pat in ipairs(COUNT_PATTERNS_HIGH) do
        local a, b = origLower:match(pat)
        if a and b then
            local have  = tonumber(a)
            local total = tonumber(b)
            -- Sanity check:
            -- 1. have <= total
            -- 2. total debe ser 10, 25 o 40 (tamaños de raid válidos)
            -- 3. total NO debe ser un conteo de bosses conocido
            if have and total
               and have <= total
               and (total == 10 or total == 25 or total == 40)
               and not BOSS_COUNTS[total] then
                return have, total, "high"
            end
        end
    end

    -- 2. Media: "faltan N cupos" → calculamos have = total - N
    if raidSize then
        for _, pat in ipairs(COUNT_PATTERNS_MEDIUM_FALTANTES) do
            local n = cleanText:match(pat)
            if n then
                local missing = tonumber(n)
                -- Sanity: no puede faltar mas de la mitad del raid (heuristica)
                if missing and missing > 0 and missing <= (raidSize / 2 + 2) then
                    local have = raidSize - missing
                    if have > 0 then
                        return have, raidSize, "medium"
                    end
                end
            end
        end

        -- 3. Media: "somos N / tenemos N"
        for _, pat in ipairs(COUNT_PATTERNS_MEDIUM_SOMOS) do
            local n = cleanText:match(pat)
            if n then
                local have = tonumber(n)
                -- Sanity: tiene sentido para el tamaño del raid
                if have and have > 0 and have < raidSize then
                    return have, raidSize, "medium"
                end
            end
        end
    end

    -- 4. Sin dato fiable
    return nil, nil, nil
end

ns.Parser = Parser
