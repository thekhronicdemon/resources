# prp-mining

QBCore mining job with:
- Ground mining circles at your three coords
- Press E to mine
- Requires an equipped `pickaxe`
- Pickaxe prop attaches to player hand
- 10 second mining animation
- Pickaxe durability/health metadata
- Random rewards: iron, coal, copper, gold, diamond

## Install

1. Put `prp-mining` into your resources folder.
2. Add this to `server.cfg`:

```cfg
ensure prp-mining
```

3. Add the items below to `qb-core/shared/items.lua`.
4. Add inventory images if you want icons.

## Items for qb-core/shared/items.lua

```lua
pickaxe = {
    name = 'pickaxe',
    label = 'Pickaxe',
    weight = 2500,
    type = 'item',
    image = 'pickaxe.png',
    unique = true,
    useable = true,
    shouldClose = true,
    combinable = nil,
    description = 'Used for mining rocks.'
},

iron = {
    name = 'iron', label = 'Iron', weight = 100, type = 'item', image = 'iron.png', unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Raw iron ore.'
},
coal = {
    name = 'coal', label = 'Coal', weight = 100, type = 'item', image = 'coal.png', unique = false, useable = false, shouldClose = false, combinable = nil, description = 'A chunk of coal.'
},
copper = {
    name = 'copper', label = 'Copper', weight = 100, type = 'item', image = 'copper.png', unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Raw copper ore.'
},
gold = {
    name = 'gold', label = 'Gold', weight = 100, type = 'item', image = 'gold.png', unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Raw gold ore.'
},
diamond = {
    name = 'diamond', label = 'Diamond', weight = 100, type = 'item', image = 'diamond.png', unique = false, useable = false, shouldClose = false, combinable = nil, description = 'A rough diamond.'
},
```

## Give yourself a pickaxe

Because pickaxe is unique, each one can keep its own durability.

```lua
Player.Functions.AddItem('pickaxe', 1, false, { durability = 100, health = 100 })
```

Or use your admin inventory item giver and add metadata if your admin panel supports it.

## Tuning

Edit `config.lua` for:
- Mining coords
- Mining time
- Pickaxe damage per mine
- Reward chances
- Marker colour/size
