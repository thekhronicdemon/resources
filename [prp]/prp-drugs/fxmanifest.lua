fx_version 'cerulean'
game 'gta5'

author 'Progression RP'
description 'PRP Drugs - persistent weed growing, quality genetics, processing and NPC selling'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
    'shared/functions.lua'
}

client_scripts {
    'client/main.lua',
    'client/plants.lua',
    'client/npc_selling.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/plants.lua',
    'server/processing.lua',
    'server/selling.lua'
}

dependencies {
    'qb-core',
    'qb-target',
    'prp-inventory',
    'oxmysql'
}
