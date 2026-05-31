-------------------------------------------------------------------------------
-- RaidStation
-- Raid browser and advertiser addon for WotLK 3.3.5a (Build 12340)
--
-- Original Author : Marfyn- (characters: Joana / WowAcademy)
-- Server          : UltimoWow (wotlk.ultimowow.com)
-- Created         : 2026
-- License         : MIT — redistribution requires author credit
--
-- If you received this addon without this header intact, it has been
-- modified without authorization. Original repository:
-- https://github.com/Marfyn-exe/RaidStation
-------------------------------------------------------------------------------

local addonName, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- 1. Run data migrations
        if ns.Migration and ns.Migration.Run then
            ns.Migration.Run()
        end

        -- 2. Initialize default SavedVariables
        if ns.Config and ns.Config.InitDefaults then
            ns.Config.InitDefaults()
        end

        ns.GUI.Initialize()
        ns.Controller.Initialize()
        ns.BuffScanner.Initialize()
        ns.Settings.Initialize()
        ns.BuffTab.Initialize()
        ns.AdvertiserUI.Initialize()
        ns.Minimap.Initialize()
        if ns.GUI.FixMainFrameShellLayering then
            ns.GUI.FixMainFrameShellLayering()
        end
        -- Paneles (Settings, BuffTab, Advertiser) se crean despues del MainFrame;
        -- refrescar acento y fuente para que switches/scrollbars queden sincronizados.
        if ns.GUI.ApplyAccentColor then
            local ar, ag, ab = ns.GUI.GetAccentColor()
            ns.GUI.ApplyAccentColor(ar, ag, ab)
        end
        if ns.GUI.ApplyGlobalFont then
            ns.GUI.ApplyGlobalFont()
        end

        local function printMsg(msg)
            local prefix = (ns.GUI and ns.GUI.ColorText) and ns.GUI.ColorText("Raid Station") or
            "|cff5B9BD5Raid Station|r"
            print(prefix .. msg)
        end

        -- Obtener referencia a LibWho-2.0 para queries asíncronas de jugadores
        local ok, lib = pcall(function() return LibStub:GetLibrary("LibWho-2.0") end)
        if ok and lib then
            ns.WhoLib = lib
        else
            ns.WhoLib = nil
            printMsg(": LibWho-2.0 no disponible. El lookup de guild/raza no funcionará.")
        end



        -- Register Chat Events
        local chatFrame = CreateFrame("Frame")
        chatFrame:RegisterEvent("CHAT_MSG_CHANNEL")
        chatFrame:RegisterEvent("CHAT_MSG_YELL")
        chatFrame:SetScript("OnEvent",
            function(self, event, msg, sender, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, guid)
                ns.Controller.AddMessage(sender, msg, guid)
            end)

        -- Verificar fuentes / LibSharedMedia
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        if not LSM then
            printMsg(
            ": |cffffaa00Aviso:|r No se detectó la librería 'LibSharedMedia-3.0' (suele venir con ElvUI). Las opciones de fuentes estarán limitadas a las básicas del juego.")
        elseif RaidStationDB.fontFace == "SFUIDisplayCondensed-Semibold" then
            local fontPath = LSM:Fetch("font", "SFUIDisplayCondensed-Semibold", true)
            if not fontPath then
                printMsg(
                ": |cffffaa00Aviso:|r Tienes seleccionada la fuente 'SFUIDisplayCondensed-Semibold' pero no existe en tu carpeta de Fonts ni en LibSharedMedia. Se usará una fuente alternativa por defecto.")
            end
        end

        printMsg(" cargado! Escribe |cffffff00/rs|r para abrir.")
    elseif event == "PLAYER_LOGIN" then
        ns.Stats.RequestRaidLockouts()

        if ns.BuffData and ns.BuffData.BuildIconCache then
            ns.BuffData.BuildIconCache()
        end

        if ns.BuffScanner and ns.BuffScanner.StartWatching then
            ns.BuffScanner.StartWatching()
        end

        -- Redibujar la lista ahora que el cache de lockouts está listo
        if ns.GUI and ns.GUI.UpdateList then
            ns.GUI.UpdateList()
        end
    end
end)
