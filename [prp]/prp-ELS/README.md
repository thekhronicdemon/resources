# prp-ELS v6

This build adds safer default bindings for different keyboard layouts.

## Default binds
- Lights toggle: `-` using `MINUS`
- Lights toggle also works on numpad `-` using `SUBTRACT`
- Siren toggle: `+` using `PLUS`
- Siren toggle also works on numpad `+` using `ADD`

## Commands
If a key still does not work on your layout, these commands will always work in F8 or can be rebound in FiveM settings:
- `prpels_lights`
- `prpels_lights_np`
- `prpels_siren`
- `prpels_siren_np`

## Vehicle config
Edit `config.lua` and add your vehicle spawn names under `Config.AllowedModels`.

## Notes
FiveM's keyboard mapper docs include `MINUS`, `PLUS`, `SUBTRACT`, and `ADD` as valid key identifiers. RegisterKeyMapping uses those identifiers for default binds. citeturn915987search0
