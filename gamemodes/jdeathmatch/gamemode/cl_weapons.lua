-- Loadout menu (Q): a primary, a secondary and two specials. It works while playing: the keyboard
-- stays on the game (you keep moving), and the new loadout applies on the next spawn.

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.Weapons = JDM.Client.Weapons or {}

    local Weapons = JDM.Client.Weapons
    local UI = JDM.UI
    local C, S = UI.Colors, UI.S

    Weapons.Slots = Weapons.Slots or {}
    Weapons.NeedsDeploy = Weapons.NeedsDeploy or false -- first spawn: the server waits for a loadout

    -- Last loadout, remembered between sessions (list of 4 classes, "" = empty)
    local function LoadCookie()
        local selection = {}
        local saved = util.JSONToTable(cookie.GetString("jdm_loadout", "")) or {}
        for slot = 1, 4 do
            if isstring(saved[slot]) and saved[slot] != "" then selection[slot] = saved[slot] end
        end
        return selection
    end

    local function SaveCookie()
        local saved = {}
        for slot = 1, 4 do saved[slot] = Weapons.Selection[slot] or "" end
        cookie.Set("jdm_loadout", util.TableToJSON(saved))
    end

    Weapons.Selection = Weapons.Selection or LoadCookie()

    local function FindWeapon(slot, id)
        for _, weapon in ipairs(Weapons.Slots[slot] or {}) do
            if weapon.id == id then return weapon end
        end
    end

    -- Drop choices that are no longer in the config
    local function CleanSelection(selection)
        for slot = 1, 4 do
            if selection[slot] and !FindWeapon(slot, selection[slot]) then selection[slot] = nil end
        end
        if selection[3] and selection[3] == selection[4] then selection[4] = nil end
    end

    local function SendSelection()
        net.Start("JDM_SetPlayerWeapons")
        for slot = 1, 4 do
            net.WriteString(Weapons.Selection[slot] or "")
        end
        net.SendToServer()
        SaveCookie()
        Weapons.NeedsDeploy = false
    end

    -- Weapon icon: the SWEP's own icon, then the spawn menu icons; false = none found (cached)
    local iconCache = {}
    function Weapons.GetIcon(class)
        if iconCache[class] == nil then
            iconCache[class] = false
            local swep = weapons.GetStored(class)
            local paths = { "entities/" .. class .. ".png", "vgui/entities/" .. class }
            if swep and isstring(swep.IconOverride) then table.insert(paths, 1, swep.IconOverride) end
            for _, path in ipairs(paths) do
                local mat = Material(path, "smooth mips")
                if mat and !mat:IsError() then
                    iconCache[class] = mat
                    break
                end
            end
        end
        return iconCache[class] or nil
    end

    -- Square icon box; without an icon, the initials of the name. weapon = { id, name } (or nil: empty box)
    function Weapons.DrawIcon(weapon, x, y, size, alpha)
        draw.RoundedBox(4, x, y, size, size, Color(0, 0, 0, 120))
        local mat = weapon and Weapons.GetIcon(weapon.id)
        if mat then
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, alpha or 255)
            surface.DrawTexturedRect(x + 2, y + 2, size - 4, size - 4)
        elseif weapon then
            local initials = ""
            for word in string.gmatch(weapon.name or weapon.id, "%w+") do
                initials = initials .. string.upper(string.sub(word, 1, 1))
                if #initials == 2 then break end
            end
            draw.SimpleText(initials, "JDM_UI_Big", x + size / 2, y + size / 2, Color(255, 255, 255, (alpha or 255) * 0.35), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Ammo only: the damage multiplier is a balance setting, not shown to players
    local function Details(weapon)
        return (weapon.ammo and weapon.ammo > 0) and (weapon.ammo .. " AMMO") or "DEFAULT AMMO"
    end

    function Weapons.IsOpen()
        return IsValid(Weapons.Frame)
    end

    function Weapons.CloseMenu()
        if IsValid(Weapons.Frame) then Weapons.Frame:Remove() end
    end

    -- Weapon card: icon on the left, name and stats on the right. tag() returns a short label shown
    -- when the weapon is picked ("SPECIAL 1" ...), or nil when it is not.
    local function WeaponCard(parent, w, h, weapon, tag, onClick)
        local card = vgui.Create("DButton", parent)
        card:SetText("")
        card:SetSize(w, h)
        card.DoClick = onClick

        local details = Details(weapon)
        card.Paint = function(self, pw, ph)
            local picked = tag()
            local hov = UI.Hover(self, self:IsHovered())

            if picked then
                draw.RoundedBox(6, 0, 0, pw, ph, C.Accent)
                draw.RoundedBox(5, 2, 2, pw - 4, ph - 4, C.Card)
                draw.RoundedBox(5, 2, 2, pw - 4, ph - 4, C.AccentSoft)
            else
                draw.RoundedBox(6, 0, 0, pw, ph, UI.LerpColor(hov, C.Panel, C.Hover))
            end

            local pad = S(8)
            local iconSize = ph - pad * 2
            Weapons.DrawIcon(weapon, pad, pad, iconSize, (picked or hov > 0.5) and 255 or 200)

            local tx = pad * 2 + iconSize
            local textW = pw - tx - pad
            draw.SimpleText(UI.Fit(string.upper(weapon.name or weapon.id), "JDM_UI", textW), "JDM_UI", tx, ph / 2 - S(1), C.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
            draw.SimpleText(UI.Fit(details, "JDM_UI_Small", textW), "JDM_UI_Small", tx, ph / 2 + S(3), picked and C.Text or C.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            if isstring(picked) then
                surface.SetFont("JDM_UI_Small")
                local tw, th = surface.GetTextSize(picked)
                local bw, bh = tw + S(10), th + S(4)
                draw.RoundedBoxEx(4, pw - bw - 2, 2, bw, bh, C.Accent, false, true, true, false)
                draw.SimpleText(picked, "JDM_UI_Small", pw - bw / 2 - 2, 2 + bh / 2, C.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
        return card
    end

    -- Specials: one list, two picks. Slot 3 weapons fit both special slots, slot 4 weapons only the
    -- second one. Returns the new [3], [4] after clicking `id` (a third pick replaces the oldest).
    local function PickSpecial(working, pickTime, id)
        local can3 = {}
        for _, weapon in ipairs(Weapons.Slots[3] or {}) do can3[weapon.id] = true end

        -- Click on a picked one: remove it
        if working[3] == id then return nil, working[4] end
        if working[4] == id then return working[3], nil end

        -- Current picks, oldest first, then the new one; keep the two newest that fit together
        local picks = {}
        for _, slot in ipairs({ 3, 4 }) do
            if working[slot] then table.insert(picks, working[slot]) end
        end
        table.sort(picks, function(a, b) return (pickTime[a] or 0) < (pickTime[b] or 0) end)
        table.insert(picks, id)
        pickTime[id] = RealTime()

        while #picks > 0 do
            while #picks > 2 do table.remove(picks, 1) end
            local a, b = picks[1], picks[2]
            if !b then
                if can3[a] then return a, nil end
                return nil, a
            end
            if can3[a] then return a, b end
            if can3[b] then return b, a end
            table.remove(picks, 1) -- both only fit the second slot: keep the new one
        end
    end

    function Weapons.OpenMenu()
        Weapons.CloseMenu()

        local working = table.Copy(Weapons.Selection)
        CleanSelection(working)

        -- Pick order of the specials (slot 3 counts as the older one)
        local pickTime = {}
        if working[3] then pickTime[working[3]] = 1 end
        if working[4] then pickTime[working[4]] = 2 end

        -- Sections: primary, secondary, and the specials merged in one list
        local sections = {}
        for slot = 1, 2 do
            if Weapons.Slots[slot] and #Weapons.Slots[slot] > 0 then
                table.insert(sections, { slot = slot, label = JDM.Config.WeaponSlotLabels[slot] or ("Slot " .. slot), list = Weapons.Slots[slot] })
            end
        end
        local specials, seen = {}, {}
        for _, slot in ipairs({ 3, 4 }) do
            for _, weapon in ipairs(Weapons.Slots[slot] or {}) do
                if !seen[weapon.id] then
                    seen[weapon.id] = true
                    table.insert(specials, weapon)
                end
            end
        end
        if #specials > 0 then
            table.insert(sections, { slot = 3, label = "Specials", hint = "PICK TWO", list = specials })
        end

        -- Size: cards in a grid, as many columns as fit
        local frameW = math.min(S(1000), ScrW() - S(40))
        local contentW = frameW - S(36) - S(16)
        local space, cardH = S(8), S(64)
        local cols = math.max(math.floor((contentW + space) / (S(220) + space)), 1)
        local cardW = math.floor((contentW - space * (cols - 1)) / cols)

        local summaryH = S(64)
        local contentH = 0
        for _, section in ipairs(sections) do
            contentH = contentH + S(44) + math.ceil(#section.list / cols) * (cardH + space)
        end
        local frameH = S(62) + S(12) + summaryH + S(14) + math.max(contentH, S(60)) + S(16) + S(40) + S(16)

        local frame = UI.Frame("Loadout", frameW, math.min(frameH, ScrH() - S(80)))
        frame:SetHint("Q  CLOSE")
        UI.Popup(frame)
        Weapons.Frame = frame

        local function UpdateSubtitle()
            local text = Weapons.NeedsDeploy and "Pick your weapons, then deploy" or "Changes apply on your next spawn"
            frame:SetSubtitle(text .. "  ·  click a picked weapon to remove it")
        end
        UpdateSubtitle()

        -- Footer: admin menu and deploy
        local footer = vgui.Create("DPanel", frame)
        footer:Dock(BOTTOM)
        footer:SetTall(S(40))
        footer:DockMargin(0, S(12), 0, 0)
        footer:SetPaintBackground(false)

        local save = UI.Button(footer, Weapons.NeedsDeploy and "Deploy" or "Save loadout", "primary", function()
            Weapons.Selection = working
            SendSelection()
            frame:Remove()
        end)
        save:Dock(RIGHT)
        save:SetWide(S(220))

        if LocalPlayer():IsAdmin() then
            local admin = UI.Button(footer, "Admin menu  (F3)", "ghost", function()
                frame:Remove()
                JDM.Client.Admin.Open()
            end)
            admin:Dock(LEFT)
            admin:SetWide(S(200))
        end

        if #sections == 0 then
            local wait = UI.Label(frame, "Waiting for the weapon list from the server...", "JDM_UI", C.TextDim)
            wait:Dock(TOP)
            return
        end

        local scroll = UI.Scroll(frame)
        local headers = {}

        -- Summary: the four picks; click one to jump to its list
        local summary = vgui.Create("DPanel", frame)
        summary:Dock(TOP)
        summary:SetTall(summaryH)
        summary:DockMargin(0, 0, 0, S(14))
        summary:SetPaintBackground(false)

        local summarySlots = {
            { slot = 1, label = "PRIMARY" },
            { slot = 2, label = "SECONDARY" },
            { slot = 3, label = "SPECIAL 1" },
            { slot = 4, label = "SPECIAL 2" },
        }
        local boxW = math.floor((contentW - space * 3) / 4)
        for i, info in ipairs(summarySlots) do
            local box = vgui.Create("DButton", summary)
            box:SetText("")
            box:SetPos((i - 1) * (boxW + space), 0)
            box:SetSize(boxW, summaryH)
            box.DoClick = function()
                local header = headers[math.min(info.slot, 3)]
                if IsValid(header) then scroll:ScrollToChild(header) end
            end
            box.Paint = function(self, pw, ph)
                local hov = UI.Hover(self, self:IsHovered())
                local id = working[info.slot]
                local weapon = id and FindWeapon(info.slot, id)
                draw.RoundedBox(6, 0, 0, pw, ph, UI.LerpColor(hov, C.Header, C.Hover))
                draw.RoundedBoxEx(6, 0, 0, S(3), ph, weapon and C.Accent or C.Line, true, false, true, false)

                local pad = S(8)
                local iconSize = ph - pad * 2
                Weapons.DrawIcon(weapon, pad + S(3), pad, iconSize)

                local tx = pad * 2 + S(3) + iconSize
                draw.SimpleText(info.label, "JDM_UI_Small", tx, ph / 2 - S(1), C.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
                local name = weapon and string.upper(weapon.name or weapon.id) or "EMPTY"
                draw.SimpleText(UI.Fit(name, "JDM_UI", pw - tx - pad), "JDM_UI", tx, ph / 2 + S(1), weapon and C.Text or C.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end

        scroll:Dock(FILL)

        for _, section in ipairs(sections) do
            local isSpecials = section.slot == 3

            local header = vgui.Create("DPanel", scroll)
            header:Dock(TOP)
            header:SetTall(S(32))
            header:DockMargin(0, 0, 0, S(8))
            headers[section.slot] = header
            local label = string.upper(section.label)
            header.Paint = function(self, pw, ph)
                draw.RoundedBox(2, 0, S(6), S(3), ph - S(12), C.Accent)
                local tw = draw.SimpleText(label, "JDM_UI_Big", S(10), ph / 2, C.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                local lineX, lineEnd = S(10) + tw + S(12), pw

                if section.hint then
                    local count = (working[3] and 1 or 0) + (working[4] and 1 or 0)
                    local hw = draw.SimpleText(section.hint .. "  " .. count .. " / 2", "JDM_UI_Small", pw, ph / 2, count == 2 and C.Text or C.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    lineEnd = pw - hw - S(12)
                end
                if lineEnd > lineX then
                    surface.SetDrawColor(C.Line)
                    surface.DrawRect(lineX, math.floor(ph / 2), lineEnd - lineX, 1)
                end
            end

            local grid = vgui.Create("DIconLayout", scroll)
            grid:Dock(TOP)
            grid:DockMargin(0, 0, 0, S(12))
            grid:SetSpaceX(space)
            grid:SetSpaceY(space)

            for _, weapon in ipairs(section.list) do
                local id = weapon.id
                local tag, onClick

                if isSpecials then
                    tag = function()
                        if working[3] == id then return "SPECIAL 1" end
                        if working[4] == id then return "SPECIAL 2" end
                    end
                    onClick = function()
                        working[3], working[4] = PickSpecial(working, pickTime, id)
                    end
                else
                    local slot = section.slot
                    tag = function() return working[slot] == id end
                    onClick = function()
                        working[slot] = working[slot] != id and id or nil
                    end
                end

                WeaponCard(grid, cardW, cardH, weapon, tag, function()
                    onClick()
                    surface.PlaySound("ui/buttonclick.wav")
                end)
            end
        end
    end

    function Weapons.Toggle()
        if Weapons.IsOpen() then Weapons.CloseMenu() else Weapons.OpenMenu() end
    end

    -- Q opens / closes the menu (the keyboard is not taken by the menu, so Q still arrives here)
    hook.Add("PlayerButtonDown", "JDM_OpenWeaponMenuOnQ", function(ply, button)
        if button == KEY_Q and IsFirstTimePredicted() then
            Weapons.Toggle()
        end
    end)

    -- Receive weapon lists from server
    net.Receive("JDM_SendWeaponSlots", function()
        Weapons.Slots = net.ReadTable()
        local openMenu = net.ReadBool()

        CleanSelection(Weapons.Selection)
        if openMenu then Weapons.NeedsDeploy = true end

        -- Rebuild an open menu with the new list (e.g. an admin changed the config)
        if openMenu or Weapons.IsOpen() then
            Weapons.OpenMenu()
        end
    end)

    -- Reminder while waiting to deploy with the menu closed
    hook.Add("HUDPaint", "JDM_LoadoutHint", function()
        if !Weapons.NeedsDeploy or Weapons.IsOpen() then return end
        surface.SetFont("JDM_UI")
        local text = "CHOOSE YOUR LOADOUT TO SPAWN"
        local w = surface.GetTextSize(text) + S(70)
        UI.DrawHint(math.Round(ScrW() / 2 - w / 2), math.Round(ScrH() * 0.7), text, "Q")
    end)

    -- Ask the server for the weapon list once the client is ready
    hook.Add("InitPostEntity", "JDM_RequestWeaponSlots", function()
        net.Start("JDM_RequestWeaponSlots")
        net.SendToServer()
    end)
end
