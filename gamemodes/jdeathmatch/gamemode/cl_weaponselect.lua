-- Client-side weapon selection (mouse wheel and number keys), grouped by the JDM loadout slots:
-- 1 = primary, 2 = secondary, 3 and 4 = specials, 5 = MOAB and anything else

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.WeaponSelect = JDM.Client.WeaponSelect or {}

    local Select = JDM.Client.WeaponSelect
    local GROUPS = 5
    local SHOW_TIME = 1.5

    Select.Labels = { "PRIMARY", "SECONDARY", "SPECIAL", "SPECIAL", "EXTRA" }
    Select.ShowUntil = 0
    Select.Selected = nil

    hook.Add("HUDShouldDraw", "JDM_HideWeaponSelection", function(name)
        if name == "CHudWeaponSelection" then return false end
    end)

    -- Group of a weapon: the server tags loadout weapons with their slot (JDM_Slot)
    local function GetGroup(wep)
        local slot = wep:GetNWInt("JDM_Slot", 0)
        if slot >= 1 and slot <= GROUPS then return slot end

        local class = wep:GetClass()
        for configSlot, weapons in pairs(JDM.Client.Weapons and JDM.Client.Weapons.Slots or {}) do
            for _, weapon in ipairs(weapons) do
                if weapon.id == class then return configSlot end
            end
        end
        return GROUPS
    end

    -- Weapons of the local player, per group, in a stable order
    function Select.GetGroups(ply)
        local groups = {}
        for i = 1, GROUPS do groups[i] = {} end

        for _, wep in ipairs(ply:GetWeapons()) do
            if IsValid(wep) then
                table.insert(groups[GetGroup(wep)], wep)
            end
        end
        for i = 1, GROUPS do
            table.sort(groups[i], function(a, b) return a:GetClass() < b:GetClass() end)
        end
        return groups
    end

    -- Weapon the selection starts from: the last one picked (switching takes a moment), else the active one
    local function GetCurrent(ply)
        if IsValid(Select.Selected) and Select.Selected:GetOwner() == ply and CurTime() < Select.ShowUntil then
            return Select.Selected
        end
        return ply:GetActiveWeapon()
    end

    local function SelectWeapon(wep)
        Select.Selected = wep
        Select.ShowUntil = CurTime() + SHOW_TIME
        if wep != LocalPlayer():GetActiveWeapon() then
            input.SelectWeapon(wep)
        end
    end

    -- Mouse wheel: next / previous weapon across all groups
    local function Cycle(ply, step)
        local list = {}
        for _, weapons in ipairs(Select.GetGroups(ply)) do
            for _, wep in ipairs(weapons) do table.insert(list, wep) end
        end
        if #list == 0 then return end

        local current = GetCurrent(ply)
        local index = 0
        for i, wep in ipairs(list) do
            if wep == current then index = i break end
        end

        if index == 0 then
            index = step > 0 and 1 or #list
        else
            index = (index - 1 + step) % #list + 1
        end
        SelectWeapon(list[index])
    end

    -- Number key: first weapon of the group, pressing again cycles inside it
    local function SelectGroup(ply, group)
        local weapons = Select.GetGroups(ply)[group]
        if !weapons or #weapons == 0 then
            surface.PlaySound("common/wpn_denyselect.wav")
            return
        end

        local current = GetCurrent(ply)
        local index = 0
        for i, wep in ipairs(weapons) do
            if wep == current then index = i break end
        end
        SelectWeapon(weapons[index % #weapons + 1])
    end

    function GM:PlayerBindPress(ply, bind, pressed)
        if !pressed or !IsValid(ply) or !ply:Alive() or ply:InVehicle() then return end

        -- Keep the wheel for the physgun while it is holding something
        local active = ply:GetActiveWeapon()
        if IsValid(active) and active:GetClass() == "weapon_physgun" and ply:KeyDown(IN_ATTACK) then return end

        if bind == "invnext" then
            Cycle(ply, 1)
            return true
        elseif bind == "invprev" then
            Cycle(ply, -1)
            return true
        end

        local slot = tonumber(string.match(bind, "^slot(%d)$"))
        if slot and slot >= 1 and slot <= GROUPS then
            SelectGroup(ply, slot)
            return true
        end
    end

    -- Columns at the top of the screen, under the kills counter
    hook.Add("HUDPaint", "JDM_DrawWeaponSelection", function()
        if CurTime() > Select.ShowUntil then return end

        local ply = LocalPlayer()
        if !IsValid(ply) or !ply:Alive() then return end

        local HUD = JDM.Client.HUD
        local colors = HUD.Colors
        local s = HUD.Scale or 1
        local alpha = math.Clamp((Select.ShowUntil - CurTime()) / 0.3, 0, 1)
        local current = GetCurrent(ply)

        local colW, gap = math.Round(170 * s), math.Round(8 * s)
        local headerH, rowH = math.Round(28 * s), math.Round(30 * s)
        local totalW = colW * GROUPS + gap * (GROUPS - 1)
        local x0, y = math.Round(ScrW() / 2 - totalW / 2), math.Round(80 * s)

        surface.SetAlphaMultiplier(alpha)
        for group, weapons in ipairs(Select.GetGroups(ply)) do
            local x = x0 + (group - 1) * (colW + gap)
            local empty = #weapons == 0

            draw.RoundedBox(4, x, y, colW, headerH, colors.Background)
            draw.SimpleText(group, "JDM_HUD_Mid", x + math.Round(10 * s), y + headerH / 2, empty and colors.TextDim or colors.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(Select.Labels[group], "JDM_HUD_Small", x + math.Round(32 * s), y + headerH / 2, colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            for i, wep in ipairs(weapons) do
                local ry = y + headerH + math.Round(4 * s) + (i - 1) * (rowH + math.Round(4 * s))
                local selected = wep == current

                draw.RoundedBox(4, x, ry, colW, rowH, selected and colors.Accent or colors.Background)
                local name = string.upper(HUD.GetWeaponName(wep))
                surface.SetFont("JDM_HUD_Small")
                while #name > 1 and surface.GetTextSize(name .. "...") > colW - math.Round(20 * s) do
                    name = string.sub(name, 1, -2)
                end
                if name != string.upper(HUD.GetWeaponName(wep)) then name = name .. "..." end
                draw.SimpleText(name, "JDM_HUD_Small", x + math.Round(10 * s), ry + rowH / 2, selected and color_white or colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        surface.SetAlphaMultiplier(1)
    end)
end
