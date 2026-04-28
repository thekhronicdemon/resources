fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Progression RP'
description 'Standalone PRP tablet apps for racing, business, and crypto.'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

files {
    'html/bootstrap.html',
    'html/bootstrap.js',
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'qb-core',
    'qb-inventory',
}
