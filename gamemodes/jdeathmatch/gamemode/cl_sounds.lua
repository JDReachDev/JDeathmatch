-- Client-side sound management

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.Sounds = JDM.Client.Sounds or {}
    
    -- MOAB sound path
    JDM.Client.Sounds.MOABSoundPath = "jdm_moabsound.wav"
    JDM.Client.Sounds.MOABFallbackSound = "ambient/machines/teleport1.wav"
    
    -- Victory sound path (same location as annihilator sound)
    JDM.Client.Sounds.VictorySoundPath = "jdm_winsound.wav"
    JDM.Client.Sounds.VictoryFallbackSound = "ambient/machines/teleport1.wav"
    
    -- Play MOAB sound
    function JDM.Client.Sounds.PlayMOAB()
        local soundPath = JDM.Client.Sounds.MOABSoundPath

        -- Check if sound exists
        local fullPath = "sound/" .. soundPath
        if file.Exists(fullPath, "GAME") then
            surface.PlaySound(soundPath)
        else
            print("[WARN] MOAB sound not found (" .. fullPath .. "), using fallback.")
            -- Use fallback sound
            surface.PlaySound(JDM.Client.Sounds.MOABFallbackSound)
        end
    end
    
    -- Play victory sound
    function JDM.Client.Sounds.PlayVictory()
        -- jdm_winmusic (replicated from the server), the classic sound if it is empty
        local soundPath = GetConVar("jdm_winmusic"):GetString()
        if soundPath == "" then soundPath = JDM.Client.Sounds.VictorySoundPath end

        -- Check if sound exists
        local fullPath = "sound/" .. soundPath
        if file.Exists(fullPath, "GAME") then
            surface.PlaySound(soundPath)
        else
            print("[WARN] Victory sound not found (" .. fullPath .. "), using fallback.")
            -- Use fallback sound
            surface.PlaySound(JDM.Client.Sounds.VictoryFallbackSound)
        end
    end
    
    -- New Annihilator: sound and banner (player, name, MOAB weapon class and name)
    net.Receive("JDM_SendMoabSound", function()
        local ply, name = net.ReadEntity(), net.ReadString()
        local weaponID, weaponName = net.ReadString(), net.ReadString()
        JDM.Client.Sounds.PlayMOAB()
        JDM.Client.Announce.Show("moab", {
            ply = ply, name = name,
            sub = "with " .. weaponName,
            weapon = { id = weaponID, name = weaponName },
        })
    end)

    -- Match won: sound and banner (player, name, kills)
    net.Receive("JDM_SendVictorySound", function()
        local ply, name, kills = net.ReadEntity(), net.ReadString(), net.ReadUInt(16)
        JDM.Client.Sounds.PlayVictory()
        JDM.Client.Announce.Show("win", { ply = ply, name = name, sub = "has won the match  ·  " .. kills .. " kills" })
    end)
end
