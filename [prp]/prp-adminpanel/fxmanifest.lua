fx_version 'cerulean'
game 'gta5'

name 'prp-adminpanel'
author 'PRP / ChatGPT'
description 'Admin panel with player tools and developer options for QBCore'
version '0.1.0'

lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/devtools.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/notes.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependency 'qb-core'
dependency 'oxmysql'
