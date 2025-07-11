ESX = exports['es_extended']:getSharedObject()

-- Assume Config is loaded from config.lua
local nearbyPoints = {}
local lastUpdate = 0
local blips = {}

-- Draw 3D text
local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 75)
    end
end

-- Calculate distance
local function GetDistance(coords1, coords2)
    if not coords1 or not coords2 then return math.huge end
    return #(vector3(coords1.x, coords1.y, coords1.z) - vector3(coords2.x, coords2.y, coords2.z))
end

-- Update nearby points
local function UpdateNearbyPoints(playerCoords)
    if GetGameTimer() - lastUpdate < (Config.NearbyUpdateInterval or 1000) then return end
    lastUpdate = GetGameTimer()

    if not ESX.InteractionPoints or type(ESX.InteractionPoints) ~= 'table' then
        if Config.DebugMode then print('[ESX_INTERACTION] ESX.InteractionPoints is nil or not a table') end
        nearbyPoints = {}
        return
    end

    local newNearbyPoints = {}
    for id, point in pairs(ESX.InteractionPoints) do
        if point and point.coords then
            local distance = GetDistance(playerCoords, point.coords)
            if distance <= (Config.NearbyThreshold or 50.0) then
                newNearbyPoints[id] = nearbyPoints[id] or point
                if not newNearbyPoints[id].groundZ then
                    local foundGround, z = GetGroundZFor_3dCoord(point.coords.x, point.coords.y, point.coords.z + 2.0, false)
                    newNearbyPoints[id].groundZ = foundGround and z or point.coords.z
                    if Config.DebugMode and not foundGround then
                        print(string.format('[ESX_INTERACTION] Ground Z not found for point %s, using z: %.2f', tostring(id), newNearbyPoints[id].groundZ))
                    end
                end
            end
        end
    end
    nearbyPoints = newNearbyPoints
end

-- Main thread for drawing markers and 3D text
Citizen.CreateThread(function()
    -- Validate Config
    if Config.ShowMarkers == nil then Config.ShowMarkers = true end
    if not Config.MarkerType then Config.MarkerType = 1 end
    if not Config.MarkerColor then Config.MarkerColor = {r = 255, g = 0, b = 0, a = 255} end
    if not Config.DefaultRadius then Config.DefaultRadius = 3.0 end
    if not Config.DrawDistance then Config.DrawDistance = 100.0 end
    if not Config.UpdateInterval then Config.UpdateInterval = 0 end
    if Config.ShowPrompts == nil then Config.ShowPrompts = true end
    if Config.Use3DText == nil then Config.Use3DText = true end

    while true do
        Citizen.Wait(Config.UpdateInterval)
        local playerPed = PlayerPedId()
        if not DoesEntityExist(playerPed) then goto continue end

        local playerCoords = GetEntityCoords(playerPed)
        UpdateNearbyPoints(playerCoords)

        if Config.ShowMarkers then
            for id, point in pairs(nearbyPoints) do
                if point and point.coords and point.groundZ then
                    local distance = GetDistance(playerCoords, point.coords)
                    if distance <= (Config.DrawDistance or 100.0) then
                        -- Main marker (type 1, upright cylinder)
                        DrawMarker(
                            Config.MarkerType,
                            point.coords.x, point.coords.y, point.groundZ + 0.2,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            1.5, 1.5, 2.0,
                            Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, Config.MarkerColor.a,
                            false, true, 2, false, nil, nil, false
                        )

                        -- Debug marker (type 27, ground circle)
                        if Config.DebugMode then
                            DrawMarker(
                                27,
                                point.coords.x, point.coords.y, point.groundZ,
                                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                point.radius or Config.DefaultRadius,
                                point.radius or Config.DefaultRadius,
                                0.5,
                                255, 255, 0, 255,
                                false, true, 2, false, nil, nil, false
                            )
                            print(string.format('[ESX_INTERACTION] Drawing debug marker (type 27) for point %s at x=%.2f, y=%.2f, z=%.2f', tostring(id), point.coords.x, point.coords.y, point.groundZ))
                        end

                        -- Draw 3D text
                        if Config.Use3DText then
                            DrawText3D(point.coords.x, point.coords.y, point.groundZ + 1.0, string.format('Press [E] to collect %s x%d', point.item or 'item', point.amount or 1))
                        end
                    end
                end
            end
        elseif Config.DebugMode then
            print('[ESX_INTERACTION] Markers not drawn: Config.ShowMarkers is false')
        end

        ::continue::
    end
end)

