# modular_carlift_prp

PRP version of modular_carlift with:

- No original UI
- No NativeUI/gui.lua
- qb-target controls
- QBCore mechanic job lock
- Uses the original `nacelle` moving lift prop
- Does **not** attach the car to the lift
- Does **not** freeze the car
- Does **not** move the car with script coords

The lift prop moves up/down and the vehicle is lifted by GTA collision. If the car is not parked on the lift properly, it can slip or fall.

## Install

```cfg
ensure qb-core
ensure qb-target
ensure modular_carlift_prp
```

## Stream files

Included:

```txt
stream/nacelle.ydr
stream/nacelle.ytyp
```

## Commands

```txt
/liftcoords
/liftmodels
/liftstop
```

## Jobs

Edit in `config.lua`:

```lua
Config.AllowedJobs = {
    mechanic = true,
    bennys = true,
}
```
