Framework.Client = {}

-- Initialize framework on client
Citizen.CreateThread(function()
    local detected = Framework.Detect()
    Framework.Debug('Framework detected: ' .. detected)
    
    if detected == 'qbox' then
        Framework.Client.Core = exports.qbx_core
    elseif detected == 'qbcore' then
        Framework.Client.Core = exports['qb-core']:GetCoreObject()
    elseif detected == 'esx' then
        Framework.Client.Core = exports['es_extended']:getSharedObject()
    end
end)

-- Get player data
function Framework.Client.GetPlayerData()
    if Framework.Name == 'qbox' then
        return Framework.Client.Core:GetPlayerData()
    elseif Framework.Name == 'qbcore' then
        return Framework.Client.Core.Functions.GetPlayerData()
    elseif Framework.Name == 'esx' then
        return Framework.Client.Core.GetPlayerData()
    end
    return nil
end

-- Check if player is dead
function Framework.Client.IsDead()
    local playerPed = PlayerPedId()
    
    if Framework.Name == 'qbox' or Framework.Name == 'qbcore' then
        local playerData = Framework.Client.GetPlayerData()
        if playerData and playerData.metadata then
            return playerData.metadata.isdead or playerData.metadata.inlaststand
        end
    elseif Framework.Name == 'esx' then
        local playerData = Framework.Client.GetPlayerData()
        if playerData then
            return playerData.dead
        end
    end
    
    -- Fallback to native check
    return IsEntityDead(playerPed) or IsPedDeadOrDying(playerPed, true)
end

-- Check if specific player is dead
function Framework.Client.IsPlayerDead(player)
    if player == nil or player == -1 then
        return Framework.Client.IsDead()
    end
    
    local targetPed = GetPlayerPed(player)
    if not DoesEntityExist(targetPed) then
        return false
    end
    
    return IsEntityDead(targetPed) or IsPedDeadOrDying(targetPed, true)
end

-- Get closest player (improved version)
function Framework.Client.GetClosestPlayer(maxDistance)
    local players = GetActivePlayers()
    local closestDistance = maxDistance or -1
    local closestPlayer = -1
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)

    for i = 1, #players do
        local targetPed = GetPlayerPed(players[i])
        if targetPed ~= myPed and DoesEntityExist(targetPed) then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(myCoords - targetCoords)
            
            if closestDistance == -1 or distance < closestDistance then
                closestPlayer = players[i]
                closestDistance = distance
            end
        end
    end

    return closestPlayer, closestDistance
end

-- Notification function (optional, returns false if no notification shown)
function Framework.Client.Notify(message, type, duration)
    -- This is intentionally left empty as per user request
    -- Can be enabled later if needed
    return false
end
