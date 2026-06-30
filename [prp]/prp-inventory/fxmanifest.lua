fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'PRP'
description 'PRP inventory system with equipment slots, quick slots, weapon mods, device mods, and item health'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config/*.lua',
}

client_scripts {
    'client/main.lua',
    'client/drops.lua',
    'client/vehicles.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/functions.lua',
    'server/crafting.lua',
    'server/commands.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    'html/images/*.png',
}

dependency 'qb-weapons'

provide 'qb-inventory'
