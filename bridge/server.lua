Framework.Server = {}

-- ================================
-- Framework Initialization (SAFE)
-- ================================
CreateThread(function()
    -- Wait for Framework table
    while not Framework or not Framework.Detect do
        Wait(50)
    end

    local detected = Framework.Detect()
    Framework.Name = detected

    if Framework.Debug then
        Framework.Debug('Server framework detected: ' .. tostring(detected))
    end

    if detected == 'qbox' then
        Framework.Server.Core = exports.qbx_core
    elseif detected == 'qbcore' then
        Framework.Server.Core = exports['qb-core']:GetCoreObject()
    elseif detected == 'esx' then
        Framework.Server.Core = exports['es_extended']:getSharedObject()
    end

    -- Wait until the core is actually usable
    while not Framework.Server.Core do
        Wait(50)
    end
end)

-- ================================
-- Player Exists (BULLETPROOF)
-- ================================
function Framework.Server.PlayerExists(src)
    if src == nil then return false end
    if type(src) ~= 'number' then return false end
    if src <= 0 then return false end

    -- Native-safe validation
    local endpoint = GetPlayerEndpoint(src)
    if endpoint == nil then return false end

    return true
end

-- ================================
-- Get Player Object
-- ================================
function Framework.Server.GetPlayer(src)
    if not Framework.Server.PlayerExists(src) then return nil end

    if Framework.Name == 'qbox' then
        return Framework.Server.Core:GetPlayer(src)
    elseif Framework.Name == 'qbcore' then
        return Framework.Server.Core.Functions.GetPlayer(src)
    elseif Framework.Name == 'esx' then
        return Framework.Server.Core.GetPlayerFromId(src)
    end

    return nil
end

-- ================================
-- Get Player Identifier
-- ================================
function Framework.Server.GetIdentifier(src)
    if not Framework.Server.PlayerExists(src) then return nil end

    local player = Framework.Server.GetPlayer(src)
    if player then
        if Framework.Name == 'qbox' or Framework.Name == 'qbcore' then
            return player.PlayerData and player.PlayerData.citizenid
        elseif Framework.Name == 'esx' then
            return player.identifier
        end
    end

    local ids = GetPlayerIdentifiers(src)
    return ids and ids[1] or nil
end

-- ================================
-- Get Player Name
-- ================================
function Framework.Server.GetPlayerName(src)
    if not Framework.Server.PlayerExists(src) then return 'Unknown' end

    local player = Framework.Server.GetPlayer(src)
    if player then
        if Framework.Name == 'qbox' or Framework.Name == 'qbcore' then
            local charinfo = player.PlayerData and player.PlayerData.charinfo
            if charinfo then
                return charinfo.firstname .. ' ' .. charinfo.lastname
            end
        elseif Framework.Name == 'esx' then
            return player.getName()
        end
    end

    return GetPlayerName(src) or 'Unknown'
end

-- ================================
-- Check if Player is Dead
-- ================================
function Framework.Server.IsPlayerDead(src)
    if not Framework.Server.PlayerExists(src) then return false end

    local player = Framework.Server.GetPlayer(src)
    if player then
        if Framework.Name == 'qbox' or Framework.Name == 'qbcore' then
            local metadata = player.PlayerData and player.PlayerData.metadata
            if metadata then
                return metadata.isdead or metadata.inlaststand
            end
        elseif Framework.Name == 'esx' then
            return player.dead or false
        end
    end

    return false
end

-- ================================
-- Escort Event (SAFE HANDLER)
-- ================================
RegisterNetEvent('idtg-escort:server:start', function(target)
    local src = source

    -- HARD validation before anything else
    if src == nil or type(src) ~= 'number' then return end
    if target == nil or type(target) ~= 'number' then return end

    if not Framework.Server.PlayerExists(src) then return end
    if not Framework.Server.PlayerExists(target) then return end

    -- Escort logic goes here
    -- Example:
    -- TriggerClientEvent('idtg-escort:client:start', target, src)
end)

-- ================================
-- Logging Helper
-- ================================
function Framework.Server.Log(message, logType)
    logType = logType or 'info'
    print(('[ESCORT %s] %s'):format(string.upper(logType), tostring(message)))
end
