-- RaidStation :: Core/BuffData.lua
-- Definicion de buffs de raid y paladin para WotLK 3.3.5a (build 12340).
--
-- NOTA (locale): la deteccion en BuffScanner compara nombres de auras (UnitBuff)
-- con nombres devueltos por GetSpellInfo(spellID). Ambos usan el idioma del cliente.
-- Si el cliente no coincide con el idioma esperado, documentar como limitacion.
local addonName, ns = ...

local BuffData = {}

-- Tokens de clase en mayusculas (asignaciones / API)
BuffData.CLASS_TOKENS = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
    "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

BuffData.CLASS_DISPLAY = {
    WARRIOR = "Guerrero",
    PALADIN = "Paladin",
    HUNTER = "Cazador",
    ROGUE = "Picaro",
    PRIEST = "Sacerdote",
    DEATHKNIGHT = "Caballero de la Muerte",
    SHAMAN = "Chaman",
    MAGE = "Mago",
    WARLOCK = "Brujo",
    DRUID = "Druida",
}

-- Lista ordenada para UI y anuncios: primero raid, luego paladin, consumible al final
BuffData.DEFINITIONS = {
    -- === RAID ===
    {
        id = "raid_fort",
        nombre = "Rezo de entereza",
        jerga = "Rezos",
        spellIDs = { 48161, 48162 },
        superiorSpellID = 48162,
        clase_origen = "Sacerdote",
        tipo = "raid",
        reagente = true,
        descripcion = "Aumenta el aguante de toda la banda.",
        responsableLinea = "Asignado: cualquier Sacerdote o Brujo",
        iconSpellID = 48162,
    },
    {
        id = "raid_spirit",
        nombre = "Rezo de espiritu",
        jerga = "Rezos",
        spellIDs = { 48073, 48074 },
        superiorSpellID = 48074,
        clase_origen = "Sacerdote",
        tipo = "raid",
        reagente = true,
        descripcion = "Aumenta el espiritu de toda la banda.",
        responsableLinea = "Asignado: cualquier Sacerdote",
        iconSpellID = 48074,
    },
    {
        id = "raid_shadow",
        nombre = "Rezo de prot. Sombras",
        jerga = "Rezos",
        spellIDs = { 48169, 48170 },
        superiorSpellID = 48170,
        clase_origen = "Sacerdote",
        tipo = "raid",
        reagente = true,
        descripcion = "Aumenta la resistencia a las Sombras.",
        responsableLinea = "Asignado: cualquier Sacerdote o Paladin",
        iconSpellID = 48170,
    },
    {
        id = "raid_motw",
        nombre = "Don de lo salvaje",
        jerga = "Patita",
        spellIDs = { 48469, 48470 },
        superiorSpellID = 48470,
        clase_origen = "Druida",
        tipo = "raid",
        reagente = true,
        descripcion = "Aumenta atributos basicos (armadura, estadisticas) de la banda.",
        responsableLinea = "Asignado: cualquier Druida",
        iconSpellID = 48470,
    },
    {
        id = "raid_int",
        nombre = "Luminosidad arcana",
        jerga = "Intelecto",
        spellIDs = { 42995,61316,43002 },
        superiorSpellID = { 43002, 61316 },
        clase_origen = "Mago",
        tipo = "raid",
        reagente = true,
        neverFor = { "WARRIOR", "ROGUE", "DEATHKNIGHT" },
        descripcion = "Aumenta el intelecto de toda la banda.",
        responsableLinea = "Asignado: cualquier Mago",
        iconSpellID = 43002,
    },
    -- === PALADIN ===
    {
        id = "pala_kings",
        nombre = "Bendicion de reyes",
        jerga = "Reyes",
        spellIDs = { 20217, 25898 },
        superiorSpellID = 25898,
        clase_origen = "Paladin",
        tipo = "paladin",
        reagente = true,
        paladinFamily = "KINGS",
        descripcion = "Aumenta todas las estadisticas un 10%.",
        responsableLinea = "Asignado:en Ajustes, o cualquier Paladin",
        iconSpellID = 25898,
    },
    {
        id = "pala_wisdom",
        nombre = "Bendicion de sabiduria",
        jerga = "Sabi",
        spellIDs = { 48936, 48938 },
        superiorSpellID = 48938,
        clase_origen = "Paladin",
        tipo = "paladin",
        reagente = true,
        paladinFamily = "WISDOM",
        neverFor = { "WARRIOR", "ROGUE", "DEATHKNIGHT" },
        descripcion = "Rege de mana Healers/casters.",
        responsableLinea = "Asignado: en Ajustes, o cualquier Paladin",
        iconSpellID = 48938,
    },
    {
        id = "pala_might",
        nombre = "Bendicion de poderio",
        jerga = "Poderio",
        spellIDs = {48932, 48934 },
        superiorSpellID = 48934,
        clase_origen = "Paladin",
        tipo = "paladin",
        reagente = true,
        paladinFamily = "MIGHT",
        neverFor = { "PRIEST", "MAGE" },
        descripcion = "Aumenta el poder de ataque.",
        responsableLinea = "Asignado: en Ajustes, o cualquier Paladin",
        iconSpellID = 48934,
    },
    {
        id = "pala_sanc",
        nombre = "Bendicion de salvaguardia",
        jerga = "Salva",
        spellIDs = { 20911, 25899 },
        superiorSpellID = 25899,
        clase_origen = "Paladin",
        tipo = "paladin",
        reagente = true,
        paladinFamily = "SANCTUARY",
        descripcion = "Reduce el dano recibido; talento de Paladin Proteccion.",
        responsableLinea = "Asignado: en Ajustes (Prot), o cualquier Paladin Prot",
        iconSpellID = 25899,
    },
    -- === CONSUMIBLES ===
    {
        id = "cons_flask",
        nombre = "Frasco",
        spellIDs = {
            53755, 53758, 53760, 54212, 62380, 17626, 17627, 17628, 28518, 28519,
        },
        superiorSpellID = 53760,
        clase_origen = "Consumible",
        tipo = "consumible",
        reagente = false,
        descripcion = "Buff de frasco/elixir. Se muestra como categoria general.",
        responsableLinea = "Asignado: cada jugador",
        iconTexture = "Interface\\Icons\\INV_Alchemy_EndlessFlask_06",
    },
    {
        id = "cons_food",
        nombre = "Comida",
        spellIDs = {
            45548, 45549, 45550, 45551, 57325, 57327, 57329, 57332, 57334, 57356, 57371, 57399, 58466,
        },
        superiorSpellID = 45551,
        clase_origen = "Consumible",
        tipo = "consumible",
        reagente = false,
        descripcion = "Buff de comida/Well Fed. Se muestra como categoria general.",
        responsableLinea = "Asignado: cada jugador",
        iconTexture = "Interface\\Icons\\INV_Misc_Food_65",
    },
}

