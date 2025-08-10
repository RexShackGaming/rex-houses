local RSGCore = exports['rsg-core']:GetCoreObject()
local OwnedHouses = {}
lib.locale()

local function SyncOwnedHouses()
    local houses = MySQL.query.await('SELECT h.houseid, h.fullname, h.citizenid FROM rex_houses h WHERE h.owned = 1')
    
    local ownedHouses = {}
    for _, house in ipairs(houses) do
        if house.houseid and house.fullname ~= '0' then
            ownedHouses[house.houseid] = {
                owner = house.fullname,
                citizenid = house.citizenid
            }
        end
    end
    
    TriggerClientEvent('rex-houses:client:SyncOwnedHouses', -1, ownedHouses)
end

RegisterNetEvent('rex-houses:server:SyncAllHouses', function()
    local src = source
    local houses = MySQL.query.await('SELECT h.houseid, h.fullname, h.citizenid FROM rex_houses h WHERE h.owned = 1')
    
    local ownedHouses = {}
    for _, house in ipairs(houses) do
        if house.houseid and house.fullname ~= '0' then
            ownedHouses[house.houseid] = {
                owner = house.fullname,
                citizenid = house.citizenid
            }
        end
    end
    
    TriggerClientEvent('rex-houses:client:SyncOwnedHouses', -1, ownedHouses)
end)

RegisterNetEvent('rex-houses:server:UpdateOwnedHouse', function(houseId, playerName, citizenId)
    OwnedHouses[houseId] = {
        owner = playerName,
        citizenid = citizenId
    }
    SyncOwnedHouses()
end)

RegisterServerEvent('rex-houses:server:RequestOwnedHouses')
AddEventHandler('rex-houses:server:RequestOwnedHouses', function()
    local src = source
    TriggerClientEvent('rex-houses:client:SyncOwnedHouses', src, OwnedHouses)
end)

RegisterNetEvent('rex-houses:server:RemoveOwnedHouse', function(houseId)
    OwnedHouses[houseId] = nil
    SyncOwnedHouses()
end)

RSGCore.Functions.CreateCallback('rex-houses:server:GetOwnedHouses', function(source, cb)
    cb(OwnedHouses)
end)


AddEventHandler('playerConnecting', function()
    local src = source
    TriggerClientEvent('rex-houses:client:SyncOwnedHouses', src, OwnedHouses)
end)

-- get house keys
RSGCore.Functions.CreateCallback('rex-houses:server:GetHouseKeys', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid
    local housekeys = MySQL.query.await('SELECT * FROM rex_housekeys WHERE citizenid=@citizenid',{ ['@citizenid'] = citizenid })
    if housekeys[1] == nil then return end
    cb(housekeys)
end)

-- get house keys (guests)
RSGCore.Functions.CreateCallback('rex-houses:server:GetGuestHouseKeys', function(source, cb)
    local guestinfo = MySQL.query.await('SELECT * FROM rex_housekeys WHERE guest=@guest', {['@guest'] = 1})
    if guestinfo[1] == nil then return end
    cb(guestinfo)
end)

-- get house info
RSGCore.Functions.CreateCallback('rex-houses:server:GetHouseInfo', function(source, cb)
    local houseinfo = MySQL.query.await('SELECT * FROM rex_houses', {})
    if houseinfo[1] == nil then return end
    cb(houseinfo)
end)

-- get owned house info
RSGCore.Functions.CreateCallback('rex-houses:server:GetOwnedHouseInfo', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player == nil then return end
    local citizenid = Player.PlayerData.citizenid
    local houseinfo = MySQL.query.await('SELECT * FROM rex_houses WHERE citizenid=@citizenid AND owned=@owned', { ['@citizenid'] = citizenid, ['@owned'] = 1 })
    if houseinfo[1] == nil then return end
    cb(houseinfo)
end)

RegisterServerEvent('rex-houses:server:openinventory', function(stashName, invWeight, invSlots)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = {
        label = stashName,
        maxweight = invWeight,
        slots = invSlots
    }
    exports['rsg-inventory']:OpenInventory(src, stashName, data)
end)

