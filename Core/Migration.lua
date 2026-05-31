-- RaidStation :: Core/Migration.lua
-- Part of RaidStation by Marfin- | 2026
-- Unauthorized redistribution without credit is prohibited.
local addonName, ns = ...
ns.Migration = {}

function ns.Migration.Run()
    if not RaidStationDB then return end

    -- Migracion: asignaciones antiguas por nombre -> lista lineal
    if type(RaidStationDB.paladinAssignments) == "table" and next(RaidStationDB.paladinAssignments)
        and (not RaidStationDB.paladinAssignmentList or #RaidStationDB.paladinAssignmentList == 0) then
        RaidStationDB.paladinAssignmentList = {}
        for pname, rows in pairs(RaidStationDB.paladinAssignments) do
            if type(rows) == "table" then
                for _, row in ipairs(rows) do
                    if type(row) == "table" and row.spellID then
                        table.insert(RaidStationDB.paladinAssignmentList, {
                            paladin = pname,
                            spellID = row.spellID,
                            clases = row.clases or row.classes or { "ALL" },
                        })
                    end
                end
            end
        end
    end

    -- Migracion: buffTab_checkConsume -> buffTab_checkConsumables
    if RaidStationDB.buffTab_checkConsume ~= nil then
        if RaidStationDB.buffTab_checkConsumables == nil then
            RaidStationDB.buffTab_checkConsumables = (RaidStationDB.buffTab_checkConsume == true)
        end
        RaidStationDB.buffTab_checkConsume = nil
    end
end
