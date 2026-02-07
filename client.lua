local isEscorting = false
local escortedPlayer = nil
local isBeingEscorted = false
local escortedBy = nil
local targetIsDead = false
local lastEscortTime = 0

-- Load animations
function LoadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(0)
    end
end

-- Toggle escort
function ToggleEscort()
    local currentTime = GetGameTimer()
    
    -- Check cooldown
    if currentTime - lastEscortTime < Config.EscortCooldown then
        Framework.Debug('Escort command on cooldown. Wait ' .. math.ceil((Config.EscortCooldown - (currentTime - lastEscortTime)) / 1000) .. ' seconds')
        return
    end
    
    Framework.Debug('Toggle escort called')
    Framework.Debug('Is Escorting: ' .. tostring(isEscorting))
    Framework.Debug('Is Being Escorted: ' .. tostring(isBeingEscorted))
    
    if not isEscorting and not isBeingEscorted then
        local closestPlayer, distance = Framework.Client.GetClosestPlayer(Config.MaxEscortDistance)
        Framework.Debug('Closest player: ' .. tostring(closestPlayer) .. ' at distance: ' .. tostring(distance))
        
        if closestPlayer ~= -1 and distance <= Config.MaxEscortDistance then
            -- Check if target is dead
            local targetDeadState = Framework.Client.IsPlayerDead(closestPlayer)
            
            -- Validate permissions based on config
            if (targetDeadState and not Config.AllowCarryDead) then
                Framework.Debug('Cannot carry dead players - disabled in config')
                return
            end
            
            if (not targetDeadState and not Config.AllowEscortAlive) then
                Framework.Debug('Cannot escort alive players - disabled in config')
                return
            end
            
            local targetServerId = GetPlayerServerId(closestPlayer)
            Framework.Debug('Requesting escort for server ID: ' .. tostring(targetServerId))
            TriggerServerEvent('escort:requestEscort', targetServerId)
            lastEscortTime = currentTime
        else
            Framework.Debug('No player nearby or too far')
        end
    elseif isEscorting then
        Framework.Debug('Stopping escort')
        TriggerServerEvent('escort:stopEscort', GetPlayerServerId(escortedPlayer))
        lastEscortTime = currentTime
    elseif isBeingEscorted then
        Framework.Debug('Being escorted, breaking free')
        TriggerServerEvent('escort:stopEscort', GetPlayerServerId(escortedBy))
        lastEscortTime = currentTime
    end
end

-- Register the keybind
RegisterCommand('escort', function()
    ToggleEscort()
end, false)

-- Register the key mapping
RegisterKeyMapping('escort', 'Toggle Escort Player', 'keyboard', Config.DefaultKey)

-- Target system integration for ox_target
if Config.UseTarget then
    Citizen.CreateThread(function()
        Wait(1000)
        
        if GetResourceState('ox_target') == 'started' then
            exports.ox_target:addGlobalPlayer({
                {
                    name = 'escort_player',
                    icon = 'fa-solid fa-user-group',
                    label = 'Escort/Release',
                    onSelect = function(data)
                        local targetId = NetworkGetPlayerIndexFromPed(data.entity)
                        if targetId ~= -1 then
                            local targetServerId = GetPlayerServerId(targetId)
                            
                            -- Check permissions based on player state
                            local targetDeadState = IsPedDeadOrDying(data.entity, true) or IsEntityDead(data.entity)
                            if (targetDeadState and not Config.AllowCarryDead) then
                                return
                            end
                            if (not targetDeadState and not Config.AllowEscortAlive) then
                                return
                            end
                            
                            local currentTime = GetGameTimer()
                            if currentTime - lastEscortTime < escortCooldown then
                                return
                            end
                            
                            if not isEscorting and not isBeingEscorted then
                                TriggerServerEvent('escort:requestEscort', targetServerId)
                                lastEscortTime = currentTime
                            elseif isEscorting then
                                TriggerServerEvent('escort:stopEscort', targetServerId)
                                lastEscortTime = currentTime
                            end
                        end
                    end,
                    distance = Config.MaxEscortDistance,
                    canInteract = function(entity, distance, coords, name)
                        return true
                    end
                }
            })
        end
    end)
end

