Framework = {}
Framework.Name = nil

-- Detect Framework
function Framework.Detect()
    if Config.Framework ~= 'auto' then
        Framework.Name = Config.Framework
        return Config.Framework
    end
    
    -- Auto-detect framework
    if GetResourceState('qbx_core') == 'started' then
        Framework.Name = 'qbox'
    elseif GetResourceState('qb-core') == 'started' then
        Framework.Name = 'qbcore'
    elseif GetResourceState('es_extended') == 'started' then
        Framework.Name = 'esx'
    else
        Framework.Name = 'standalone'
    end
    
    return Framework.Name
end

-- Debug print function
function Framework.Debug(message)
    if Config.Debug then
        print('[ESCORT DEBUG] ' .. message)
    end
end
