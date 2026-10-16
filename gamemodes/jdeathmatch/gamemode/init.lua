-- Client files to send
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("sh_config.lua")
AddCSLuaFile("sh_convars.lua")
AddCSLuaFile("cl_weapons.lua")
AddCSLuaFile("cl_mapvote.lua")
AddCSLuaFile("cl_sounds.lua")
AddCSLuaFile("cl_scoreboard.lua")

-- Custom sounds clients must download (when not installed via Workshop)
resource.AddFile("sound/jdm_moabsound.wav")
resource.AddFile("sound/jdm_winsound.wav")

-- Include shared files
include("shared.lua")

-- Include server-side modules
include("sv_networking.lua")
include("sv_spawn.lua")
include("sv_weapons.lua")
include("sv_player.lua")
include("sv_moab.lua")
include("sv_mapvote.lua")
include("sv_round.lua")

print("[INFO] JDeathmatch gamemode loaded successfully")
