-- Round management and winner

if SERVER then
    JDM = JDM or {}
    JDM.Round = JDM.Round or {}
    JDM.Round.IsEnding = JDM.Round.IsEnding or false
    
    -- Track if slow motion is active
    JDM.Round.SlowMotionActive = false
    JDM.Round.SlowMotionStartTime = 0
    JDM.Round.SlowMotionDuration = 8 -- real seconds of slow motion

    -- Start slow motion (jdm_slowmo % speed, 30% by default)
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
        
        -- Slow down everything: movement, animations, physics, etc.
        -- (host_timescale would need sv_cheats, game.SetTimeScale does not)
        -- Player speeds are left untouched, halving them too would give 25%.
        local scale = math.Clamp(GetConVar("jdm_slowmo"):GetFloat(), 5, 100) / 100
        game.SetTimeScale(scale)

        -- Timers run on game time: the slow motion lasts SlowMotionDuration real seconds at any speed
        timer.Create("JDM_Round_EndSlowMotion", JDM.Round.SlowMotionDuration * scale, 1, function()
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