BuffData.CONSUMABLE_DEFINITIONS = {}

local spellIdToDefId = {}
local paladinSpellToFamily = {}

for _, def in ipairs(BuffData.DEFINITIONS) do
    for _, sid in ipairs(def.spellIDs) do
        spellIdToDefId[sid] = def.id
    end
    if def.paladinFamily then
        for _, sid in ipairs(def.spellIDs) do
            paladinSpellToFamily[sid] = def.paladinFamily
        end
    end
end
BuffData.paladinSpellToFamily = paladinSpellToFamily


function BuffData.GetDefinitionById(id)
    for _, def in ipairs(BuffData.DEFINITIONS) do
        if def.id == id then return def end
    end
    return nil
end

function BuffData.GetDefinitionsByTipo(tipo)
    local out = {}
    for _, def in ipairs(BuffData.DEFINITIONS) do
        if def.tipo == tipo then
            table.insert(out, def)
        end
    end
    return out
end

BuffData.CONSUMABLE_DEFINITIONS = BuffData.GetDefinitionsByTipo("consumible")

function BuffData.SpellIdToDefinitionId(spellId)
    return spellIdToDefId[spellId]
end

function BuffData.SpellIdToPaladinFamily(spellId)
    return paladinSpellToFamily[spellId]
end

function BuffData.GetDefinitionForPaladinFamily(family)
    for _, def in ipairs(BuffData.DEFINITIONS) do
        if def.paladinFamily == family then return def end
    end
    return nil
end

-- Nombres de hechizo en runtime (locale del cliente) para emparejar con UnitBuff
function BuffData.BuildSpellNameSetForDefinition(def)
    local names = {}
    for _, sid in ipairs(def.spellIDs) do
        local n = select(1, GetSpellInfo(sid))
        if n and n ~= "" then
            names[n] = sid
        end
    end
    return names
end

function BuffData.FormatClassList(tokens)
    if not tokens or #tokens == 0 then return "" end
    local parts = {}
    for _, t in ipairs(tokens) do
        if t == "ALL" then
            table.insert(parts, "Todos")
        else
            table.insert(parts, BuffData.CLASS_DISPLAY[t] or t)
        end
    end
    return table.concat(parts, ", ")
end

BuffData._iconCache = {}
function BuffData.BuildIconCache()
    for _, def in ipairs(BuffData.DEFINITIONS) do
        local tex = def.iconTexture
        if not tex then
            local iconId = def.iconSpellID or def.spellIDs[1]
            tex = select(3, GetSpellInfo(iconId))
        end
        BuffData._iconCache[def.id] = tex or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
end

ns.BuffData = BuffData
