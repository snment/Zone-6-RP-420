local Framework = nil
local isRobbing = false
local lastRobTime = 0
local isHandsUp = false
local robberyCancelled = false

local function CheckESXExport()
    local resource = GetResourceMetadata('es_extended', 'export', 0)
    if resource and resource == 'getSharedObject' then
        return true
    end
    return false
end

local function InitializeFramework()
    if Config.Framework == 'qbcore' or Config.Framework == 'qb-core' then
        if GetResourceState('qb-core') == 'started' then
            Framework = exports['qb-core']:GetCoreObject()
            print('^2[FEARX-OXROB] QBCore Framework loaded (manual config)^0')
        else
            print('^1[FEARX-OXROB] QBCore not found but set in config^0')
        end
    elseif Config.Framework == 'qbx' or Config.Framework == 'qbx_core' then
        if GetResourceState('qbx_core') == 'started' then
            Framework = exports.qbx_core
            print('^2[FEARX-OXROB] QBX Framework loaded (manual config)^0')
        else
            print('^1[FEARX-OXROB] QBX not found but set in config^0')
        end
    elseif Config.Framework == 'esx' or Config.Framework == 'es_extended' then
        if GetResourceState('es_extended') == 'started' then
            if CheckESXExport() then
                Framework = exports['es_extended']:getSharedObject()
                print('^2[FEARX-OXROB] ESX Framework loaded (manual config - new version)^0')
            else
                local esxReceived = false
                TriggerEvent('esx:getSharedObject', function(obj) 
                    Framework = obj 
                    esxReceived = true
                end)
                local timeout = 0
                while not esxReceived and timeout < 30 do
                    Wait(100)
                    timeout = timeout + 1
                end
                if Framework then
                    print('^2[FEARX-OXROB] ESX Framework loaded (manual config - legacy version)^0')
                else
                    print('^1[FEARX-OXROB] ESX detected but failed to initialize^0')
                end
            end
        else
            print('^1[FEARX-OXROB] ESX not found but set in config^0')
        end
    elseif Config.Framework == 'standalone' or Config.Framework == 'none' then
        print('^3[FEARX-OXROB] Running in standalone mode (manual config)^0')
    elseif Config.Framework == 'auto' then
        if GetResourceState('qb-core') == 'started' then
            Framework = exports['qb-core']:GetCoreObject()
            print('^2[FEARX-OXROB] QBCore Framework detected (auto)^0')
        elseif GetResourceState('qbx_core') == 'started' then
            Framework = exports.qbx_core
            print('^2[FEARX-OXROB] QBX Framework detected (auto)^0')
        elseif GetResourceState('es_extended') == 'started' then
            if CheckESXExport() then
                Framework = exports['es_extended']:getSharedObject()
                print('^2[FEARX-OXROB] ESX Framework detected (auto - new version)^0')
            else
                local esxReceived = false
                TriggerEvent('esx:getSharedObject', function(obj) 
                    Framework = obj 
                    esxReceived = true
                end)
                local timeout = 0
                while not esxReceived and timeout < 30 do
                    Wait(100)
                    timeout = timeout + 1
                end
                if Framework then
                    print('^2[FEARX-OXROB] ESX Framework detected (auto - legacy version)^0')
                else
                    print('^1[FEARX-OXROB] ESX detected but failed to initialize^0')
                end
            end
        else
            print('^3[FEARX-OXROB] No framework detected, running in standalone mode^0')
        end
    else
        print('^1[FEARX-OXROB] Invalid framework setting in config: ' .. Config.Framework .. '^0')
        print('^3[FEARX-OXROB] Valid options: auto, qbcore, qbx, esx, standalone^0')
    end
end

local function IsPlayerHandsUp(playerId)
    local playerPed = GetPlayerPed(GetPlayerFromServerId(playerId))
    if not playerPed or playerPed == 0 then return false end
    
    return IsEntityPlayingAnim(playerPed, 'missminuteman_1ig_2', 'handsup_base', 3) or
           IsEntityPlayingAnim(playerPed, 'mp_arresting', 'idle', 3) or
           IsEntityPlayingAnim(playerPed, 'random@mugging3', 'handsup_standing_base', 3)
end

