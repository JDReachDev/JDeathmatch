-- Server-side player management and hooks

if SERVER then
    JDM = JDM or {}
    JDM.Player = JDM.Player or {}
    
    -- Table to track first spawn
    JDM.Player.FirstSpawn = {}
    
    -- Player spawn handling
    function GM:PlayerSpawn(ply)
        if !IsValid(ply) then return end
        
        -- First spawn: put in spectate
        if JDM.Player.FirstSpawn[JDM.PlayerKey(ply)] then
            ply:StripWeapons()
            ply:Spectate(OBS_MODE_ROAMING)
            return
        end
        
        -- Far spawn if enabled
        if GetConVar("jdm_farspawn"):GetBool() then
            local farthestSpawn = JDM.Spawn.GetFarthestSpawn(ply)
            
            if IsValid(farthestSpawn) then
                ply:SetPos(farthestSpawn:GetPos())
                ply:SetAngles(farthestSpawn:GetAngles())
            else
                print("[WARN] No valid spawn point found. Using default spawn.")
            end
        end
        
        -- Set player statistics
        local health = GetConVar("jdm_playerhealth"):GetInt()
        ply:SetMaxHealth(health)
        ply:SetHealth(health)
        ply:SetWalkSpeed(2.65 * GetConVar("jdm_playerwalkspeed"):GetFloat())
        ply:SetRunSpeed(4.10 * GetConVar("jdm_playerrunspeed"):GetFloat())
        ply:SetGravity(0.01 * GetConVar("jdm_gravity"):GetFloat())

        -- Flashlight
        if GetConVar("jdm_flashlight"):GetBool() then
            ply:AllowFlashlight(true)
        else
            ply:AllowFlashlight(false)
        end

        -- Player model (before SetupHands, so the hands match the model)
        local preferredModel = player_manager.TranslatePlayerModel(ply:GetInfo("cl_playermodel"))
        if preferredModel then
            ply:SetModel(preferredModel)
        end

        ply:SetupHands()
    end
    
    -- First spawn handling
    function GM:PlayerInitialSpawn(ply)
        if !IsValid(ply) then return end

        -- Bots can't use the loadout menu: they spawn right away with the default weapon
        if ply:IsBot() then return end

        JDM.Player.FirstSpawn[JDM.PlayerKey(ply)] = true
        
        ply:ChatPrint("Welcome to JDeathmatch")
        ply:ChatPrint("Press Q to access the weapon menu")
        ply:ChatPrint("Get " .. GetConVar("jdm_maxkills"):GetInt() .. " kills to win the match.")
        ply:ChatPrint("Get " .. GetConVar("jdm_moabkills"):GetInt() .. " kills to become an Annihilator.")
    end
    
    -- Give weapons to player when they spawn
    hook.Add("PlayerSpawn", "JDM_GivePlayerWeapons", function(ply)
        if !IsValid(ply) then return end
        
        -- Skip if first spawn
        if JDM.Player.FirstSpawn[JDM.PlayerKey(ply)] then
            return
        end
        
        -- Get player selection (no selection = default weapon)
        local selection = JDM.Weapons.PlayerSelections[JDM.PlayerKey(ply)]
        JDM.Weapons.GiveToPlayer(ply, selection or {})
    end)
    
    -- Remove annoying tinnitus sound
    hook.Add("OnDamagedByExplosion", "JDM_DisableTinnitus", function()
        return true
    end)
    
    -- Clean up player data on disconnect
    hook.Add("PlayerDisconnected", "JDM_CleanupPlayerData", function(ply)
        if !IsValid(ply) then return end
        
        local steamID = JDM.PlayerKey(ply)
        JDM.Player.FirstSpawn[steamID] = nil
        JDM.Weapons.PlayerSelections[steamID] = nil
        
        if JDM.MapVote then
            JDM.MapVote.Votes[steamID] = nil
        end
        
        if JDM.MOAB then
            JDM.MOAB.Players[steamID] = nil
        end
    end)
end
