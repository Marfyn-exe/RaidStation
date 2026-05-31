-- RaidStation :: Data.lua
-- Part of RaidStation by Marfin- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
ns.Config = {}



-- Synonym Map: Regionalisms/Slang to Canonical IDs
ns.Config.SYNONYM_MAP = {
    ["ciudadela"] = "icc", ["lady"] = "icc", ["barcos"] = "icc", ["profe"] = "icc",
    ["sagrario"] = "sr", ["rubi"] = "sr", ["halion"] = "sr", ["rs"] = "sr",
    ["prueba"] = "toc", ["cruzado"] = "toc", ["bestias"] = "toc", ["valkys"] = "toc",
    ["archavon"] = "archa", ["conquista"] = "archa", ["voa"] = "archa", ["vov"] = "archa", ["archa"] = "archa",
    ["sem"] = "weekly", ["weekly"] = "weekly",
    ["u5"] = "u5", ["utgara"] = "weekly",
}

-- Raid Map: Configuration and Patterns
ns.Config.RAID_LIST = {
    {
        id = "icc",
        name = "ICC",
        patterns = {"icc", "profe", "lady", "barcos", "tuetano", "lk", "sindra", "reyna"},
        priorities = 10
    },
    {
        id = "sr",
        name = "SR",
        patterns = {"sr", "sagrario", "halion", "rubi", "rs", "ruby", "sanctum"},
        priorities = 9
    },
    {
        id = "toc",
        name = "TOC",
        patterns = {"toc", "prueba", "cruzado", "trial", "crusader"},
        priorities = 8
    },
    {
        id = "archa",
        name = "ARCHA",
        patterns = {"archa", "archavon", "conquista", "voa", "toravon", "koralon", "vault"},
        priorities = 7
    },
    {
        id = "weekly",
        name = "Semanal",
        patterns = {"semanal", "weekly", "u5", "utgara", "naxx", "naxxramas", "maly", "malygos", "sarth", "sartharion", "ony", "onyxia"},
        priorities = 6
    }
}

-- Mapping patterns to IDs for O(1) matching
ns.Config.PATTERN_TO_ID = {}
for _, raid in ipairs(ns.Config.RAID_LIST) do
    for _, p in ipairs(raid.patterns) do
        ns.Config.PATTERN_TO_ID[p] = raid.id
    end
end

-- Role Patterns
ns.Config.ROLE_PATTERNS = {
    tank = {
        -- español
        "tank", "tanke", "tanques", "tanque", "tanqe", "tanks", "tankear",
        -- inglés / spanglish
        "mt", "ot", "offtank",
        -- clases usadas como tank en este servidor
        "oso",   -- druida guardian
        "prot",  -- guerrero/paladin prot
        "dk",    -- death knight tank (cuando aparece solo en contexto tank)
        -- combinaciones donde el token de clase actúa como rol
        "war",   -- warrior tank
    },
    healer = {
        -- genérico
        "heal", "healer", "heals", "heler", "helers", "healers",
        "hyler",  -- typo frecuente observado en logs
        -- specs/clases heal
        "holy",   -- paladin holy / priest holy
        "disci", "disc",  -- priest discipline
        "resto",  -- druida/shaman resto
        "restauracion",
        -- clases heal abreviadas
        "hpala",  -- holy paladin
        "dudu",   -- druida (cuando aparece en contexto heal)
        "rdudu",  -- druida restauracion
        "chamy", "chami", "chaman", "chammy", "sham", "shaman",
        "rshaman", -- shaman resto
        "pri",    -- priest
        "priest",
        "sacer",  -- sacerdote
        -- combinaciones observadas (token individual)
        "druida", -- druida heal/resto
        "pala",   -- paladin heal (cuando aparece solo)
        "nito",   -- "necesito" abreviado, en este servidor se usa como "busco rol"
    },
    dps = {
        -- genérico
        "dps", "dpser", "dd",
        -- tipos de dps
        "melee", "mele", "mdps",
        "ranged", "rdps",
        "caster", "casters",
        -- clases DPS observadas en logs
        "feral",   -- druida feral dps
        "picaro",  -- rogue
        "rogue",
        "mago",
        "brujo", "lock",
        "cazador", "caza",  -- hunter
        "shadow",  -- priest shadow
        "pollo",   -- apodo local para druida balance / chaman mejora
        "ele",     -- chamán elemental
        "mejora",  -- chamán mejora
        "demo", "demon",    -- brujo demonología
        "afli",    -- brujo affliction
        "retri", "retry",   -- paladín retribución
        "profano", -- dk unholy
        "frost",   -- dk frost / mago frost
        "war",     -- warrior dps (cuando aparece en contexto dps)
        "warr",
        "equilibrio", -- druida balance
        -- combinaciones observadas como token individual
        "sacer",   -- sacerdote dps (shadow)
        "prot",    -- en raros casos prot dps (evaluar)
    },
}

