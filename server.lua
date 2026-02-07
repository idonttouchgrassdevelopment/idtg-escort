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

local function handleRequest(src, targetId, mode)
    mode = mode == 'carry' and 'carry' or 'escort'

    if not targetId or targetId == src then
        return
    end

    if not Framework.Server.PlayerExists(src) or not Framework.Server.PlayerExists(targetId) then
        return
    end

    if isOnCooldown(src) or isOnCooldown(targetId) then
        Framework.Debug(('Cooldown blocked action between %s and %s'):format(src, targetId))
        return
    end

    if escortStates[src] then
        return
    end

    if escortStates[targetId] or getEscorterForTarget(src) or getEscorterForTarget(targetId) then
        return
    end

    escortStates[src] = targetId
    stampCooldown(src)
    stampCooldown(targetId)

    TriggerClientEvent('escort:start', src, targetId)
    TriggerClientEvent('escort:beingEscorted', targetId, src)

    local srcName = Framework.Server.GetPlayerName(src)
    local targetName = Framework.Server.GetPlayerName(targetId)
    Framework.Server.Log(('%s (ID: %s) started %s on %s (ID: %s)'):format(srcName, src, mode, targetName, targetId), 'info')
end

local function handleStop(src, targetId)

    local expectedTarget = escortStates[src]
    if expectedTarget and (not targetId or targetId == expectedTarget) then
        targetId = expectedTarget
    else
        local escorter = getEscorterForTarget(src)
        if escorter then
            targetId = src
            src = escorter
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

    local srcName = Framework.Server.GetPlayerName(src)
    Framework.Server.Log(('%s (ID: %s) stopped escort/carry'):format(srcName, src), 'info')
end

RegisterNetEvent('escort:requestAction', function(targetId, mode)
    handleRequest(source, targetId, mode)
end)

RegisterNetEvent('escort:stopAction', function(targetId)
    handleStop(source, targetId)
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
