ESX = exports['es_extended']:getSharedObject()
local interactionPoints = {}

-- Configuration (loaded from config.lua)
Config = Config or {
    AdminGroups = {'admin', 'superadmin'},
    DefaultRadius = 2.0,
    DefaultBlipSprite = 478,
    DefaultBlipColor = 2,
    DefaultBlipScale = 0.8
}

-- Load points from database
AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Citizen.Wait(2000)
        exports.oxmysql:execute('SELECT * FROM interaction_points', {}, function(results)
            for _, point in ipairs(results) do
                interactionPoints[point.id] = {
                    coords = {x = point.x, y = point.y, z = point.z},
                    item = point.item,
                    amount = point.amount,
                    radius = point.radius,
                    blipSprite = point.blipSprite,
                    blipColor = point.blipColor,
                    blipScale = point.blipScale,
                    blipName = point.blipName,
                    duration = point.duration
                }
            end
            TriggerClientEvent('esx_interaction:syncPoints', -1, interactionPoints)
            if Config.DebugMode then
                print(string.format('[ESX_INTERACTION] Loaded %d interaction points from database', #results))
            end
        end)
    end
end)

-- Handle sync request
RegisterNetEvent('esx_interaction:requestSync')
AddEventHandler('esx_interaction:requestSync', function()
    TriggerClientEvent('esx_interaction:syncPoints', source, interactionPoints)
    if Config.DebugMode then
        print(string.format('[ESX_INTERACTION] Sync requested by player %d', source))
    end
end)

-- Create interaction point
RegisterNetEvent('esx_interaction:createPoint')
AddEventHandler('esx_interaction:createPoint', function(data)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local isAdmin = false
    local playerGroup = xPlayer.getGroup()
    for _, group in ipairs(Config.AdminGroups) do
        if playerGroup == group then
            isAdmin = true
            break
        end
    end
    if not isAdmin then
        TriggerClientEvent('esx_interaction:error', source, 'You are not authorized to create interaction points.')
        return
    end

    local coords = data.coords
    if not coords then
        local ped = GetPlayerPed(source)
        if ped and DoesEntityExist(ped) then
            local playerCoords = GetEntityCoords(ped)
            coords = {x = playerCoords.x, y = playerCoords.y, z = playerCoords.z - 0.5}
        else
            TriggerClientEvent('esx_interaction:error', source, 'Could not get player coordinates')
            return
        end
    end

    if not coords or not coords.x or not coords.y or not coords.z or not data.item or data.item == '' or not data.amount or data.amount < 1 then
        TriggerClientEvent('esx_interaction:error', source, 'Invalid data')
        if Config.DebugMode then
            print('[ESX_INTERACTION] Invalid data for createPoint: ' .. json.encode(data))
        end
        return
    end

    if exports.ox_inventory and not exports.ox_inventory:Items()[data.item] then
        TriggerClientEvent('esx_interaction:error', source, 'Item does not exist in inventory system')
        if Config.DebugMode then
            print(string.format('[ESX_INTERACTION] Item %s not found in ox_inventory', data.item))
        end
        return
    end

    data.radius = data.radius or Config.DefaultRadius
    data.blipSprite = data.blipSprite or Config.DefaultBlipSprite
    data.blipColor = data.blipColor or Config.DefaultBlipColor
    data.blipScale = data.blipScale or Config.DefaultBlipScale
    data.blipName = data.blipName or 'Interaction Point'
    data.duration = data.duration or 0

    local insertQuery = 'INSERT INTO interaction_points (x, y, z, item, amount, radius, blipSprite, blipColor, blipScale, blipName, duration) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
    exports.oxmysql:insert(insertQuery, {
        coords.x, coords.y, coords.z,
        data.item, data.amount, data.radius,
        data.blipSprite, data.blipColor, data.blipScale,
        data.blipName, data.duration
    }, function(id)
        if id then
            interactionPoints[id] = {
                coords = coords,
                item = data.item,
                amount = data.amount,
                radius = data.radius,
                blipSprite = data.blipSprite,
                blipColor = data.blipColor,
                blipScale = data.blipScale,
                blipName = data.blipName,
                duration = data.duration
            }
            TriggerClientEvent('esx_interaction:pointCreated', source)
            TriggerClientEvent('esx_interaction:syncPoints', -1, interactionPoints)
            xPlayer.showNotification('Interaction point created successfully!')
            if Config.DebugMode then
                print(string.format('[ESX_INTERACTION] Created point %d: %s', id, json.encode(interactionPoints[id])))
            end
        else
            TriggerClientEvent('esx_interaction:error', source, 'Failed to create point in database')
            if Config.DebugMode then
                print('[ESX_INTERACTION] Failed to insert point into database')
            end
        end
    end)
end)

-- Use interaction point
RegisterNetEvent('esx_interaction:usePoint')
AddEventHandler('esx_interaction:usePoint', function(id)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        TriggerClientEvent('esx_interaction:error', source, 'Player not found')
        if Config.DebugMode then
            print(string.format('[ESX_INTERACTION] Player %d not found for usePoint', source))
        end
        return
    end

    if not interactionPoints[id] or not interactionPoints[id].item or not interactionPoints[id].amount then
        TriggerClientEvent('esx_interaction:error', source, 'Interaction point does not exist or is invalid')
        if Config.DebugMode then
            print(string.format('[ESX_INTERACTION] Invalid point %s for player %d', tostring(id), source))
        end
        return
    end

    local point = interactionPoints[id]
    local canCarry
    if exports.ox_inventory then
        canCarry = exports.ox_inventory:CanCarryItem(source, point.item, point.amount)
    else
        canCarry = xPlayer.canCarryItem(point.item, point.amount)
    end

    if canCarry then
        if exports.ox_inventory then
            exports.ox_inventory:AddItem(source, point.item, point.amount)
        else
            xPlayer.addInventoryItem(point.item, point.amount)
        end
        TriggerClientEvent('esx_interaction:itemReceived', source, point.item, point.amount)
        if Config.DebugMode then
            print(string.format('[ESX_INTERACTION] Player %d received %s x%d from point %s', source, point.item, point.amount, tostring(id)))
        end
    else
        TriggerClientEvent('esx_interaction:error', source, 'Cannot carry more of this item')
        if Config.DebugMode then
            print(string.format('[ESX_INTERACTION] Player %d cannot carry %s x%d from point %s', source, point.item, point.amount, tostring(id)))
        end
    end
end)

-- Delete interaction point
RegisterNetEvent('esx_interaction:deletePoint')
AddEventHandler('esx_interaction:deletePoint', function(id)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        TriggerClientEvent('esx_interaction:error', source, 'Player not found')
        return
    end

    if not interactionPoints[id] then
        TriggerClientEvent('esx_interaction:error', source, 'Interaction point does not exist')
        return
    end

    local isAdmin = false
    local playerGroup = xPlayer.getGroup()
    for _, group in ipairs(Config.AdminGroups) do
        if playerGroup == group then
            isAdmin = true
            break
        end
    end
    if not isAdmin then
        TriggerClientEvent('esx_interaction:error', source, 'You are not authorized to delete interaction points.')
        return
    end

    exports.oxmysql:execute('DELETE FROM interaction_points WHERE id = ?', {id}, function(result)
        if result.affectedRows > 0 then
            interactionPoints[id] = nil
            TriggerClientEvent('esx_interaction:pointDeleted', source, id)
            TriggerClientEvent('esx_interaction:syncPoints', -1, interactionPoints)
            xPlayer.showNotification('Interaction point deleted successfully!')
            if Config.DebugMode then
                print(string.format('[ESX_INTERACTION] Deleted point %s by player %d', tostring(id), source))
            end
        else
            TriggerClientEvent('esx_interaction:error', source, 'Failed to delete point from database')
            if Config.DebugMode then
                print(string.format('[ESX_INTERACTION] Failed to delete point %s from database', tostring(id)))
            end
        end
    end)
end)

-- Clear all points and reset AUTO_INCREMENT
RegisterNetEvent('esx_interaction:clearAllPoints')
AddEventHandler('esx_interaction:clearAllPoints', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        if Config.DebugMode then
            print('[ESX_INTERACTION] Player not found for clearAllPoints')
        end
        return
    end

    local isAdmin = false
    local playerGroup = xPlayer.getGroup()
    for _, group in ipairs(Config.AdminGroups) do
        if playerGroup == group then
            isAdmin = true
            break
        end
    end
    if not isAdmin then
        TriggerClientEvent('esx_interaction:error', source, 'You are not authorized to clear interaction points.')
        return
    end

    exports.oxmysql:execute('TRUNCATE TABLE interaction_points', {}, function(result)
        interactionPoints = {}
        local deletedCount = result.affectedRows or 0
        -- Verify AUTO_INCREMENT reset
        exports.oxmysql:execute('SHOW TABLE STATUS LIKE "interaction_points"', {}, function(status)
            local autoIncrement = status[1].Auto_increment or 0
            TriggerClientEvent('esx_interaction:syncPoints', -1, interactionPoints)
            xPlayer.showNotification(string.format('Cleared %d interaction points and reset IDs', deletedCount))
            if Config.DebugMode then
                print(string.format('[ESX_INTERACTION] Cleared %d points and reset AUTO_INCREMENT to %d by player %d', deletedCount, autoIncrement, source))
            end
        end)
    end)
end)

-- Clear all points command (for testing)
RegisterCommand('clearallpoints', function(source)
    if source == 0 then
        TriggerEvent('esx_interaction:clearAllPoints')
        print('[ESX_INTERACTION] Cleared all points from console')
    else
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return end
        local isAdmin = false
        local playerGroup = xPlayer.getGroup()
        for _, group in ipairs(Config.AdminGroups) do
            if playerGroup == group then
                isAdmin = true
                break
            end
        end
        if isAdmin then
            TriggerEvent('esx_interaction:clearAllPoints')
        else
            xPlayer.showNotification('You are not authorized to clear points')
        end
    end
end, false)

-- Check database
RegisterNetEvent('esx_interaction:checkDatabase')
AddEventHandler('esx_interaction:checkDatabase', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local function checkTable(tableName, callback)
        exports.oxmysql:execute('SHOW TABLES LIKE ?', {tableName}, function(result)
            callback(result and #result > 0)
        end)
    end

    checkTable('interaction_points', function(interactionExists)
        checkTable('items', function(itemsExists)
            checkTable('users', function(usersExists)
                checkTable('user_inventory', function(inventoryExists)
                    local status = string.format('Database check: items %s, users %s, user_inventory %s, interaction_points %s',
                        itemsExists and 'OK' or 'MISSING',
                        usersExists and 'OK' or 'MISSING',
                        inventoryExists and 'OK' or 'MISSING',
                        interactionExists and 'OK' or 'MISSING')
                    TriggerClientEvent('esx_interaction:error', source, status)
                    if Config.DebugMode then
                        print(string.format('[ESX_INTERACTION] Database check by player %d: %s', source, status))
                        exports.oxmysql:execute('SHOW TABLE STATUS LIKE "interaction_points"', {}, function(status)
                            print(string.format('[ESX_INTERACTION] Auto_increment: %d', status[1].Auto_increment or 0))
                        end)
                    end
                end)
            end)
        end)
    end)
end)

-- Manual sync command
RegisterCommand('syncpoints', function(source)
    if source == 0 then
        TriggerClientEvent('esx_interaction:syncPoints', -1, interactionPoints)
        print('[ESX_INTERACTION] Synced points from console')
    else
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return end
        local isAdmin = false
        local playerGroup = xPlayer.getGroup()
        for _, group in ipairs(Config.AdminGroups) do
            if playerGroup == group then
                isAdmin = true
                break
            end
        end
        if isAdmin then
            TriggerClientEvent('esx_interaction:syncPoints', source, interactionPoints)
            xPlayer.showNotification('Interaction points synced')
            if Config.DebugMode then
                print(string.format('[ESX_INTERACTION] Synced points for player %d', source))
            end
        else
            xPlayer.showNotification('You are not authorized to sync points')
        end
    end
end, false)

-- Initialize
Citizen.CreateThread(function()
    print(string.format('[ESX_INTERACTION] Server initialized, DebugMode: %s', tostring(Config.DebugMode)))
end)