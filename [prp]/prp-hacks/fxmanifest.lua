fx_version 'cerulean'
game 'gta5'

name 'prp-hacks'
author 'PRP / ChatGPT'
description 'Reusable PRP hack minigames: Tetris, Flappy, Crossy, Memory, and Typing'
version '1.2.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

exports {
    'StartHack',
    'StartTetris',
    'StartFlappy',
    'StartCrossy',
    'StartMemory',
    'StartTyping',
    'StartRandomHack'
}
