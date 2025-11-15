# REX-Houses Documentation

**Version:** 2.0.7  
**Framework:** RSG-Core (RedM)  
**Game:** Red Dead Redemption 3 (rdr3)

---

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Dependencies](#dependencies)
4. [Configuration](#configuration)
5. [Features](#features)
6. [Database Schema](#database-schema)
7. [Events & Callbacks](#events--callbacks)
8. [Server-Side Functions](#server-side-functions)
9. [Client-Side Functions](#client-side-functions)
10. [Localization](#localization)
11. [Admin Commands](#admin-commands)
12. [Troubleshooting](#troubleshooting)

---

## Overview

REX-Houses is a comprehensive property management system for RedM servers using the RSG-Core framework. It allows players to buy, sell, and manage houses with features including:

- **Property ownership** and trading
- **Land tax system** with automatic billing cycles
- **House storage** with customizable weight and slot limits
- **Guest management** for granting access to other players
- **Outfit storage** for saving character appearances
- **Mailbox system** with telegram notifications
- **Dynamic house blips** showing ownership status (green for owned, yellow for others, white for available)
- **Estate agent NPCs** at multiple locations across the map

---

## Installation

### 1. Extract Files

Place the `rex-houses` folder into your server's `resources` directory.

### 2. Database Setup

Run the SQL file to create required tables:

```bash
mysql < resources/rex-houses/installation/rex-houses.sql
```

### 3. Configure Dependencies

Ensure the following resources are started in your `server.cfg` before `rex-houses`:

```
ensure ox_lib
ensure rsg-core
ensure rsg-bossmenu
ensure rsg-inventory
ensure oxmysql
```

### 4. Start Resource

Add to your `server.cfg`:

```
ensure rex-houses
```

### 5. Import Shared Jobs (Optional)

If using the shared jobs system, import the jobs configuration:

```lua
-- In your job configuration system
dofile('resources/rex-houses/installation/shared_jobs.lua')
```

---

## Dependencies

| Dependency | Purpose | Required |
|-----------|---------|----------|
| `rsg-core` | Core framework and player management | ✅ Yes |
| `ox_lib` | UI notifications, dialogs, and utilities | ✅ Yes |
| `oxmysql` | MySQL database operations | ✅ Yes |
| `rsg-bossmenu` | Boss menu integration | ✅ Yes |
| `rsg-inventory` | Item storage and inventory system | ✅ Yes |

---

## Configuration

### Main Config File: `config.lua`

#### General Settings

```lua
Config.Debug = true  -- Enable debug output
Config.LandTaxPerCycle = 1  -- Tax amount per cycle ($)
Config.StartCredit = 10  -- Initial tax credit hours for new owners
Config.CreditWarning = 5  -- Warning triggers at (CreditWarning × LandTaxPerCycle) = 5 hours
Config.SellBack = 0.8  -- Resale value multiplier (0.8 = 80% of original price)
Config.StorageMaxWeight = 4000000  -- Max house storage weight
Config.StorageMaxSlots = 48  -- Max storage slots
Config.OwnedHouseBlips = false  -- Show blips only for owned houses if true
Config.PurgeStorage = false  -- Delete stored items when house is repossessed
Config.EnableGovenor = false  -- Enable governor tax integration
Config.TaxBillingCronJob = '0 * * * *'  -- Cron job runs every hour on the hour
```

#### Estate Agents Configuration

Define NPC locations where players can view/purchase properties:

```lua
Config.EstateAgents = {
    {
        name = 'Estate Agent',
        prompt = 'valestateagent',
        coords = vector3(-250.8893, 743.20239, 118.08129),
        location = 'newhanover',
        npcmodel = `A_M_O_SDUpperClass_01`,
        npccoords = vector4(-250.8893, 743.20239, 118.08129, 105.66469),
        showblip = true
    },
    -- Additional agents...
}
```

#### Estate Agent Blip Settings

```lua
Config.Blip = {
    blipName = 'Estate Agent',
    blipSprite = 'blip_ambient_quartermaster',
    blipScale = 0.2
}
```

#### Houses Configuration

Define all purchasable properties:

```lua
Config.Houses = {
    {
        name = 'House 1',
        houseid = 'house1',
        houseprompt = 'houseprompt1',
        menucoords = vector3(220.0229, 984.58837, 190.89463),
        blipcoords = vector3(215.8, 988.065, 189.9),
        showblip = true,
        price = 5000  -- Purchase price
    },
    -- Additional houses...
}
```

---

## Features

### 1. House Purchasing

- Players can purchase available properties from estate agents
- Limit of **1 house per player**
- Full name recorded as owner
- Immediate access after purchase

### 2. Land Tax System

**Automatic Billing:**
- Deducts `Config.LandTaxPerCycle` per billing cycle (hourly by default)
- Started with `Config.StartCredit` hours of credit
- Warning telegram sent at `Config.CreditWarning` threshold

**Warning System:**
- First warning when credit reaches critical level
- Final warning before repossession
- Notifications via mailbox system

**Repossession:**
- House reclaimed if credit reaches zero
- Optional: House inventory purged based on `Config.PurgeStorage`
- House returns to unowned status

### 3. House Storage

- **Weight Limit:** `Config.StorageMaxWeight` grams
- **Slot Limit:** `Config.StorageMaxSlots` slots
- Only owner and guests with access can use storage
- Integrated with rsg-inventory system

### 4. Guest Management

- Owner can add/remove guests
- Guests get limited access (no storage by default)
- Guests can enter/exit house freely
- Citizens can't hold keys to multiple houses
- Tracked in database with guest status

### 5. Outfit Storage

- Save and load character outfits
- Personal wardrobe system
- Useful for role-play scenarios

### 6. Mailbox System

- Receive tax notifications
- Warning messages about credit
- Repossession notices
- Integrated with rsg-core notification system

### 7. Dynamic Blip System

**Blip Colors:**
- **White:** Available for purchase
- **Green:** Owned by current player
- **Yellow:** Owned by another player

---

## Database Schema

### Table: `rex_houses`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INT (PK) | Auto-incrementing ID |
| `houseid` | VARCHAR(50) | Unique house identifier |
| `fullname` | VARCHAR(50) | Owner's full name |
| `citizenid` | VARCHAR(50) | Owner's citizen ID |
| `owned` | TINYINT | 1 = owned, 0 = available |
| `price` | INT | Purchase price |
| `credit` | INT | Current tax credit (hours) |
| `house_setup` | LONGTEXT | Stored furniture/decorations (JSON) |

### Table: `rex_housekeys`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INT (PK) | Auto-incrementing ID |
| `citizenid` | VARCHAR(50) | Player's citizen ID |
| `houseid` | VARCHAR(50) | House identifier |
| `guest` | TINYINT | 1 = guest, 0 = owner |

### Table: `rex_house_storage`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INT (PK) | Auto-incrementing ID |
| `houseid` | VARCHAR(50) | House identifier |
| `storage` | LONGTEXT | Inventory data (JSON) |

---

## Events & Callbacks

### Server Events

#### `rex-houses:server:UpdateOwnedHouse`

Triggered when a house is purchased. Updates ownership data.

```lua
TriggerServerEvent('rex-houses:server:UpdateOwnedHouse', houseId, playerName, citizenId)
```

**Parameters:**
- `houseId` (string): House identifier
- `playerName` (string): Owner's full name
- `citizenId` (string): Owner's citizen ID

#### `rex-houses:server:RemoveOwnedHouse`

Triggered when a house is sold or repossessed.

```lua
TriggerServerEvent('rex-houses:server:RemoveOwnedHouse', houseId)
```

#### `rex-houses:server:buyhouse`

Handles house purchase logic on server.

```lua
RegisterServerEvent('rex-houses:server:buyhouse')
AddEventHandler('rex-houses:server:buyhouse', function(data)
    -- data.house = houseid
    -- data.price = purchase price
end)
```

#### `rex-houses:server:openinventory`

Opens house storage inventory.

```lua
RegisterServerEvent('rex-houses:server:openinventory')
AddEventHandler('rex-houses:server:openinventory', function(stashName, invWeight, invSlots)
    -- Handles inventory opening
end)
```

#### `rex-houses:server:SyncAllHouses`

Forces a sync of all owned houses from database.

```lua
TriggerServerEvent('rex-houses:server:SyncAllHouses')
```

### Server Callbacks

#### `rex-houses:server:GetOwnedHouses`

Returns table of all owned houses with owner info.

```lua
RSGCore.Functions.TriggerCallback('rex-houses:server:GetOwnedHouses', function(ownedHouses)
    -- ownedHouses[houseid] = { owner = "Name", citizenid = "xxx" }
end)
```

#### `rex-houses:server:GetHouseKeys`

Returns keys for houses owned by requesting player.

```lua
RSGCore.Functions.TriggerCallback('rex-houses:server:GetHouseKeys', function(housekeys)
    -- housekeys[] = { citizenid, houseid, guest }
end)
```

#### `rex-houses:server:GetGuestHouseKeys`

Returns keys for houses where player is a guest.

```lua
RSGCore.Functions.TriggerCallback('rex-houses:server:GetGuestHouseKeys', function(guestinfo)
    -- guestinfo[] = { citizenid, houseid, guest = 1 }
end)
```

#### `rex-houses:server:GetHouseInfo`

Returns all house configuration data.

```lua
RSGCore.Functions.TriggerCallback('rex-houses:server:GetHouseInfo', function(houseinfo)
    -- houseinfo[] = complete house data from database
end)
```

#### `rex-houses:server:GetOwnedHouseInfo`

Returns house info for calling player's owned houses.

```lua
RSGCore.Functions.TriggerCallback('rex-houses:server:GetOwnedHouseInfo', function(houseinfo)
    -- houseinfo[] = player's owned houses only
end)
```

### Client Events

#### `rex-houses:client:SyncOwnedHouses`

Syncs owned houses list and updates blips.

```lua
RegisterNetEvent('rex-houses:client:SyncOwnedHouses', function(ownedHouses)
    -- Updates client-side blips and ownership data
end)
```

#### `rex-houses:client:UpdateHouseBlips`

Updates blip display for owned houses.

```lua
RegisterNetEvent('rex-houses:client:UpdateHouseBlips', function(ownedHouses)
    -- Refreshes all house blips on map
end)
```

---

## Server-Side Functions

### Core Functions

#### `SyncOwnedHouses()`

**Description:** Synchronizes owned houses from database to all clients.

**Location:** `server/server.lua` (line 5)

**Usage:**
```lua
SyncOwnedHouses()  -- Called after house purchase/sale/repossession
```

**Database Query:**
```sql
SELECT h.houseid, h.fullname, h.citizenid FROM rex_houses h WHERE h.owned = 1
```

#### Tax Billing Cron Job

**Description:** Runs automatically every hour, deducting tax credit from all house owners.

**Trigger:** `0 * * * *` (hourly)

**Process:**
1. Queries all owned houses
2. Deducts `Config.LandTaxPerCycle` from credit
3. Sends warning telegrams if credit low
4. Repossesses houses if credit reaches 0

### Localization

The system uses ox_lib localization with keys defined in `locales/en.json`.

**Usage in code:**
```lua
locale('sv_lang_1')  -- Returns localized string
```

---

## Client-Side Functions

### Blip Management

#### `UpdateHouseBlips(ownedHouses)`

**Description:** Creates/updates all house blips on the map based on ownership status.

**Parameters:**
- `ownedHouses` (table): Table of owned houses with owner info

**Blip Sprites:**
- Available house: `blip_proc_home` (white)
- Owned house (player): `blip_proc_home_locked` + green modifier
- Owned house (other): `blip_proc_home_locked` + yellow modifier

**Location:** `client/client.lua` (line 41)

### NPC Spawning

#### Estate Agent NPCs

**File:** `client/npcs.lua`

**Features:**
- Spawns at configured locations
- Despawns when player moves away (`Config.DistanceSpawn`)
- Optional fade-in animation (`Config.FadeIn`)
- Static poses

---

## Localization

Language strings are stored in `locales/en.json`.

### Key Prefixes

- **`cl_lang_*`**: Client-side messages
- **`sv_lang_*`**: Server-side messages

### Common Keys

| Key | Usage |
|-----|-------|
| `cl_lang_4` | "Buy a Property" |
| `cl_lang_6` | "Sell a Property" |
| `cl_lang_8` | "Buy House" |
| `cl_lang_15` | "Open House Menu" |
| `sv_lang_2` | "You already have a house!" |
| `sv_lang_4` | "House purchased!" |
| `sv_lang_7` | "Property Tax" |

### Adding New Languages

1. Create `locales/[language].json` with same structure as `en.json`
2. Language files are auto-loaded via `files` section in `fxmanifest.lua`

---

## Admin Commands

### Price Adjustment (Admin Only)

**Description:** Allows admins to change house prices before purchase.

**Restriction:** Only works on unowned houses

**Error Messages:**
- "Could not update. The house may already been purchased"
- "No houses found!"

**Implementation:** Requires admin permission checks via rsg-core

---

## Troubleshooting

### Issue: Houses not showing on map

**Solution:**
- Check `Config.Houses` entries have `showblip = true`
- Ensure `blipcoords` are set correctly
- Verify blip sprites exist in game files

### Issue: Players can own multiple houses

**Solution:**
- Database might have stale data
- Verify SQL migration ran correctly
- Check `rex_houses` table for duplicate citizenid entries

### Issue: Tax not being deducted

**Solution:**
- Verify cron job: `Config.TaxBillingCronJob = '0 * * * *'`
- Check server timezone matches database
- Ensure ox_lib is loaded (required for cron jobs)

### Issue: Storage not opening

**Solution:**
- Verify rsg-inventory is running: `status rsg-inventory`
- Check player has key to house (verify `rex_housekeys` table)
- Ensure storage is enabled in house config

### Issue: Guests can't access house

**Solution:**
- Check `rex_housekeys` has `guest = 1` entry for player
- Verify owner actually added guest (check for errors in console)
- Ensure guest house permission checks pass

### Issue: NPC not appearing

**Solution:**
- Check distance to NPC location (default: 20 units)
- Verify model hash `A_M_O_SDUpperClass_01` is valid
- Check `Config.FadeIn` setting

### Common Console Errors

**"rsg-core not loaded"**
- Ensure `ensure rsg-core` in server.cfg before rex-houses

**"oxmysql connection failed"**
- Check database credentials in oxmysql config
- Verify MySQL server is running

**"Missing locale key"**
- Check key exists in `locales/en.json`
- Clear client cache (restart FiveM)

---

## Performance Optimization

### Recommendations

1. **Cron Job:** Adjust billing frequency if heavy server load
2. **Blips:** Disable `Config.OwnedHouseBlips` on very populated servers
3. **Storage:** Reduce `Config.StorageMaxSlots` if inventory lags
4. **Debug:** Keep `Config.Debug = false` in production

---

## Version History

**v2.0.7**
- Current version
- Dynamic blip system with ownership indicators
- Full guest management
- Automated tax billing with cron jobs

---

## Support

For issues, bugs, or feature requests related to REX-Houses, refer to the original project repository or contact the development team.

---

**Last Updated:** 2024  
**Framework:** RSG-Core v1.0+  
**RedM Version:** Latest Cerulean
