# prp-ELS

This build uses the PRP emergency control layout. Indicators work in any driven vehicle; emergency lights and sirens are limited to allowed ELS vehicles.

## Controls
	Left indicator:		[
	Right indicator:	]
	Hazard lights:		Backspace	(Phone Cancel)
	Toggle emergency lights:	Y	(Text Chat Team)
	Airhorn:		E	(Horn)
	Toggle siren:		,	(Previous Radio Station)
	Manual siren / Change siren tone:	N	(Next Radio Station)
	Auxiliary siren:	Down Arrow	(Phone Up)

## Commands
If a key still does not work on your layout, these commands can be run from F8 or rebound in FiveM settings:

- `prpels_right_indicator`
- `prpels_left_indicator`
- `prpels_hazards`
- `prpels_lights`
- `prpels_siren`
- `+prpels_airhorn`
- `-prpels_airhorn`
- `+prpels_manual_siren`
- `-prpels_manual_siren`
- `+prpels_aux_siren`
- `-prpels_aux_siren`

## Vehicle config
Edit `config.lua` and add your vehicle spawn names under `Config.AllowedModels`.

## Audio
Emergency lights use GTA's siren-light state, but the default vehicle siren audio is muted. prp-ELS plays configured police sirens, airhorn, and auxiliary siren sounds from the vehicle instead.
