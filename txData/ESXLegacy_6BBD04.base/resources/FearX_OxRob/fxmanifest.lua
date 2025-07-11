fx_version 'cerulean'
game 'gta5'
lua54 'true'

author 'Fearx'
description 'Fearx-oxrob - Enhanced Robbing System for ox_inventory'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'ox_inventory',
    'ox_lib'
}