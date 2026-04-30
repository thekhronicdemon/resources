# qb-fuel

Fuel and fuelstations system for Fivem :fuelpump:

## Dependencies

-   [qb-core](https://github.com/qbcore-framework/qb-core) (Required)
-   [qb-target](https://github.com/BerkieBb/qb-target) (Required)
-   [PolyZone](https://github.com/mkafrin/PolyZone) (Required)

## Exports 📡

|  Name   | Namespace |    Arguments    | Return |
| :-----: | :-------: | :-------------: | :----: |
| GetFuel |  Client   |     vehicle     | number |
| SetFuel |  Client   | vehicle, number |  void  |

_\* The exports can be use with the resource name (qb-fuel) or with prp_fuel_

## Compatibility

This resource is fully compatible with QBCore servers and it sustitutes the _[prp_fuel](https://github.com/InZidiuZ/prp_fuel)_, thanks to InZidiuZ for that amazing script that inspired us to make a new Fuel System script.

```lua
-- Will return the same
exports['qb-fuel']:GetFuel(vehicle)
exports['prp_fuel']:GetFuel(vehicle)
```

This will make it easier to change from _prp_fuel_ to _qb-fuel_.
