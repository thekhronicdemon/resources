fx_version 'cerulean'
game 'gta5'

author 'PRP'
description 'PRP Workout System'
version '1.3.0'

lua54 'yes'

shared_scripts {
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
    'html/style.css',
    'html/app.js'
}
