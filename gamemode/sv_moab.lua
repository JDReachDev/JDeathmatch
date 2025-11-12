-- MOAB (Mother of All Bombs) system - Special weapons for kill streaks

if SERVER then
    JDM = JDM or {}
    JDM.MOAB = JDM.MOAB or {}
    
    -- Table to track players who have already received MOAB
    JDM.MOAB.Players = {}
    
    -- Assign a random MOAB weapon to player
    function JDM.MOAB.AssignRandomWeapon(ply)
        if !IsValid(ply) then return end
        
        -- Check if MOAB weapons are available
        if table.Count(JDM.Weapons.MOAB) == 0 then
            print("[WARN] No MOAB weapons available!")
            return
        end
        
        -- Get weapon IDs (table keys)
        local weaponIDs = table.GetKeys(JDM.Weapons.MOAB)
        if #weaponIDs == 0 then
            print("[WARN] No MOAB weapons available!")
            return
        end
        
        -- Choose a random ID
        local randomWeaponID = weaponIDs[math.random(1, #weaponIDs)]
        local weapon = JDM.Weapons.MOAB[randomWeaponID]
        
        -- Make sure weapon is valid
        if !weapon or !weapon.id or !weapon.name then
            print("[WARN] A MOAB weapon is not valid!")
            return
        end
        
        -- Give weapon to player
        ply:Give(weapon.id)
        
        -- Notify all players
        local message = ply:Nick() .. " has become an Annihilator with " .. weapon.name .. "."
        PrintMessage(HUD_PRINTCENTER, message)
        
        -- Play sound to all players
        print("[DEBUG] Sending MOAB sound to all clients")
        net.Start("SendMoabSound")
        net.Broadcast()
        print("[DEBUG] MOAB sound sent")
        
        -- After X seconds, remove weapon
        local timerSeconds = GetConVar("jdm_moabtimer"):GetInt()
        timer.Simple(timerSeconds, function()
            if IsValid(ply) then
                ply:StripWeapon(weapon.id)
                PrintMessage(HUD_PRINTTALK, ply:Nick() .. " is no longer an Annihilator.")
            end
        end)
    end
    
    -- Check if a player has reached MOAB kills
    hook.Add("PlayerDeath", "JDM_CheckMOABKills", function(victim, inflictor, attacker)
        if !IsValid(attacker) or !attacker:IsPlayer() then return end
        
        local kills = attacker:Frags()
        local moabKills = GetConVar("jdm_moabkills"):GetInt()
        local steamID = attacker:SteamID()
        
        -- Check if reached MOAB kills and hasn't received MOAB yet
        if kills == moabKills and !JDM.MOAB.Players[steamID] then
            JDM.MOAB.Players[steamID] = true
            JDM.MOAB.AssignRandomWeapon(attacker)
            -- Sync MOAB status to all clients
            JDM.MOAB.SyncToClients()
        end
    end)
    
    -- Sync MOAB status to all clients
    function JDM.MOAB.SyncToClients()
        net.Start("SendMoabStatus")
        -- Send list of SteamIDs who have MOAB
        local moabPlayers = {}
        for steamID, _ in pairs(JDM.MOAB.Players) do
            table.insert(moabPlayers, steamID)
        end
        net.WriteTable(moabPlayers)
        net.Broadcast()
    end
    
    -- Send MOAB status when player connects
    hook.Add("PlayerInitialSpawn", "JDM_SendMoabStatus", function(ply)
        if !IsValid(ply) then return end
        timer.Simple(1, function()
            if IsValid(ply) then
                JDM.MOAB.SyncToClients()
            end
        end)
    end)
end
