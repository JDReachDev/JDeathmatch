-- Admin menu (client side): weapons config and server settings.
-- F3, "jdm_admin" or the button in the loadout menu. It works while playing: F3 hides it and shows it
-- again with the unsaved edits, and the keyboard stays on the game unless you are typing in a field.

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.Admin = JDM.Client.Admin or {}

    local Admin = JDM.Client.Admin
    local UI = JDM.UI
    local C, S = UI.Colors, UI.S

    local SLOT_CHOICES = {
        { 1, "1 - Primary", "PRIMARY" },
        { 2, "2 - Secondary", "SECONDARY" },
        { 3, "3 - Special (slots 3 and 4)", "SPECIAL 3+4" },
        { 4, "4 - Special (slot 4 only)", "SPECIAL 4" },
        { JDM.Config.MOABSlot, "666 - MOAB weapon", "MOAB" },
    }

    -- HL2 weapons are not in weapons.GetList()
    local HL2_WEAPONS = {
        weapon_crowbar = "Crowbar", weapon_stunstick = "Stunstick", weapon_pistol = "Pistol",
        weapon_357 = ".357 Magnum", weapon_smg1 = "SMG", weapon_ar2 = "AR2", weapon_shotgun = "Shotgun",
        weapon_crossbow = "Crossbow", weapon_frag = "Grenade", weapon_rpg = "RPG", weapon_slam = "S.L.A.M",
        weapon_physcannon = "Gravity Gun", weapon_bugbait = "Bugbait",
    }

    local function SlotShort(slot)
        for _, choice in ipairs(SLOT_CHOICES) do
            if choice[1] == slot then return choice[3] end
        end
        return tostring(slot)
    end

    -- Installed weapons (SWEPs + HL2) that are not in the list yet
    local function GetInstalledWeapons(exclude)
        local result = {}
        for class, name in pairs(HL2_WEAPONS) do
            if !exclude[class] then table.insert(result, { id = class, name = name, category = "Half-Life 2" }) end
        end
        for _, swep in ipairs(weapons.GetList()) do
            local class = swep.ClassName
            if class and !exclude[class] and (swep.Spawnable or swep.AdminSpawnable) then
                table.insert(result, { id = class, name = language.GetPhrase(swep.PrintName or class), category = swep.Category })
            end
        end
        table.sort(result, function(a, b) return a.id < b.id end)
        return result
    end

    -- Text in a column of a row: x and width as fractions of the row
    local function Cell(text, font, color, pw, ph, from, to, align)
        local x, w = math.Round(pw * from), math.Round(pw * (to - from)) - S(10)
        text = UI.Fit(tostring(text), font, w)
        if align == TEXT_ALIGN_RIGHT then
            draw.SimpleText(text, font, x + w, ph / 2, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText(text, font, x, ph / 2, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local function ColumnHeader(parent, columns)
        local header = vgui.Create("DPanel", parent)
        header:Dock(TOP)
        header:SetTall(S(26))
        header:DockMargin(0, 0, S(10), S(4))
        header.Paint = function(self, pw, ph)
            for _, col in ipairs(columns) do
                Cell(col[1], "JDM_UI_Small", C.TextMuted, pw, ph, col[2], col[3], col[4])
            end
        end
        return header
    end

    ---------------------------------------------------------------------------
    -- Weapon picker
    ---------------------------------------------------------------------------

    -- Picker to add installed weapons; onPick(weapon) for each one chosen
    local function OpenWeaponPicker(exclude, onPick)
        if IsValid(Admin.Picker) then Admin.Picker:Remove() end

        local frame = UI.Frame("Add weapons", S(720), S(640))
        frame:SetSubtitle("Click to select, double-click to add right away")
        UI.Popup(frame)
        Admin.Picker = frame

        local search = UI.TextEntry(frame, "Search by class, name or category...")
        search:Dock(TOP)
        search:DockMargin(0, 0, 0, S(10))

        local footer = vgui.Create("DPanel", frame)
        footer:Dock(BOTTOM)
        footer:SetTall(S(36))
        footer:DockMargin(0, S(10), 0, 0)
        footer:SetPaintBackground(false)

        local columns = { { "CLASS", 0.10, 0.42 }, { "NAME", 0.42, 0.72 }, { "CATEGORY", 0.72, 1 } }
        ColumnHeader(frame, columns)

        local scroll = UI.Scroll(frame)
        scroll:Dock(FILL)

        local selected = {}
        local all = GetInstalledWeapons(exclude)

        local function Fill()
            scroll:Clear()
            local filter = string.lower(search:GetValue() or "")
            for _, weapon in ipairs(all) do
                local text = string.lower(weapon.id .. " " .. weapon.name .. " " .. (weapon.category or ""))
                if filter != "" and !string.find(text, filter, 1, true) then continue end

                local row = UI.Row(scroll, S(42), function(self, pw, ph)
                    JDM.Client.Weapons.DrawIcon(weapon, S(6), S(4), ph - S(8))
                    Cell(weapon.id, "JDM_UI", C.Text, pw, ph, 0.10, 0.42)
                    Cell(weapon.name, "JDM_UI", C.TextDim, pw, ph, 0.42, 0.72)
                    Cell(weapon.category or "", "JDM_UI_Small", C.TextMuted, pw, ph, 0.72, 1)
                end)
                row.JDM_Selected = selected[weapon.id] != nil
                row.DoClick = function(self)
                    selected[weapon.id] = !selected[weapon.id] and weapon or nil
                    self.JDM_Selected = selected[weapon.id] != nil
                end
                row.DoDoubleClick = function()
                    selected[weapon.id] = nil
                    onPick(weapon)
                    exclude[weapon.id] = true
                    all = GetInstalledWeapons(exclude)
                    Fill()
                end
            end
        end
        Fill()
        search.OnChange = Fill

        local add = UI.Button(footer, "Add selected", "primary", function()
            for id, weapon in SortedPairs(selected) do
                onPick(weapon)
                exclude[id] = true
            end
            selected = {}
            all = GetInstalledWeapons(exclude)
            Fill()
        end)
        add:Dock(RIGHT)
        add:SetWide(S(170))

        local classEntry = UI.TextEntry(footer, "...or type a class (e.g. m9k_ak47) and press Enter")
        classEntry:Dock(FILL)
        classEntry:DockMargin(0, 0, S(8), 0)
        classEntry.OnEnter = function(self)
            local class = string.Trim(self:GetValue())
            self:KillFocus()
            if class == "" or exclude[class] then return end
            onPick({ id = class, name = class })
            exclude[class] = true
            self:SetValue("")
        end
    end

    ---------------------------------------------------------------------------
    -- Settings tab: every JDM ConVar (sh_convars.lua), sent to the server with "Apply"
    ---------------------------------------------------------------------------

    function Admin.BuildSettings(parent)
        local values = {}

        local footer = vgui.Create("DPanel", parent)
        footer:Dock(BOTTOM)
        footer:SetTall(S(36))
        footer:DockMargin(0, S(10), 0, 0)
        footer:SetPaintBackground(false)

        local scroll = UI.Scroll(parent)
        scroll:Dock(FILL)

        for _, cvar in ipairs(JDM.ConVars) do
            local current = GetConVar(cvar.name):GetString()
            values[cvar.name] = current

            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:SetTall(S(54))
            row:DockMargin(0, 0, 0, S(4))
            row:DockPadding(S(14), S(10), S(12), S(10))
            local info = cvar.name .. "  ·  default " .. cvar.default
            row.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, C.Panel)
                draw.SimpleText(cvar.help, "JDM_UI", S(14), h / 2 + S(1), C.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
                draw.SimpleText(info, "JDM_UI_Small", S(14), h / 2 + S(2), C.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            if cvar.type == "bool" then
                local toggle = UI.Toggle(row, tobool(current), function(on) values[cvar.name] = on and "1" or "0" end)
                toggle:Dock(RIGHT)
                toggle:DockMargin(0, S(5), 0, S(5))

            elseif cvar.type == "number" then
                local entry = UI.NumberEntry(row, cvar.min, cvar.max, 0, tonumber(current) or tonumber(cvar.default), function(n)
                    values[cvar.name] = tostring(n)
                end)
                entry:Dock(RIGHT)
                entry:SetWide(S(120))

            elseif cvar.type == "music" then
                local play = UI.Button(row, "Play", "ghost", function()
                    RunConsoleCommand("stopsound")
                    timer.Simple(0.1, function() surface.PlaySound(values[cvar.name]) end)
                end)
                play:Dock(RIGHT)
                play:SetWide(S(70))

                local entry = UI.TextEntry(row, "sound path")
                entry:Dock(RIGHT)
                entry:SetWide(S(260))
                entry:DockMargin(0, 0, S(6), 0)
                entry:SetValue(current)
                entry.OnChange = function(self) values[cvar.name] = string.Trim(self:GetValue()) end

                local box = UI.Combo(row)
                box:Dock(RIGHT)
                box:SetWide(S(250))
                box:DockMargin(0, 0, S(6), 0)
                box:SetValue("Pick a track...")
                for _, track in ipairs(JDM.Config.WinMusic) do
                    box:AddChoice(track[2], track[1], track[1] == current)
                end
                box.OnSelect = function(_, _, _, path) entry:SetValue(path) values[cvar.name] = path end
            end
        end

        local apply = UI.Button(footer, "Apply settings", "primary")
        apply:Dock(RIGHT)
        apply:SetWide(S(220))
        apply.DoClick = function(self)
            local changed = {}
            for name, value in pairs(values) do
                if value != GetConVar(name):GetString() then changed[name] = value end
            end
            if table.IsEmpty(changed) then
                self:SetLabel("Nothing changed")
            else
                net.Start("JDM_AdminSetConVars")
                net.WriteTable(changed)
                net.SendToServer()
                self:SetLabel("Applied")
            end
            timer.Create("JDM_AdminApplyLabel", 1.5, 1, function()
                if IsValid(self) then self:SetLabel("Apply settings") end
            end)
        end

        local vote = UI.Button(footer, "Start map vote now (30s)", "ghost", function()
            RunConsoleCommand("jdm_mapvote", "30")
        end)
        vote:Dock(LEFT)
        vote:SetWide(S(260))
    end

    ---------------------------------------------------------------------------
    -- Weapons tab
    ---------------------------------------------------------------------------

    local function BuildWeapons(parent, frame, working)
        local selected
        local loading = false

        local function MarkDirty()
            frame.JDM_Dirty = true
        end

        -- Right: fields of the selected weapon
        local side = vgui.Create("DPanel", parent)
        side:Dock(RIGHT)
        side:SetWide(S(320))
        side:DockMargin(S(12), 0, 0, 0)
        side:DockPadding(S(14), S(4), S(14), S(14))
        side.Paint = function(self, w, h) draw.RoundedBox(6, 0, 0, w, h, C.Panel) end

        -- Left: search + list
        local left = vgui.Create("DPanel", parent)
        left:Dock(FILL)
        left:SetPaintBackground(false)

        local top = vgui.Create("DPanel", left)
        top:Dock(TOP)
        top:SetTall(S(34))
        top:DockMargin(0, 0, 0, S(10))
        top:SetPaintBackground(false)

        local columns = {
            { "NAME", 0.11, 0.36 }, { "CLASS", 0.36, 0.62 }, { "SLOT", 0.62, 0.80 },
            { "AMMO", 0.80, 0.91, TEXT_ALIGN_RIGHT }, { "DMG", 0.91, 1, TEXT_ALIGN_RIGHT },
        }
        ColumnHeader(left, columns)

        local scroll = UI.Scroll(left)
        scroll:Dock(FILL)

        local search = UI.TextEntry(top, "Filter the list...")
        search:Dock(FILL)
        search:DockMargin(0, 0, S(8), 0)

        local fields = {}
        local Refresh, Select

        Refresh = function()
            scroll:Clear()
            local filter = string.lower(search:GetValue() or "")
            for _, weapon in ipairs(working) do
                local text = string.lower((weapon.name or "") .. " " .. (weapon.id or ""))
                if filter != "" and !string.find(text, filter, 1, true) then continue end

                local row = UI.Row(scroll, S(44), function(self, pw, ph)
                    JDM.Client.Weapons.DrawIcon(weapon, S(6), S(4), ph - S(8))
                    local moab = weapon.slot == JDM.Config.MOABSlot
                    Cell(weapon.name, "JDM_UI", C.Text, pw, ph, 0.11, 0.36)
                    Cell(weapon.id, "JDM_UI_Small", C.TextDim, pw, ph, 0.36, 0.62)
                    Cell(SlotShort(weapon.slot), "JDM_UI_Small", moab and C.Gold or C.TextDim, pw, ph, 0.62, 0.80)
                    Cell(weapon.ammo == 0 and "default" or weapon.ammo, "JDM_UI", C.Text, pw, ph, 0.80, 0.91, TEXT_ALIGN_RIGHT)
                    Cell("x" .. weapon.dmgmul, "JDM_UI", weapon.dmgmul != 1 and C.Gold or C.Text, pw, ph, 0.91, 1, TEXT_ALIGN_RIGHT)
                    self.JDM_Selected = selected == weapon
                end)
                row.DoClick = function() Select(weapon) end
            end
        end
        search.OnChange = Refresh

        local function SetFieldsEnabled(enabled)
            for _, field in ipairs(fields) do field:SetEnabled(enabled) end
        end

        -- Preview of the selected weapon: icon, name and class
        local preview = vgui.Create("DPanel", side)
        preview:Dock(TOP)
        preview:SetTall(S(84))
        preview:DockMargin(0, S(10), 0, 0)
        preview.Paint = function(self, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, C.Header)
            JDM.Client.Weapons.DrawIcon(selected, S(6), S(6), ph - S(12))
            local tx = ph + S(4)
            local name = selected and string.upper(selected.name or "") or "NO WEAPON SELECTED"
            draw.SimpleText(UI.Fit(name, "JDM_UI", pw - tx - S(8)), "JDM_UI", tx, ph / 2 - S(1), selected and C.Text or C.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
            local sub = selected and selected.id or "Click a weapon in the list"
            draw.SimpleText(UI.Fit(sub, "JDM_UI_Small", pw - tx - S(8)), "JDM_UI_Small", tx, ph / 2 + S(3), C.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        UI.Section(side, "Name shown in menus")
        local nameEntry = UI.TextEntry(side)
        nameEntry:Dock(TOP)

        UI.Section(side, "Weapon class")
        local classEntry = UI.TextEntry(side)
        classEntry:Dock(TOP)

        UI.Section(side, "Slot")
        local slotBox = UI.Combo(side)
        slotBox:Dock(TOP)
        for _, choice in ipairs(SLOT_CHOICES) do slotBox:AddChoice(choice[2], choice[1]) end

        UI.Section(side, "Ammo on spawn (0 = weapon default)")
        local ammoEntry = UI.NumberEntry(side, 0, 9999, 0, 0, function(n)
            if loading or !selected then return end
            selected.ammo = n
            MarkDirty()
        end)
        ammoEntry:Dock(TOP)

        UI.Section(side, "Damage multiplier (1 = normal)")
        local dmgEntry = UI.NumberEntry(side, 0, 100, 2, 1, function(n)
            if loading or !selected then return end
            selected.dmgmul = n
            MarkDirty()
        end)
        dmgEntry:Dock(TOP)

        fields = { nameEntry, classEntry, slotBox, ammoEntry, dmgEntry }
        SetFieldsEnabled(false)

        -- Edits apply to the working copy right away; nothing is sent until "Save"
        nameEntry.OnChange = function(self)
            if loading or !selected then return end
            selected.name = self:GetValue()
            MarkDirty()
        end
        classEntry.OnChange = function(self)
            if loading or !selected then return end
            selected.id = string.Trim(self:GetValue())
            MarkDirty()
        end
        slotBox.OnSelect = function(_, _, _, slot)
            if loading or !selected then return end
            selected.slot = slot
            MarkDirty()
        end

        Select = function(weapon)
            selected = weapon
            loading = true
            nameEntry:SetValue(weapon and weapon.name or "")
            classEntry:SetValue(weapon and weapon.id or "")
            slotBox:SetValue("")
            if weapon then
                for i, choice in ipairs(SLOT_CHOICES) do
                    if choice[1] == weapon.slot then slotBox:ChooseOptionID(i) end
                end
            end
            ammoEntry:SetNumber(weapon and weapon.ammo or 0)
            dmgEntry:SetNumber(weapon and weapon.dmgmul or 1)
            loading = false
            SetFieldsEnabled(weapon != nil)
        end

        -- Bottom of the side panel, from the bottom up
        local function SideButton(text, style, onClick)
            local button = UI.Button(side, text, style, onClick)
            button:Dock(BOTTOM)
            button:DockMargin(0, S(6), 0, 0)
            return button
        end

        SideButton("Save and apply", "primary", function()
            local data = util.Compress(util.TableToJSON(working))
            net.Start("JDM_AdminSaveConfig")
            net.WriteUInt(#data, 32)
            net.WriteData(data, #data)
            net.SendToServer()
            frame:Remove()
        end)

        SideButton("Remove selected", "danger", function()
            if !selected then return end
            table.RemoveByValue(working, selected)
            Select(nil)
            MarkDirty()
            Refresh()
        end)

        local add = UI.Button(top, "Add weapons...", "ghost", function()
            local exclude = {}
            for _, weapon in ipairs(working) do exclude[weapon.id] = true end

            OpenWeaponPicker(exclude, function(weapon)
                local entry = { id = weapon.id, name = weapon.name, slot = 1, ammo = 0, dmgmul = 1 }
                table.insert(working, entry)
                MarkDirty()
                Refresh()
                Select(entry)
            end)
        end)
        add:Dock(RIGHT)
        add:SetWide(S(170))

        Refresh()
    end

    ---------------------------------------------------------------------------
    -- Frame
    ---------------------------------------------------------------------------

    function Admin.OpenEditor(weaponList)
        if IsValid(Admin.Frame) then Admin.Frame:Remove() end

        local working = table.Copy(weaponList)
        for _, weapon in ipairs(working) do
            weapon.name = weapon.name or weapon.id
            weapon.ammo = tonumber(weapon.ammo) or 0
            weapon.dmgmul = tonumber(weapon.dmgmul) or 1
        end

        local frame = UI.Frame("Admin", S(1100), S(720))
        frame:SetHint("F3  HIDE")
        UI.Popup(frame)
        Admin.Frame = frame

        frame.Think = function(self)
            self:SetSubtitle(self.JDM_Dirty and "Unsaved weapon changes" or "Weapons config and server settings")
        end

        -- The X discards the edits; F3 only hides the menu
        frame.OnRemove = function()
            if IsValid(Admin.Picker) then Admin.Picker:Remove() end
        end

        local tabs = UI.Tabs(frame)
        tabs:Dock(FILL)
        BuildWeapons(tabs:AddTab("Weapons"), frame, working)
        Admin.BuildSettings(tabs:AddTab("Settings"))
    end

    function Admin.Toggle()
        if !IsValid(Admin.Frame) then return false end
        local show = !Admin.Frame:IsVisible()
        Admin.Frame:SetVisible(show)
        if !show and IsValid(Admin.Picker) then Admin.Picker:Remove() end
        return true
    end

    net.Receive("JDM_AdminOpenEditor", function()
        local len = net.ReadUInt(32)
        local json = util.Decompress(net.ReadData(len))
        local weaponList = json and util.JSONToTable(json)
        if istable(weaponList) then Admin.OpenEditor(weaponList) end
    end)

    -- Show the hidden menu (edits kept), or ask the server for the config
    function Admin.Open()
        if IsValid(Admin.Frame) then
            Admin.Frame:SetVisible(true)
            return
        end
        net.Start("JDM_AdminRequestEditor")
        net.SendToServer()
    end
    Admin.RequestEditor = Admin.Open

    concommand.Add("jdm_admin", function() Admin.Open() end)

    -- F3 (gm_showspare1): hide / show an existing menu here; otherwise the server sends the config
    hook.Add("PlayerBindPress", "JDM_AdminKey", function(ply, bind, pressed)
        if pressed and bind == "gm_showspare1" and Admin.Toggle() then return true end
    end)
end
