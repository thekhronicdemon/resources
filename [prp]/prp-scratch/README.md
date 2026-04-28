# prp-scratch

Configurable scratch ticket system for QB-Core.

## Features
- Uses a `scratch_ticket` item
- Removes the item from inventory when used
- 4 clickable scratch boxes
- ESC closes the ticket
- 3 matching logos wins
- STAR and X2 modifiers supported
- Server-side ticket generation and payout validation
- Extremely configurable config

## Install
1. Drop `prp-scratch` into your server resources folder.
2. Add `ensure prp-scratch` to your `server.cfg` after `qb-core` and inventory.
3. Add the scratch item to your shared items file.
4. Restart the server.

## Example qb-core item
Add this to `qb-core/shared/items.lua`:

```lua
['scratch_ticket'] = {
    ['name'] = 'scratch_ticket',
    ['label'] = 'Scratch Ticket',
    ['weight'] = 50,
    ['type'] = 'item',
    ['image'] = 'scratch_ticket.png',
    ['unique'] = false,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['description'] = 'Scratch 4 boxes and try to match 3 logos.'
},
```

## Shop example
Sell `scratch_ticket` in your normal shop resource or give it as a reward item.

## Default rules
- 4 boxes per ticket
- Match 3 symbols to win
- Default symbols are 8 jackpot symbols worth $5,000 each
- X2 doubles the matched symbol prize
- STAR can be required if you turn `Config.RequireModifierForPayout = true`
- Default win chance is extremely rare

## Main config areas
- `Config.Symbols` = all logos and payout values
- `Config.Rolling` = ticket odds
- `Config.Modifiers` = STAR / X2 setup
- `Config.UI` = visible text and box count
- `Config.UseTargetMoney` = payout account

## Notes
- The UI uses emoji icons by default so you can swap it quickly without image work.
- You can replace the icons with custom images by editing the NUI and config structure.
- If you want tickets to always lose unless specifically forced, just lower `Config.Rolling.WinChance` more.
