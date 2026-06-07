fx_version 'cerulean'
game 'gta5'

name 's_core'
author 'ValRavn'
description 'Saga Framework — core (multicharacter, player, money, persistence)'
version '0.2.0'
lua54 'yes'

dependency 's_lib'

ui_page 'web/index.html'

shared_scripts {
    '@s_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    'server/storage.lua',
    'server/sv_main.lua',
}

client_scripts {
    'client/cl_main.lua',
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}
