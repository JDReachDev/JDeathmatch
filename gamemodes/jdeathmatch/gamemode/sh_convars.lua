-- ConVars shared between client and server
-- FCVAR_REPLICATED lets clients (scoreboard, HUD) read the server values.

local flags = bit.bor(FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_ARCHIVE)

JDM = JDM or {}

-- Also used by the admin settings menu (cl_admin.lua) and to validate its changes (sv_admin.lua)
JDM.ConVars = {
    { name = "jdm_playerhealth",    default = "100", help = "Player health",                         type = "number", min = 1, max = 10000 },
    { name = "jdm_playerwalkspeed", default = "100", help = "Walk speed (%)",                        type = "number", min = 10, max = 1000 },
    { name = "jdm_playerrunspeed",  default = "100", help = "Sprint speed (%)",                      type = "number", min = 10, max = 1000 },
    { name = "jdm_gravity",         default = "100", help = "Gravity (%)",                           type = "number", min = 1, max = 1000 },
    { name = "jdm_maxkills",        default = "30",  help = "Kills to win the match",                type = "number", min = 1, max = 1000 },
    { name = "jdm_moabkills",       default = "25",  help = "Kills to get the MOAB",                 type = "number", min = 1, max = 1000 },
    { name = "jdm_moabtimer",       default = "30",  help = "MOAB duration (seconds)",               type = "number", min = 1, max = 600 },
    { name = "jdm_flashlight",      default = "1",   help = "Allow the flashlight",                  type = "bool" },
    { name = "jdm_farspawn",        default = "0",   help = "Spawn far from enemies",                type = "bool" },
    { name = "jdm_slowmo",          default = "30",  help = "Slow motion speed on the winning kill (%)", type = "number", min = 5, max = 100 },
    { name = "jdm_winmusic",        default = "music/hl2_song20_submix0.mp3", help = "Victory music (sound path)", type = "music" },
}

for _, cvar in ipairs(JDM.ConVars) do
    if !ConVarExists(cvar.name) then
        CreateConVar(cvar.name, cvar.default, flags, cvar.help)
    end
end
