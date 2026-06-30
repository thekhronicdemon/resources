fx_version 'cerulean'
game 'gta5'

name 'modular_carlift_prp'
author 'KhronicDemon'
description 'PRP modular car lifts using nacelle model, qb-target controls, no UI, no vehicle attachment'
version '3.0.0'

lua54 'yes'

this_is_a_map 'yes'

data_file 'DLC_ITYP_REQUEST' 'stream/nacelle.ytyp'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
