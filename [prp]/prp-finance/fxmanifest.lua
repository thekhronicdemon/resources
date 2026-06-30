fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Progression RP'
description 'PRP finance profiles, loans, credit scores, and phone app connector'
version '1.0.0'

shared_scripts {
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependency 'qb-core'