-- Settings Defaults
ns.Config.DEFAULTS = {
    ttl = 120,
    mergeByLeader = true,
    showProgress = true,
    enableSmartSearch = true,
    showMinimap = true,
    minimapPos = 45,
    windowLocked = false,
    windowPoint = "CENTER",
    windowRelativePoint = "CENTER",
    windowX = 0,
    windowY = 0,
    reactiveSync = true,
    patterns = {},
    debug = false,
    -- Modulo Buffs
    buffTab_threshold = 600,
    buffTab_channel = "RAID",
    buffTab_showAll = true,
    buffTab_checkRaid = true,
    buffTab_checkPaladin = true,
    buffTab_checkConsumables = false,
    buffAnnounceChannel = "SELF",
    buffTab_alerts = {},
    buffTab_alertToRaidWarning = true,
    buffTab_alertToRaid = false,
    paladinAssignments = {},
    paladinAssignmentList = {},
    dbmPullSeconds = 10,
    floatBtnX = 200,
    floatBtnY = -200,
    showFloatBtn = false,
}

function ns.Config.InitDefaults()
    if not RaidStationDB then
        RaidStationDB = {}
    end
    if RaidStationDB.reactiveSync == nil then
        RaidStationDB.reactiveSync = true
    end
    if RaidStationDB.bgChoice == nil then
        RaidStationDB.bgChoice = 0   -- 0 = sin fondo (default), 1-6 = índice de fondo
    end
    if RaidStationDB.bgAlpha == nil then
        RaidStationDB.bgAlpha = 1.0   -- 100% por defecto
    end
    if RaidStationDB.showBorder == nil then
        RaidStationDB.showBorder = true  -- mostrar borde del frame principal
    end
    if RaidStationDB.bodyColor == nil then
        RaidStationDB.bodyColor = {0.13, 0.13, 0.13}  -- color del panel body (gris oscuro)
    end
    if RaidStationDB.bodyAlpha == nil then
        RaidStationDB.bodyAlpha = 1.0  -- opacidad del panel body (100%)
    end
    if RaidStationDB.accentColor == nil then
        RaidStationDB.accentColor = {0.36, 0.61, 0.84}  -- color de acento Frost (#5B9BD5)
    end
    if RaidStationDB.playerNotes == nil then
        RaidStationDB.playerNotes = {}   -- notas manuales por jugador
    end

    -- Default settings merge
    for k, v in pairs(ns.Config.DEFAULTS) do
        if RaidStationDB[k] == nil then
            RaidStationDB[k] = v
        end
    end
    -- Sync config with DB
    for k, v in pairs(RaidStationDB) do
        ns.Config.DEFAULTS[k] = v
    end

    -- Inicialización de buffTab_alerts (DESPUÉS DEL MERGE CON DEFAULTS)
    if type(RaidStationDB.buffTab_alerts) ~= "table" then
        RaidStationDB.buffTab_alerts = {}
    end
    for i = 1, 2 do
        if type(RaidStationDB.buffTab_alerts[i]) ~= "table" then
            RaidStationDB.buffTab_alerts[i] = { shortName = "", message = "", channel = "DEFAULT" }
        end
    end

    if RaidStationDB.buffTab_alertToRaidWarning == nil then
        RaidStationDB.buffTab_alertToRaidWarning = true
    end
    if RaidStationDB.buffTab_alertToRaid == nil then
        RaidStationDB.buffTab_alertToRaid = false
    end
end

