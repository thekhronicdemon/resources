fx_version 'cerulean'
game 'gta5'

name 'prp-mechanic'
author 'PRP / ChatGPT'
description 'Mechanic job progression, hidden vehicle issues, repairs, diagnostics, tow dispatch and NUI tablet for QBCore.'
version '1.0.0'

lua54 'yes'

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

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

dependency 'qb-core'
dependency 'qb-target'
dependency 'oxmysql'
