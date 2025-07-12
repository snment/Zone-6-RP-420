print("r_drugsales server/main.lua loading...")

lib.callback.register('r_drugsales:checkIfPolice', function(src)
    print("DEBUG: checkIfPolice called for player " .. src)
    local job = Core.Framework.GetPlayerJob(src)
    for _, policeJob in pairs(Cfg.Dispatch.policeJobs) do
        if job == policeJob then
            return true
        end
    end
    return false
end)

lib.callback.register('r_drugsales:getPoliceOnline', function(src)
    print("DEBUG: getPoliceOnline called for player " .. src)
    local count = 0
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local job = Core.Framework.GetPlayerJob(tonumber(playerId))
        for _, policeJob in pairs(Cfg.Dispatch.policeJobs) do
            if job == policeJob then
                count = count + 1
            end
        end
    end
    print("DEBUG: Police online count: " .. count)
    return count or 0
end)

lib.callback.register('r_drugsales:getPlayerItems', function(src)
    print("DEBUG: getPlayerItems called for player " .. src)
    local items = Core.Inventory.GetInventoryItems(src)
    print("DEBUG: Found " .. #items .. " items in inventory")
    return items
end)

lib.callback.register('r_drugsales:streetSale', function(src, playerNetId, customerNetId, itemInfo)
    print("=== STREET SALE CALLBACK CALLED ===")
    print("Player ID: " .. tostring(src))
    print("Player NetId: " .. tostring(playerNetId))
    print("Customer NetId: " .. tostring(customerNetId))
    print("Item Info: " .. json.encode(itemInfo))
    
    local saleStep = lib.callback.await('r_drugsales:getSaleStep', src)
    print("Sale step: " .. tostring(saleStep))
    
    if saleStep ~= 3 then 
        print("ERROR: Invalid sale step, expected 3, got " .. tostring(saleStep))
        DropPlayer(src, _L('cheater')) 
        return false 
    end
    
    local player, customer = NetworkGetEntityFromNetworkId(playerNetId), NetworkGetEntityFromNetworkId(customerNetId)
    local pCoords, cCoords = GetEntityCoords(player), GetEntityCoords(customer)
    local distance = #(pCoords - cCoords)
    
    print("Distance between player and customer: " .. tostring(distance))
    
    if distance > 10 then 
        print("ERROR: Distance too far: " .. tostring(distance))
        DropPlayer(src, _L('cheater')) 
        return false 
    end
    
    -- Check if ox_inventory exists
    if not exports.ox_inventory then
        print("ERROR: ox_inventory export not found!")
        return false
    end
    
    -- Check player's inventory
    print("=== CHECKING PLAYER INVENTORY ===")
    local oxItems = exports.ox_inventory:GetInventoryItems(src, false)
    print("ox_inventory items found: " .. tostring(#oxItems))
    
    local foundWeed = false
    local weedCount = 0
    for i, item in pairs(oxItems) do
        print("Item " .. i .. ": " .. item.name .. " x" .. item.count)
        if item.name == itemInfo.name then
            foundWeed = true
            weedCount = item.count
            print("Found target item: " .. item.name .. " x" .. item.count)
            break
        end
    end
    
    if not foundWeed then
        print("ERROR: Player doesn't have " .. itemInfo.name)
        return false
    end
    
    if weedCount < Cfg.Selling.streetQuantity[1] then
        print("ERROR: Not enough " .. itemInfo.name .. ". Has: " .. weedCount .. ", needs: " .. Cfg.Selling.streetQuantity[1])
        return false
    end
    
    local quantity = math.random(Cfg.Selling.streetQuantity[1], math.min(Cfg.Selling.streetQuantity[2], weedCount))
    local pay = math.random(Cfg.Selling.drugs[itemInfo.name].street[1], Cfg.Selling.drugs[itemInfo.name].street[2]) * quantity
    
    print("=== TRANSACTION DETAILS ===")
    print("Quantity to sell: " .. quantity)
    print("Payment amount: $" .. pay)
    print("Account type: " .. Cfg.Selling.account)
    
    -- Remove the drugs
    print("=== REMOVING DRUGS ===")
    print("Calling exports.ox_inventory:RemoveItem(" .. src .. ", '" .. itemInfo.name .. "', " .. quantity .. ")")
    local removeSuccess = exports.ox_inventory:RemoveItem(src, itemInfo.name, quantity)
    print("RemoveItem result: " .. tostring(removeSuccess))
    
    if not removeSuccess then
        print("ERROR: Failed to remove items")
        return false
    end
    
    -- Add payment
    print("=== ADDING PAYMENT ===")
    local addSuccess = false
    
    if Cfg.Selling.account == 'black_money' then
        print("Attempting to add black_money as item...")
        
        -- Check if black_money item exists
        local blackMoneyItem = exports.ox_inventory:Items('black_money')
        if blackMoneyItem then
            print("black_money item found in ox_inventory")
            print("Calling exports.ox_inventory:AddItem(" .. src .. ", 'black_money', " .. pay .. ")")
            addSuccess = exports.ox_inventory:AddItem(src, 'black_money', pay)
            print("AddItem black_money result: " .. tostring(addSuccess))
        else
            print("black_money item NOT found in ox_inventory, using ESX account")
            -- Fallback to ESX account
            local ESX = exports["es_extended"]:getSharedObject()
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                xPlayer.addAccountMoney('black_money', pay)
                addSuccess = true
                print("Added $" .. pay .. " to black_money account via ESX")
            else
                print("ERROR: Could not get ESX player object")
            end
        end
    else
        print("Adding to account: " .. Cfg.Selling.account)
        Core.Framework.AddAccountBalance(src, Cfg.Selling.account, pay)
        addSuccess = true
    end
    
    print("=== FINAL RESULTS ===")
    print("Remove success: " .. tostring(removeSuccess))
    print("Add success: " .. tostring(addSuccess))
    print("=== STREET SALE COMPLETE ===")
    
    return addSuccess, quantity, pay
end)

lib.callback.register('r_drugsales:bulkSale', function(src, playerNetId, customerNetId, itemInfo)
    print("=== BULK SALE CALLBACK CALLED ===")
    print("Player ID: " .. tostring(src))
    
    -- Similar logic to street sale but shorter debug output
    local saleStep = lib.callback.await('r_drugsales:getSaleStep', src)
    if saleStep ~= 3 then 
        DropPlayer(src, _L('cheater')) 
        return false 
    end
    
    local player, customer = NetworkGetEntityFromNetworkId(playerNetId), NetworkGetEntityFromNetworkId(customerNetId)
    local pCoords, cCoords = GetEntityCoords(player), GetEntityCoords(customer)
    local distance = #(pCoords - cCoords)
    
    if distance > 10 then 
        DropPlayer(src, _L('cheater')) 
        return false 
    end
    
    local oxItems = exports.ox_inventory:GetInventoryItems(src, false)
    local foundWeed, weedCount = false, 0
    for i, item in pairs(oxItems) do
        if item.name == itemInfo.name then
            foundWeed, weedCount = true, item.count
            break
        end
    end
    
    if not foundWeed or weedCount < Cfg.Selling.bulkQuantity[1] then
        print("ERROR: Not enough items for bulk sale")
        return false
    end
    
    local quantity = math.random(Cfg.Selling.bulkQuantity[1], math.min(Cfg.Selling.bulkQuantity[2], weedCount))
    local pay = math.random(Cfg.Selling.drugs[itemInfo.name].bulk[1], Cfg.Selling.drugs[itemInfo.name].bulk[2]) * quantity
    
    local removeSuccess = exports.ox_inventory:RemoveItem(src, itemInfo.name, quantity)
    print("Bulk RemoveItem result: " .. tostring(removeSuccess))
    
    if not removeSuccess then return false end
    
    local addSuccess = false
    if Cfg.Selling.account == 'black_money' then
        local blackMoneyItem = exports.ox_inventory:Items('black_money')
        if blackMoneyItem then
            addSuccess = exports.ox_inventory:AddItem(src, 'black_money', pay)
        else
            local ESX = exports["es_extended"]:getSharedObject()
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                xPlayer.addAccountMoney('black_money', pay)
                addSuccess = true
            end
        end
    else
        Core.Framework.AddAccountBalance(src, Cfg.Selling.account, pay)
        addSuccess = true
    end
    
    print("Bulk sale result: " .. tostring(addSuccess))
    return addSuccess, quantity, pay
end)

lib.callback.register('r_drugsales:robPlayer', function(src, slot)
    print("=== ROB PLAYER CALLBACK CALLED ===")
    local quantity = math.random(table.unpack(Cfg.Selling.streetQuantity))
    local removeSuccess = exports.ox_inventory:RemoveItem(src, slot.name, quantity)
    print("Rob RemoveItem result: " .. tostring(removeSuccess))
    return removeSuccess, quantity
end)

lib.callback.register('r_drugsales:retrieveDrugs', function(src, slot, quantity, playerNetId, customerNetId)
    print("=== RETRIEVE DRUGS CALLBACK CALLED ===")
    local saleStep = lib.callback.await('r_drugsales:getSaleStep', src)
    local player, customer = NetworkGetEntityFromNetworkId(playerNetId), NetworkGetEntityFromNetworkId(customerNetId)
    local pCoords, cCoords = GetEntityCoords(player), GetEntityCoords(customer)
    local distance = #(pCoords - cCoords)
    
    if distance > 10 then DropPlayer(src, _L('cheater')) return false end
    if saleStep ~= 3 then DropPlayer(src, _L('cheater')) return false end
    
    local addSuccess = exports.ox_inventory:AddItem(src, slot.name, quantity)
    print("Retrieve AddItem result: " .. tostring(addSuccess))
    return addSuccess
end)

if Cfg.Server.interaction == 'item' then
    print("DEBUG: Registering r_trapphone as usable item")
    Core.Framework.RegisterUsableItem('r_trapphone', function(src)
        print("DEBUG: r_trapphone used by player " .. src)
        TriggerClientEvent('r_drugsales:openDealerMenu', src)
    end)
elseif Cfg.Server.interaction == 'command' then
    print("DEBUG: Registering command: " .. Cfg.Server.command)
    RegisterCommand(Cfg.Server.command, function(src)
        print("DEBUG: Command " .. Cfg.Server.command .. " used by player " .. src)
        TriggerClientEvent('r_drugsales:openDealerMenu', src)
    end, false)
end

print("r_drugsales server/main.lua loaded successfully")