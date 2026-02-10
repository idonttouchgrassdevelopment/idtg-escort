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



local function isVehicleEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    if type(IsEntityAVehicle) == 'function' then
        return IsEntityAVehicle(entity)
    end

    if type(GetEntityType) == 'function' then
        return GetEntityType(entity) == 2
    end

    if type(GetVehicleClass) == 'function' then
        local ok = pcall(GetVehicleClass, entity)
        return ok
    end

    return false
end

local function isNearVehicle(src, vehicleNetId)
    if not vehicleNetId then
        return false
    end

    local srcPed = GetPlayerPed(src)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if srcPed == 0 or not isVehicleEntity(vehicle) then
        return false
    end

    local srcCoords = GetEntityCoords(srcPed)
    local vehicleCoords = GetEntityCoords(vehicle)
    return #(srcCoords - vehicleCoords) <= ((Config.VehicleSearchRadius or 5.0) + 1.0)
end

local function isPedInVehicle(ped)
    if not ped or ped == 0 then
        return false
    end

    return IsPedInAnyVehicle(ped, false)
end

local function notifyPlayer(playerId, message, messageType)
    TriggerClientEvent('escort:notify', playerId, message, messageType or 'inform', Config.NotifyDuration or 5000)
end


local function stopEscortPair(escorter, target)
    if not escorter or not target then
        return false
    end

    escortStates[escorter] = nil
    stampCooldown(escorter)
    stampCooldown(target)

    if Framework.Server.PlayerExists(escorter) then
        TriggerClientEvent('escort:stop', escorter)
    end
    if Framework.Server.PlayerExists(target) then
        TriggerClientEvent('escort:stop', target)
    end

    local srcName = Framework.Server.GetPlayerName(escorter)
    Framework.Server.Log(('%s (ID: %s) stopped escort'):format(srcName, escorter), 'info')
    return true
end

local function handleRequest(src, targetId, mode)
    mode = mode == 'carry' and 'carry' or 'escort'

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

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if isPedInVehicle(srcPed) or isPedInVehicle(targetPed) then
        notifyPlayer(src, 'You cannot escort while either player is inside a vehicle', 'error')
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

    TriggerClientEvent('escort:start', src, targetId, mode)
    TriggerClientEvent('escort:beingEscorted', targetId, src, mode)

    notifyPlayer(src, ('You started %s on ID %s'):format(mode, targetId), 'success')
    notifyPlayer(targetId, ('You are being %sed by ID %s'):format(mode, src), 'inform')

    local srcName = Framework.Server.GetPlayerName(src)
    local targetName = Framework.Server.GetPlayerName(targetId)
    Framework.Server.Log(('%s (ID: %s) started %s on %s (ID: %s)'):format(srcName, src, mode, targetName, targetId), 'info')
end

local function handleStop(src)
    local escorter = src
    local target = escortStates[escorter]

    if not escorter or not target then
        -- Ignore stale/automatic stop requests from non-escorters to avoid
        -- notification spam during normal gameplay state transitions.
        return
    end

    if stopEscortPair(escorter, target) then
        if Framework.Server.PlayerExists(src) then
            notifyPlayer(src, 'Escort stopped', 'success')
        end
    end
end

local function handleSystemStop(src)
    local escorter = src
    local target = escortStates[escorter]

    if not target then
        escorter = getEscorterForTarget(src)
        target = escorter and escortStates[escorter] or nil
    end

    if not escorter or not target then
        return
    end

    stopEscortPair(escorter, target)
end

