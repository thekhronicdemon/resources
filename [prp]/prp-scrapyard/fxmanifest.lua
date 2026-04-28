fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'OpenAI'
description 'PRP Scrapyard replacement for QB-Core'
version '1.2.0'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'qb-core',
    'qb-target'
}
