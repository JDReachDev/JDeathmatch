GM.Name = "JDeathmatch"
GM.Author = "JDReach"
GM.Email = "N/A"
GM.Website = "https://github.com/JDReachDev/JDeathmatch"

-- Include shared configuration
include("sh_config.lua")
include("sh_convars.lua")

-- Unique key for per-player tables.
-- SteamID() is "BOT" for every bot, so bots would share the same data.
function JDM.PlayerKey(ply)
    return ply:UserID()
end

function GM:Initialize()
    -- Base gamemode initialization
end