-- Separate thread for interaction prompts
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if not Config.ShowPrompts then goto continue end

        local playerPed = PlayerPedId()
        if not DoesEntityExist(playerPed) then goto continue end

        local playerCoords = GetEntityCoords(playerPed)
        for id, point in pairs(nearbyPoints) do
            if point and point.coords and point.item and point.amount then
                local distance = GetDistance(playerCoords, point.coords)
                if distance <= (point.radius or Config.DefaultRadius or 3.0) then
                    SetTextComponentFormat("STRING")
                    AddTextComponentString(string.format('Press ~g~[E]~w~ to collect %s', point.item))
                    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                    if IsControlJustPressed(0, 38) then
                        if Config.DebugMode then
                            print(string.format('[ESX_INTERACTION] Attempting to use point %s (item: %s, amount: %d)', tostring(id), point.item, point.amount))
                        end
                        TriggerServerEvent('esx_interaction:usePoint', id)
                    end
                end
            elseif Config.DebugMode then
                print(string.format('[ESX_INTERACTION] Point %s missing item or amount', tostring(id)))
            end
        end

        ::continue::
    end
end)

-- Create interaction command
RegisterCommand('createinteraction', function(source)
    local xPlayer = ESX.GetPlayerData()
    local isAdmin = false
    if xPlayer and xPlayer.group then
        for _, group in ipairs(Config.AdminGroups or {'admin', 'superadmin'}) do
            if xPlayer.group == group then
                isAdmin = true
                break
            end
        end
    end
    if isAdmin then
        SetNuiFocus(true, true)
        SendNUIMessage({type = 'show', items = exports.ox_inventory and exports.ox_inventory:Items() or {}})
    else
        ESX.ShowNotification('You are not authorized to create interaction points.')
    end
end, false)

-- Delete point command
RegisterCommand('deletepoint', function(source, args)
    local id = tonumber(args[1])
    if not id then
        ESX.ShowNotification('Please provide a point ID')
        return
    end
    if not ESX.InteractionPoints[id] then
        ESX.ShowNotification('Point ID does not exist')
        return
    end
    TriggerServerEvent('esx_interaction:deletePoint', id)
end, false)

-- Register NUI callbacks
RegisterNUICallback('createPoint', function(data, cb)
    TriggerServerEvent('esx_interaction:createPoint', data)
    cb('ok')
end)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('clearAllPoints', function(data, cb)
    if Config.DebugMode then
        print('[ESX_INTERACTION] NUI triggered clearAllPoints')
    end
    TriggerServerEvent('esx_interaction:clearAllPoints')
    ESX.ShowNotification('All interaction points cleared')
    cb('ok')
end)

RegisterNUICallback('debug', function(data, cb)
    if Config.DebugMode then
        print('[ESX_INTERACTION] NUI debug callback triggered: ' .. json.encode(data))
    end
    cb('ok')
end)

-- Event handlers
RegisterNetEvent('esx_interaction:pointCreated')
AddEventHandler('esx_interaction:pointCreated', function()
    SetNuiFocus(false, false)
    ESX.ShowNotification('Interaction point created successfully!')
end)

RegisterNetEvent('esx_interaction:pointDeleted')
AddEventHandler('esx_interaction:pointDeleted', function(id)
    ESX.ShowNotification('Point deleted successfully')
    nearbyPoints[id] = nil
    if blips[id] then
        RemoveBlip(blips[id])
        blips[id] = nil
        if Config.DebugMode then
            print(string.format('[ESX_INTERACTION] Removed blip for point %s', tostring(id)))
        end
    end
end)

