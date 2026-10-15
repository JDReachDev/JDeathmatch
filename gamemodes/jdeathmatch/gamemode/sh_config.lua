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

-- Default weapons configuration used to bootstrap data/jdmw.txt.
JDM.Config.DefaultWeapons = {
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
