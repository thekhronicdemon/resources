fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Progression RP'
description 'Self-contained mechanic tablet with permanent stance, airbags and hydraulics upgrades'
version '2.5.7'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'shared/airbag.mp3'
}

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'qb-core',
    'oxmysql'
}
