# prp-mechanic

Full QBCore mechanic job core with:

- Mechanic NUI tablet
- Mechanic EXP, levels, reputation and skill points
- Skill tree
- Hidden vehicle issues saved by plate
- Advanced diagnostics
- Hidden issue repairs
- Tow Dispatch tab inside the NUI
- Tow depot truck rental and return with deposit
- Tow vehicle spawn, attach, drop-off and payout
- qb-target workshop tablet zones
- qb-target tow depot zone
- map blips for mechanic shops and tow depot

## Dependencies

- qb-core
- qb-target
- oxmysql

## Install

1. Drop `prp-mechanic` into your resources folder.
2. Import `sql/prp_mechanic.sql` into your database.
3. Add to server.cfg:

```cfg
ensure qb-core
ensure qb-target
ensure oxmysql
ensure prp-mechanic
```

4. Restart server.
5. Give yourself mechanic job:

```txt
/setjob ID mechanic 0
```

## Commands

```txt
/mechanic
```

Opens the tablet if the player has the mechanic job.

The tablet can also be opened using qb-target at workshop zones in `shared/config.lua`.

## NUI Sections

### Dashboard
Shows level, EXP, skill points and reputation.

### Diagnostics
Stand near a vehicle and click `Inspect Nearby Vehicle`.
The script checks the plate and loads hidden issues from database.

### Repairs
Quick repair engine/body/clean vehicle, plus advanced hidden issue repairs:

- Axle / Alignment
- Fuel Pump
- Transmission
- Radiator / Cooling
- ECU / Electrical
- Brakes
- Suspension
- Tyres

### Skill Tree
Unlock:

- Engine Specialist
- Tow Operator
- Advanced Diagnostics
- Electrical Expert
- Fabricator

### Tow Dispatch
Accept a tow job from the tablet.
The script sets GPS, spawns a broken tow vehicle, and allows attaching it to the rented tow truck.

## Tow Job Flow

1. Open `/mechanic`.
2. Go to Tow Dispatch.
3. Accept a contract.
4. Go to the tow depot qb-target zone.
5. Use `Retrieve Tow Truck`.
6. Drive to the GPS pickup.
7. Third-eye the broken vehicle and select `Attach Tow Vehicle`.
8. Drive to the GPS drop-off.
9. Use `Complete Tow Contract`.
10. Return to depot and select `Return Tow Truck` to refund deposit.

## How vehicles get axle, fuel pump, transmission issues, etc.

GTA does not natively track axle/fuel pump/ECU/transmission issues, so this script creates its own system.

The client detects crashes and driving wear, then saves hidden damage by plate in `prp_vehicle_issues`.

Hard crashes can damage:

- axle
- radiator
- suspension
- brakes
- transmission
- fuel pump
- ECU on severe crashes

Driving wear can slowly damage:

- brakes
- fuel pump
- transmission
- tyres
- suspension

These issues then affect vehicles:

- Bad fuel pump can randomly stall the engine
- Bad radiator slowly reduces engine health
- Bad transmission reduces power
- Bad axle/suspension reduces grip
- Bad brakes can randomly cause braking issues


## Blips

Blips are controlled in:

```txt
shared/config.lua
```

Look for:

```lua
Config.Blips
```

You can enable/disable mechanic shop blips and tow depot blips separately, and change sprite, colour, scale, name and short-range behaviour.

To rename a specific mechanic shop blip, add `blipName` to that workshop entry, for example:

```lua
blipName = 'Hayes Autos'
```

## Config

Edit everything in:

```txt
shared/config.lua
```

Important sections:

- `Config.Locations.Workshops`
- `Config.Locations.TowDepot`
- `Config.Locations.TowDropoffs`
- `Config.Tow.Jobs`
- `Config.Issues`
- `Config.Skills`
- `Config.DamageDetection`

## Notes

This is a strong core system, not a full replacement for every possible tuning/customs script.
It is built to be expanded into:

- business management
- part inventory
- customer service records
- player roadside requests
- police impound integration
- illegal mechanic/chop shop progression