-- buy house
RegisterServerEvent('rex-houses:server:buyhouse', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid
    local firstname = Player.PlayerData.charinfo.firstname
    local lastname = Player.PlayerData.charinfo.lastname
    local fullname = (firstname..' '..lastname)
    local housecount = MySQL.prepare.await('SELECT COUNT(*) FROM rex_houses WHERE citizenid = ?', {citizenid})

    if housecount >= 1 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_1'),
            description = locale('sv_lang_2'),
            type = 'error'
        })
        return
    end

    if (Player.PlayerData.money.cash < data.price) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_1'),
            description = locale('sv_lang_3'),
            type = 'error'
        })
        return
    end

    MySQL.update('UPDATE rex_houses SET citizenid = ?, fullname = ?, owned = ?, credit = ? WHERE houseid = ?',
    {   citizenid,
        fullname,
        1,
        Config.StartCredit,
        data.house
    })

    MySQL.insert('INSERT INTO rex_housekeys(citizenid, houseid) VALUES(@citizenid, @houseid)',
    {   ['@citizenid']  = citizenid,
        ['@houseid']    = data.house
    })

    Player.Functions.RemoveMoney('cash', data.price)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_lang_1'),
        description = locale('sv_lang_4'),
        type = 'success'
    })

    -- Update OwnedHouses with new ownership info
    OwnedHouses[data.house] = {
        owner = fullname,
        citizenid = citizenid
    }
    
    -- Broadcast the update to all clients
    TriggerClientEvent('rex-houses:client:SyncOwnedHouses', -1, OwnedHouses)
end)

-- sell house
RegisterServerEvent('rex-houses:server:sellhouse', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    MySQL.update('UPDATE rex_houses SET citizenid = 0, fullname = 0, credit = 0, owned = 0 WHERE houseid = ?', {data.house})
    MySQL.update('DELETE FROM rex_housekeys WHERE houseid = ?', {data.house})
    Player.Functions.AddMoney('cash', data.price, "house-sale")
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_lang_5'),
        description = locale('sv_lang_6'),
        type = 'success'
    })

    -- Remove house from OwnedHouses
    OwnedHouses[data.house] = nil
    SyncOwnedHouses()
end)


-- add house credit
RegisterNetEvent('rex-houses:server:addcredit', function(newcredit, removemoney, houseid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local cashBalance = Player.PlayerData.money["cash"]
        
    if cashBalance >= removemoney then
        Player.Functions.RemoveMoney('cash', removemoney)
        MySQL.update('UPDATE rex_houses SET credit = ? WHERE houseid = ?', {newcredit, houseid})
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_7'),
            description = locale('sv_lang_8')..houseid,
            type = 'success'
        })
        Wait(3000)
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_7'),
            description = locale('sv_lang_9')..newcredit,
            type = 'inform'
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_7'),
            description = locale('sv_lang_10'),
            type = 'error'
        })
    end
end)

-- remove house credit
RegisterNetEvent('rex-houses:server:removecredit', function(newcredit, removemoney, houseid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local cashBalance = Player.PlayerData.money['cash']
        
    if cashBalance >= removemoney then
        local updatedCredit = newcredit

        if updatedCredit < 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('sv_lang_7'),
                description = locale('sv_lang_11'),
                type = 'error'
            })
            return
        end

        Player.Functions.AddMoney('cash', removemoney)
        MySQL.update('UPDATE rex_houses SET credit = ? WHERE houseid = ?', {updatedCredit, houseid})
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_7'),
            description = locale('sv_lang_12')..houseid,
            type = 'success'
        })
        Wait(3000)
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_7'),
            description = locale('sv_lang_13')..updatedCredit,
            type = 'inform'
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_7'),
            description = locale('sv_lang_14'),
            type = 'error'
        })
    end
end)

--------------------------------------------------------------------------------------------------

-- get all door states
RSGCore.Functions.CreateCallback('rex-houses:server:GetDoorState', function(source, cb)
    local doorstate = MySQL.query.await('SELECT * FROM rex_doors', {})
    if doorstate[1] == nil then return end
    cb(doorstate)
end)

-- get current door state
RSGCore.Functions.CreateCallback('rex-houses:server:GetCurrentDoorState', function(source, cb, door)
    local result = MySQL.query.await('SELECT doorstate FROM rex_doors WHERE doorid = ?', {door})
    if result[1] == nil then return end
    cb(result[1].doorstate)
end)

