# prp-fuel

Standalone QBCore fuel script using qb-target. Replaces prp_fuel, LegacyFuel, and qb-fuel export calls.

Fuel cans:
- Buy a `jerry_can` at any pump for the configured price.
- A full can has 100% quality/fuel.
- Filling a vehicle from 0% to 100% uses 50% of the can.
- Empty cans are removed automatically.

Exports:
- exports['prp-fuel']:GetFuel(vehicle)
- exports['prp-fuel']:SetFuel(vehicle, amount)
- exports['prp_fuel']:GetFuel(vehicle)
- exports['prp_fuel']:SetFuel(vehicle, amount)
- exports['LegacyFuel']:GetFuel(vehicle)
- exports['LegacyFuel']:SetFuel(vehicle, amount)
- exports['qb-fuel']:GetFuel(vehicle)
- exports['qb-fuel']:SetFuel(vehicle, amount)