local function handleVehicleAction(src, targetId, action, vehicleNetId)
    if not Config.AllowVehicleEscort then
        notifyPlayer(src, 'Vehicle escort actions are disabled', 'error')
        return
    end

    action = action == 'takeout' and 'takeout' or 'putin'

    if not targetId or targetId == src then
        return
    end

    if not Framework.Server.PlayerExists(src) or not Framework.Server.PlayerExists(targetId) then
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if targetPed == 0 then
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

    local targetNearby = areNearby(src, targetId)
    local vehicleNearby = isNearVehicle(src, vehicleNetId)
    if not targetNearby and not vehicleNearby then
        notifyPlayer(src, 'Target is too far away', 'error')
        return
    end

    if action == 'putin' and isPedInVehicle(targetPed) then
        notifyPlayer(src, 'Target is already in a vehicle', 'error')
        return
    end

    if action == 'takeout' and not isPedInVehicle(targetPed) then
        notifyPlayer(src, 'Target is not in a vehicle', 'error')
        return
    end

    TriggerClientEvent('escort:vehicle', targetId, action, vehicleNetId)
    TriggerClientEvent('escort:vehicleAnimation', src, action)
    stampCooldown(src)

    if action == 'putin' then
        notifyPlayer(src, 'Attempting to place target in vehicle', 'success')
        notifyPlayer(targetId, 'You are being put in a vehicle', 'inform')
    else
        notifyPlayer(src, 'Attempting to remove target from vehicle', 'success')
        notifyPlayer(targetId, 'You are being taken out of a vehicle', 'inform')
    end
end

local function isVehicleUnlocked(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    return lockStatus == 0 or lockStatus == 1
end

local function handleDirectTakeout(src, targetId, vehicleNetId)
    if not targetId or targetId == src then
        return
    end

    if not Framework.Server.PlayerExists(src) or not Framework.Server.PlayerExists(targetId) then
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if targetPed == 0 then
        return
    end

    if isOnCooldown(src) then
        notifyPlayer(src, 'Action is on cooldown', 'error')
        return
    end

    if not areNearby(src, targetId) and not isNearVehicle(src, vehicleNetId) then
        notifyPlayer(src, 'Target is too far away', 'error')
        return
    end

    if not isPedInVehicle(targetPed) then
        notifyPlayer(src, 'Target is not in a vehicle', 'error')
        return
    end

    TriggerClientEvent('escort:vehicle', targetId, 'takeout', vehicleNetId)
    TriggerClientEvent('escort:vehicleAnimation', src, 'takeout')
    stampCooldown(src)

    notifyPlayer(src, 'Attempting to remove target from vehicle', 'success')
    notifyPlayer(targetId, 'You are being taken out of a vehicle', 'inform')
end

local function handleTrunkAction(src, targetId, action, vehicleNetId)
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

    local vehicle = vehicleNetId and NetworkGetEntityFromNetworkId(vehicleNetId) or 0
    if not isVehicleEntity(vehicle) then
        notifyPlayer(src, 'Invalid vehicle selected', 'error')
        return
    end

    if not isVehicleUnlocked(vehicle) then
        notifyPlayer(src, 'Vehicle must be unlocked', 'error')
        return
    end

    if not areNearby(src, targetId) and not isNearVehicle(src, vehicleNetId) then
        notifyPlayer(src, 'Target is too far away', 'error')
        return
    end

    TriggerClientEvent('escort:trunk', targetId, action, vehicleNetId)
    TriggerClientEvent('escort:vehicleAnimation', src, action == 'putin' and 'putin' or 'takeout')
    stampCooldown(src)

    if action == 'putin' then
        notifyPlayer(src, 'Attempting to place target in trunk', 'success')
        notifyPlayer(targetId, 'You are being placed in a trunk', 'inform')
    else
        notifyPlayer(src, 'Attempting to remove target from trunk', 'success')
        notifyPlayer(targetId, 'You are being removed from a trunk', 'inform')
    end
end

RegisterNetEvent('escort:requestAction', function(targetId, mode)
    handleRequest(source, targetId, mode)
end)

RegisterNetEvent('escort:stopAction', function()
    handleStop(source)
end)

RegisterNetEvent('escort:systemStop', function()
    handleSystemStop(source)
end)

RegisterNetEvent('escort:vehicleAction', function(targetId, action, vehicleNetId)
    handleVehicleAction(source, targetId, action, vehicleNetId)
end)

RegisterNetEvent('escort:directTakeout', function(targetId, vehicleNetId)
    handleDirectTakeout(source, targetId, vehicleNetId)
end)

RegisterNetEvent('escort:trunkAction', function(targetId, action, vehicleNetId)
    handleTrunkAction(source, targetId, action, vehicleNetId)
end)

-- Backwards compatibility with older clients
RegisterNetEvent('escort:requestEscort', function(targetId)
    handleRequest(source, targetId, 'escort')
end)

RegisterNetEvent('escort:stopEscort', function()
    handleSystemStop(source)
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
