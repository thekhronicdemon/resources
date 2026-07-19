# PRP Mechanic Tablet v2

A self-contained QBCore mechanic upgrade resource. It does not require VStancer or any other stance/hydraulics script.

## Features

- Permanent upgrades saved by number plate
- Built-in stance editor NUI
- Front and rear camber
- Front and rear track width
- Wheel width
- Suspension/ride height
- Live stance preview, including camber, and permanent save
- Airbags installed/removed using the `airbags` item
- Stancer controls installed/removed using the `stancer` item
- Hydraulics installed/removed using the `hydraulics_kit` item
- Airbags smoothly lower when the vehicle stops and smoothly raise when it takes off
- Driver airbag auto-height toggle
- Driver hydraulic keybinds with front, rear, left, right and full bounce
- Hydraulics lock until the vehicle leaves the ground and lands again
- Server-side stance clamping
- Mechanic job and grade restrictions

## Dependencies

- qb-core
- oxmysql
- A QBCore-compatible inventory

`qb-menu` is no longer required because the tablet has its own NUI.

## Installation

1. Place `prp-mechanic-tablet` in your resources folder.
2. Import `sql/prp_vehicle_upgrades.sql`.
3. Add the item definitions from `shared/items.lua` to `qb-core/shared/items.lua`.
4. Add matching item images to your inventory image folder.
5. Add `ensure prp-mechanic-tablet` after `qb-core` and `oxmysql` in `server.cfg`.
6. Restart the server.

For an existing v1 database, run only the commented `ALTER TABLE` statement in the SQL file if `airbags_down` does not exist.

## Upgrade flow

- Use `stancer` beside or inside a vehicle to permanently install the stance controller.
- Use `airbags` to permanently install air suspension.
- Use `hydraulics_kit` to permanently install hydraulic bounce controls.
- Use the same upgrade item again to remove that upgrade from the vehicle.
- Use `mechanic_tablet` near the vehicle to access installed stance and hydraulics controls.

Upgrade installation/removal consumes one item each time.

## Default hydraulic controls

- `J`: enable/disable automatic airbags
- `H`: enable/disable hydraulic controls
- `Numpad 8`: front bounce
- `Numpad 2`: rear bounce
- `Numpad 4`: left bounce
- `Numpad 6`: right bounce
- `Numpad 5`: full vehicle bounce

Players can remap all controls under FiveM Settings > Key Bindings > FiveM.

## Configuration

Edit `config.lua` to change:

- Mechanic jobs and minimum grades
- Installation/removal times
- Stance limits
- Airbag ride heights, animation timing, sound volume, speed thresholds and default toggle key
- Hydraulic force, cooldown and landing lockout
- Default keybinds

## Notes

Wheel natives depend on a reasonably current FiveM server artifact. The resource protects wheel-width application with `pcall`, so an older artifact will continue running, but updating artifacts is recommended for all stance features.

## v2.1 troubleshooting commands

These commands use the same code paths as the inventory items and make setup testing easier:

- `/mechanictablet`
- `/installairbags`
- `/installstancer`
- `/installhydraulics`

The resource now creates the SQL table automatically and adds missing `airbags_down` or `stance_data` columns. It supports the normal QBCore `progressbar` export and falls back to `QBCore.Functions.Progressbar`.

If an inventory item does nothing, confirm its exact item name exists in `qb-core/shared/items.lua`, restart `qb-core`, then restart this resource. The item names must be `mechanic_tablet`, `airbags`, `stancer`, and `hydraulics_kit`.


## v2.2 wheel and installation-state fix

- Track values are adjustments from each vehicle model's factory wheel positions.
- Wheel width is an adjustment from factory width instead of an absolute value.
- Legacy `wheelWidth = 1.0` database values are converted safely to `0.0`.
- The tablet refreshes all installed upgrade states immediately after installation.
- Reusing an already-installed kit no longer removes or consumes it.
- `/fixvehiclewheels` restores factory wheel positions and reapplies the saved setup.

After replacing the resource, restart it and use `/fixvehiclewheels` beside the affected vehicle once.


## v2.4 database-state fix
- The NUI accepts boolean, numeric and string database values for installed upgrades.
- Installations are verified in SQL before an item is consumed.
- `/checkvehicleupgrades` displays the exact saved state for the nearest vehicle and logs the full record to F8/server console.


## v2.4 database boolean fix
- Supports oxmysql returning TINYINT values as Lua booleans, numbers, or strings.
- Existing installed upgrades now validate correctly.
- A SQL update returning 0 affected rows is verified instead of automatically treated as failure.


## v2.5 live suspension behavior
- Airbags now auto-lower after the vehicle stops and auto-raise once it starts moving.
- Automatic airbag state is synced live without saving every stop/start to SQL.
- Hydraulics cannot be spammed while the vehicle is still airborne from the last bounce.
- Stancer camber preview now persists while sliders are being adjusted.


## v2.5.1 tablet UI
- The tablet can be dragged by its header and remembers its last screen position.
- The Airbags tab was removed because air suspension is automatic.


## v2.5.2 airbag controls
- Airbag lowered height now uses the in-game direction that drops the car while stopped.
- `J` toggles automatic airbags on or off for the driver.
- Disabling automatic airbags raises the current vehicle back to normal height.


## v2.5.3 airbag animation and sound
- Airbag lowering and raising now animate over configurable durations.
- `shared/airbag.mp3` plays when airbags lower.
- Airbag sound volume is configurable in `config.lua`.


## v2.5.4 airbag sound path
- Airbag audio now uses an explicit `nui://` resource URL for more reliable playback.
- Playback failures are logged to the client console with the source URL and error message.


## v2.5.7 bikes unsupported
- Motorcycle and bicycle classes are no longer supported by the mechanic tablet.
- Upgrade installation, tablet opening, stance, airbags and hydraulics now ignore bikes.
- Any old bike suspension override from earlier versions is cleared when a bike is encountered.
