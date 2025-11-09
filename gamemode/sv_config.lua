-- Server-side configuration and ConVars

if SERVER then
    -- ConVar for player health
    if !ConVarExists("jdm_playerhealth") then 
        CreateConVar("jdm_playerhealth", "100", FCVAR_NOTIFY, "Set player health") 
    end

    -- ConVar for walk speed
    if !ConVarExists("jdm_playerwalkspeed") then 
        CreateConVar("jdm_playerwalkspeed", "100", FCVAR_NOTIFY, "Set player walk speed") 
    end

    -- ConVar for run speed
    if !ConVarExists("jdm_playerrunspeed") then 
        CreateConVar("jdm_playerrunspeed", "100", FCVAR_NOTIFY, "Set player run speed") 
    end

    -- ConVar for gravity
    if !ConVarExists("jdm_gravity") then 
        CreateConVar("jdm_gravity", "100", FCVAR_NOTIFY, "Set gravity") 
    end

    -- ConVar for max kills
    if !ConVarExists("jdm_maxkills") then 
        CreateConVar("jdm_maxkills", "30", FCVAR_NOTIFY, "Set max kills") 
    end

    -- ConVar for MOAB kills
    if !ConVarExists("jdm_moabkills") then 
        CreateConVar("jdm_moabkills", "25", FCVAR_NOTIFY, "Set moab kills") 
    end

    -- ConVar for MOAB timer
    if !ConVarExists("jdm_moabtimer") then 
        CreateConVar("jdm_moabtimer", "30", FCVAR_NOTIFY, "Set moab timer") 
    end

    -- ConVar for flashlight
    if !ConVarExists("jdm_flashlight") then 
        CreateConVar("jdm_flashlight", "1", FCVAR_NOTIFY, "Enable Flashlight") 
    end

    -- ConVar for far spawn
    if !ConVarExists("jdm_farspawn") then 
        CreateConVar("jdm_farspawn", "1", FCVAR_NOTIFY, "Enable FarSpawn") 
    end
end

