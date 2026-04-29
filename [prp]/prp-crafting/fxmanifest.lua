fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'PRP / Khronic Demon'
description 'PRP Crafting with NUI, XP, permanent benches, and placeable benches'
version '1.1.1'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'config.lua'
}

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
