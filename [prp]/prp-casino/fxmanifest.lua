fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'PRP Casino'
description 'QBCore immersive blackjack with free-look seating, dealer card dealing, and felt-based props'
version '2.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/dealer.lua',
    'client/cards.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
