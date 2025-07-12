local entities = {}
local meetBlip = false
local saleStep = 0

local state = LocalPlayer.state

-- Add console logging for F8
local function clientLog(message)
    print("[CLIENT] " .. message)
    TriggerEvent('chat:addMessage', {
        color = { 255, 255, 0 },
        multiline = true,
        args = { "[DEBUG]", message }
    })
end

clientLog("r_drugsales client loading...")

lib.callback.register('r_drugsales:getSaleStep', function()
    clientLog("getSaleStep called, returning: " .. saleStep)
    return saleStep
end)

local function initiateBulkSale(slot)
    clientLog("initiateBulkSale called")
    saleStep = 3
    local bagModel, cashModel = 'xm_prop_x17_bag_01d', 'prop_anim_cash_pile_01'
    local animDict, animName = 'mp_common', 'givetake1_a'
    local animDict2, animName2 = 'weapons@holster_fat_2h', 'holster'
    local playerNetId = NetworkGetNetworkIdFromEntity(cache.ped)
    local customerNetId = NetworkGetNetworkIdFromEntity(entities.customer)
    
    clientLog("Bulk sale - Player NetId: " .. playerNetId .. ", Customer NetId: " .. customerNetId)
    
    entities.bag = Core.Natives.CreateProp(bagModel, GetEntityCoords(cache.ped), 0.0, true)
    AttachEntityToEntity(entities.bag, cache.ped, 90, 0.39, -0.06, -0.06, -100.00, -180.00, -78.00, true, true, false, true, 1, true)
    TaskTurnPedToFaceEntity(cache.ped, entities.customer, 500)
    Core.Natives.SetEntityProperties(entities.customer, false, true, true)
    SetTimeout(500, function()
        entities.cash = Core.Natives.CreateProp(cashModel, vec3(0, 0, 0), 0.0, false)
        AttachEntityToEntity(entities.cash, entities.customer, GetPedBoneIndex(entities.customer, 28422), 0.07, 0, -0.02, -83.09, -93.18, 86.26, true, true, false, true, 1, true)
        Core.Natives.PlayAnim(cache.ped, animDict, animName, -1, 32, 0.0)
        Core.Natives.PlayAnim(entities.customer, animDict, animName, -1, 32, 0.0)
        Wait(1500)
        AttachEntityToEntity(entities.bag, entities.customer, GetPedBoneIndex(entities.customer, 28422), 0.39, -0.06, -0.06, -100.00, -180.00, -78.00, true, true, false, true, 1, true)
        AttachEntityToEntity(entities.cash, cache.ped, 90, 0.07, 0, -0.02, -83.09, -93.18, 86.26, true, true, false, true, 1, true)
        Core.Natives.PlayAnim(cache.ped, animDict2, animName2, 1500, 32, 0.0)
        StopAnimTask(entities.customer, animDict, animName, 1.0)
        Wait(500)
        DeleteEntity(entities.cash)
        
        clientLog("About to call bulkSale server callback...")
        local paid, quantity, pay = lib.callback.await('r_drugsales:bulkSale', false, playerNetId, customerNetId, slot)
        clientLog("bulkSale callback result: paid=" .. tostring(paid) .. ", quantity=" .. tostring(quantity) .. ", pay=" .. tostring(pay))
        
        if not paid then 
            clientLog("Bulk sale FAILED!")
            Core.Framework.Notify("Bulk sale failed - You don't have enough drugs!", 'error')
            return CancelSelling() 
        end
        
        Core.Framework.Notify(_L('sold_drugs', quantity, slot.label, pay), 'success')
        PlayPedAmbientSpeechNative(entities.customer, 'Generic_Thanks', 'Speech_Params_Force')
        
        -- INSTANT CLEANUP AND RESET
        clientLog("Despawning bulk customer after successful sale")
        
        -- Clean up bag first
        if entities.bag then
            clientLog("Removing bag entity")
            SetEntityAsNoLongerNeeded(entities.bag)
            DeleteEntity(entities.bag)
            entities.bag = nil
        end
        
        -- Properly despawn bulk customer
        if entities.customer then
            clientLog("Removing bulk customer entity")
            SetEntityAsMissionEntity(entities.customer, false, true)  -- Allow deletion
            DeleteEntity(entities.customer)
            entities.customer = nil
        end
        
        -- RESET STATE IMMEDIATELY
        state.sellingDrugs = false
        saleStep = 0
        
        clientLog("Bulk sale SUCCESS - All entities despawned, ready for next sale")
    end)
