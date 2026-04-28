fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'prp-scratch'
author 'OpenAI'
description 'Configurable scratch ticket system for QB-Core'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}

dependencies {
    'qb-core'
}
