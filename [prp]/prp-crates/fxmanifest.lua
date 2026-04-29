fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'PRP'
description 'PRP Crates - CS style instant rolling crate system for QB-Core'
version '1.0.1'

ui_page 'html/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'qb-core'
}
