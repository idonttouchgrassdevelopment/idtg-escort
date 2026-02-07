local isEscorting = false
local escortedPlayer = nil
local isBeingEscorted = false
local escortedBy = nil
local targetIsDead = false
local lastActionTime = 0

local function getCooldownMs()
    return Config.ActionCooldown or Config.EscortCooldown or 5000
end

local function onCooldown()
    local currentTime = GetGameTimer()
    local remaining = getCooldownMs() - (currentTime - lastActionTime)

    if remaining > 0 then
        Framework.Debug(('Action on cooldown. Wait %s seconds'):format(math.ceil(remaining / 1000)))
        return true
    end

    return false
end

local function stampCooldown()
    lastActionTime = GetGameTimer()
end

local function getTargetByMode(mode)
    local closestPlayer, distance = Framework.Client.GetClosestPlayer(Config.MaxEscortDistance)
    if closestPlayer == -1 or distance > Config.MaxEscortDistance then
        Framework.Debug('No nearby player in range')
        return nil
    end

    local isDead = Framework.Client.IsPlayerDead(closestPlayer)
    if mode == 'carry' and not isDead then
        Framework.Debug('Carry requires a dead player target')
        return nil
    end

    if mode == 'escort' and isDead then
        Framework.Debug('Escort requires a living player target')
        return nil
    end

    return closestPlayer, isDead
end

local function requestStart(mode)
    if isEscorting or isBeingEscorted then
        return
    end

    if onCooldown() then
        return
    end

    local targetPlayer, isDead = getTargetByMode(mode)
    if not targetPlayer then
        return
    end

    if isDead and not Config.AllowCarryDead then
        Framework.Debug('Carrying dead players is disabled')
        return
    end

    if not isDead and not Config.AllowEscortAlive then
        Framework.Debug('Escorting alive players is disabled')
        return
    end

    local targetServerId = GetPlayerServerId(targetPlayer)
    TriggerServerEvent('escort:requestAction', targetServerId, mode)
    stampCooldown()
end

local function requestStop()
    if onCooldown() then
        return
    end

    if isEscorting and escortedPlayer then
        TriggerServerEvent('escort:stopAction', GetPlayerServerId(escortedPlayer))
        stampCooldown()
        return
    end

    if isBeingEscorted and escortedBy then
        TriggerServerEvent('escort:stopAction', GetPlayerServerId(escortedBy))
        stampCooldown()
    end
end

local function toggleMode(mode)
    if isEscorting or isBeingEscorted then
        requestStop()
    else
        requestStart(mode)
    end
end

RegisterCommand('escort', function()
    toggleMode('escort')
end, false)

RegisterCommand('carry', function()
    toggleMode('carry')
end, false)

RegisterKeyMapping('escort', 'Toggle Escort Player (alive target)', 'keyboard', Config.DefaultEscortKey or Config.DefaultKey or 'H')
RegisterKeyMapping('carry', 'Toggle Carry Player (dead target)', 'keyboard', Config.DefaultCarryKey or 'G')

if Config.UseTarget then
    CreateThread(function()
        Wait(1000)

        if GetResourceState('ox_target') == 'started' then
            exports.ox_target:addGlobalPlayer({
                {
                    name = 'escort_player',
                    icon = 'fa-solid fa-user-group',
                    label = 'Escort/Release',
                    distance = Config.MaxEscortDistance,
                    onSelect = function(data)
                        local targetId = NetworkGetPlayerIndexFromPed(data.entity)
                        if targetId == -1 then
                            return
                        end

                        local targetServerId = GetPlayerServerId(targetId)

                        if isEscorting then
                            if onCooldown() then
                                return
                            end
                            TriggerServerEvent('escort:stopAction', targetServerId)
                            stampCooldown()
                            return
                        end

                        if isBeingEscorted or onCooldown() then
                            return
                        end

                        local targetDeadState = IsPedDeadOrDying(data.entity, true) or IsEntityDead(data.entity)
                        if targetDeadState and not Config.AllowCarryDead then
                            return
                        end
                        if (not targetDeadState) and not Config.AllowEscortAlive then
                            return
                        end

                        local mode = targetDeadState and 'carry' or 'escort'
                        TriggerServerEvent('escort:requestAction', targetServerId, mode)
                        stampCooldown()
                    end,
                    canInteract = function()
                        return true
                    end
                }
            })
        end
    end)
end