RegisterNetEvent('esx_interaction:syncPoints')
AddEventHandler('esx_interaction:syncPoints', function(points)
    ESX.InteractionPoints = points or {}
    -- Clear outdated nearbyPoints and blips
    for id in pairs(nearbyPoints) do
        if not ESX.InteractionPoints[id] then
            nearbyPoints[id] = nil
        end
    end
    for id, blip in pairs(blips) do
        if not ESX.InteractionPoints[id] then
            RemoveBlip(blip)
            blips[id] = nil
            if Config.DebugMode then
                print(string.format('[ESX_INTERACTION] Removed blip for point %s', tostring(id)))
            end
        end
    end
    -- Create blips for new points
    for id, point in pairs(ESX.InteractionPoints) do
        if point and point.coords and not blips[id] and point.blipSprite then
            local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
            SetBlipSprite(blip, point.blipSprite or 478)
            SetBlipColour(blip, point.blipColor or 2)
            SetBlipScale(blip, point.blipScale or 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(point.blipName or 'Interaction Point')
            EndTextCommandSetBlipName(blip)
            blips[id] = blip
            if Config.DebugMode then
                print(string.format('[ESX_INTERACTION] Created blip for point %s at x=%.2f, y=%.2f, z=%.2f', tostring(id), point.coords.x, point.coords.y, point.coords.z))
            end
        end
    end
    if Config.DebugMode then
        print(string.format('[ESX_INTERACTION] Synced %d points', #points))
    end
end)

RegisterNetEvent('esx_interaction:error')
AddEventHandler('esx_interaction:error', function(message)
    ESX.ShowNotification(tostring(message))
    if Config.DebugMode then
        print('[ESX_INTERACTION] Error: ' .. tostring(message))
    end
end)

RegisterNetEvent('esx_interaction:itemReceived')
AddEventHandler('esx_interaction:itemReceived', function(item, amount)
    ESX.ShowNotification(string.format('Received %s x%d', tostring(item), tonumber(amount) or 0))
end)

-- Debug commands
RegisterCommand('togglemarkers', function()
    Config.ShowMarkers = not Config.ShowMarkers
    ESX.ShowNotification('Markers toggled: ' .. tostring(Config.ShowMarkers))
    if Config.DebugMode then
        print('[ESX_INTERACTION] Markers toggled: ' .. tostring(Config.ShowMarkers))
    end
end, false)

RegisterCommand('toggledebug', function()
    Config.DebugMode = not Config.DebugMode
    ESX.ShowNotification('Debug mode toggled: ' .. tostring(Config.DebugMode))
    print('[ESX_INTERACTION] Debug mode toggled: ' .. tostring(Config.DebugMode))
end, false)

RegisterCommand('tt', function(source, args)
    local id = tonumber(args[1])
    if id and ESX.InteractionPoints and ESX.InteractionPoints[id] and ESX.InteractionPoints[id].coords then
        SetEntityCoords(PlayerPedId(), ESX.InteractionPoints[id].coords.x, ESX.InteractionPoints[id].coords.y, ESX.InteractionPoints[id].coords.z)
        if Config.DebugMode then
            print(string.format('[ESX_INTERACTION] Teleported to point %d', id))
        end
    else
        ESX.ShowNotification('Invalid point ID')
    end
end, false)

RegisterCommand('checkdb', function()
    TriggerServerEvent('esx_interaction:checkDatabase')
end, false)

RegisterCommand('listpoints', function()
    if ESX.InteractionPoints then
        local count = 0
        for id, point in pairs(ESX.InteractionPoints) do
            count = count + 1
            if Config.DebugMode then
                print(string.format('[ESX_INTERACTION] Point %s: %s', tostring(id), json.encode(point)))
            end
        end
        ESX.ShowNotification(string.format('Total points: %d', count))
    else
        ESX.ShowNotification('No interaction points loaded')
    end
end, false)

RegisterCommand('getcoords', function()
    local playerPed = PlayerPedId()
    if not DoesEntityExist(playerPed) then
        ESX.ShowNotification('Player not found')
        return
    end
    local coords = GetEntityCoords(playerPed)
    ESX.ShowNotification(string.format('Coords: %.2f, %.2f, %.2f', coords.x, coords.y, coords.z))
    if Config.DebugMode then
        print(string.format('[ESX_INTERACTION] Current coordinates: x=%.2f, y=%.2f, z=%.2f', coords.x, coords.y, coords.z))
    end
end, false)

-- Initialize
Citizen.CreateThread(function()
    ESX.InteractionPoints = ESX.InteractionPoints or {}
    while not ESX.GetPlayerData().job do
        Citizen.Wait(100)
    end
    TriggerServerEvent('esx_interaction:requestSync')
    print(string.format('[ESX_INTERACTION] Initialized, ShowMarkers: %s, MarkerType: %d, ShowPrompts: %s', tostring(Config.ShowMarkers), Config.MarkerType or 1, tostring(Config.ShowPrompts)))
end)