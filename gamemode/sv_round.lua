-- Round management and winner

if SERVER then
    JDM = JDM or {}
    JDM.Round = JDM.Round or {}
    
    -- Freeze all players and show winner
    function JDM.Round.FreezeTimeAndShowWinner(winner)
        if !IsValid(winner) then return end
        
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
    
    -- Check if a player has won
    hook.Add("PlayerDeath", "JDM_CheckWinner", function(victim, inflictor, attacker)
        if !IsValid(attacker) or !attacker:IsPlayer() then return end
        
        local kills = attacker:Frags()
        local maxKills = GetConVar("jdm_maxkills"):GetInt()
        
        -- Check if player reached max kills
        if kills >= maxKills then
            JDM.Round.FreezeTimeAndShowWinner(attacker)
        end
    end)
end
