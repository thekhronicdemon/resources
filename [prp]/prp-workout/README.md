# prp-workout

## Install
1. Put `prp-workout` into your resources folder.
2. Import `prp_workout_stats.sql`.
3. Add this to server.cfg:

ensure prp-workout

## Commands
/workoutstats

## Punching bag height
If the bag is in the ground, open:

shared/config.lua

Change:

Config.PunchingBag.ZOffset = 1.35

Try 1.0, 1.35, 1.6 or 2.0 until it sits right.
