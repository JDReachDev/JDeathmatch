-- Round management and winner

if SERVER then
    JDM = JDM or {}
    JDM.Round = JDM.Round or {}
    
    -- Track if slow motion is active
    JDM.Round.SlowMotionActive = false
    JDM.Round.SlowMotionStartTime = 0
    JDM.Round.SlowMotionDuration = 5 -- 5 seconds of slow motion
    JDM.Round.OriginalPlayerSpeeds = {} -- Store original player speeds
    
    -- Start slow motion (50% speed for 5 seconds)
    function JDM.Round.StartSlowMotion(winner)
        if !IsValid(winner) then return end
        
        -- Set slow motion active
        JDM.Round.SlowMotionActive = true
        JDM.Round.SlowMotionStartTime = CurTime()
        
        -- Play victory sound immediately
        print("[DEBUG] Sending victory sound to all clients")
        net.Start("SendVictorySound")
        net.Broadcast()
        print("[DEBUG] Victory sound sent")
        
        -- Store original speeds and apply slow motion to all players
        JDM.Round.OriginalPlayerSpeeds = {}
        for _, ply in ipairs(player.GetAll()) do
            if !IsValid(ply) then continue end
            
            -- Store original speeds
            local walkSpeed = ply:GetWalkSpeed()
            local runSpeed = ply:GetRunSpeed()
            JDM.Round.OriginalPlayerSpeeds[ply:SteamID()] = {
                walkSpeed = walkSpeed,
                runSpeed = runSpeed
            }
            
            -- Apply 50% speed
            ply:SetWalkSpeed(walkSpeed * 0.5)
            ply:SetRunSpeed(runSpeed * 0.5)
        end
        
        -- Try to use host_timescale for true slow motion (requires server admin)
        -- This will slow down everything: animations, physics, etc.
        -- Note: host_timescale affects game speed but timers run in real time
        RunConsoleCommand("host_timescale", "0.5")
        
        -- After 5 seconds of real time, end slow motion and show freeze frame
        -- The game will run at 50% speed during these 5 real seconds
        timer.Simple(5, function()
            JDM.Round.EndSlowMotionAndFreeze(winner)
        end)
    end
    
    -- End slow motion and freeze all players
    function JDM.Round.EndSlowMotionAndFreeze(winner)
        if !IsValid(winner) then return end
        
        -- Reset slow motion
        JDM.Round.SlowMotionActive = false
        
        -- Reset host_timescale to normal
        RunConsoleCommand("host_timescale", "1.0")
        
        -- Restore original player speeds
        for _, ply in ipairs(player.GetAll()) do
            if !IsValid(ply) then continue end
            
            local steamID = ply:SteamID()
            if JDM.Round.OriginalPlayerSpeeds[steamID] then
                local speeds = JDM.Round.OriginalPlayerSpeeds[steamID]
                ply:SetWalkSpeed(speeds.walkSpeed)
                ply:SetRunSpeed(speeds.runSpeed)
            else
                -- Fallback: restore from config
                ply:SetWalkSpeed(2.65 * GetConVar("jdm_playerwalkspeed"):GetFloat())
                ply:SetRunSpeed(4.10 * GetConVar("jdm_playerrunspeed"):GetFloat())
            end
        end
        
        -- Clear stored speeds
        JDM.Round.OriginalPlayerSpeeds = {}
        
        -- Freeze all players
        for _, ply in ipairs(player.GetAll()) do
            if !IsValid(ply) then continue end
            
            ply:Freeze(true)
            ply:SetNWBool("JDM_DisableFire", true)
            
            if ply ~= winner then
                -- Point camera at winner
                ply:StripWeapons()
                ply:Spectate(OBS_MODE_CHASE)
                ply:SpectateEntity(winner)
            end
        end
        
        -- Message for everyone
        PrintMessage(HUD_PRINTCENTER, winner:Nick() .. " has won the match!")
        
        -- After 5 seconds, show map voting menu
        timer.Simple(5, function()
            if JDM.MapVote and JDM.MapVote.AvailableMaps then
                net.Start("SendMapList")
                net.WriteTable(JDM.MapVote.AvailableMaps)
                net.Broadcast()
            end
        end)
        
        -- After 20 seconds, change map
        timer.Simple(20, function()
            if JDM.MapVote then
                JDM.MapVote.ChangeToWinningMap()
            end
        end)
    end
    
    -- Freeze all players and show winner (legacy function, now replaced by StartSlowMotion)
    function JDM.Round.FreezeTimeAndShowWinner(winner)
        if !IsValid(winner) then return end
        
        -- Start slow motion phase first
        JDM.Round.StartSlowMotion(winner)
    end
    
    -- Check if a player has won
    hook.Add("PlayerDeath", "JDM_CheckWinner", function(victim, inflictor, attacker)
        if !IsValid(attacker) or !attacker:IsPlayer() then return end
        
        local kills = attacker:Frags()
        local maxKills = GetConVar("jdm_maxkills"):GetInt()
        
        -- Check if player reached max kills
        if kills >= maxKills then
            JDM.Round.StartSlowMotion(attacker)
        end
    end)
end
