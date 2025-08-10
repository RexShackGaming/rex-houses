local RSGCore = exports['rsg-core']:GetCoreObject()
local doorLockPrompt = GetRandomIntInRange(0, 0xffffff)
local lockPrompt = nil
local DoorID = nil
local HouseID = nil
local myhouse = nil
local HouseBlip = nil
local blipchecked = false
local checked = false
local doorStatus = '~e~Locked~q~'
local createdEntries = {}
local doorLists = {}
local currenthouseshop = nil
local OwnedHouseBlips = {}
local HouseBlips = {}
lib.locale()

RegisterNetEvent('rex-houses:client:UpdateHouseBlips', function(ownedHouses)
    -- Clear existing blips
    for _, blip in pairs(houseBlips) do
        RemoveBlip(blip)
    end
    houseBlips = {}
    -- Create new blips for all owned houses
    for houseId, ownerName in pairs(ownedHouses) do
        local houseCoords = GetHouseCoords(houseId) -- Replace with a function to get house coordinates
        if houseCoords then
            local blip = AddBlipForCoord(houseCoords.x, houseCoords.y, houseCoords.z)
            SetBlipSprite(blip, 40) -- Green house icon
            SetBlipColour(blip, 2) -- Green color
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(ownerName .. "'s House") -- Display owner name
            EndTextCommandSetBlipName(blip)
            houseBlips[houseId] = blip
        end
    end
end)

local function UpdateHouseBlips(ownedHouses)
    -- Remove all existing blips
    for _, blipData in pairs(HouseBlips) do
        if blipData.handle and DoesBlipExist(blipData.handle) then
            RemoveBlip(blipData.handle)
        end
    end
    HouseBlips = {}
    -- Get current player's data
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local playerCitizenId = PlayerData.citizenid
    
    -- Create new blips for all houses
    for _, house in ipairs(Config.Houses) do
        if house.showblip and house.blipcoords then
            local blip = BlipAddForCoords(1664425300, house.blipcoords)
            if blip then
                local isOwned = ownedHouses[house.houseid] ~= nil
                local ownerInfo = isOwned and ownedHouses[house.houseid] or nil
                local isOwnedByPlayer = isOwned and ownerInfo.citizenid == playerCitizenId

                -- Set blip properties based on ownership
                if isOwned then
                    if isOwnedByPlayer then
                        -- Player's own house - Green
                        SetBlipSprite(blip, joaat('blip_proc_home_locked'), true)
                        BlipAddModifier(blip, joaat('BLIP_MODIFIER_MP_COLOR_8'))
                        -- Use player's name for their own house
                        local playerName = string.format("%s's House", ownerInfo.owner or PlayerData.charinfo.firstname.." "..PlayerData.charinfo.lastname)
                        SetBlipName(blip, playerName)
                    else
                        -- Other player's house - Yellow
                        SetBlipSprite(blip, joaat('blip_proc_home_locked'), true)
                        BlipAddModifier(blip, joaat('BLIP_MODIFIER_MP_COLOR_4'))
                        -- Use the owner's name from the ownedHouses table
                        local ownerName = string.format("%s's House", ownerInfo.owner or "Unknown Owner")
                        SetBlipName(blip, ownerName)
                    end
                else
                    -- Available house - White
                    SetBlipSprite(blip, joaat('blip_proc_home'), true)
                    BlipAddModifier(blip, joaat('BLIP_MODIFIER_MP_COLOR_1'))
                    SetBlipName(blip, "Available: " .. (house.name or "Property"))
                end

                HouseBlips[house.houseid] = { type = "BLIP", handle = blip }
            end
        end
    end
end

RegisterNetEvent('rex-houses:client:SyncOwnedHouses', function(ownedHouses)
    UpdateHouseBlips(ownedHouses)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Request initial house data from server
        TriggerServerEvent('rex-houses:server:RequestOwnedHouses')
    end
end)

