-- Client-side sound management

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.Sounds = JDM.Client.Sounds or {}
    
    -- MOAB sound path
    JDM.Client.Sounds.MOABSoundPath = "jdm_moabSound.wav"
    JDM.Client.Sounds.MOABFallbackSound = "ambient/machines/teleport1.wav"
    
    -- Play MOAB sound
    function JDM.Client.Sounds.PlayMOAB()
        local soundPath = JDM.Client.Sounds.MOABSoundPath
        
        print("[DEBUG] Attempting to play MOAB sound: " .. soundPath)
        
        -- Check if sound exists
        local fullPath = "sound/" .. soundPath
        if file.Exists(fullPath, "GAME") then
            print("[DEBUG] Sound found, playing: " .. soundPath)
            surface.PlaySound(soundPath)
        else
            print("[WARN] Sound " .. fullPath .. " was not found! Using fallback.")
            -- Use fallback sound
            surface.PlaySound(JDM.Client.Sounds.MOABFallbackSound)
        end
    end
    
    -- Receive command to play MOAB sound
    net.Receive("SendMoabSound", function()
        print("[DEBUG] Received SendMoabSound command from server")
        JDM.Client.Sounds.PlayMOAB()
    end)
end