-- Start escort
RegisterNetEvent('escort:start', function(targetId)
    print('[ESCORT CLIENT] ========== START ESCORT ==========')
    print('[ESCORT CLIENT] Received escort:start event')
    print('[ESCORT CLIENT] Target Server ID: ' .. tostring(targetId))
    
    local targetPlayer = GetPlayerFromServerId(targetId)
    print('[ESCORT CLIENT] Target Player Index: ' .. tostring(targetPlayer))
    print('[ESCORT CLIENT] Target Player Index Type: ' .. type(targetPlayer))
    
    if targetPlayer == -1 or targetPlayer == nil then 
        print('[ESCORT CLIENT] ERROR: Target player not found!')
        return 
    end
    
    local targetPed = GetPlayerPed(targetPlayer)
    print('[ESCORT CLIENT] Target Ped: ' .. tostring(targetPed))
    print('[ESCORT CLIENT] Target Ped Exists: ' .. tostring(DoesEntityExist(targetPed)))
    
    if not DoesEntityExist(targetPed) then
        print('[ESCORT CLIENT] ERROR: Target ped does not exist!')
        return
    end
    
    -- Check if target is dead
    targetIsDead = IsPedDeadOrDying(targetPed, true) or IsEntityDead(targetPed)
    print('[ESCORT CLIENT] Target is dead: ' .. tostring(targetIsDead))
    
    escortedPlayer = targetPlayer
    isEscorting = true
    print('[ESCORT CLIENT] Successfully started escorting')
    print('[ESCORT CLIENT] =====================================')
    
    Citizen.CreateThread(function()
        local attachAttempts = 0
        while isEscorting do
            Wait(0)
            
            local targetPed = GetPlayerPed(escortedPlayer)
            local myPed = PlayerPedId()
            
            if DoesEntityExist(targetPed) and DoesEntityExist(myPed) then
                attachAttempts = attachAttempts + 1
                
                -- Check if player is still dead
                local isNowDead = IsPedDeadOrDying(targetPed, true) or IsEntityDead(targetPed)
                
                if isNowDead then
                    -- CARRY DEAD PLAYER
                    if not IsEntityAttachedToEntity(targetPed, myPed) then
                        -- Make sure target ped is ragdolled
                        SetEntityAsNoLongerNeeded(targetPed)
                        SmashVehicleWindow(targetPed, 0)
                        SmashVehicleWindow(targetPed, 1)
                        
                        -- Set ped to ragdoll
                        SetPedToRagdoll(targetPed, 60000, 60000, false, false, false, false)
                        
                        -- Attach to shoulder
                        AttachEntityToEntity(targetPed, myPed, 11816, 0.5, 0.5, 0.0, 305.28, 161.04, 0.0, false, false, false, false, 2, true)
                        
                        if attachAttempts % 50 == 1 then
                            Wait(100) -- Small delay to let attachment register
                            if IsEntityAttachedToEntity(targetPed, myPed) then
                                print('[ESCORT CLIENT] SUCCESS: Dead entity is now attached!')
                            else
                                print('[ESCORT CLIENT] WARNING: Dead entity attachment failed')
                            end
                        end
                    end
                else
                    -- ESCORT LIVING PLAYER
                    if not IsEntityAttachedToEntity(targetPed, myPed) then
                        if attachAttempts % 50 == 1 then
                            print('[ESCORT CLIENT] Attempting to attach living entities')
                        end
                        
                        -- Attach the target to the player
                        AttachEntityToEntity(targetPed, myPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                        
                        if attachAttempts % 50 == 1 then
                            Wait(100)
                            if IsEntityAttachedToEntity(targetPed, myPed) then
                                print('[ESCORT CLIENT] SUCCESS: Living entity is now attached!')
                            else
                                print('[ESCORT CLIENT] WARNING: Living entity attachment failed')
                            end
                        end
                    end
                end
            else
                -- Entity doesn't exist, stop escorting
                print('[ESCORT CLIENT] Entity no longer exists, stopping escort')
                print('[ESCORT CLIENT] Target Ped Exists: ' .. tostring(DoesEntityExist(targetPed)))
                print('[ESCORT CLIENT] My Ped Exists: ' .. tostring(DoesEntityExist(myPed)))
                TriggerServerEvent('escort:stopEscort', GetPlayerServerId(escortedPlayer))
                break
            end
        end
        print('[ESCORT CLIENT] Escort thread ended')
    end)
end)

-- Being escorted
RegisterNetEvent('escort:beingEscorted', function(escorterId)
    Framework.Debug('Received beingEscorted event from escorter ID: ' .. tostring(escorterId))
    
    local escorterPlayer = GetPlayerFromServerId(escorterId)
    Framework.Debug('Escorter player index: ' .. tostring(escorterPlayer))
    
    if escorterPlayer == -1 then 
        Framework.Debug('Escorter player not found!')
        return 
    end
    
    escortedBy = escorterPlayer
    isBeingEscorted = true
    Framework.Debug('Now being escorted')
    
    -- If you're dead, enable ragdoll
    local myPed = PlayerPedId()
    if IsPedDeadOrDying(myPed, true) or IsEntityDead(myPed) then
        SetPedToRagdoll(myPed, 60000, 60000, false, false, false, false)
    end
end)

-- Stop escort
RegisterNetEvent('escort:stop', function()
    Framework.Debug('Received stop event')
    
    if isEscorting then
        Framework.Debug('Stopping escort (was escorting)')
        local targetPed = GetPlayerPed(escortedPlayer)
        if DoesEntityExist(targetPed) then
            DetachEntity(targetPed, true, false)
            
            -- If they were dead, stop ragdoll
            if targetIsDead then
                StopPedRagdoll(targetPed)
            end
            
            ClearPedTasksImmediately(targetPed)
        end
        isEscorting = false
        escortedPlayer = nil
        targetIsDead = false
    end
    
    if isBeingEscorted then
        Framework.Debug('Stopping escort (was being escorted)')
        local myPed = PlayerPedId()
        if DoesEntityExist(myPed) then
            DetachEntity(myPed, true, false)
            StopPedRagdoll(myPed)
            ClearPedTasksImmediately(myPed)
        end
        isBeingEscorted = false
        escortedBy = nil
    end
end)

-- Chat suggestion
TriggerEvent('chat:addSuggestion', '/escort', 'Toggle escorting nearby player')

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
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
    end
end)

