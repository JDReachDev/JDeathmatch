-- Round management and winner

if SERVER then
    JDM = JDM or {}
    JDM.Round = JDM.Round or {}
    JDM.Round.IsEnding = JDM.Round.IsEnding or false
    
    -- Track if slow motion is active
    JDM.Round.SlowMotionActive = false
    JDM.Round.SlowMotionStartTime = 0
    JDM.Round.SlowMotionDuration = 5 -- 5 seconds of slow motion
    JDM.Round.OriginalPlayerSpeeds = {} -- Store original player speeds
    
    -- Start slow motion (50% speed for 5 seconds)
    function JDM.Round.StartSlowMotion(winner)
        if !IsValid(winner) then return end
        if JDM.Round.IsEnding then return end
        JDM.Round.IsEnding = true
        
        -- Set slow motion active
        JDM.Round.SlowMotionActive = true
        JDM.Round.SlowMotionStartTime = CurTime()
        
        -- Play victory sound immediately
        net.Start("JDM_SendVictorySound")
        net.Broadcast()
        
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
        
        -- Slow down everything: animations, physics, etc.
        -- (host_timescale would need sv_cheats, game.SetTimeScale does not)
        game.SetTimeScale(0.5)

        -- After 5 game seconds, end slow motion and show freeze frame
        timer.Create("JDM_Round_EndSlowMotion", 5, 1, function()
            JDM.Round.EndSlowMotionAndFreeze(winner)
        end)
    end
    
    -- End slow motion and freeze all players
    function JDM.Round.EndSlowMotionAndFreeze(winner)
        -- Reset slow motion (always, even if the winner disconnected)
        JDM.Round.SlowMotionActive = false
        game.SetTimeScale(1)

        if !IsValid(winner) then
            JDM.MapVote.ChangeToWinningMap()
            return
        end
        
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
        timer.Create("JDM_Round_MapVote", 5, 1, function()
            if JDM.MapVote and JDM.MapVote.AvailableMaps then
                net.Start("JDM_SendMapList")
                net.WriteTable(JDM.MapVote.AvailableMaps)
                net.Broadcast()
            end
        end)
        
        -- After 20 seconds, change map
        timer.Create("JDM_Round_ChangeMap", 20, 1, function()
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
    
    -- No respawning while the match is ending
    hook.Add("PlayerDeathThink", "JDM_BlockRespawnOnRoundEnd", function(ply)
        if JDM.Round.IsEnding then return false end
    end)

    -- Check if a player has won
    hook.Add("PlayerDeath", "JDM_CheckWinner", function(victim, inflictor, attacker)
        if JDM.Round.IsEnding then return end
        if !IsValid(attacker) or !attacker:IsPlayer() then return end
        
        local kills = attacker:Frags()
        local maxKills = GetConVar("jdm_maxkills"):GetInt()
        
        -- Check if player reached max kills
        if kills >= maxKills then
            JDM.Round.StartSlowMotion(attacker)
        end
    end)
end
