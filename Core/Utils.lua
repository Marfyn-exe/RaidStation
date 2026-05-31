-- RaidStation :: Core/Utils.lua
-- Part of RaidStation by Marfin- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
local Utils = {}

-- Ticker implementation for 3.3.5a
local tickers = {}
local function NewTicker(duration, callback)
    local ticker = CreateFrame("Frame")
    ticker.elapsed = 0
    ticker:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= duration then
            self.elapsed = 0
            callback()
        end
    end)
    table.insert(tickers, ticker)
    return ticker
end

local function NewTimer(duration, callback)
    local timer = CreateFrame("Frame")
    timer.elapsed = 0
    timer:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= duration then
            self:SetScript("OnUpdate", nil)
            callback()
        end
    end)
    return timer
end

local function CancelTimer(ticker)
    if ticker then
        ticker:SetScript("OnUpdate", nil)
        for i, t in ipairs(tickers) do
            if t == ticker then
                table.remove(tickers, i)
                break
            end
        end
    end
end

function Utils.CopyTable(src)
    local res = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            res[k] = Utils.CopyTable(v)
        else
            res[k] = v
        end
    end
    return res
end

ns.Utils = Utils

ns.Utils.NewTicker = NewTicker
ns.Utils.NewTimer = NewTimer
ns.Utils.CancelTimer = CancelTimer