RegisterNetEvent('escort:start', function(targetId)
    local targetPlayer = GetPlayerFromServerId(targetId)
    if targetPlayer == -1 or targetPlayer == nil then
        return
    end

    local targetPed = GetPlayerPed(targetPlayer)
    if not DoesEntityExist(targetPed) then
        return
    end

    targetIsDead = IsPedDeadOrDying(targetPed, true) or IsEntityDead(targetPed)
    escortedPlayer = targetPlayer
    isEscorting = true

    CreateThread(function()
        while isEscorting do
            Wait(500)

            local myPed = PlayerPedId()
            local ped = GetPlayerPed(escortedPlayer)
            if not DoesEntityExist(myPed) or not DoesEntityExist(ped) then
                if escortedPlayer then
                    TriggerServerEvent('escort:stopAction', GetPlayerServerId(escortedPlayer))
                end
                break
            end
        end
    end)
end)

RegisterNetEvent('escort:beingEscorted', function(escorterId)
    local escorterPlayer = GetPlayerFromServerId(escorterId)
    if escorterPlayer == -1 then
        return
    end

    escortedBy = escorterPlayer
    isBeingEscorted = true

    local myPed = PlayerPedId()
    if IsPedDeadOrDying(myPed, true) or IsEntityDead(myPed) then
        SetPedToRagdoll(myPed, Config.RagdollDuration or 60000, Config.RagdollDuration or 60000, false, false, false, false)
    end

    CreateThread(function()
        while isBeingEscorted do
            Wait(0)

            local escorterPed = GetPlayerPed(escortedBy)
            local me = PlayerPedId()

            if not DoesEntityExist(escorterPed) or not DoesEntityExist(me) then
                TriggerServerEvent('escort:stopAction')
                break
            end

            if not IsEntityAttachedToEntity(me, escorterPed) then
                local dead = IsPedDeadOrDying(me, true) or IsEntityDead(me)
                if dead then
                    SetPedToRagdoll(me, Config.RagdollDuration or 60000, Config.RagdollDuration or 60000, false, false, false, false)

                    if Config.CarryOnShoulder then
                        AttachEntityToEntity(me, escorterPed, 11816, 0.5, 0.5, 0.0, 305.28, 161.04, 0.0, false, false, false, false, 2, true)
                    else
                        AttachEntityToEntity(me, escorterPed, 11816, 0.30, 0.30, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                    end
                else
                    AttachEntityToEntity(me, escorterPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                end
            end
        end
    end)
end)

RegisterNetEvent('escort:stop', function()
    if isEscorting and escortedPlayer then
        local targetPed = GetPlayerPed(escortedPlayer)
        if DoesEntityExist(targetPed) then
            DetachEntity(targetPed, true, false)
            if targetIsDead then
                StopPedRagdoll(targetPed)
            end
            ClearPedTasksImmediately(targetPed)
        end
    end

    if isBeingEscorted then
        local myPed = PlayerPedId()
        if DoesEntityExist(myPed) then
            DetachEntity(myPed, true, false)
            StopPedRagdoll(myPed)
            ClearPedTasksImmediately(myPed)
        end
    end

    isEscorting = false
    escortedPlayer = nil
    isBeingEscorted = false
    escortedBy = nil
    targetIsDead = false
end)

TriggerEvent('chat:addSuggestion', '/escort', 'Escort or release a nearby living player')
TriggerEvent('chat:addSuggestion', '/carry', 'Carry or release a nearby dead player')

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    if isEscorting and escortedPlayer then
        local targetPed = GetPlayerPed(escortedPlayer)
        if DoesEntityExist(targetPed) then
            DetachEntity(targetPed, true, false)
            if targetIsDead then
                StopPedRagdoll(targetPed)
            end
            ClearPedTasksImmediately(targetPed)
        end
    end

    if isBeingEscorted then
        local myPed = PlayerPedId()
        if DoesEntityExist(myPed) then
            DetachEntity(myPed, true, false)
            StopPedRagdoll(myPed)
            ClearPedTasksImmediately(myPed)
        end
    end
end)

RegisterCommand('escortdebug', function()
    print('=== ESCORT DEBUG ===')
    print('Is Escorting: ' .. tostring(isEscorting))
    print('Escorted Player: ' .. tostring(escortedPlayer))
    print('Is Being Escorted: ' .. tostring(isBeingEscorted))
    print('Escorted By: ' .. tostring(escortedBy))
    print('Last Action Time: ' .. tostring(lastActionTime))

    local closestPlayer, distance = Framework.Client.GetClosestPlayer(Config.MaxEscortDistance)
    print('Closest Player Index: ' .. tostring(closestPlayer))
    print('Distance: ' .. tostring(distance))
    print('===================')
end, false)
