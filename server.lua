-- Cooldown tracking: {playerId = {lastTime = timestamp}}
local escortCooldowns = {}
local escortStates = {} -- Track who is escorting whom

RegisterNetEvent('escort:requestEscort', function(targetId)
    local src = source
    
    Framework.Debug('Request received from source: ' .. tostring(src) .. ' for target: ' .. tostring(targetId))
    
    -- Validation using bridge
    if not targetId or targetId == src then
        Framework.Debug('Invalid target ID (same as source or nil)')
        return
    end
    
    -- Check if both players exist using bridge
    if not Framework.Server.PlayerExists(src) then
        Framework.Debug('Source player does not exist or is offline')
        return
    end
    
    if not Framework.Server.PlayerExists(targetId) then
        Framework.Debug('Target player does not exist or is offline')
        return
    end
    
    -- Check cooldown
    if escortCooldowns[src] and (GetGameTimer() - escortCooldowns[src]) < Config.EscortCooldown then
        Framework.Debug('Source player is on cooldown')
        return
    end
    
    -- Prevent escorting while already escorting
    if escortStates[src] then
        Framework.Debug('Source player is already escorting someone')
        return
    end
    
    -- Prevent escorting someone who is currently being escorted
    if escortStates[targetId] then
        Framework.Debug('Target is already being escorted')
        return
    end
    
    -- Prevent being escorted while escorting
    for playerId, targetPlayer in pairs(escortStates) do
        if targetPlayer == src then
            Framework.Debug('Source player is currently being escorted')
            return
        end
    end
    
    -- Set cooldown
    escortCooldowns[src] = GetGameTimer()
    
    -- Track the escort state
    escortStates[src] = targetId
    
    -- Trigger escort for both players
    Framework.Debug('Triggering escort:start for source: ' .. tostring(src))
    TriggerClientEvent('escort:start', src, targetId)
    
    Framework.Debug('Triggering escort:beingEscorted for target: ' .. tostring(targetId))
    TriggerClientEvent('escort:beingEscorted', targetId, src)
    
    -- Log the action using bridge
    local srcName = Framework.Server.GetPlayerName(src)
    local targetName = Framework.Server.GetPlayerName(targetId)
    Framework.Server.Log(string.format('%s (ID: %s) is escorting %s (ID: %s)', srcName, src, targetName, targetId), 'info')
end)

RegisterNetEvent('escort:stopEscort', function(targetId)
    local src = source
    
    Framework.Debug('Stop request from source: ' .. tostring(src))
    
    -- Verify this player is actually escorting the target
    if not escortStates[src] or escortStates[src] ~= targetId then
        Framework.Debug('Player is not escorting this target')
        return
    end
    
    -- Set cooldown
    escortCooldowns[src] = GetGameTimer()
    
    -- Clear escort state
    escortStates[src] = nil
    
    -- Stop escort for both players
    TriggerClientEvent('escort:stop', src)
    
    if targetId and Framework.Server.PlayerExists(targetId) then
        Framework.Debug('Stopping escort for target: ' .. tostring(targetId))
        TriggerClientEvent('escort:stop', targetId)
    end
    
    -- Log the action using bridge
    local srcName = Framework.Server.GetPlayerName(src)
    Framework.Server.Log(string.format('%s (ID: %s) stopped escorting', srcName, src), 'info')
end)

-- Clean up escort states when player leaves
AddEventHandler('playerDropped', function(reason)
    local src = source
    escortCooldowns[src] = nil
    
    -- If they were escorting someone, stop that too
    if escortStates[src] then
        local targetId = escortStates[src]
        escortStates[src] = nil
        if Framework.Server.PlayerExists(targetId) then
            TriggerClientEvent('escort:stop', targetId)
        end
    end
    
    -- If they were being escorted, stop that
    for playerId, targetPlayer in pairs(escortStates) do
        if targetPlayer == src then
            escortStates[playerId] = nil
            if Framework.Server.PlayerExists(playerId) then
                TriggerClientEvent('escort:stop', playerId)
            end
        end
    end
end)
