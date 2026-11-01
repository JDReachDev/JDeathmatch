-- Kill feed (server side): works out the weapon name from the config and sends it to everyone

if SERVER then
    JDM = JDM or {}

    -- Config name, then the SWEP name, then the class
    local function WeaponName(class)
        local weapon = JDM.Weapons.Indexed[class]
        if weapon and weapon.name then return weapon.name end
        local swep = weapons.Get(class)
        if swep and swep.PrintName then return swep.PrintName end
        return class
    end

    hook.Add("DoPlayerDeath", "JDM_KillFeed", function(victim, attacker, dmginfo)
        local inflictor = dmginfo:GetInflictor()
        local killer, text

        if IsValid(attacker) and attacker:IsPlayer() and attacker != victim then
            killer = attacker
            local class
            if IsValid(inflictor) and inflictor != attacker then
                -- Projectiles carry the class of the weapon that fired them (sv_weapons.lua)
                class = inflictor.JDM_WeaponClass or inflictor:GetClass()
            else
                local wep = attacker:GetActiveWeapon()
                class = IsValid(wep) and wep:GetClass() or "unknown"
            end
            text = WeaponName(class)
        elseif attacker == victim then
            text = "Suicide"
        elseif dmginfo:IsFallDamage() then
            text = "Fall"
        else
            text = "World"
        end

        net.Start("JDM_KillFeed")
        net.WriteEntity(killer or NULL)
        net.WriteString(IsValid(killer) and killer:Nick() or "")
        net.WriteEntity(victim)
        net.WriteString(victim:Nick())
        net.WriteString(text)
        net.WriteBool(victim:LastHitGroup() == HITGROUP_HEAD)
        net.Broadcast()
    end)
end
