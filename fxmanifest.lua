fx_version 'cerulean'
game 'gta5'

author 'IDTG Development'
description 'Player Escort Script - Multi-Framework Compatible'
version '1.0.0'

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
