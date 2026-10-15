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
    JDM.Weapons.LastSelectionAt = {}

    function JDM.Weapons.WriteDefaultConfig(filePath)
        local defaultWeapons = JDM.Config and JDM.Config.DefaultWeapons
        if !istable(defaultWeapons) or #defaultWeapons == 0 then
            print("[ERROR] Missing JDM.Config.DefaultWeapons, cannot build default weapons JSON.")
            return false
        end

        local jsonData = util.TableToJSON(defaultWeapons, true)
        if !jsonData then
            print("[ERROR] Failed to build default weapons JSON.")
            return false
        end

        file.Write(filePath, jsonData)
        print("[WARN] Weapons config missing/invalid. Generated default config at data/" .. filePath)
        return true
    end
    
    -- Load weapons from JSON file
    function JDM.Weapons.Load()
        local filePath = JDM.Config.WeaponFilePath
        
        if !file.Exists(filePath, "DATA") then
            JDM.Weapons.WriteDefaultConfig(filePath)
        end
        
        local jsonData = file.Read(filePath, "DATA")
        if !jsonData then
            if !JDM.Weapons.WriteDefaultConfig(filePath) then
                print("[ERROR] Unable to read weapons file!")
                JDM.Weapons.List = {}
                return
            end
            jsonData = file.Read(filePath, "DATA")
            if !jsonData then
                print("[ERROR] Unable to read generated weapons file!")
                JDM.Weapons.List = {}
                return
            end
        end
        
        JDM.Weapons.List = util.JSONToTable(jsonData)
        if !istable(JDM.Weapons.List) or #JDM.Weapons.List == 0 then
            if !JDM.Weapons.WriteDefaultConfig(filePath) then
                print("[ERROR] Error parsing JSON file!")
                JDM.Weapons.List = {}
                return
            end

            jsonData = file.Read(filePath, "DATA")
            JDM.Weapons.List = util.JSONToTable(jsonData or "")
            if !istable(JDM.Weapons.List) or #JDM.Weapons.List == 0 then
                print("[ERROR] Generated weapons config is invalid.")
                JDM.Weapons.List = {}
                return
            end
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
            if !isnumber(slot) or slot < 1 or slot > 4 then
                return false, "Invalid slot: " .. tostring(slot)
            end

            if !isstring(weaponID) or weaponID == "" or #weaponID > 64 then
                return false, "Invalid weapon: " .. tostring(weaponID)
            end
            
            if !JDM.Weapons.Indexed[weaponID] then
                return false, "Invalid weapon: " .. tostring(weaponID)
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
    net.Receive("JDM_SetPlayerWeapons", function(len, ply)
        if !IsValid(ply) then return end

        local steamID = ply:SteamID()
        local now = CurTime()
        local lastUpdate = JDM.Weapons.LastSelectionAt[steamID] or 0
        if now - lastUpdate < 1 then
            return
        end
        JDM.Weapons.LastSelectionAt[steamID] = now

        local selection = {}
        for slot = 1, 4 do
            local weaponID = net.ReadString()
            if weaponID != "" then
                selection[slot] = weaponID
            end
        end
        local isValid, errorMsg = JDM.Weapons.ValidateSelection(selection)
        
        if !isValid then
            ply:ChatPrint("Invalid weapon selection: " .. (errorMsg or "Unknown error"))
            return
        end
        
        -- Save selection
        JDM.Weapons.PlayerSelections[steamID] = selection
        
        -- If first spawn, spawn the player
        if JDM.Player.FirstSpawn[steamID] then
            ply:UnSpectate()
            JDM.Player.FirstSpawn[steamID] = false
            ply:Spawn()
        else
            ply:ChatPrint("Weapons saved for next spawn!")
        end
    end)
    
    -- Damage multiplier from config (applied per hit, so it never stacks)
    hook.Add("EntityTakeDamage", "JDM_WeaponDamageMultiplier", function(target, dmginfo)
        local attacker = dmginfo:GetAttacker()
        if !IsValid(attacker) or !attacker:IsPlayer() then return end

        local wep = dmginfo:GetInflictor()
        if wep == attacker then
            wep = attacker:GetActiveWeapon()
        end
        if !IsValid(wep) then return end

        local weaponObj = JDM.Weapons.Indexed[wep:GetClass()]
        if weaponObj and isnumber(weaponObj.dmgmul) and weaponObj.dmgmul != 1 then
            dmginfo:ScaleDamage(weaponObj.dmgmul)
        end
    end)

    -- Send weapon slots to one player or a list of players
    function JDM.Weapons.SendSlots(target, openMenu)
        net.Start("JDM_SendWeaponSlots")
        net.WriteTable(JDM.Weapons.Slots)
        net.WriteBool(openMenu)
        net.Send(target)
    end

    -- Client asks for the weapon list once it is fully loaded
    -- (net messages sent during PlayerInitialSpawn can be lost)
    net.Receive("JDM_RequestWeaponSlots", function(len, ply)
        if !IsValid(ply) or ply.JDM_SlotsRequested then return end
        ply.JDM_SlotsRequested = true

        JDM.Weapons.SendSlots(ply, JDM.Player.FirstSpawn[ply:SteamID()] == true)
    end)
    
    -- Command to reload weapons
    concommand.Add("jdm_reloadWeaponsConfig", function(ply, cmd, args)
        if IsValid(ply) and !ply:IsAdmin() then
            ply:ChatPrint("Only admins can use this command!")
            return
        end
        
        JDM.Weapons.Load()
        JDM.Weapons.SendSlots(player.GetHumans(), false)
        print("[INFO] Weapons configuration reloaded!")

        if IsValid(ply) then
            ply:ChatPrint("Weapons configuration reloaded!")
        end
    end)
    
    -- Load weapons on startup
    JDM.Weapons.Load()
end