---------------------------------------
-- door lock / unlock animation
---------------------------------------
local UnlockAnimation = function()
    local ped = PlayerPedId()
    local boneIndex = GetEntityBoneIndexByName(ped, "SKEL_R_Finger12")
    local dict = "script_common@jail_cell@unlock@key"

    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)

        while not HasAnimDictLoaded(dict) do
            Citizen.Wait(10)
        end
    end

    local prop = CreateObject("P_KEY02X", GetEntityCoords(ped) + vec3(0, 0, 0.2), true, true, true)

    TaskPlayAnim(ped, "script_common@jail_cell@unlock@key", "action", 8.0, -8.0, 2500, 31, 0, true, 0, false, 0, false)
    Wait(750)
    AttachEntityToEntity(prop, ped, boneIndex, 0.02, 0.0120, -0.00850, 0.024, -160.0, 200.0, true, true, false, true, 1, true)

    while IsEntityPlayingAnim(ped, "script_common@jail_cell@unlock@key", "action", 3) do
        Wait(100)
    end

    DeleteObject(prop)
end

---------------------------------------
-- door prompt
---------------------------------------
local DoorLockPrompt = function()
    local str = locale('cl_lang_1')
    local stra = CreateVarString(10, 'LITERAL_STRING', str)

    lockPrompt = PromptRegisterBegin()
    PromptSetControlAction(lockPrompt, RSGCore.Shared.Keybinds['ENTER'])
    PromptSetText(lockPrompt, stra)
    PromptSetEnabled(lockPrompt, 1)
    PromptSetVisible(lockPrompt, 1)
    PromptSetHoldMode(lockPrompt, true)
    PromptSetGroup(lockPrompt, doorLockPrompt)
    PromptRegisterEnd(lockPrompt)

    createdEntries[#createdEntries + 1] = {type = "nPROMPT", handle = lockPrompt}
    createdEntries[#createdEntries + 1] = {type = "nPROMPT", handle = doorLockPrompt}
end

---------------------------------------
-- real estate agent blips
---------------------------------------
 CreateThread(function()
    for i = 1, #Config.EstateAgents do
        local agent = Config.EstateAgents[i]
        if agent.showblip then
            local AgentBlip = BlipAddForCoords(1664425300, agent.coords)
            local blipSprite = joaat(Config.Blip.blipSprite)

            SetBlipSprite(AgentBlip, blipSprite, true)
            SetBlipScale(AgentBlip, Config.Blip.blipScale)
            SetBlipName(AgentBlip, Config.Blip.blipName)

            createdEntries[#createdEntries + 1] = {type = "BLIP", handle = AgentBlip}
        end
    end
end)

-----------------------------------------------------------------------
-- house my house blip
-----------------------------------------------------------------------
local SetHouseBlips = function()
    RSGCore.Functions.TriggerCallback('rex-houses:server:GetOwnedHouseInfo', function(result)
        local houseid = result[1].houseid
        local playerName = result[1].fullname -- Get the player's full name
        myhouse = houseid

        for i = 1, #Config.Houses do
            local house = Config.Houses[i]

            if house.houseid == myhouse then
                local HouseBlip = BlipAddForCoords(1664425300, house.blipcoords)
                SetBlipSprite(HouseBlip, joaat('blip_proc_home_locked'), true)
                SetBlipScale(HouseBlip, 0.4)
                SetBlipName(HouseBlip, playerName) -- Set the player's name as the blip name
                BlipAddModifier(HouseBlip, joaat('BLIP_MODIFIER_MP_COLOR_8'))

                createdEntries[#createdEntries + 1] = {type = "BLIP", handle = HouseBlip}
            end
        end
    end)
end


Citizen.CreateThread(function()
    for _, v in pairs(Config.Houses) do
        if not Config.OwnedHouseBlips and v.showblip then
            HouseBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v.blipcoords)
            SetBlipSprite(HouseBlip, `blip_proc_home`, true)
            SetBlipScale(HouseBlip, 0.1)
            BlipAddModifier(HouseBlip, joaat('BLIP_MODIFIER_MP_COLOR_1'))
            Citizen.InvokeNative(0x9CB1A1623062F402, HouseBlip, v.name)
            createdEntries[#createdEntries + 1] = {type = "BLIP", handle = HouseBlip}
        end
    end
end)

--------------------------------------
-- set house blips on player load
--------------------------------------
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    SetHouseBlips()
end)

---------------------------------
-- update blips every min
---------------------------------
CreateThread(function()
    while true do
        SetHouseBlips()
        Wait(10000) -- every min
    end       
end)

---------------------------------------
-- get door state from database and set
---------------------------------------
CreateThread(function()
    while true do
        checked = false

        RSGCore.Functions.TriggerCallback('rex-houses:server:GetDoorState', function(results)
            for i = 1, #results do
                local door = results[i]
                Citizen.InvokeNative(0xD99229FE93B46286, tonumber(door.doorid), 1, 1, 0, 0, 0, 0) -- AddDoorToSystemNew
                Citizen.InvokeNative(0x6BAB9442830C7F53, tonumber(door.doorid), door.doorstate) -- DoorSystemSetDoorState
            end
        end)

        Wait(10000)
    end
end)

---------------------------------------
-- get specific door state from database
---------------------------------------
CreateThread(function()
    local ped = PlayerPedId()
    DoorLockPrompt()
    while true do
        ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        local t = 1000
        for i = 1, #Config.HouseDoors do
            local house = Config.HouseDoors[i]
            local distance = #(playerCoords - house.doorcoords)
            if distance < 2.0 then
                t = 4
                HouseID = house.houseid
                DoorID = house.doorid

                if Config.Debug then
                    print("")
                    print("House ID: "..HouseID)
                    print("Door ID: "..DoorID)
                    print("")
                end
                if not checked then
                    TriggerServerEvent('rex-houses:server:GetSpecificDoorState', DoorID)
                    checked = true
                end

                 local label = CreateVarString(10, 'LITERAL_STRING', house.name..': '..doorStatus)

                PromptSetActiveGroupThisFrame(doorLockPrompt, label)

                if PromptHasHoldModeCompleted(lockPrompt) then
                    TriggerEvent("rex-houses:client:toggledoor", DoorID, HouseID)
                    t = 1000
                    checked = false
                end
            end
        end
        Wait(t)
    end
end)

---------------------------------------
-- house menu prompt
---------------------------------------
CreateThread(function()
    for i = 1, #Config.Houses do
        local house = Config.Houses[i]

        exports['rsg-core']:createPrompt(house.houseprompt, house.menucoords, RSGCore.Shared.Keybinds['J'], locale('cl_lang_15'),
        {
            type = 'client',
            event = 'rex-houses:client:housemenu',
            args = {house.houseid},
        })

        createdEntries[#createdEntries + 1] = {type = "PROMPT", handle = house.houseprompt}
    end
end)

---------------------------------------
-- get door state
---------------------------------------
RegisterNetEvent('rex-houses:client:GetSpecificDoorState', function(id, state)
    DoorID = id
    local doorstate = state

    if doorstate == 1 then
        doorStatus = locale('cl_lang_2')
    else
        doorStatus = locale('cl_lang_3')
    end
end)

---------------------------------------
-- real estate agent menu
---------------------------------------
RegisterNetEvent('rex-houses:client:agentmenu', function(location)
    lib.registerContext({
        id = "estate_agent_menu",
        title = locale('cl_lang_4'),
        options = {
                {   title = locale('cl_lang_4'),
                    icon = 'fa-solid fa-user',
                    description = locale('cl_lang_5'),
                    event = 'rex-houses:client:buymenu',
                    arrow = true,
                    args = { 
                        isServer = false,
                        agentlocation = location }
                },
                {   title = locale('cl_lang_6'),
                    icon = 'fa-solid fa-user',
                    description = locale('cl_lang_7'),
                    event = 'rex-houses:client:sellmenu',
                    arrow = true,
                    args = { 
                        isServer = false,
                        agentlocation = location }
                }
            }
        })
    lib.showContext("estate_agent_menu")
end)

RegisterNetEvent('rex-houses:client:UpdateHouseBlip', function(houseId, playerName)
    for i = 1, #Config.Houses do
        local house = Config.Houses[i]

        if house.houseid == houseId then
            -- Update the blip name
            if house.blipcoords then
                local houseBlip = BlipAddForCoords(1664425300, house.blipcoords)
                SetBlipSprite(houseBlip, joaat('blip_proc_home_locked'), true)
                SetBlipScale(houseBlip, 0.4)
                SetBlipName(houseBlip, playerName) -- Set the player's name as the blip name
                BlipAddModifier(houseBlip, joaat('BLIP_MODIFIER_MP_COLOR_8'))

                createdEntries[#createdEntries + 1] = {type = "BLIP", handle = houseBlip}
            end
        end
    end
end)

---------------------------------------
-- buy house menu
---------------------------------------
RegisterNetEvent('rex-houses:client:buymenu', function(data)
    local houseContextOptions = {
        {
            title = locale('cl_lang_8'),
            isMenuHeader = true,
            icon = "fas fa-home"
        }
    }

    RSGCore.Functions.TriggerCallback('rex-houses:server:GetHouseInfo', function(cb)
        for i = 1, #cb do
            local house = cb[i]
            local agent = house.agent
            local houseid = house.houseid
            local owned = house.owned
            local price = house.price

            if agent == data.agentlocation and owned == 0 then
                houseContextOptions[#houseContextOptions + 1] = {
                    title = locale('cl_lang_9')..houseid,
                    icon = "fas fa-home",
                    description = locale('cl_lang_10')..house.price..locale('cl_lang_11')..Config.LandTaxPerCycle,
                    onSelect = function()
                        TriggerServerEvent('rex-houses:server:buyhouse', {
                            house = houseid,
                            price = price,
                            blip = HouseBlip
                        })
                    end
                }
            end
        end

        lib.registerContext({
            id = "context_buy_house_Id",
            title = locale('cl_lang_8'),
            options = houseContextOptions
        })

        lib.showContext("context_buy_house_Id")
    end)
end)

---------------------------------------
-- sell house menu
---------------------------------------
RegisterNetEvent('rex-houses:client:sellmenu', function(data)
    local sellContextOptions = {
        {
            title = locale('cl_lang_12'),
            isMenuHeader = true,
            icon = "fas fa-home"
        }
    }

    RSGCore.Functions.TriggerCallback('rex-houses:server:GetOwnedHouseInfo', function(cb)
        for i = 1, #cb do
            local house = cb[i]
            local agent = house.agent
            local houseid = house.houseid
            local owned = house.owned
            local sellprice = (house.price * Config.SellBack)

            if agent == data.agentlocation and owned == 1 then
                sellContextOptions[#sellContextOptions + 1] = {
                    title = locale('cl_lang_9')..houseid,
                    icon = "fas fa-home",
                    description = locale('cl_lang_13')..sellprice,
                    onSelect = function()
                        TriggerServerEvent('rex-houses:server:sellhouse', {
                            house = houseid,
                            price = sellprice,
                            blip = HouseBlip
                        })
                    end
                }
            end
        end

        lib.registerContext({
            id = "context_sell_house_Id",
            title = locale('cl_lang_12'),
            options = sellContextOptions
        })

        lib.showContext("context_sell_house_Id")
    end)
end)

---------------------------------------
-- lock / unlock door
---------------------------------------
RegisterNetEvent('rex-houses:client:toggledoor', function(door, house)
    RSGCore.Functions.TriggerCallback('rex-houses:server:GetHouseKeys', function(results)
        for i = 1, #results do
            local housekey = results[i]
            local playercitizenid = RSGCore.Functions.GetPlayerData().citizenid
            local resultcitizenid = housekey.citizenid
            local resulthouseid = housekey.houseid

            if resultcitizenid == playercitizenid and resulthouseid == house then
                RSGCore.Functions.TriggerCallback('rex-houses:server:GetCurrentDoorState', function(cb)
                    local doorstate = cb
                    if doorstate == 1 then
                        UnlockAnimation()
                        Citizen.InvokeNative(0xD99229FE93B46286, door, 1, 1, 0, 0, 0, 0) -- AddDoorToSystemNew
                        Citizen.InvokeNative(0x6BAB9442830C7F53, door, 0) -- DoorSystemSetDoorState
                        TriggerServerEvent('rex-houses:server:UpdateDoorState', door, 0)                                   
                        doorStatus = locale('cl_lang_3')
                    end

                    if doorstate == 0 then
                        UnlockAnimation()
                        Citizen.InvokeNative(0xD99229FE93B46286, door, 1, 1, 0, 0, 0, 0) -- AddDoorToSystemNew
                        Citizen.InvokeNative(0x6BAB9442830C7F53, door, 1) -- DoorSystemSetDoorState
                        TriggerServerEvent('rex-houses:server:UpdateDoorState', door, 1)
                        doorStatus = locale('cl_lang_2')
                    end
                end, door)
            end

            createdEntries[#createdEntries + 1] = {type = "DOOR", handle = door}
        end
    end)
end)

---------------------------------------
-- house storage
---------------------------------------
RegisterNetEvent('rex-houses:client:storage', function(data)
    local stashName = locale('cl_lang_14')..data.house
    local invWeight = Config.StorageMaxWeight
    local invSlots = Config.StorageMaxSlots
    TriggerServerEvent('rex-houses:server:openinventory', stashName, invWeight, invSlots)
end)

---------------------------------------
-- house menu
---------------------------------------
RegisterNetEvent('rex-houses:client:housemenu', function(houseid)
    RSGCore.Functions.TriggerCallback('rex-houses:server:GetHouseKeys', function(results)
        for i = 1, #results do
            local housekey = results[i]
            local playercitizenid = RSGCore.Functions.GetPlayerData().citizenid
            local citizenid = housekey.citizenid
            local houseids = housekey.houseid
            local guest = housekey.guest

            if citizenid == playercitizenid and houseids == houseid and guest == 0 then
                lib.registerContext(
                    {   id = 'house_menu',
                    title = locale('cl_lang_51'),
                    position = 'top-right',
                    options = {
                        {   title = locale('cl_lang_17'),
                            description = locale('cl_lang_18'),
                            icon = 'fas fa-glass-cheers',
                            event = 'rex-houses:client:guestmenu',
                            arrow = true,
                            args = { house = houseid },
                        },
                        {   title = locale('cl_lang_19'),
                            description = locale('cl_lang_20'),
                            icon = 'fas fa-dollar-sign',
                            event = 'rex-houses:client:creditmenu',
                            arrow = true,
                            args = { house = houseid },
                        },
                        {   title = locale('cl_lang_21'),
                            description = locale('cl_lang_22'),
                            icon = 'fas fa-box',
                            event = 'rex-houses:client:storage',
                            arrow = true,
                            args = { house = houseid },
                        },
                        {   title = locale('cl_lang_23'),
                            description = locale('cl_lang_24'),
                            icon = 'fas fa-hat-cowboy-side',
                            event = 'rsg-appearance:client:outfits',
                            arrow = true,
                            args = {}
                        },
                        {   title = locale('cl_lang_25'),
                            description = locale('cl_lang_26'),
                            icon = 'fa-solid fa-envelope',
                            event = 'rsg-prison:client:telegrammenu',
                            arrow = true,
                            args = {}
                        }
                    }
                })
                lib.showContext('house_menu')
            elseif citizenid == playercitizenid and houseids == houseid and guest == 1 then
                lib.registerContext(
                {   id = 'house_guest_menu',
                    title = locale('cl_lang_52'),
                    position = 'top-right',
                    options = {
                        {   title = locale('cl_lang_21'),
                            description = locale('cl_lang_22'),
                            icon = 'fas fa-box',
                            event = 'rex-houses:client:storage',
                            args = { house = houseid },
                        },
                        {   title = locale('cl_lang_23'),
                            description = locale('cl_lang_24'),
                            icon = 'fas fa-hat-cowboy-side',
                            event = 'rsg-appearance:client:outfits',
                            arrow = true,
                            args = {}
                        },
                        {   title = locale('cl_lang_25'),
                            description = locale('cl_lang_26'),
                            icon = 'fa-solid fa-envelope',
                            event = 'rsg-prison:client:telegrammenu',
                            arrow = true,
                            args = {}
                        }
                    }
                })
                lib.showContext('house_guest_menu')
            end
        end
    end)
end)

---------------------------------------
-- house credit menu
---------------------------------------
RegisterNetEvent('rex-houses:client:creditmenu', function(data)
    RSGCore.Functions.TriggerCallback('rex-houses:server:GetOwnedHouseInfo', function(result)
        local housecitizenid = result[1].citizenid
        local houseid = result[1].houseid
        local credit = result[1].credit
        local playercitizenid = RSGCore.Functions.GetPlayerData().citizenid

        if housecitizenid ~= playercitizenid then
            lib.notify({ title = locale('cl_lang_28'), type = 'error', duration = 5000 })
            return
        end

        if housecitizenid == playercitizenid then
            lib.registerContext({
                id = 'house_credit_menu',
                title = locale('cl_lang_29'),
                menu = "house_menu",
                icon = 'fas fa-home',
                position = 'top-right',
                options = {
                    {
                        title = locale('cl_lang_30') .. credit,
                        description = locale('cl_lang_31'),
                        icon = 'fas fa-dollar-sign',
                        args =
                            {   isServer = false,
                                houseid = houseid,
                                credit = credit
                            }
                    },
                    {
                        title = locale('cl_lang_32'),
                        description = locale('cl_lang_33'),
                        icon = 'fas fa-dollar-sign',
                        event = 'rex-houses:client:addcredit',
                        args =
                            {   isServer = false,
                                houseid = houseid,
                                credit = credit
                            }
                    },
                    {
                        title = locale('cl_lang_34'),
                        description =  locale('cl_lang_35'),
                        icon = 'fas fa-dollar-sign',
                        event = 'rex-houses:client:removecredit',
                        args = {
                            isServer = false,
                            houseid = houseid,
                            credit = credit
                        }
                    }
                }
            })

            lib.showContext('house_credit_menu')
        end
    end)
end) 

---------------------------------------
-- credit form
---------------------------------------
RegisterNetEvent('rex-houses:client:addcredit', function(data)
    local input = lib.inputDialog(locale('cl_lang_36'), {
        { 
            type = 'number',
            title = locale('cl_lang_37'),
            description = locale('cl_lang_38'),
            required = true,
            default = 50,
        },
    }, {
        allowCancel = true,
    })

    if input then
        local amount = tonumber(input[1])

        if Config.Debug == true then
            print(amount)
            print(data.houseid)
        end

        local newcredit = data.credit + amount
        TriggerServerEvent('rex-houses:server:addcredit', newcredit, amount, data.houseid)
    else
        if Config.Debug == true then
            print(locale('cl_lang_39'))
        end
    end
end)

---------------------------------------
-- remove house credit
---------------------------------------
RegisterNetEvent('rex-houses:client:removecredit', function(data)
    local input = lib.inputDialog(locale('cl_lang_40'), {
        { 
            type = 'number',
            title = locale('cl_lang_37'),
            description = locale('cl_lang_41'),
            required = true,
            default = 50,
        },
    }, {
        allowCancel = true,
    })

    if input then
        local amount = tonumber(input[1])

        if Config.Debug == true then
            print(amount)
            print(data.houseid)
        end

        local newcredit = data.credit - amount
        TriggerServerEvent('rex-houses:server:removecredit', newcredit, amount, data.houseid)
    else
        if Config.Debug == true then
            print(locale('cl_lang_39'))
        end
    end
end)

---------------------------------------
-- guest menu
---------------------------------------
RegisterNetEvent('rex-houses:client:guestmenu', function(data)
    RSGCore.Functions.TriggerCallback('rex-houses:server:GetOwnedHouseInfo', function(result)
        local housecitizenid = result[1].citizenid
        local houseid = result[1].houseid
        local playercitizenid = RSGCore.Functions.GetPlayerData().citizenid

        if housecitizenid ~= playercitizenid then
            lib.notify({ title = locale('cl_lang_28'), type = 'error', duration = 5000 })
            return
        end

        if housecitizenid == playercitizenid then
            lib.registerContext(
            {   id = 'house_addguest_menu',
                title = locale('cl_lang_16')..(' \n\"')..locale('cl_lang_9')..houseid..('\"'),
                menu = "house_menu",
                position = 'top-right',
                options = {
                    {   title = locale('cl_lang_42'),
                        description = locale('cl_lang_43'),
                        icon = 'fas fa-house',
                        event = 'rex-houses:client:addguest',
                        arrow = true,
                        args = { houseid = houseid, isServer = false, },
                    },
                    {   title = locale('cl_lang_44'),
                        description = locale('cl_lang_45'),
                        icon = 'fas fa-book',
                        event = 'rex-houses:client:removeguest',
                        arrow = true,
                        args = { houseid = houseid, isServer = false, },
                    },
                }
            })
            lib.showContext('house_addguest_menu')
        end
    end)
end)

---------------------------------------
-- Add House Guest
---------------------------------------
RegisterNetEvent('rex-houses:client:addguest', function(data)
    local upr = string.upper

    local input = lib.inputDialog(locale('cl_lang_46'), {
        {   type = 'input', 
            label = locale('cl_lang_47'), 
            required = true },
    })

    if not input then return end

    local addguest = input[1]
    local houseid = data.houseid

    if Config.Debug then
        print("")
        print("House ID: " .. houseid)
        print("Add Guest: " .. addguest)
        print("")
    end

    TriggerServerEvent('rex-houses:server:addguest', upr(addguest), houseid)
end)

---------------------------------------
-- Remove House Guest
---------------------------------------
RegisterNetEvent('rex-houses:client:removeguest', function(data)
    RSGCore.Functions.TriggerCallback('rex-houses:server:GetGuestHouseKeys', function(cb)
        local option = {}

        for i = 1, #cb do
            local guest = cb[i]
            local houseid = guest.houseid
            local citizenid = guest.citizenid

            if houseid == data.houseid then
                local content = { 
                    value = citizenid,
                    label = citizenid }
                option[#option + 1] = content
            end
        end

        if #option == 0 then
            lib.notify({ title = locale('cl_lang_48'), type = 'error', duration = 5000 })
            return
        end

        local input = lib.inputDialog(locale('cl_lang_49'), {
            {   type = 'select', 
                options = option, 
                required = true, 
                default = option[1].value }
        })

        if not input then return end

        local citizenid = input[1]

        if citizenid then
            local houseid = data.houseid
            TriggerServerEvent('rex-houses:server:removeguest', citizenid, houseid)
        end
    end)
end)

---------------------------------------
-- update door state on restart
---------------------------------------
AddEventHandler('onResourceStart', function(resource)
    TriggerServerEvent('rex-houses:server:UpdateDoorStateRestart')
end)

-- Request owned house blips on player load
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('rex-houses:server:RequestOwnedHouses')
end)


AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, blipData in pairs(HouseBlips) do
            if DoesBlipExist(blipData.handle) then
                RemoveBlip(blipData.handle)
            end
        end
    end
end)

---------------------------------------
-- Change House Price
---------------------------------------
RegisterNetEvent('rex-houses:client:priceupdate', function(data)
    if #data == 0 then
        lib.notify({ title = locale('cl_lang_50'), type = 'error', duration = 5000 })
        return
    end

    local input = lib.inputDialog(locale('cl_lang_54'), {
        {
            type = 'select',
            label = locale('cl_lang_55'),
            options = data,
            required = true,
            default = data[1].value,
            name = 'houseid'
        },
        {
            type = 'number',
            label = locale('cl_lang_56'),
            name = 'newprice',
            required = true,
            min = 1
        }
    })

    if not input then return end
    local houseid = input[1]
    local newprice = tonumber(input[2])

    TriggerServerEvent('rex-houses:server:handlePriceUpdate', { houseid = houseid, newprice = newprice })
end)

---------------------------------------
-- cleanup system
---------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for i = 1, #createdEntries do
        if createdEntries[i].type == "BLIP" then
            RemoveBlip(createdEntries[i].handle)
        end

        if createdEntries[i].type == "PROMPT" then
            exports['rsg-core']:deletePrompt(createdEntries[i].handle)
        end

        if createdEntries[i].type == "nPROMPT" then
            PromptDelete(createdEntries[i].handle)
            PromptDelete(createdEntries[i].handle)
        end

        if createdEntries[i].type == "DOOR" then
            Citizen.InvokeNative(0xD99229FE93B46286, createdEntries[i].handle, 1, 1, 0, 0, 0, 0) -- AddDoorToSystemNew
            Citizen.InvokeNative(0x6BAB9442830C7F53, createdEntries[i].handle, 1) -- DoorSystemSetDoorState

            TriggerServerEvent('rex-houses:server:UpdateDoorState', createdEntries[i].handle, 1)
        end
    end
end)