local function GetClosestPlayer()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local players = GetActivePlayers()
    local closestDistance = Config.RobDistance
    local closestPlayer = nil
    
    for i = 1, #players do
        local playerId = players[i]
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if targetPed and targetPed ~= 0 then
                local distance = #(playerCoords - GetEntityCoords(targetPed))
                if distance < closestDistance then
                    closestDistance = distance
                    closestPlayer = GetPlayerServerId(playerId)
                end
            end
        end
    end
    
    return closestPlayer
end

local function DoProgressBar(duration, label, animData)
    local success = false
    
    if Config.ProgressBar == 'ox_lib' then
        success = lib.progressBar({
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = true,
            disable = {car = true, move = true, combat = true},
            anim = {dict = animData.dict, clip = animData.anim, flag = animData.flag}
        })
    elseif Config.ProgressBar == 'mythic_progbar' then
        exports['mythic_progbar']:Progress({
            name = "robbery",
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = true,
            controlDisables = {disableMovement = true, disableCarMovement = true, disableCombat = true},
            animation = {animDict = animData.dict, anim = animData.anim, flags = animData.flag}
        }, function(cancelled) success = not cancelled end)
        
        local timeout = GetGameTimer() + duration + 500
        while exports['mythic_progbar']:isDoingSomething() and GetGameTimer() < timeout do
            Wait(50)
        end
    elseif Config.ProgressBar == 'qb-progressbar' then
        local finished = false
        exports['qb-progressbar']:Progress({
            name = "robbery",
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = true,
            controlDisables = {disableMovement = true, disableCarMovement = true, disableCombat = true},
            animation = {animDict = animData.dict, anim = animData.anim, flags = animData.flag}
        }, function(cancelled)
            finished = true
            success = not cancelled
        end)
        
        local timeout = GetGameTimer() + duration + 500
        while not finished and GetGameTimer() < timeout do
            Wait(50)
        end
    end
    
    return success
end

