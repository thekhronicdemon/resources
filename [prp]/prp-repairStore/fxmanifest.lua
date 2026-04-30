fx_version 'cerulean'
game 'gta5'

author 'PRP'
description 'PRP Repair Store - repair, cosmetics, performance mods with mechanic lockout'
version '1.0.1'

lua54 'yes'

shared_script 'config.lua'

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html'
}
