# prp-bankrobbery

Small QBCore Fleeca starter robbery for PRP.

## Features

- Built-in NUI keypad hack, no qb-minigames needed
- Built-in NUI lockpick minigame for the security gate
- Built-in NUI drill minigame for loot boxes
- Vault door opens after successful gatecrack hack
- Vault resets after 15 minutes
- Failed keypad hack triggers police alert and 60 second cooldown
- Second security gate is controlled/frozen by this script and lockpickable only through target
- 6 drillable loot locations
- Reward chance system:
  - security_card_01, 20%
  - crypto_usb, 30%
  - markedbills, 90%
- Animations and progressbars before/while actions

## Dependencies

Required:

- qb-core
- qb-target
- qb-inventory or compatible QBCore item system
- QBCore progressbar function

Not required:

- qb-minigames
- ps-ui
- qb-lock
- ox_lib

## Install

1. Drop `prp-bankrobbery` into your resources folder.
2. Add this to `server.cfg`:

```cfg
ensure prp-bankrobbery
```

3. Add these items to your `qb-core/shared/items.lua` if you do not already have them:

```lua
gatecrack = {
    name = 'gatecrack',
    label = 'Gatecrack Device',
    weight = 1000,
    type = 'item',
    image = 'gatecrack.png',
    unique = false,
    useable = false,
    shouldClose = true,
    combinable = nil,
    description = 'Used to bypass bank keypad security.'
},

drill = {
    name = 'drill',
    label = 'Drill',
    weight = 3500,
    type = 'item',
    image = 'drill.png',
    unique = false,
    useable = false,
    shouldClose = true,
    combinable = nil,
    description = 'Used to drill bank deposit boxes.'
},

crypto_usb = {
    name = 'crypto_usb',
    label = 'Crypto USB',
    weight = 250,
    type = 'item',
    image = 'crypto_usb.png',
    unique = false,
    useable = false,
    shouldClose = true,
    combinable = nil,
    description = 'A USB loaded with suspicious crypto wallet data.'
},
```

`lockpick`, `markedbills`, and `security_card_01` usually already exist in QBCore. Add them if your server does not have them.

## Tuning

Edit `shared/config.lua` to change:

- required police
- alert event
- door headings
- drill spot locations
- reward chances
- item consumption
- reset timers

## Notes

The second security gate is frozen closed by the script on sync/refresh. Players should not be able to open it normally. They need to open the vault first, then lockpick the gate using the target option.
