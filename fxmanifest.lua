fx_version 'cerulean'
game 'gta5'

author 'Your Name'
description 'Player Escort Script - Multi-Framework Compatible'
version '2.0.0'

shared_script 'bridge/shared.lua'
shared_script 'config.lua'

client_scripts {
    'bridge/client.lua',
    'client.lua'
}

server_scripts {
    'bridge/server.lua',
    'server.lua'
}
