-- Client-side HUD: health, armor, ammo, kill progress

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.HUD = JDM.Client.HUD or {}

    local HUD = JDM.Client.HUD

    -- Colors (same red as the logo)
    HUD.Colors = {
        Background = Color(15, 15, 18, 200),
        BarBack    = Color(255, 255, 255, 18),
        Accent     = Color(220, 40, 40),
        Health     = Color(235, 60, 60),
        HealthLow  = Color(255, 150, 40),
        Armor      = Color(60, 150, 255),
        Text       = Color(240, 240, 240),
        TextDim    = Color(160, 160, 165),
        Gold       = Color(255, 200, 0),
    }

    -- Default HL2 elements replaced by this HUD (weapon selection is in cl_weaponselect.lua)
    local hidden = {
        CHudHealth = true,
        CHudBattery = true,
        CHudAmmo = true,
        CHudSecondaryAmmo = true,
    }

    hook.Add("HUDShouldDraw", "JDM_HideDefaultHUD", function(name)
        if hidden[name] then return false end
    end)

    -- Fonts scale with the screen height (designed at 1080p)
    local function CreateFonts()
        local s = ScrH() / 1080
        surface.CreateFont("JDM_HUD_Big",   { font = "Roboto", size = math.Round(46 * s), weight = 800 })
        surface.CreateFont("JDM_HUD_Mid",   { font = "Roboto", size = math.Round(26 * s), weight = 700 })
        surface.CreateFont("JDM_HUD_Small", { font = "Roboto", size = math.Round(17 * s), weight = 600 })
        HUD.Scale = s
    end
    CreateFonts()
    hook.Add("OnScreenSizeChanged", "JDM_HUDFonts", CreateFonts)

    -- Smoothed values, so bars slide instead of jumping
    local smoothHealth, smoothArmor, damageFlash = 0, 0, 0
    local lastHealth = 0

    local function DrawBar(x, y, w, h, frac, color)
        draw.RoundedBox(2, x, y, w, h, HUD.Colors.BarBack)
        if frac > 0 then
            draw.RoundedBox(2, x, y, math.max(math.Round(w * math.Clamp(frac, 0, 1)), 2), h, color)
        end
    end

    -- Name from the weapons config, then the weapon's own name
    function HUD.GetWeaponName(wep)
        local class = wep:GetClass()
        for _, weapons in pairs(JDM.Client.Weapons and JDM.Client.Weapons.Slots or {}) do
            for _, weapon in ipairs(weapons) do
                if weapon.id == class then return weapon.name end
            end
        end
        return language.GetPhrase(wep:GetPrintName() or class)
    end

    local function DrawHealthArmor(ply, s)
        local health, maxHealth = math.max(ply:Health(), 0), math.max(ply:GetMaxHealth(), 1)
        local armor = ply:Armor()
        local dt = FrameTime() * 8

        if health < lastHealth then damageFlash = 1 end
        lastHealth = health
        damageFlash = math.max(damageFlash - FrameTime() * 2, 0)

        smoothHealth = Lerp(dt, smoothHealth, health)
        smoothArmor = Lerp(dt, smoothArmor, armor)

        local w, h = math.Round(330 * s), math.Round((armor > 0 and 104 or 74) * s)
        local x, y = math.Round(30 * s), ScrH() - h - math.Round(30 * s)
        local pad = math.Round(14 * s)

        draw.RoundedBox(6, x, y, w, h, HUD.Colors.Background)
        draw.RoundedBoxEx(6, x, y, math.Round(4 * s), h, HUD.Colors.Accent, true, false, true, false)

        -- Red flash when hit
        if damageFlash > 0 then
            draw.RoundedBox(6, x, y, w, h, Color(255, 0, 0, 60 * damageFlash))
        end

        local healthColor = health <= maxHealth * 0.25 and HUD.Colors.HealthLow or HUD.Colors.Health
        local barX, barW = x + pad + math.Round(110 * s), w - pad * 2 - math.Round(110 * s)

        -- Health
        draw.SimpleText(health, "JDM_HUD_Big", x + pad + math.Round(4 * s), y + pad - math.Round(6 * s), HUD.Colors.Text)
        draw.SimpleText("HEALTH", "JDM_HUD_Small", barX, y + pad, HUD.Colors.TextDim)
        DrawBar(barX, y + pad + math.Round(24 * s), barW, math.Round(12 * s), smoothHealth / maxHealth, healthColor)

        -- Armor (only when the player has some)
        if armor > 0 then
            local ay = y + pad + math.Round(54 * s)
            draw.SimpleText(armor, "JDM_HUD_Mid", x + pad + math.Round(4 * s), ay - math.Round(4 * s), HUD.Colors.Armor)
            draw.SimpleText("ARMOR", "JDM_HUD_Small", barX, ay - math.Round(4 * s), HUD.Colors.TextDim)
            DrawBar(barX, ay + math.Round(18 * s), barW, math.Round(8 * s), smoothArmor / 100, HUD.Colors.Armor)
        end
    end

    local function DrawAmmo(ply, s)
        local wep = ply:GetActiveWeapon()
        if !IsValid(wep) then return end

        -- Weapons with their own ammo display (e.g. some SWEP bases) can opt out
        if wep.DrawAmmo == false then return end

        local primaryType = wep:GetPrimaryAmmoType()
        local secondaryType = wep:GetSecondaryAmmoType()
        local clip, maxClip = wep:Clip1(), wep:GetMaxClip1()
        local reserve = primaryType >= 0 and ply:GetAmmoCount(primaryType) or 0
        local secondary = secondaryType >= 0 and ply:GetAmmoCount(secondaryType) or 0
        local hasPrimary = primaryType >= 0 or clip >= 0

        local w, h = math.Round(300 * s), math.Round((hasPrimary and 104 or 50) * s)
        local x, y = ScrW() - w - math.Round(30 * s), ScrH() - h - math.Round(30 * s)
        local pad = math.Round(14 * s)

        draw.RoundedBox(6, x, y, w, h, HUD.Colors.Background)
        draw.RoundedBoxEx(6, x + w - math.Round(4 * s), y, math.Round(4 * s), h, HUD.Colors.Accent, false, true, false, true)

        -- Weapon name
        draw.SimpleText(string.upper(HUD.GetWeaponName(wep)), "JDM_HUD_Small", x + pad, y + pad - math.Round(2 * s), HUD.Colors.TextDim)

        if !hasPrimary then return end

        local ammoY = y + pad + math.Round(20 * s)
        if clip >= 0 then
            -- Clip / reserve
            local low = maxClip > 0 and clip <= maxClip * 0.25
            local clipW = draw.SimpleText(clip, "JDM_HUD_Big", x + pad, ammoY, low and HUD.Colors.HealthLow or HUD.Colors.Text)
            draw.SimpleText("/ " .. reserve, "JDM_HUD_Mid", x + pad + clipW + math.Round(8 * s), ammoY + math.Round(14 * s), HUD.Colors.TextDim)

            if maxClip > 0 then
                DrawBar(x + pad, y + h - pad - math.Round(6 * s), w - pad * 2, math.Round(6 * s), clip / maxClip, low and HUD.Colors.HealthLow or HUD.Colors.Text)
            end
        else
            -- No clip (grenades, RPG...): only the reserve
            draw.SimpleText(reserve, "JDM_HUD_Big", x + pad, ammoY, reserve == 0 and HUD.Colors.HealthLow or HUD.Colors.Text)
        end

        -- Secondary ammo (AR2 balls, SMG grenades)
        if secondary > 0 then
            draw.SimpleText("ALT " .. secondary, "JDM_HUD_Mid", x + w - pad - math.Round(6 * s), ammoY + math.Round(14 * s), HUD.Colors.Gold, TEXT_ALIGN_RIGHT)
        end
    end

    -- Kills / kills to win, and MOAB progress, at the top center
    local function DrawKills(ply, s)
        local maxKills = GetConVar("jdm_maxkills"):GetInt()
        local moabKills = GetConVar("jdm_moabkills"):GetInt()
        if maxKills <= 0 then return end

        local kills = math.max(ply:Frags(), 0)
        local w, h = math.Round(260 * s), math.Round(46 * s)
        local x, y = math.Round(ScrW() / 2 - w / 2), math.Round(20 * s)

        draw.RoundedBox(6, x, y, w, h, HUD.Colors.Background)
        draw.SimpleText(kills .. " / " .. maxKills .. " KILLS", "JDM_HUD_Mid", x + w / 2, y + math.Round(6 * s), HUD.Colors.Text, TEXT_ALIGN_CENTER)

        local barY, barH = y + h - math.Round(10 * s), math.Round(4 * s)
        DrawBar(x + math.Round(12 * s), barY, w - math.Round(24 * s), barH, kills / maxKills, HUD.Colors.Accent)

        -- MOAB marker on the bar
        if moabKills > 0 and moabKills < maxKills then
            local mx = x + math.Round(12 * s) + (w - math.Round(24 * s)) * moabKills / maxKills
            surface.SetDrawColor(HUD.Colors.Gold)
            surface.DrawRect(math.Round(mx) - 1, barY - math.Round(3 * s), 2, barH + math.Round(6 * s))
        end
    end

    function GM:HUDPaint()
        self.BaseClass.HUDPaint(self)

        local ply = LocalPlayer()
        if !IsValid(ply) then return end

        local s = HUD.Scale or 1
        DrawKills(ply, s)

        if !ply:Alive() or ply:GetObserverMode() != OBS_MODE_NONE then return end
        DrawHealthArmor(ply, s)
        DrawAmmo(ply, s)
    end
end
