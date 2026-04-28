# PRP Band Hero Live Charts

This version fixes the issue where admin edits save but the main stage does not show them.

## What changed
Player mode no longer loads chart JSON directly from the NUI static file cache.
It asks the server for the latest chart using LoadResourceFile.

## Install
1. Put this folder into your resources.
2. Add:
   ensure prp-bandhero-livecharts

## Add songs
Put MP3 files in:
html/songs/

Then add each song to:
html/songs/songs.json

## Admin chart editor
/bandheroedit

Pick song + difficulty:
- easy
- hard
- expert

ENTER = save
ESC = save and exit
Song ending = auto save

Charts save here:
html/songs/charts/songid_easy.json
html/songs/charts/songid_hard.json
html/songs/charts/songid_expert.json

## Player mode
/bandhero

Player mode now loads the latest saved server chart immediately.
