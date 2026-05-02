fx_version 'cerulean'
game 'gta5'

name 'prp-mining'
author 'PRP / ChatGPT'
description 'Simple QBCore mining job with pickaxe durability, prop equip, markers and random rewards.'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

lua54 'yes'
