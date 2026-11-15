-- Loadout menu (Q): one weapon per slot. It works while playing: the keyboard stays on the game
-- (you keep moving), and the new loadout applies on the next spawn.

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

    function Weapons.IsOpen()
        return IsValid(Weapons.Frame)
    end

    function Weapons.CloseMenu()
        if IsValid(Weapons.Frame) then Weapons.Frame:Remove() end
    end

    local function WeaponCard(parent, w, h, weapon, isSelected, isBlocked, onClick)
        local card = vgui.Create("DButton", parent)
        card:SetText("")
        card:SetSize(w, h)
        card.DoClick = onClick

        local details = (weapon.ammo and weapon.ammo > 0) and (weapon.ammo .. " AMMO") or "DEFAULT AMMO"
        if weapon.dmgmul and weapon.dmgmul != 1 then
            details = details .. "   x" .. weapon.dmgmul .. " DMG"
        end

        card.Paint = function(self, pw, ph)
            local selected, blocked = isSelected(), isBlocked()
            local hov = UI.Hover(self, self:IsHovered() and !blocked)

            if selected then
                draw.RoundedBox(6, 0, 0, pw, ph, C.Accent)
                draw.RoundedBox(6, 2, 2, pw - 4, ph - 4, C.Card)
                draw.RoundedBox(4, 2, 2, pw - 4, ph - 4, C.AccentSoft)
            else
                draw.RoundedBox(6, 0, 0, pw, ph, UI.LerpColor(hov, C.Panel, C.Hover))
            end

            local pad = S(12)
            local nameColor = blocked and C.TextMuted or C.Text
            draw.SimpleText(UI.Fit(string.upper(weapon.name or weapon.id), "JDM_UI", pw - pad * 2), "JDM_UI", pad, ph / 2 - S(1), nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
            draw.SimpleText(blocked and "IN THE OTHER SPECIAL SLOT" or details, "JDM_UI_Small", pad, ph / 2 + S(3), selected and C.Text or C.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        return card
    end

    function Weapons.OpenMenu()
        Weapons.CloseMenu()

        local working = table.Copy(Weapons.Selection)
        CleanSelection(working)

        local slots = {}
        for slot = 1, 4 do
            if Weapons.Slots[slot] and #Weapons.Slots[slot] > 0 then table.insert(slots, slot) end
        end

        -- Size: cards in a grid, as many columns as fit
        local frameW = math.min(S(880), ScrW() - S(40))
        local contentW = frameW - S(36) - S(16)
        local space, cardH = S(8), S(58)
        local cols = math.max(math.floor((contentW + space) / (S(190) + space)), 1)
        local cardW = math.floor((contentW - space * (cols - 1)) / cols)

        local contentH = 0
        for _, slot in ipairs(slots) do
            local rows = math.ceil(#Weapons.Slots[slot] / cols)
            contentH = contentH + S(40) + rows * (cardH + space)
        end
        local frameH = S(62) + S(12) + math.max(contentH, S(60)) + S(16) + S(40) + S(16)

        local frame = UI.Frame("Loadout", frameW, math.min(frameH, ScrH() - S(80)))
        frame:SetHint("Q  CLOSE")
        UI.Popup(frame)
        Weapons.Frame = frame

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

        local function UpdateSubtitle()
            local count = table.Count(working)
            local text = Weapons.NeedsDeploy and "Pick your weapons, then deploy" or "Changes apply on your next spawn"
            frame:SetSubtitle(text .. "  ·  " .. count .. " selected  ·  click a selected weapon to remove it")
        end
        UpdateSubtitle()

        local scroll = UI.Scroll(frame)
        scroll:Dock(FILL)

        if #slots == 0 then
            local wait = UI.Label(scroll, "Waiting for the weapon list from the server...", "JDM_UI", C.TextDim)
            wait:Dock(TOP)
            return
        end

        for _, slot in ipairs(slots) do
            local header = vgui.Create("DPanel", scroll)
            header:Dock(TOP)
            header:SetTall(S(32))
            header:DockMargin(0, 0, 0, S(8))
            local label = string.upper(JDM.Config.WeaponSlotLabels[slot] or ("Slot " .. slot))
            header.Paint = function(self, pw, ph)
                draw.RoundedBox(4, 0, 0, ph, ph, working[slot] and C.Accent or C.Panel)
                draw.SimpleText(slot, "JDM_UI_Big", ph / 2, ph / 2, C.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(label, "JDM_UI", ph + S(10), ph / 2, C.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                local chosen = working[slot] and FindWeapon(slot, working[slot])
                draw.SimpleText(chosen and string.upper(chosen.name) or "NONE", "JDM_UI_Small", pw, ph / 2, chosen and C.Text or C.TextMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            local grid = vgui.Create("DIconLayout", scroll)
            grid:Dock(TOP)
            grid:DockMargin(0, 0, 0, S(12))
            grid:SetSpaceX(space)
            grid:SetSpaceY(space)

            -- Slots 3 and 4 share the special weapons: the same one can't be in both
            local other = (slot == 3 and 4) or (slot == 4 and 3) or nil

            for _, weapon in ipairs(Weapons.Slots[slot]) do
                local function IsSelected() return working[slot] == weapon.id end
                local function IsBlocked() return other != nil and working[other] == weapon.id end

                WeaponCard(grid, cardW, cardH, weapon, IsSelected, IsBlocked, function()
                    if IsBlocked() then
                        surface.PlaySound("common/wpn_denyselect.wav")
                        return
                    end
                    working[slot] = !IsSelected() and weapon.id or nil
                    surface.PlaySound("ui/buttonclick.wav")
                    UpdateSubtitle()
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
