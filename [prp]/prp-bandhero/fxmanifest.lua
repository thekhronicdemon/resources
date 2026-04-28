fx_version 'cerulean'
game 'gta5'

author 'PRP'
description 'PRP Band Hero - live server-loaded charts'
version '1.0.2'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/songs/*.mp3',
    'html/songs/*.json',
    'html/songs/charts/*.json'
}

client_script 'client.lua'
server_script 'server.lua'