-- get specific door state
RegisterNetEvent('rex-houses:server:GetSpecificDoorState', function(door)
    local src = source
    local result = MySQL.query.await('SELECT * FROM rex_doors WHERE doorid = ?', {door})

    if result[1] == nil then return end

    local doorid = result[1].doorid
    local doorstate = result[1].doorstate

    if Config.Debug then
        print("")
        print("Door ID: "..doorid)
        print("Door State: "..doorstate)
        print("")
    end

    TriggerClientEvent('rex-houses:client:GetSpecificDoorState', src, doorid, doorstate)
end)

-- update door state
RegisterNetEvent('rex-houses:server:UpdateDoorState', function(doorid, doorstate)
    local src = source

    MySQL.update('UPDATE rex_doors SET doorstate = ? WHERE doorid = ?', {doorstate, doorid})

    TriggerClientEvent('rex-houses:client:GetSpecificDoorState', src, doorid, doorstate)
end)

RegisterNetEvent('rex-houses:server:UpdateDoorStateRestart', function()
    local result = MySQL.query.await('SELECT * FROM rex_doors WHERE doorstate=@doorstate', {['@doorstate'] = 1})
    
    if not result then
        MySQL.update('UPDATE rex_doors SET doorstate = 1')
    end
end)

-- add house guest
RegisterNetEvent('rex-houses:server:addguest', function(cid, houseid)
    local src = source
    local keycount = MySQL.prepare.await('SELECT COUNT(*) FROM rex_housekeys WHERE citizenid = ? AND houseid = ?', {cid, houseid})

    if keycount >= 1 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_24'),
            description = locale('sv_lang_25'),
            type = 'error'
        })
        return
    end

    MySQL.insert('INSERT INTO rex_housekeys(citizenid, houseid, guest) VALUES(@citizenid, @houseid, @guest)',
    {   ['@citizenid']  = cid,
        ['@houseid']    = houseid,
        ['@guest']      = 1,
    })
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_lang_24'),
        description = cid..locale('sv_lang_26'),
        type = 'success'
    })
end)

RegisterNetEvent('rex-houses:server:removeguest', function(houseid, guestcid)
    local src = source
    MySQL.update('DELETE FROM rex_housekeys WHERE houseid = ? AND citizenid = ?', { houseid, guestcid })
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_lang_24'),
        description = guestcid..locale('sv_lang_27'),
        type = 'success'
    })
end)

RegisterNetEvent('rex-houses:server:OpenStorage', function(house)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then 
        print(locale('sv_lang_28'))
        return 
    end

    -- Check if player has access to this house
    local hasAccess = MySQL.query.await('SELECT COUNT(*) as count FROM rex_housekeys WHERE citizenid = ? AND houseid = ?', 
    {
        Player.PlayerData.citizenid,
        house
    })
    
    if not hasAccess then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_29'),
            description = locale('sv_lang_30'),
            type = 'error'
        })
        print(locale('sv_lang_31'))
        return
    end
    
    if hasAccess[1].count == 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_29'),
            description = locale('sv_lang_32'),
            type = 'error'
        })
        return
    end

    -- Define a unique stash ID for the house
    local stashId = "house_storage_" .. house   -- Unique identifier for each house stash
    local maxWeight = Config.StorageMaxWeight   -- Maximum weight for the stash
    local slots = Config.StorageMaxSlots        -- Number of slots for the stash

    -- Open the storage inventory with predefined weight and slots
    local data = { label = locale('sv_lang_29'), maxweight = maxWeight, slots = slots }
    exports['rsg-inventory']:OpenInventory(src, stashId, data)
end)

CreateThread(function()
    Wait(1000) -- Wait for database to be ready
    local houses = MySQL.query.await('SELECT houseid, fullname, citizenid FROM rex_houses WHERE owned = 1')
    
    for _, house in ipairs(houses) do
        if house.houseid and house.fullname ~= '0' then
            OwnedHouses[house.houseid] = {
                owner = house.fullname,
                citizenid = house.citizenid
            }
        end
    end
    
    print(locale('sv_lang_33') .. #houses .. locale('sv_lang_34'))
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    local src = source
    TriggerClientEvent('rex-houses:client:SyncOwnedHouses', src, OwnedHouses)
end)

---------------------------------------
-- Change House Price
---------------------------------------
RSGCore.Commands.Add('sethouseprices', locale('sv_lang_48'), {}, true, function(source, args)
    local src = source
    local houses = MySQL.query.await('SELECT houseid, price FROM rex_houses WHERE owned = 0')
    if not houses or #houses == 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_49'),
            type = 'inform'
        })
        return
    end
    local houseOptions = {}
    for _, house in pairs(houses) do
        houseOptions[#houseOptions + 1] = {
            value = house.houseid,
            label = string.format(" %s - %s$", house.houseid, house.price)
        }
    end
    TriggerClientEvent('rex-houses:client:priceupdate', src, houseOptions)
