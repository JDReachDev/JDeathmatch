-- Client files to send
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("sh_config.lua")
AddCSLuaFile("cl_weapons.lua")
AddCSLuaFile("cl_mapvote.lua")
AddCSLuaFile("cl_sounds.lua")
AddCSLuaFile("cl_scoreboard.lua")

-- Include shared files
include("shared.lua")

-- Include server-side modules
include("sv_config.lua")
include("sv_networking.lua")
include("sv_spawn.lua")
include("sv_weapons.lua")
include("sv_player.lua")
include("sv_moab.lua")
include("sv_mapvote.lua")
include("sv_round.lua")

print("[INFO] JDeathmatch gamemode loaded successfully")
