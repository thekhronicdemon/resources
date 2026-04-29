fx_version 'cerulean'
game 'gta5'

name 'prp-mdt'
author 'PRP'
description 'PRP MDT/CAD System for QBCore'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/*.png',
    'html/images/*.jpg',
    'html/images/*.webp'
}

shared_scripts {
    '@qb-core/shared/locale.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependency 'qb-core'