end

local function setupBulkSale(slot, coords)
    clientLog("setupBulkSale starting...")
    saleStep = 2
    local pedModel = Cfg.Peds.bulkPeds[math.random(#Cfg.Peds.bulkPeds)]
    entities.customer = Core.Natives.CreateNpc(pedModel, coords.xyz, coords.w, true)
    while not DoesEntityExist(entities.customer) do Wait(100) end
    Core.Natives.SetEntityProperties(entities.customer, true, true, true)
    Core.Target.AddLocalEntity(entities.customer, {
        {
            label = _L('sell_drug', slot.label),
            icon = 'fas fa-joint',
            onSelect = function()
                clientLog("Bulk sale target CLICKED!")
                Core.Target.RemoveLocalEntity(entities.customer)
                initiateBulkSale(slot)
            end
        }
    })
    clientLog("Bulk customer spawned, target added")
    while state.sellingDrugs and saleStep == 2 do
        local pCoords = GetEntityCoords(cache.ped)
        local cCoords = GetEntityCoords(entities.customer)
        local distance = #(pCoords - cCoords)
        if distance <= 5.0 then
            PlayPedAmbientSpeechNative(entities.customer, 'Generic_Hows_It_Going', 'Speech_Params_Force')
            Core.Natives.SetGpsRoute(false)
            Core.Natives.RemoveBlip(meetBlip)
            meetBlip = false
            clientLog("Player approached bulk meetup")
            break
        end
        Wait(100)
    end
end

local function startBulkSaleTimer()
    CreateThread(function()
        local timer = Cfg.Selling.bulkMeetTime * 60000
        local startTime = GetGameTimer()
        while state.sellingDrugs and saleStep > 0 do
            local elapsedTime = GetGameTimer() - startTime
            local remainingTime = timer - elapsedTime
            if remainingTime <= 0 then
                Core.Framework.Notify(_L('no_show'), 'error')
                CancelSelling()
                return
            end
            Wait(100)
        end
    end)
end

local function taskBulkSale(slot, coords)
    clientLog("taskBulkSale starting...")
    startBulkSaleTimer()
    meetBlip = Core.Natives.CreateBlip(coords.xyz, 143, 2, 0.7, _L('meetup_location'), false)
    Core.Natives.SetGpsRoute(true, coords.xyz, 18)
    saleStep = 1
    while state.sellingDrugs and saleStep == 1 do
        local pCoords = GetEntityCoords(cache.ped)
        local distance = #(pCoords - coords.xyz)
        if distance <= 300 then return setupBulkSale(slot, coords) end
        Wait(100)
    end
end

local function initializeBulkSale()
    clientLog("initializeBulkSale starting...")
    local playerItems = lib.callback.await('r_drugsales:getPlayerItems', false)
    clientLog("Got " .. #playerItems .. " items from inventory")
    
    -- Check if player has any sellable drugs for bulk sale
    local hasSellableDrugs = false
    for _, slot in pairs(playerItems) do
        if Cfg.Selling.drugs[slot.name] and slot.count >= Cfg.Selling.bulkQuantity[1] then
            clientLog("Found sellable drug for bulk: " .. slot.name .. " x" .. slot.count)
            PlaySound(-1, 'Menu_Accept', 'Phone_SoundSet_Default', false, 0, true)
            Core.Natives.PlayAnim(cache.ped, 'cellphone@', 'cellphone_text_to_call', 500, 48, 0.0)
            Wait(500)
            Core.Natives.PlayAnim(cache.ped, 'cellphone@', 'cellphone_call_listen_base', 5000, 48, 0.0)
            SetTimeout(5000, function()
                local coords = Cfg.Selling.meetupCoords[math.random(#Cfg.Selling.meetupCoords)]
                Core.Natives.PlayAnim(cache.ped, 'cellphone@', 'cellphone_call_out', 1000, 17, 0.0)
                PlaySound(-1, 'Hang_Up', 'Phone_SoundSet_Michael', false, 0, true)
                Core.Framework.Notify(_L('go_meet_customer'), 'info')
                state.sellingDrugs = true
                SetTimeout(750, function()
                    if entities.phone then
                        clientLog("Cleaning up bulk sale phone after call")
                        DeleteEntity(entities.phone)
                        entities.phone = nil
                    end
                end)
                taskBulkSale(slot, coords)
                clientLog("Bulk sale process initiated")
            end)
            hasSellableDrugs = true
            return
        end
    end
    
    -- No sellable drugs found for bulk sale - notify player and close menu
    if not hasSellableDrugs then
        clientLog("No sellable drugs found for bulk sale!")
        PlaySound(-1, 'Click_Fail', 'WEB_NAVIGATION_SOUNDS_PHONE', false, 0, true)
        Core.Framework.Notify("You don't have enough drugs for bulk sale! (Need " .. Cfg.Selling.bulkQuantity[1] .. "+)", 'error')
        
        -- Clean up dealer menu phone before closing
        if entities.phone then
            clientLog("Cleaning up dealer menu phone - not enough for bulk")
            DeleteEntity(entities.phone)
            entities.phone = nil
        end
        
        CloseDealerMenu()
    end
end

local function retrieveDrugs(slot, quantity)
    clientLog("retrieveDrugs called")
    local drugProp = 'prop_meth_bag_01'
    local animDict, animName = 'pickup_object', 'pickup_low'
    local animDict2, animName2 = 'weapons@holster_fat_2h', 'holster'
    local playerNetId = NetworkGetNetworkIdFromEntity(cache.ped)
    local customerNetId = NetworkGetNetworkIdFromEntity(entities.customer)
    TaskTurnPedToFaceEntity(cache.ped, entities.customer, 500)
    SetTimeout(500, function()
        Core.Natives.PlayAnim(cache.ped, animDict, animName, 1000, 32, 0.0)
        Wait(500)
        entities.drugs = Core.Natives.CreateProp(drugProp, GetEntityCoords(entities.customer), 0.0, false)
        AttachEntityToEntity(entities.drugs, entities.customer, GetPedBoneIndex(entities.customer, 28422), 0.07, 0.01, -0.01, 136.33, 50.23, -50.26, true, true, false, true, 1, true)
        Wait(500)
        Core.Natives.PlayAnim(cache.ped, animDict2, animName2, 500, 32, 0.0)
        DeleteEntity(entities.drugs)
        local retrieved = lib.callback.await('r_drugsales:retrieveDrugs', false, slot, quantity, playerNetId, customerNetId)
        if not retrieved then return CancelSelling() end
        Core.Framework.Notify(_L('retrieved_drugs', quantity, slot.label), 'success')
        if state.inSellZone then TaskStreetSale(slot) end
    end)
end

local function initiateRobbery(slot, quantity)
    clientLog("initiateRobbery called")
    SetPedAsEnemy(entities.customer, true)
    SetPedHasAiBlip(entities.customer, true)
    TaskSmartFleePed(entities.customer, cache.ped, 100.0, -1, false, false)
    Core.Framework.Notify(_L('robbed'), 'error')
    while state.sellingDrugs and saleStep == 3 do
        local isDead = IsEntityDead(entities.customer)
        local playerCoords = GetEntityCoords(cache.ped)
        local pedCoords = GetEntityCoords(entities.customer)
        local pedDistance = #(playerCoords - pedCoords)
        if pedDistance >= 50 then Core.Framework.Notify(_L('got_away'), 'error') return CancelSelling() end
        if isDead then break end
        Wait(100)
    end
    Core.Target.AddLocalEntity(entities.customer, {
        {
            label = _L('retrieve_drugs'),
            icon = 'fas fa-box',
            canInteract = function()
                return state.sellingDrugs
            end,
            onSelect = function()
                retrieveDrugs(slot, quantity)
                Core.Target.RemoveLocalEntity(entities.customer)
            end
        }
    })
end

local function initiateStreetSale(slot)
    clientLog("initiateStreetSale called for: " .. slot.name)
    saleStep = 3
    local roll = math.random(1, 100)
    local reject = roll <= Cfg.Selling.rejectChance
    local robbery = false
    if reject then robbery = math.random(1, 100) <= Cfg.Selling.robberyChance end
    local isDead = IsEntityDead(entities.customer)
    if isDead then Core.Framework.Notify(_L('customer_dead'), 'error') return TaskStreetSale(slot) end
    local animDict, animName = 'mp_common', 'givetake1_a'
    local animDict2, animName2 = 'weapons@holster_fat_2h', 'holster'
    local drugProp, moneyProp = 'prop_meth_bag_01', 'prop_anim_cash_note'
    TaskTurnPedToFaceEntity(cache.ped, entities.customer, 500)
    SetTimeout(500, function()
        entities.drugs = Core.Natives.CreateProp(drugProp, GetEntityCoords(cache.ped), 0.0, true)
        entities.money = Core.Natives.CreateProp(moneyProp, GetEntityCoords(entities.customer), 0.0, true)
        AttachEntityToEntity(entities.drugs, cache.ped, 90, 0.07, 0.01, -0.01, 136.33, 50.23, -50.26, true, true, false, true, 1, true)
        AttachEntityToEntity(entities.money, entities.customer, GetPedBoneIndex(entities.customer, 28422), 0.07, 0, -0.01, 18.12, 7.21, -12.44, true, true, false, true, 1, true)
        Core.Natives.PlayAnim(cache.ped, animDict, animName, -1, 32, 0.0)
        Core.Natives.PlayAnim(entities.customer, animDict, animName, -1, 32, 0.0)
        Wait(1500)
        AttachEntityToEntity(entities.drugs, entities.customer, GetPedBoneIndex(entities.customer, 28422), 0.07, 0.01, -0.01, 136.33, 50.23, -50.26, true, true, false, true, 1, true)
        AttachEntityToEntity(entities.money, cache.ped, 90, 0.07, 0, -0.01, 18.12, 7.21, -12.44, true, true, false, true, 1, true)
        Core.Natives.PlayAnim(cache.ped, animDict2, animName2, 500, 32, 0.0)
        Core.Natives.PlayAnim(entities.customer, animDict2, animName2, 500, 32, 0.0)
        DeleteEntity(entities.drugs)
        DeleteEntity(entities.money)
        if not reject then
            local playerNetId = NetworkGetNetworkIdFromEntity(cache.ped)
            local customerNetId = NetworkGetNetworkIdFromEntity(entities.customer)
            
            clientLog("About to call streetSale server callback...")
            local paid, quantity, pay = lib.callback.await('r_drugsales:streetSale', false, playerNetId, customerNetId, slot)
            clientLog("streetSale callback result: paid=" .. tostring(paid) .. ", quantity=" .. tostring(quantity) .. ", pay=" .. tostring(pay))
            
            if not paid then 
                clientLog("Street sale FAILED!")
                Core.Framework.Notify("Sale failed - You don't have enough drugs to sell!", 'error')
                return CancelSelling() 
            end
            
            Core.Framework.Notify(_L('sold_drugs', quantity, slot.label, pay), 'success')
            PlayPedAmbientSpeechNative(entities.customer, 'Generic_Thanks', 'Speech_Params_Force')
            
            -- INSTANT CUSTOMER CLEANUP & PROPER DESPAWN
            clientLog("Despawning customer after successful sale")
            Core.Target.RemoveLocalEntity(entities.customer)
            SetEntityAsMissionEntity(entities.customer, false, true)  -- Allow deletion
            DeleteEntity(entities.customer)
            entities.customer = nil
            
            -- RESET STATE AND CONTINUE SELLING IMMEDIATELY
            saleStep = 0
            clientLog("Street sale SUCCESS - Customer despawned, looking for next customer...")
            
            -- Continue selling automatically without resetting state.sellingDrugs
            return TaskStreetSale(slot)
        elseif reject and not robbery then
            local roll = math.random(1, 100)
            if roll <= Cfg.Dispatch.reportOdds then TriggerDispatch() end
            Core.Framework.Notify(_L('rejected_sale'), 'error')
            PlayPedAmbientSpeechNative(entities.customer, 'Generic_Insult_High', 'Speech_Params_Force')
            
            -- INSTANT CUSTOMER CLEANUP & PROPER DESPAWN
            clientLog("Despawning customer after rejected sale")
            Core.Target.RemoveLocalEntity(entities.customer)
            SetEntityAsMissionEntity(entities.customer, false, true)  -- Allow deletion
            DeleteEntity(entities.customer)
            entities.customer = nil
            saleStep = 0
            
            clientLog("Sale rejected - Customer despawned, looking for next customer...")
            return TaskStreetSale(slot)
        elseif reject and robbery then
            local robbed, quantity = lib.callback.await('r_drugsales:robPlayer', false, slot)
            if not robbed then return CancelSelling() end
            clientLog("Robbery initiated")
            initiateRobbery(slot, quantity)
        end
    end)
end

local function setupStreetSale(slot)
    clientLog("setupStreetSale called")
    
    -- Stop the customer from running and make them stand still
    ClearPedTasks(entities.customer)
    TaskStandStill(entities.customer, -1)
    SetPedMoveRateOverride(entities.customer, 1.0)  -- Reset to normal speed
    
    Core.Target.AddLocalEntity(entities.customer, {
        {
            label = _L('sell_drug', slot.label),
            icon = 'fas fa-joint',
            iconColor = 'white',
            onSelect = function()
                clientLog("Street sale target CLICKED!")
                Core.Target.RemoveLocalEntity(entities.customer)
                initiateStreetSale(slot)
            end
        }
    })
    PlayPedAmbientSpeechNative(entities.customer, 'Generic_Hows_It_Going', 'Speech_Params_Force')
    saleStep = 2
    clientLog("Customer ready for street sale, target added")
    while state.sellingDrugs and saleStep == 2 do
        local pCoords = GetEntityCoords(cache.ped)
        local cCoords = GetEntityCoords(entities.customer)
        local cDistance = #(pCoords - cCoords)
        TaskStandStill(entities.customer, 1000)  -- Keep them standing still
        if cDistance >= 30.0 then Core.Framework.Notify(_L('too_far'), 'error') return CancelSelling() end
        Wait(100)
    end
end

function TaskStreetSale(slot)
    clientLog("TaskStreetSale called")
    
    -- Check if player still has the drugs before calling next customer
    local playerItems = lib.callback.await('r_drugsales:getPlayerItems', false)
    local stillHasDrugs = false
    for _, item in pairs(playerItems) do
        if item.name == slot.name and item.count > 0 then
            stillHasDrugs = true
            break
        end
    end
    
    if not stillHasDrugs then
        clientLog("Player ran out of " .. slot.name .. " - stopping sales")
        Core.Framework.Notify("You ran out of " .. slot.label .. " to sell!", 'error')
        
        -- Clean up any phone that might be in hand
        if entities.phone then
            clientLog("Cleaning up phone - ran out of drugs")
            DeleteEntity(entities.phone)
            entities.phone = nil
        end
        
        state.sellingDrugs = false
        return
    end
    
    -- Show "calling next customer" notification with phone animation
    Core.Framework.Notify("Calling next customer...", 'info')
    entities.phone = Core.Natives.CreateProp('prop_prologue_phone', vec3(0, 0, 0), 0, true)
    AttachEntityToEntity(entities.phone, cache.ped, GetPedBoneIndex(cache.ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    Core.Natives.PlayAnim(cache.ped, 'cellphone@', 'cellphone_call_listen_base', 2000, 48, 0.0)
    
    -- SIMPLE FIX: Use integer math.random only
    local waitSeconds = math.random(Cfg.Selling.pedFrequency[1], Cfg.Selling.pedFrequency[2])
    local wait = waitSeconds * 1000  -- Convert to milliseconds
    
    local startCoords = GetEntityCoords(cache.ped)
    local customerModel = Cfg.Peds.streetPeds[math.random(#Cfg.Peds.streetPeds)]
    
    -- SPAWN IN FRONT OF PLAYER at realistic distance (25-40 units)
    local spawnDistance = math.random(25, 40)
    local playerCoords = GetEntityCoords(cache.ped)
    local playerHeading = GetEntityHeading(cache.ped)
    
    -- Calculate spawn position in front of player using trigonometry
    local radians = math.rad(playerHeading)
    local customerCoords = vec3(
        playerCoords.x + (math.sin(radians) * spawnDistance),
        playerCoords.y + (math.cos(radians) * spawnDistance),
        playerCoords.z
    )
    
    -- Make customer face toward player
    local customerHeading = playerHeading + 180.0
    if customerHeading > 360 then customerHeading = customerHeading - 360 end
    
    clientLog("Customer will spawn in " .. waitSeconds .. " seconds, " .. spawnDistance .. " units in front of player")
    
    SetTimeout(wait, function()
        -- End phone animation and clean up phone
        Core.Natives.PlayAnim(cache.ped, 'cellphone@', 'cellphone_call_out', 1000, 17, 0.0)
        SetTimeout(500, function()
            if entities.phone then
                clientLog("Cleaning up street sale phone after call")
                DeleteEntity(entities.phone)
                entities.phone = nil
            end
        end)
        
        if not state.sellingDrugs then return end
        
        -- ALWAYS SPAWN NEW PED IN FRONT OF PLAYER
        clientLog("Spawning new customer: " .. customerModel)
        
        -- Ensure spawn position is on ground level
        local groundZ = customerCoords.z
        local foundGround, groundHeight = GetGroundZFor_3dCoord(customerCoords.x, customerCoords.y, customerCoords.z + 10.0, false)
        if foundGround then
            groundZ = groundHeight
        end
        
        -- Create customer at proper ground level
        local finalSpawnCoords = vec3(customerCoords.x, customerCoords.y, groundZ)
        entities.customer = Core.Natives.CreateNpc(customerModel, finalSpawnCoords, customerHeading, true)
        
        while not DoesEntityExist(entities.customer) do Wait(100) end
        
        -- Set ped properties for proper spawning and realistic appearance
        SetEntityAsMissionEntity(entities.customer, true, true)
        SetPedRandomComponentVariation(entities.customer, false)
        SetPedRandomProps(entities.customer)
        SetPedCanRagdoll(entities.customer, true)
        SetEntityMaxHealth(entities.customer, 200)
        SetEntityHealth(entities.customer, 200)
        
        saleStep = 1
        
        -- Calculate actual distance for notification
        local actualDistance = #(GetEntityCoords(cache.ped) - GetEntityCoords(entities.customer))
        clientLog("Customer spawned successfully at " .. math.floor(actualDistance) .. "m in front of player")
        
        -- Notify player that customer is on the way
        Core.Framework.Notify("Customer spotted you from " .. math.floor(actualDistance) .. "m ahead!", 'info')
        
        -- Make customer run to player
        SetPedMoveRateOverride(entities.customer, 2.0)  -- Set to running speed
        
        while state.sellingDrugs and saleStep == 1 do
            local pCoords = GetEntityCoords(cache.ped)
            local cCoords = GetEntityCoords(entities.customer)
            local cDistance = #(pCoords - cCoords)
            local sDistance = #(pCoords - startCoords)
            
            -- MAKE CUSTOMER RUN - increased speed from 1.4 to 2.5 (running)
            TaskGoToEntity(entities.customer, cache.ped, -1, 1.5, 2.5, 1073741824, 0)
            
            -- Show distance notification when customer is approaching from far away
            if cDistance <= 15 and cDistance > 4 then
                if math.random(1, 30) == 1 then  -- Only show occasionally to avoid spam
                    Core.Framework.Notify("Customer approaching from " .. math.floor(cDistance) .. "m away...", 'info')
                end
            end
            
            if sDistance >= 25.0 then Core.Framework.Notify(_L('too_far'), 'error') return CancelSelling() end
            if cDistance <= 4.0 then  -- Increased from 2.0 to 4.0 since they spawn farther
                Core.Framework.Notify("Customer arrived! Click to sell.", 'success')
                setupStreetSale(slot) 
                return 
            end
            Wait(100)
        end
    end)
end

local function initializeStreetSelling()
    clientLog("initializeStreetSelling called")
    if IsPedInAnyVehicle(cache.ped, false) then 
        -- Clean up dealer menu phone before showing error
        if entities.phone then
            DeleteEntity(entities.phone)
            entities.phone = nil
        end
        Core.Framework.Notify(_L('no_vehicle'), 'error') 
        return CloseDealerMenu() 
    end
    
    if not state.inSellZone then
        PlaySound(-1, 'Click_Fail', 'WEB_NAVIGATION_SOUNDS_PHONE', false, 0, true)
        
        -- Clean up dealer menu phone before showing error
        if entities.phone then
            DeleteEntity(entities.phone)
            entities.phone = nil
        end
        
        Core.Framework.Notify(_L('no_zone'), 'error') 
        return CloseDealerMenu()
    end
    
    local playerItems = lib.callback.await('r_drugsales:getPlayerItems', false)
    clientLog("Got " .. #playerItems .. " items for street sale")
    
    -- Check if player has any sellable drugs
    local hasSellableDrugs = false
    for _, slot in pairs(playerItems) do
        if Cfg.Selling.drugs[slot.name] and slot.count > 0 then
            clientLog("Found sellable drug: " .. slot.name .. " x" .. slot.count)
            PlaySound(-1, 'Menu_Accept', 'Phone_SoundSet_Default', false, 0, true)
            Core.Framework.Notify(_L('wait_for_customer'), 'info')
            state.sellingDrugs = true
            clientLog("Starting street sale process")
            CloseDealerMenu()
            hasSellableDrugs = true
            return TaskStreetSale(slot)
        end
    end
    
    -- No sellable drugs found - notify player and close menu
    if not hasSellableDrugs then
        clientLog("No sellable drugs found!")
        PlaySound(-1, 'Click_Fail', 'WEB_NAVIGATION_SOUNDS_PHONE', false, 0, true)
        Core.Framework.Notify("You don't have any drugs to sell!", 'error')
        
        -- Clean up dealer menu phone before closing
        if entities.phone then
            clientLog("Cleaning up dealer menu phone - no drugs")
            DeleteEntity(entities.phone)
            entities.phone = nil
        end
        
        CloseDealerMenu()
    end
end

local function openDealerMenu() 
    clientLog("openDealerMenu called")
    entities.phone = Core.Natives.CreateProp('prop_prologue_phone', vec3(0, 0, 0), 0, true)
    while not DoesEntityExist(entities.phone) do print('spawning phone') Wait(100) end
    AttachEntityToEntity(entities.phone, cache.ped, GetPedBoneIndex(cache.ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    Core.Natives.PlayAnim(cache.ped, 'cellphone@', 'cellphone_text_in', 750, 17, 0.0)
    SetTimeout(750, function()
        Core.Natives.PlayAnim(cache.ped, 'cellphone@', 'cellphone_text_read_base', -1, 17, 0.0)
        PlaySound(-1, 'Click_Special', 'WEB_NAVIGATION_SOUNDS_PHONE', false, 0, true)
        lib.showContext('dealermenu')
    end)
end

local function initializeDealerMenu()
    clientLog("initializeDealerMenu called")
    local isCop = lib.callback.await('r_drugsales:checkIfPolice', false)
    local copCount = lib.callback.await('r_drugsales:getPoliceOnline', false)
    clientLog("Cop check: " .. tostring(isCop) .. ", cop count: " .. copCount)
    if isCop then Core.Framework.Notify(_L('no_narcs'), 'error') return end
    if state.sellingDrugs then Core.Framework.Notify(_L('already_selling'), 'error') return end
    if copCount < Cfg.Selling.minPolice then Core.Framework.Notify(_L('no_police'), 'error') return end
    lib.registerContext({
        id = 'dealermenu',
        title = _L('dealer_menu'),
        onExit = CloseDealerMenu,
        options = {
            {
                title = _L('street_sales'),
                description = _L('street_sales_desc'),
                icon = 'fas fa-joint',
                onSelect = function()
                    clientLog("Street sales option SELECTED")
                    initializeStreetSelling()
                end
            },
            {
                title = _L('bulk_sales'),
                description = _L('bulk_sales_desc'),
                icon = 'fas fa-box',
                onSelect = function()
                    clientLog("Bulk sales option SELECTED")
                    initializeBulkSale()
                end
            }
        }
    })
    clientLog("Dealer menu registered, opening...")
    openDealerMenu()
end

RegisterNetEvent('r_drugsales:openDealerMenu', function()
    clientLog("r_drugsales:openDealerMenu event received")
    initializeDealerMenu()
end)

-- ADD COMMAND TO STOP SELLING
RegisterCommand('stopselling', function()
    clientLog("Stop selling command used")
    CancelSelling()
    Core.Framework.Notify('Stopped selling drugs', 'info')
end, false)

function CloseDealerMenu()
    clientLog("CloseDealerMenu called")
    PlaySound(-1, 'CLICK_BACK', 'WEB_NAVIGATION_SOUNDS_PHONE', false, 0, true)
    Core.Natives.PlayAnim(cache.ped, 'cellphone@', 'cellphone_text_out', 750, 17, 0.0)
    SetTimeout(750, function()
        -- Make sure to delete the dealer menu phone
        if entities.phone then
            clientLog("Removing dealer menu phone from hand")
            DeleteEntity(entities.phone)
            entities.phone = nil
        end
    end)
end

function CancelSelling()
    clientLog("CancelSelling called - Cleaning up spawned entities")
    state.sellingDrugs = false
    
    -- Clean up spawned customer
    if entities.customer then
        clientLog("Despawning customer entity")
        Core.Target.RemoveLocalEntity(entities.customer)
        SetEntityAsMissionEntity(entities.customer, false, true)  -- Allow deletion
        DeleteEntity(entities.customer)
        entities.customer = nil
    end
    
    -- Clean up any phone entities (dealer menu phone or street sale phone)
    if entities.phone then
        clientLog("Despawning phone entity")
        DeleteEntity(entities.phone)
        entities.phone = nil
    end
    
    -- Clean up bag entity (for bulk sales)
    if entities.bag then
        clientLog("Despawning bag entity")
        SetEntityAsNoLongerNeeded(entities.bag)
        DeleteEntity(entities.bag)
        entities.bag = nil
    end
    
    -- Clean up drug/money props
    if entities.drugs then
        clientLog("Despawning drugs prop")
        DeleteEntity(entities.drugs)
        entities.drugs = nil
    end
    
    if entities.money then
        clientLog("Despawning money prop")
        DeleteEntity(entities.money)
        entities.money = nil
    end
    
    if entities.cash then
        clientLog("Despawning cash prop")
        DeleteEntity(entities.cash)
        entities.cash = nil
    end
    
    saleStep = 0
    Core.Natives.SetGpsRoute(false)
    Core.Natives.RemoveBlip(meetBlip)
    clientLog("All entities cleaned up successfully")
end

-- GetNearbyPed function removed - no longer needed since we always spawn new peds

CreateThread(function()
    if Cfg.Zones.enabled then
        for _, coords in pairs(Cfg.Zones.zoneCoords) do
            lib.zones.poly({
                points = coords,
                thickness = 50,
                onEnter = function()
                    state.inSellZone = true
                    clientLog("Entered sell zone")
                end,
                onExit = function()
                    state.inSellZone = false
                    clientLog("Exited sell zone")
                end,
                debug = Cfg.Debug
            })
        end
    else 
        state.inSellZone = true 
        clientLog("Sell zones disabled, always in sell zone")
    end 
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        clientLog("Resource stopping - cleaning up all spawned entities")
        CancelSelling()
        state.inSellZone = false
        
        -- Clean up any remaining entities with comprehensive cleanup
        for entityType, entity in pairs(entities) do
            if DoesEntityExist(entity) then
                clientLog("Cleaning up remaining entity: " .. entityType)
                SetEntityAsMissionEntity(entity, false, true)
                DeleteEntity(entity)
            end
        end
        
        -- Extra cleanup for common entity types that might get stuck
        local entityTypes = {'phone', 'customer', 'bag', 'drugs', 'money', 'cash'}
        for _, entityType in pairs(entityTypes) do
            if entities[entityType] and DoesEntityExist(entities[entityType]) then
                clientLog("Force cleaning entity: " .. entityType)
                DeleteEntity(entities[entityType])
            end
        end
        
        -- Clear entities table
        entities = {}
        clientLog("All spawned entities cleaned up on resource stop")
    end
end)

clientLog("r_drugsales client loaded successfully")