local function StartRobbery(targetId)
    local playerPed = PlayerPedId()
    local robTime = math.random(Config.RobTimer.min * 1000, Config.RobTimer.max * 1000)
    local animData = Config.Animations[math.random(1, #Config.Animations)]
    local startCoords = GetEntityCoords(playerPed)
    
    isRobbing = true
    robberyCancelled = false
    lastRobTime = GetGameTimer()
    
    lib.requestAnimDict(animData.dict)
    Wait(100)
    TaskPlayAnim(playerPed, animData.dict, animData.anim, 8.0, 8.0, -1, animData.flag, 0, false, false, false)
    
    TriggerServerEvent('fearx-oxrob:server:startRob', targetId)
    
    CreateThread(function()
        local targetPlayer = GetPlayerFromServerId(targetId)
        if not targetPlayer or targetPlayer == -1 then
            robberyCancelled = true
            return
        end
        
        local targetPed = GetPlayerPed(targetPlayer)
        local targetStartCoords = GetEntityCoords(targetPed)
        
        while isRobbing and not robberyCancelled do
            Wait(500)
            
            if not DoesEntityExist(targetPed) then
                robberyCancelled = true
                break
            end
            
            if #(targetStartCoords - GetEntityCoords(targetPed)) > 3.0 then
                lib.notify({description = 'Target moved too far away', type = 'error'})
                robberyCancelled = true
                break
            end
            
            if not IsPlayerHandsUp(targetId) then
                lib.notify({description = 'Target put hands down', type = 'error'})
                robberyCancelled = true
                break
            end
            
            if not IsEntityPlayingAnim(playerPed, animData.dict, animData.anim, 3) then
                TaskPlayAnim(playerPed, animData.dict, animData.anim, 8.0, 8.0, -1, animData.flag, 0, false, false, false)
            end
        end
        
        if robberyCancelled and isRobbing then
            lib.cancelProgress()
        end
    end)
    
    local success = DoProgressBar(robTime, Config.Locales['robbing_in_progress'], animData)
    
    StopAnimTask(playerPed, animData.dict, animData.anim, 1.0)
    isRobbing = false
    
    if robberyCancelled or not success then
        lib.notify({description = Config.Locales['rob_cancelled'], type = 'error'})
        TriggerServerEvent('fearx-oxrob:server:cancelRob', targetId)
        return
    end
    
    if #(startCoords - GetEntityCoords(playerPed)) > 3.0 then
        TriggerServerEvent('fearx-oxrob:server:anticheat', 'position_check')
        return
    end
    
    StopAnimTask(playerPed, animData.dict, animData.anim, 1.0)
    exports.ox_inventory:openNearbyInventory()
end

local function HandsUpCommand()
    local playerPed = PlayerPedId()
    
    if IsPedInAnyVehicle(playerPed, false) then
        lib.notify({description = 'Cannot put hands up while in a vehicle', type = 'error'})
        return
    end
    
    if isHandsUp then
        StopAnimTask(playerPed, 'missminuteman_1ig_2', 'handsup_base', 1.0)
        isHandsUp = false
        lib.notify({description = 'Hands down', type = 'inform'})
        TriggerServerEvent('fearx-oxrob:server:targetHandsDown', GetPlayerServerId(PlayerId()))
    else
        lib.requestAnimDict('missminuteman_1ig_2')
        TaskPlayAnim(playerPed, 'missminuteman_1ig_2', 'handsup_base', 8.0, 8.0, -1, 50, 0, false, false, false)
        isHandsUp = true
        lib.notify({description = 'Hands up', type = 'inform'})
    end
end

local function CustomStealCommand()
    if isRobbing then return end
    
    local currentTime = GetGameTimer()
    if currentTime - lastRobTime < (Config.AntiSpam * 1000) then
        lib.notify({description = Config.Locales['anti_cheat'], type = 'error'})
        return
    end
    
    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then
        lib.notify({description = Config.Locales['robber_in_vehicle'], type = 'error'})
        return
    end
    
    local targetId = GetClosestPlayer()
    if not targetId then
        lib.notify({description = Config.Locales['no_target'], type = 'error'})
        return
    end
    
    if targetId == GetPlayerServerId(PlayerId()) then
        lib.notify({description = Config.Locales['cant_rob_self'], type = 'error'})
        return
    end
    
    local targetPlayer = GetPlayerFromServerId(targetId)
    if targetPlayer and targetPlayer ~= -1 then
        local targetPed = GetPlayerPed(targetPlayer)
        if IsPedInAnyVehicle(targetPed, false) then
            lib.notify({description = Config.Locales['target_in_vehicle'], type = 'error'})
            return
        end
    end
    
    if Config.RequireHandsUp and not IsPlayerHandsUp(targetId) then
        lib.notify({description = Config.Locales['hands_not_up'], type = 'error'})
        return
    end
    
    StartRobbery(targetId)
end

CreateThread(function()
    InitializeFramework()
    
    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(100)
    end
    
    Wait(2000)
    
    RegisterCommand('steal', CustomStealCommand, false)
    RegisterCommand('handsup', HandsUpCommand, false)
    RegisterKeyMapping('steal', 'Steal from player', 'keyboard', 'f')
    RegisterKeyMapping('handsup', 'Toggle hands up', 'keyboard', 'x')
    
    TriggerEvent('chat:removeSuggestion', '/steal')
    TriggerEvent('chat:addSuggestion', '/steal', 'Rob a nearby player with hands up')
    
    print('^2[FEARX-OXROB] Successfully overrode ox_inventory steal command^0')
end)

AddEventHandler('playerSpawned', function()
    CreateThread(function()
        Wait(5000)
        
        RegisterCommand('steal', CustomStealCommand, false)
        TriggerEvent('chat:removeSuggestion', '/steal')
        TriggerEvent('chat:addSuggestion', '/steal', 'Rob a nearby player with hands up')
        
        print('^2[FEARX-OXROB] Command override reapplied after spawn^0')
    end)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == 'ox_inventory' then
        Wait(3000)
        RegisterCommand('steal', CustomStealCommand, false)
        TriggerEvent('chat:removeSuggestion', '/steal')
        TriggerEvent('chat:addSuggestion', '/steal', 'Rob a nearby player with hands up')
        print('^2[FEARX-OXROB] Command override reapplied after ox_inventory restart^0')
    end
end)

RegisterNetEvent('fearx-oxrob:client:beingRobbed', function()
    lib.notify({description = Config.Locales['robbery_started'], type = 'error'})
end)

RegisterNetEvent('fearx-oxrob:client:notify', function(message, msgType)
    lib.notify({description = Config.Locales[message] or message, type = msgType or 'inform'})
end)