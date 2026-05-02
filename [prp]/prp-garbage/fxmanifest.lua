fx_version 'cerulean'
game 'gta5'

name 'prp-garbage'
author 'PRP / ChatGPT'
description 'Advanced QBCore garbage job with depot NPC, Trashmaster deposit, bin runs and hard rubbish clusters.'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'qb-core',
    'qb-target'
}
