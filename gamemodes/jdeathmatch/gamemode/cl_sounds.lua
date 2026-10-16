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
        local soundPath = JDM.Client.Sounds.VictorySoundPath

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
    
    -- Receive command to play MOAB sound
    net.Receive("JDM_SendMoabSound", function()
        JDM.Client.Sounds.PlayMOAB()
    end)
    
    -- Receive command to play victory sound
    net.Receive("JDM_SendVictorySound", function()
        JDM.Client.Sounds.PlayVictory()
    end)
end
