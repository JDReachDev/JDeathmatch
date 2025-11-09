-- Shared configuration between client and server

JDM = JDM or {}
JDM.Config = JDM.Config or {}

-- Weapons file path
JDM.Config.WeaponFilePath = "jdmw.txt"

-- Weapon slot labels
JDM.Config.WeaponSlotLabels = {
    [1] = "Primary",
    [2] = "Secondary",
    [3] = "Specials",
    [4] = "Specials",
}

-- Special slot for MOAB weapons
JDM.Config.MOABSlot = 666

-- Create default weapons file if it doesn't exist (server-side only)
if SERVER then
    local filePath = JDM.Config.WeaponFilePath
    
    if !file.Exists(filePath, "DATA") then
        print("[WARN] Weapons file does not exist: " .. filePath .. " - Creating default file...")
        
        -- Default weapons configuration
        local defaultWeapons = {
            {
                name = "SMG",
                id = "weapon_smg1",
                ammo = 80,
                dmgmul = 1,
                slot = 1
            },
            {
                name = "AR2",
                id = "weapon_ar2",
                ammo = 60,
                dmgmul = 1,
                slot = 1
            },
            {
                name = "Shotgun",
                id = "weapon_shotgun",
                ammo = 30,
                dmgmul = 1,
                slot = 1
            },
            {
                name = "Pistol",
                id = "weapon_pistol",
                ammo = 5,
                dmgmul = 1,
                slot = 2
            },
            {
                name = "Grenade",
                id = "weapon_frag",
                ammo = 1,
                dmgmul = 1,
                slot = 3
            }
        }
        
        -- Convert to JSON and write to file
        local jsonData = util.TableToJSON(defaultWeapons, true)
        file.Write(filePath, jsonData, "DATA")
        print("[INFO] Default weapons file created: " .. filePath)
    end
end

