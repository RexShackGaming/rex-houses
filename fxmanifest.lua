fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

version '2.0.8'
name 'rex-houses'
author 'RexShackGaming'
description 'Advanced house system for RSG Framework'
url 'https://discord.gg/YUV7ebzkqs'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/client.lua',
    'client/npcs.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/versionchecker.lua'
}

dependencies {
    'ox_lib',
    'rsg-core',
    'rsg-bossmenu'
}

files {
  'locales/*.json'
}
