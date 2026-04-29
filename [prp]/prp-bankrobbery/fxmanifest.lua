fx_version 'cerulean'
game 'gta5'

name 'prp-bankrobbery'
author 'PRP'
description 'Small QBCore bank robbery with keypad hack, lockpick bar door, and drill loot spots.'
version '1.0.0'

shared_scripts {
    'shared/config.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

lua54 'yes'
