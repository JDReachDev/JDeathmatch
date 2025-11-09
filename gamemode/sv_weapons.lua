-- Server-side weapons management

if SERVER then
    JDM = JDM or {}
    JDM.Weapons = JDM.Weapons or {}
    
    -- Data structures
    JDM.Weapons.Slots = {
        [1] = {}, -- Slot 1
        [2] = {}, -- Slot 2
        [3] = {}, -- Slot 3
        [4] = {}, -- Slot 4
    }
    JDM.Weapons.MOAB = {}
    JDM.Weapons.List = nil
    JDM.Weapons.Indexed = {}
    JDM.Weapons.PlayerSelections = {}
    
    -- Load weapons from JSON file
    function JDM.Weapons.Load()
        local filePath = JDM.Config.WeaponFilePath
        
        if !file.Exists(filePath, "DATA") then
            print("[ERROR] Weapons file does not exist: " .. filePath)
            JDM.Weapons.List = {}
            return
        end
        
        local jsonData = file.Read(filePath, "DATA")
        if !jsonData then
            print("[ERROR] Unable to read weapons file!")
            JDM.Weapons.List = {}
            return
        end
        
        JDM.Weapons.List = util.JSONToTable(jsonData)
        if !JDM.Weapons.List then
            print("[ERROR] Error parsing JSON file!")
            JDM.Weapons.List = {}
            return
        end
        
        -- Reset structures
        for i = 1, 4 do
            JDM.Weapons.Slots[i] = {}
        end
        JDM.Weapons.MOAB = {}
        JDM.Weapons.Indexed = {}
        
        -- Divide weapons by slot
        for _, weapon in ipairs(JDM.Weapons.List) do
            if !weapon.id then
                print("[WARN] A weapon does not have a valid ID and was not indexed.")
                continue
            end
            
            -- MOAB weapons (special slot 666)
            if weapon.slot == JDM.Config.MOABSlot then
                JDM.Weapons.MOAB[weapon.id] = weapon
            else
                -- Slot validation
                if weapon.slot and weapon.slot >= 1 and weapon.slot <= 4 then
                    table.insert(JDM.Weapons.Slots[weapon.slot], weapon)
                    
                    -- Slot 3 weapons are also added to slot 4
                    if weapon.slot == 3 then
                        table.insert(JDM.Weapons.Slots[4], weapon)
                    end
                else
                    print("[WARN] Weapon " .. weapon.id .. " has an invalid slot: " .. tostring(weapon.slot))
                end
            end
            
            -- Indexing for fast access
            JDM.Weapons.Indexed[weapon.id] = weapon
        end
        
        print("[INFO] Weapons loaded and divided into slots!")
    end
    
    -- Validate a weapon selection
    function JDM.Weapons.ValidateSelection(selection)
        if !selection then return false end
        
        for slot, weaponID in pairs(selection) do
            if !weaponID or !JDM.Weapons.Indexed[weaponID] then
                return false, "Invalid weapon: " .. tostring(weaponID)
            end
            
            if !JDM.Weapons.Slots[slot] then
                return false, "Invalid slot: " .. tostring(slot)
            end
            
            local isValid = false
            for _, weapon in ipairs(JDM.Weapons.Slots[slot]) do
                if weapon.id == weaponID then
                    isValid = true
                    break
                end
            end
            
            if !isValid then
                return false, "Weapon " .. weaponID .. " is not valid for slot " .. slot
            end
        end
        
        return true
    end
    
    -- Give selected weapons to player
    function JDM.Weapons.GiveToPlayer(ply, selection)
        if !IsValid(ply) or !selection then return end
        
        local weaponsEmpty = true
        
        for slot, weaponID in pairs(selection) do
            if !weaponID then continue end
            
            ply:Give(weaponID)
            weaponsEmpty = false
            local wep = ply:GetWeapon(weaponID)
            
            if IsValid(wep) then
                local weaponObj = JDM.Weapons.Indexed[weaponID]
                if !weaponObj then continue end
                
                -- Ammunition management
                if weaponObj.ammo and weaponObj.ammo ~= 0 then
                    local maxClipSize = wep:GetMaxClip1()
                    local clipAmmo, bagAmmo
                    
                    if maxClipSize > weaponObj.ammo then
                        clipAmmo = weaponObj.ammo
                        bagAmmo = 0
                    else
                        clipAmmo = maxClipSize
                        bagAmmo = weaponObj.ammo - clipAmmo
                    end
                    
                    wep:SetClip1(clipAmmo)
                    wep:SetClip2(0)
                    
                    -- Add ammunition to reserve
                    local ammoType = wep:GetPrimaryAmmoType()
                    if ammoType >= 0 then
                        ply:SetAmmo(bagAmmo, ammoType, true)
                    end
                end
                
                -- Damage multiplier (note: this modification does not persist after respawn)
                if weaponObj.dmgmul and wep.Primary then
                    wep.Primary.Damage = (wep.Primary.Damage or 10) * weaponObj.dmgmul
                end
            end
        end
        
        -- If no weapons selected, give the first available
        if weaponsEmpty then
            if JDM.Weapons.List and JDM.Weapons.List[1] and JDM.Weapons.List[1].id then
                ply:Give(JDM.Weapons.List[1].id)
            end
        end
    end
    
    -- Receive weapon selection from client
    net.Receive("SetPlayerWeapons", function(len, ply)
        if !IsValid(ply) then return end
        
        local selection = net.ReadTable()
        local isValid, errorMsg = JDM.Weapons.ValidateSelection(selection)
        
        if !isValid then
            ply:ChatPrint("Invalid weapon selection: " .. (errorMsg or "Unknown error"))
            return
        end
        
        -- Save selection
        JDM.Weapons.PlayerSelections[ply:SteamID()] = selection
        
        -- If first spawn, spawn the player
        if JDM.Player.FirstSpawn[ply:SteamID()] then
            ply:UnSpectate()
            JDM.Player.FirstSpawn[ply:SteamID()] = false
            ply:Spawn()
        else
            ply:ChatPrint("Weapons saved for next spawn!")
        end
    end)
    
    -- Send weapon list to clients when they connect
    hook.Add("PlayerInitialSpawn", "JDM_SendWeaponSlots", function(ply)
        if !IsValid(ply) then return end
        
        net.Start("SendWeaponSlots")
        net.WriteTable(JDM.Weapons.Slots)
        net.Send(ply)
    end)
    
    -- Command to reload weapons
    concommand.Add("jdm_reloadWeaponsConfig", function(ply, cmd, args)
        if IsValid(ply) and !ply:IsAdmin() then
            ply:ChatPrint("Only admins can use this command!")
            return
        end
        
        JDM.Weapons.Load()
        print("[INFO] Weapons configuration reloaded!")
        
        if IsValid(ply) then
            ply:ChatPrint("Weapons configuration reloaded!")
        end
    end)
    
    -- Load weapons on startup
    JDM.Weapons.Load()
end
