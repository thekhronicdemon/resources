prp-npcLoading
=================

What it does
-------------
- Slightly reduces traffic and ambient ped population
- Makes nearby AI drivers less aggressive / less chaotic
- Removes weapons from nearby ambient civilian peds
- Disables a lot of random police/dispatch world noise

Install
-------
1. Drop the folder `prp-npcLoading` into your server's resources folder.
2. Add this to your server.cfg:

   ensure prp-npcLoading

3. Restart the server.

Config tips
-----------
Open `config.lua` and edit these values:

Traffic / ped loading:
- parkedVehicles = 0.80
- vehicles = 0.78
- peds = 0.88
- scenarioPeds = 0.85
- randomVehicles = 0.75

Lower number = fewer NPCs / vehicles.
1.00 = default GTA.

Recommended if you want only a small reduction:
- parkedVehicles = 0.90
- vehicles = 0.88
- peds = 0.92
- scenarioPeds = 0.90
- randomVehicles = 0.85

About the gun removal
---------------------
This script removes weapons from nearby ambient civilian peds.
It does NOT fully rewrite GTA's spawn system.
So the most reliable method is:
- let ambient peds spawn
- strip weapons from allowed nearby peds

By default:
- police stay armed
- security can be kept armed or disarmed in config
- mission/scripted peds are skipped if `onlyAmbientPeds = true`

Notes
-----
If you are running another traffic or population script, they may conflict.
Make sure only one main density controller is active.
