# PRP Drugs

A server-authoritative QBCore weed system for Progression RP.

## Requirements

- qb-core
- qb-target
- qb-inventory
- oxmysql

## Features

- Renamed replacement-style resource for `qb-drugs`
- Buy fertilizer, bags, rolling paper, plant pots, shovels and water
- Use a shovel to find Class A/B/C/D dirt
- Percentage-based dirt quality, seed genetics, buds, baggies, joints and bricks
- Strains are assigned from final quality:
  - 96-100: AK47
  - 91-95.9: Purple Haze
  - 86-90.9: Amnesia
  - 81-85.9: Skunk
  - 76-80.9: OG-Kush
  - below 76: Whitewidow
- Persistent plant pots and plants
- Five-minute grow cycle
- Three waters required, four waters ideal
- Fertilizer improves quality and yield
- Harvest gives 5-15 buds
- Harvest can return a new percentage-based seed
- Loose buds can be bagged, rolled, or pressed into a brick
- Bagged weed can be unpacked; the empty bag is destroyed
- Any suitable ambient NPC can be targeted for selling
- Server validates inventory, distance, plant state, quality, payouts and cooldowns

## Installation

1. Copy `prp-drugs` into your resources folder.
2. Import `sql/prp_drugs.sql`.
3. Add every item from `install/items.lua` to `qb-core/shared/items.lua`.
4. Add matching PNG icons to `qb-inventory/html/images`.
5. Add `ensure prp-drugs` after its dependencies in server.cfg.
6. Stop or remove `qb-drugs` if this script replaces it.
7. Set the shop and press coordinates in `config.lua`.
8. Restart the server, not only the resource, after changing shared items.

Example load order:

```cfg
ensure oxmysql
ensure qb-core
ensure qb-inventory
ensure qb-target
ensure prp-drugs
```

## Gameplay

1. Buy a shovel and plant supplies from the farm supplier.
2. Use the shovel to dig up graded dirt.
3. Use a plant pot to place it.
4. Target the pot and add the best dirt in your inventory.
5. Add a percentage-based seed.
6. Water it three or four times while it grows for five minutes.
7. Optionally add fertilizer.
8. Harvest 5-15 percentage-tagged buds.
9. Use a bud to pack it, use rolling paper to roll one, or take 25 loose buds to the press.
10. Target an ambient NPC and select **Offer drugs**.

## Important integration notes

- This build uses current qb-target global ped and target entity exports.
- It uses current qb-inventory server exports and item `info` metadata.
- Quality items are intentionally marked `unique = true`; stacking different metadata would destroy accurate percentages.
- Change `Config.Dispatch` to match your police dispatch resource.
- With one bud per bag, each bag stores one bud. Increase `BudsPerBag` to make larger bags.
- The script automatically selects the best available dirt grade and the first seed/bud slot. A custom NUI can later provide manual selection.
- The included plant objects are GTA props. Replace models in `Config.Models` if your map uses custom weed assets.
