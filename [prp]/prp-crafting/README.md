# prp-Crafting

PRP crafting resource with:

- `/crafting` skill tree NUI only
- crafting points from levels
- recipe unlocks that spend crafting points
- physical bench crafting only
- permanent bench locations from `Config.Locations`
- placeable bench items
- qb-target support

## Important flow

`/crafting` does **not** craft items.

Players use `/crafting` to spend points and unlock recipes. Players must go to a real crafting bench to craft unlocked recipes.

## Points

Config values:

```lua
Config.XPPerLevel = 100
Config.PointsPerLevel = 1
```

Level is calculated from XP. Each level gives points. Spent points are saved in player metadata.

Metadata used:

```lua
prp_crafting_unlocks
prp_crafting_spent
```

## Recipe unlock costs

Each recipe can have:

```lua
xpRequired = 100,
unlockCost = 3,
```

`xpRequired` means the player needs that crafting XP before they can unlock it.
`unlockCost` is how many crafting points it costs.

## Bench locations

Your included locations:

```lua
Config.Locations = {
    {
        id = 'hippy_public_items',
        label = 'Craft Items',
        benchType = 'item_bench',
        coords = vector4(2331.93, 2571.49, 46.68, 155),
        spawnObject = true,
    },
    {
        id = 'warehouse_attachments',
        label = 'Craft Attachments',
        benchType = 'attachment_bench',
        coords = vector4(1038.35, -2509.57, 28.46, 85),
        spawnObject = true,
    },
}
```

## Install

1. Put folder in resources as `prp-Crafting`
2. Add to server.cfg:

```cfg
ensure prp-Crafting
```

3. Make sure dependencies are running before it:

```cfg
ensure qb-core
ensure qb-target
ensure qb-inventory
ensure qb-input
ensure qb-menu
```

`qb-menu` is no longer used by this UI, but many QBCore servers already run it. You can remove it from this list if nothing else uses it.