end, admin)

RegisterNetEvent('rex-houses:server:handlePriceUpdate', function(data)
    local src = source
    local houseid = data.houseid
    local newprice = tonumber(data.newprice)

    if not houseid or not newprice then return end

    local updated = MySQL.update.await('UPDATE rex_houses SET price = ? WHERE houseid = ? AND owned = 0', {
        newprice, houseid
    })

    if updated > 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_44'),
            description = locale('sv_lang_45'),
            type = 'success'
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('sv_lang_46'),
            description = locale('sv_lang_47'),
            type = 'error'
        })
    end
end)

---------------------------------------------
-- land tax billing system
---------------------------------------------
lib.cron.new(Config.TaxBillingCronJob, function ()
    local result = MySQL.query.await('SELECT * FROM rex_houses WHERE owned=@owned', {['@owned'] = 1})

    if not result then goto continue end

    for i = 1, #result do
        local row = result[i]

        if Config.Debug then
            print(row.agent, row.houseid, row.citizenid, row.fullname, row.owned, row.price, row.credit)
        end

        if row.credit >= Config.LandTaxPerCycle then
            local creditadjust = (row.credit - Config.LandTaxPerCycle)

            MySQL.update('UPDATE rex_houses SET credit = ? WHERE houseid = ? AND citizenid = ?', { creditadjust, row.houseid, row.citizenid })

            local creditwarning = (Config.LandTaxPerCycle * Config.CreditWarning)

            if row.credit < creditwarning then
                MySQL.insert('INSERT INTO telegrams (citizenid, recipient, sender, sendername, subject, sentDate, message) VALUES (?, ?, ?, ?, ?, ?, ?)',
                {   row.citizenid,
                    row.fullname,
                    '22222222',
                    locale('sv_lang_35'),
                    locale('sv_lang_36'),
                    os.date("%x"),
                    locale('sv_lang_37'),
                })
            end
        else
            MySQL.insert('INSERT INTO telegrams (citizenid, recipient, sender, sendername, subject, sentDate, message) VALUES (?, ?, ?, ?, ?, ?, ?)',
            {   row.citizenid,
                row.fullname,
                '22222222',
                locale('sv_lang_35'),
                locale('sv_lang_38'),
                os.date("%x"),
                locale('sv_lang_39'),
            })

            Wait(1000)

            MySQL.update('UPDATE rex_houses SET citizenid = 0, fullname = 0, owned = 0 WHERE houseid = ?', {row.houseid})
            MySQL.update('DELETE FROM rex_housekeys WHERE houseid = ?', {row.houseid})
            if Config.PurgeStorage then
                MySQL.update('DELETE FROM inventories WHERE identifier = ?', {row.houseid})
            end
            TriggerEvent('rsg-log:server:CreateLog', 'rexhouses', locale('sv_lang_40'), 'red', row.fullname..locale('sv_lang_41')..row.houseid..locale('sv_lang_42'))
        end
        -- if you have govenor setup then adds money to their accounts
        if Config.EnableGovenor then
            if row.agent == 'newhanover' then
               exports['rsg-bossmenu']:AddMoney('govenor1', Config.LandTaxPerCycle)
            end

            if row.agent == 'westelizabeth' then
                exports['rsg-bossmenu']:AddMoney('govenor2', Config.LandTaxPerCycle)
            end

            if row.agent == 'newaustin' then
                exports['rsg-bossmenu']:AddMoney('govenor3', Config.LandTaxPerCycle)
            end

            if row.agent == 'ambarino' then
                exports['rsg-bossmenu']:AddMoney('govenor4', Config.LandTaxPerCycle)
            end

            if row.agent == 'lemoyne' then
                exports['rsg-bossmenu']:AddMoney('govenor5', Config.LandTaxPerCycle)
            end
        end
    end

    ::continue::

    print(locale('sv_lang_43'))

end)
