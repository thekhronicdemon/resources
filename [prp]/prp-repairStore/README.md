# prp-repairStore v4

Fixes:
- Front bumper camera now goes to front.
- Rear bumper and spoiler camera now go to rear.
- Wheels now show all wheel categories, not only stock/current type.

Install:
ensure qb-core
ensure qb-target
ensure prp-repairStore

Only one config file: config.lua


## v5 fixes
- Fixed crash when MySQL global is nil.
- If no MySQL is found, mod saving is skipped safely instead of crashing the server.
- Smaller/tighter cosmetic UI.
- Extra controls disabled while NUI is open to stop radio/weapon controls when scrolling.


## v6 fix
- Removed qb-progressbar usage from repair to stop FiveM deadloop after repair completes.
- Repair now uses a safe internal timer and mechanic animation.


## v7 ownership save fix
- Owned vehicles save mods to `player_vehicles.mods`.
- Stolen/unowned vehicles can still be repaired/customized, but changes do not save.
- MySQL/oxmysql missing no longer crashes or spams unless `Config.Debug = true`.

## Database saving
To persist owned vehicle mods, make sure your server has oxmysql started before this resource:

ensure oxmysql
ensure prp-repairStore

Your `player_vehicles` table must have:
- citizenid
- plate
- mods


## v8 safe repair fix
- Removed repair timer/thread/scenario completely.
- Repair now instantly sets vehicle to a fixed state.
- Repair button is hidden when engine/body are already at 100%.
- This avoids FiveM deadloops caused by progressbar or repair wait callbacks.


## v9 safe close/back fix
- Closing/ESC/back no longer re-applies all original vehicle props.
- This avoids FiveM deadloops on close/back with some add-on vehicles.
- Removed SetNuiFocusKeepInput(true).
- ESC is handled by NUI only with debounce to stop double-close loops.


## v10 fix
- Fixed `IsVehicleAlreadyRepaired` nil error by moving the helper before all menu/NUI calls.
- Added guard so repair visibility checks do not run against nil vehicles.


## v11 stack overflow camera fix
- Guarded `DestroyCam()` so `RenderScriptCams(false)` can only fire once at a time.
- Guarded `CloseMenu()` so ESC/back/NUI cannot double-close.
- Removed client-side ESC close; ESC is handled by NUI only.
- Added NUI close debounce.
- Resource stop cleanup is safe and does not restore every vehicle mod.


## v12 preview rollback fix
- Previewed items now rollback if you leave/back/ESC without buying.
- It only restores the single unpaid previewed part, not the whole vehicle.
- Purchased items stay applied and save as normal.


## v13 mouse rotate fix
- Restored mouse camera rotate using a safe transparent drag zone.
- Drag empty screen area with left or right mouse button to rotate the camera.
- Scroll still zooms camera, while UI controls stay clickable.
- Keeps the v11 guarded camera close stack overflow fix.


## v14 livery button
- Added a dedicated bottom menu button: Liveries.
- Liveries now open separately from Customize.
- Supports both mod-kit liveries `SetVehicleMod(..., 48, ...)` and native vehicle liveries `SetVehicleLivery`.


## v15 mechanic on-duty rules
- On-duty mechanics can use the repair store, but only:
  - Customize
  - Liveries
- On-duty mechanics cannot use:
  - Repair
  - Engine Modify
- Mechanic purchases are 75% cheaper by default.
- Civilians are still blocked from using the store while an on-duty mechanic is online.
