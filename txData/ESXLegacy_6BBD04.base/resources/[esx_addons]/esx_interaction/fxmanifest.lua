fx_version 'cerulean'
game 'gta5'

author '888ENTEI'
description 'ESX Interaction Point Creator'
version '1.0.0'

-- Specify UI page for NUI
ui_page 'html/index.html'

-- Dependencies
dependencies {
    'es_extended',
    'oxmysql' -- Replace with 'oxmysql' if using oxmysql
}

-- Client scripts
client_scripts {
    'config.lua',
    'client.lua'
}

-- Server scripts
server_scripts {
    'config.lua',
    'server.lua'
}

-- HTML/UI files
files {
    'html/index.html',
    'html/script.js',
    'html/style.css'
}

