# prp-garbage

Advanced QBCore garbage job.

## Features

- `/jobmenu` NUI for the `garbage` job
- Depot NPC rents and returns the Trashmaster
- $250 truck deposit
- Player cannot rent another truck while one is already rented
- Return only the same assigned truck by plate
- Truck must be near the depot NPC to return/refund
- qb-target only, no marker spam or floating text
- Mirror Park bin route
- Bins spawn as `prop_bin_08a`, are not frozen, and change to `prop_bin_08open`
- Player carries `hei_prop_heist_binbag` to rear of truck
- Hard rubbish clusters with visible props
- Player carries scrap props to rear of truck
- Scrapyard breakdown object rewards rubber/plastic/steel/glass

## Install

1. Put `prp-garbage` in your resources folder.
2. Add this to `server.cfg`:

```cfg
ensure prp-garbage
```

3. Make sure these items exist in `qb-core/shared/items.lua`:

```lua
rubber = { name = 'rubber', label = 'Rubber', weight = 100, type = 'item', image = 'rubber.png', unique = false, useable = false, shouldClose = false, description = '' },
plastic = { name = 'plastic', label = 'Plastic', weight = 100, type = 'item', image = 'plastic.png', unique = false, useable = false, shouldClose = false, description = '' },
steel = { name = 'steel', label = 'Steel', weight = 100, type = 'item', image = 'steel.png', unique = false, useable = false, shouldClose = false, description = '' },
glass = { name = 'glass', label = 'Glass', weight = 100, type = 'item', image = 'glass.png', unique = false, useable = false, shouldClose = false, description = '' },
```

## Notes

- Requires `qb-core` and `qb-target`.
- Uses `vehiclekeys:client:SetOwner`. If your keys resource uses a different event, change it in `client/main.lua`.
- Default job name is `garbage` in `config.lua`.