-- Debug command
RegisterCommand('escortdebug', function()
    print("=== ESCORT DEBUG ===")
    print("Framework: " .. tostring(Framework.Name))
    print("Is Escorting: " .. tostring(isEscorting))
    print("Escorted Player: " .. tostring(escortedPlayer))
    print("Is Being Escorted: " .. tostring(isBeingEscorted))
    print("Escorted By: " .. tostring(escortedBy))
    print("")
    
    if isEscorting and escortedPlayer then
        print("--- CURRENT ESCORT INFO ---")
        local targetPed = GetPlayerPed(escortedPlayer)
        local myPed = PlayerPedId()
        print("Target Ped: " .. tostring(targetPed))
        print("Target Ped Exists: " .. tostring(DoesEntityExist(targetPed)))
        print("My Ped: " .. tostring(myPed))
        print("My Ped Exists: " .. tostring(DoesEntityExist(myPed)))
        print("Is Attached: " .. tostring(IsEntityAttachedToEntity(targetPed, myPed)))
        print("")
    end
    
    print("--- Nearby Player Info ---")
    
    local closestPlayer, distance = Framework.Client.GetClosestPlayer(Config.MaxEscortDistance)
    print("Closest Player Index: " .. tostring(closestPlayer))
    print("Distance: " .. tostring(distance))
    print("Max Distance: " .. tostring(Config.MaxEscortDistance))
    
    if closestPlayer ~= -1 then
        local serverId = GetPlayerServerId(closestPlayer)
        local playerPed = GetPlayerPed(closestPlayer)
        print("Closest Player Server ID: " .. tostring(serverId))
        print("Closest Player Ped: " .. tostring(playerPed))
        print("Closest Player Ped Exists: " .. tostring(DoesEntityExist(playerPed)))
        print("Closest Player Name: " .. tostring(GetPlayerName(closestPlayer)))
        
        -- Try to test if we can get the ped from server id
        local testPlayer = GetPlayerFromServerId(serverId)
        print("GetPlayerFromServerId Result: " .. tostring(testPlayer))
        if testPlayer ~= -1 then
            local testPed = GetPlayerPed(testPlayer)
            print("Test Ped: " .. tostring(testPed))
            print("Test Ped Exists: " .. tostring(DoesEntityExist(testPed)))
        end
    else
        print("No player nearby within max distance")
    end
    
    print("")
    print("--- My Player Info ---")
    local myPed = PlayerPedId()
    local myServerId = GetPlayerServerId(PlayerId())
    local myCoords = GetEntityCoords(myPed)
    print("My Server ID: " .. tostring(myServerId))
    print("My Ped: " .. tostring(myPed))
    print("My Coords: " .. tostring(myCoords))
    
    print("===================")
end, false)
