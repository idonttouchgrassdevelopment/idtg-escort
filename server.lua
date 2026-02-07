local escortCooldowns = {}
local escortStates = {} -- [escorter] = target

local function getCooldownMs()
    return Config.ActionCooldown or Config.EscortCooldown or 5000
end

local function isOnCooldown(playerId)
    local lastTime = escortCooldowns[playerId]
    if not lastTime then
        return false
    end

    return (GetGameTimer() - lastTime) < getCooldownMs()
end

local function stampCooldown(playerId)
    escortCooldowns[playerId] = GetGameTimer()
end

local function getEscorterForTarget(targetId)
    for escorter, target in pairs(escortStates) do
        if target == targetId then
            return escorter
        end
    end

    return nil
end

local function areNearby(src, targetId)
    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if srcPed == 0 or targetPed == 0 then
        return false
    end

    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)
    return #(srcCoords - targetCoords) <= (Config.MaxEscortDistance + 1.0)
end

local function notifyPlayer(playerId, message, messageType)
    TriggerClientEvent('escort:notify', playerId, message, messageType or 'inform', Config.NotifyDuration or 5000)
end

local function handleRequest(src, targetId)

    if not targetId or targetId == src then
        return
    end

    if not Framework.Server.PlayerExists(src) or not Framework.Server.PlayerExists(targetId) then
        return
    end

    if not areNearby(src, targetId) then
        notifyPlayer(src, 'Target is too far away', 'error')
        return
    end

    if isOnCooldown(src) or isOnCooldown(targetId) then
        Framework.Debug(('Cooldown blocked action between %s and %s'):format(src, targetId))
        notifyPlayer(src, 'Action is on cooldown', 'error')
        return
    end

    if escortStates[src] then
        notifyPlayer(src, 'You are already escorting someone', 'error')
        return
    end

    if escortStates[targetId] or getEscorterForTarget(src) or getEscorterForTarget(targetId) then
        notifyPlayer(src, 'Either you or the target is already busy', 'error')
        return
    end

    escortStates[src] = targetId
    stampCooldown(src)
    stampCooldown(targetId)

    TriggerClientEvent('escort:start', src, targetId)
    TriggerClientEvent('escort:beingEscorted', targetId, src)

    notifyPlayer(src, ('You started escort on ID %s'):format(targetId), 'success')
    notifyPlayer(targetId, ('You are being escorted by ID %s'):format(src), 'inform')

    local srcName = Framework.Server.GetPlayerName(src)
    local targetName = Framework.Server.GetPlayerName(targetId)
    Framework.Server.Log(('%s (ID: %s) started escort on %s (ID: %s)'):format(srcName, src, targetName, targetId), 'info')
end

local function handleStop(src, targetId)
    local originalSource = src

    local expectedTarget = escortStates[src]
    if expectedTarget and (not targetId or targetId == expectedTarget) then
        targetId = expectedTarget
    else
        local escorter = getEscorterForTarget(src)
        if escorter then
            targetId = src
            src = escorter
        elseif targetId then
            local reverseEscorter = getEscorterForTarget(targetId)
            if reverseEscorter and (reverseEscorter == src or targetId == src or targetId == escortStates[src]) then
                src = reverseEscorter
                targetId = escortStates[reverseEscorter]
            else
                return
            end
        else
            return
        end
    end

    escortStates[src] = nil
    stampCooldown(src)
    if targetId then
        stampCooldown(targetId)
    end

    TriggerClientEvent('escort:stop', src)
    if targetId and Framework.Server.PlayerExists(targetId) then
        TriggerClientEvent('escort:stop', targetId)
    end

    if Framework.Server.PlayerExists(originalSource) then
        notifyPlayer(originalSource, 'Escort stopped', 'success')
    end

    local srcName = Framework.Server.GetPlayerName(src)
    Framework.Server.Log(('%s (ID: %s) stopped escort'):format(srcName, src), 'info')
end

local function handleVehicleAction(src, targetId, action)
    action = action == 'takeout' and 'takeout' or 'putin'

    if not targetId or targetId == src then
        return
    end

    if not Framework.Server.PlayerExists(src) or not Framework.Server.PlayerExists(targetId) then
        return
    end

    if isOnCooldown(src) then
        notifyPlayer(src, 'Action is on cooldown', 'error')
        return
    end

    local expectedTarget = escortStates[src]
    local escorter = getEscorterForTarget(src)
    local isValidPair = (expectedTarget and expectedTarget == targetId) or (escorter and escorter == targetId)

    if not isValidPair then
        notifyPlayer(src, 'You must escort this player first', 'error')
        return
    end

    if not areNearby(src, targetId) then
        notifyPlayer(src, 'Target is too far away', 'error')
        return
    end

    TriggerClientEvent('escort:vehicle', targetId, action)
    stampCooldown(src)

    if action == 'putin' then
        notifyPlayer(src, 'Attempting to place target in vehicle', 'success')
        notifyPlayer(targetId, 'You are being put in a vehicle', 'inform')
    else
        notifyPlayer(src, 'Attempting to remove target from vehicle', 'success')
        notifyPlayer(targetId, 'You are being taken out of a vehicle', 'inform')
    end
end

RegisterNetEvent('escort:requestAction', function(targetId)
    handleRequest(source, targetId)
end)

RegisterNetEvent('escort:stopAction', function(targetId)
    handleStop(source, targetId)
end)

RegisterNetEvent('escort:vehicleAction', function(targetId, action)
    handleVehicleAction(source, targetId, action)
end)

-- Backwards compatibility with older clients
RegisterNetEvent('escort:requestEscort', function(targetId)
    handleRequest(source, targetId, 'escort')
end)

RegisterNetEvent('escort:stopEscort', function(targetId)
    handleStop(source, targetId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    escortCooldowns[src] = nil

    if escortStates[src] then
        local targetId = escortStates[src]
        escortStates[src] = nil

        if Framework.Server.PlayerExists(targetId) then
            TriggerClientEvent('escort:stop', targetId)
        end
    end

    for escorter, target in pairs(escortStates) do
        if target == src then
            escortStates[escorter] = nil
            if Framework.Server.PlayerExists(escorter) then
                TriggerClientEvent('escort:stop', escorter)
            end
            break
        end
    end
end)
