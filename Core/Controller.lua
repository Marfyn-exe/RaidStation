-- RaidStation :: Core/Controller.lua
-- Part of RaidStation by Marfin- | 2026
-- Unauthorized redistribution without credit is prohibited.

local addonName, ns = ...
local Controller = {
    messages = {},       -- Main storage: sender -> data
    buckets = {},        -- Category storage: raidId -> { sender = true }
    buffer = {},         -- Throttled message queue
    isInteracting = false,
    isFrozen = false,
    dataDirty = false,
    filterDirty = false,
    lastUpdate = 0,
    THROTTLE_INTERVAL = 1.5,
    POOL = {},            -- Table pool for reuse
    hiddenLeaders = {}   -- Session-based hidden leaders
}

-- Table Pooling
function Controller:AcquireTable()
    return tremove(self.POOL) or {}
end

function Controller:ReleaseTable(t)
    wipe(t)
    tinsert(self.POOL, t)
end

function Controller.AddMessage(sender, message, guid)
    -- Guard: respetar estado global ON/OFF
    if RaidStationDB and RaidStationDB.addonActive == false then return end
    
    local parsed = ns.Parser.SafeParse(sender, message)
    if not parsed then return end
    
    local match = ns.Matcher.Match(parsed)
    if not match then return end
    
    -- Filter out hidden leaders immediately if possible, or wait for ProcessBuffer
    if Controller.hiddenLeaders[sender] or (RaidStationDB and RaidStationDB.hiddenLeaders and RaidStationDB.hiddenLeaders[sender]) then
        return
    end
    
    tinsert(Controller.buffer, {
        sender = sender,
        guid = guid,
        parsed = parsed,
        match = match,
        timestamp = GetTime()
    })
    
    Controller.dataDirty = true
end

function Controller.ProcessBuffer()
    if #Controller.buffer == 0 then return end
    if Controller.isInteracting or Controller.isFrozen then return end
    
    local now = GetTime()
    if now - Controller.lastUpdate < Controller.THROTTLE_INTERVAL then return end
    
    for _, entry in ipairs(Controller.buffer) do
        local sender = entry.sender
        local existing = Controller.messages[sender]
        
        -- Duplicate Leader Merge Logic
        if existing and ns.Config.DEFAULTS.mergeByLeader then
            -- Update existing
            existing.lastSeenTimestamp = entry.timestamp
            existing.parsed = entry.parsed
            existing.match = entry.match
            existing.message = entry.parsed.original
            existing.guid = entry.guid
        else
            -- Create new entry
            local data = Controller:AcquireTable()
            data.sender = sender
            data.guid = entry.guid
            data.parsed = entry.parsed
            data.match = entry.match
            data.timestamp = entry.timestamp
            data.lastSeenTimestamp = entry.timestamp
            data.message = entry.parsed.original
            
            -- Extract player info if GUID available
            if data.guid and data.guid ~= 0 and data.guid ~= "0" then
                pcall(function()
                    local locClass, engClass, locRace, _, sex = GetPlayerInfoByGUID(data.guid)
                    data.class = engClass -- Used for coloring (e.g. "PRIEST")
                    data.locClass = locClass
                    data.race = locRace
                    data.gender = sex
                end)
            end
            
            Controller.messages[sender] = data
            
            -- Insert into bucket
            local raidId = entry.match.raidId or "GENERAL"
            Controller.buckets[raidId] = Controller.buckets[raidId] or {}
            Controller.buckets[raidId][sender] = true
        end
    end
    
    wipe(Controller.buffer)
    Controller.lastUpdate = now
    Controller.filterDirty = true
    
    if ns.GUI and ns.GUI.UpdateList then
        ns.GUI.UpdateList()
    end
end

-- Entry Expiration System (TTL)
function Controller.ExpireEntries()
    local now = GetTime()
    local ttl = ns.Config.DEFAULTS.ttl or 120
    local changed = false
    
    for sender, data in pairs(Controller.messages) do
        if now - data.lastSeenTimestamp > ttl then
            -- Remove from bucket
            local raidId = data.match.raidId or "GENERAL"
            if Controller.buckets[raidId] then
                Controller.buckets[raidId][sender] = nil
            end
            
            -- Release table to pool
            Controller:ReleaseTable(data)
            Controller.messages[sender] = nil
            changed = true
        end
    end
    
    if changed then
        Controller.filterDirty = true
        if ns.GUI and ns.GUI.UpdateList then
            ns.GUI.UpdateList()
        end
    end
end

-- Tickers
ns.Tickers = {}

function Controller.Initialize()
    if ns.Tickers.buffer then return end
    -- Usar ns.Utils.NewTicker después de quitar la exportación global
    ns.Tickers.buffer = ns.Utils.NewTicker(0.5, Controller.ProcessBuffer)
    ns.Tickers.ttl = ns.Utils.NewTicker(10, Controller.ExpireEntries)
end

-- Interface Detection (for scrolling safety)
function Controller.SetInteracting(state)
    Controller.isInteracting = state
    if state then
        if Controller.interactionTimer then
            ns.Utils.CancelTimer(Controller.interactionTimer)
        end
        Controller.interactionTimer = ns.Utils.NewTicker(5, function()
            Controller.isInteracting = false
            Controller.interactionTimer = nil
        end)
    end
end

function Controller.HideLeader(sender)
    if not sender then return end
    Controller.hiddenLeaders[sender] = true
    
    -- Remove from current messages
    local data = Controller.messages[sender]
    if data then
        local raidId = data.match.raidId or "GENERAL"
        if Controller.buckets[raidId] then
            Controller.buckets[raidId][sender] = nil
        end
        Controller:ReleaseTable(data)
        Controller.messages[sender] = nil
    end
    
    Controller.filterDirty = true
    if ns.GUI and ns.GUI.UpdateList then
        ns.GUI.UpdateList()
    end
end

ns.Controller = Controller
