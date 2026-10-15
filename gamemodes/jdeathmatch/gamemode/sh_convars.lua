-- ConVars shared between client and server
-- FCVAR_REPLICATED lets clients (scoreboard, HUD) read the server values.

local flags = bit.bor(FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_ARCHIVE)

local convars = {
    { "jdm_playerhealth",    "100", "Set player health" },
    { "jdm_playerwalkspeed", "100", "Set player walk speed (%)" },
    { "jdm_playerrunspeed",  "100", "Set player run speed (%)" },
    { "jdm_gravity",         "100", "Set gravity (%)" },
    { "jdm_maxkills",        "30",  "Set max kills" },
    { "jdm_moabkills",       "25",  "Set moab kills" },
    { "jdm_moabtimer",       "30",  "Set moab timer" },
    { "jdm_flashlight",      "1",   "Enable Flashlight" },
    { "jdm_farspawn",        "0",   "Enable FarSpawn" },
}

for _, cvar in ipairs(convars) do
    if !ConVarExists(cvar[1]) then
        CreateConVar(cvar[1], cvar[2], flags, cvar[3])
    end
end
