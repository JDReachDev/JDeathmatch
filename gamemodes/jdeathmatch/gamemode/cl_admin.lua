-- Admin weapon config editor (client side): F3, "jdm_admin" or the button in the loadout menu

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.Admin = JDM.Client.Admin or {}

    local Admin = JDM.Client.Admin

    local SLOT_CHOICES = {
        { 1, "1 - Primary" },
        { 2, "2 - Secondary" },
        { 3, "3 - Special (slots 3 and 4)" },
        { 4, "4 - Special (slot 4 only)" },
        { JDM.Config.MOABSlot, "666 - MOAB weapon" },
    }

    -- HL2 weapons are not in weapons.GetList()
    local HL2_WEAPONS = {
        weapon_crowbar = "Crowbar", weapon_stunstick = "Stunstick", weapon_pistol = "Pistol",
        weapon_357 = ".357 Magnum", weapon_smg1 = "SMG", weapon_ar2 = "AR2", weapon_shotgun = "Shotgun",
        weapon_crossbow = "Crossbow", weapon_frag = "Grenade", weapon_rpg = "RPG", weapon_slam = "S.L.A.M",
        weapon_physcannon = "Gravity Gun", weapon_bugbait = "Bugbait",
    }

    local function SlotLabel(slot)
        for _, choice in ipairs(SLOT_CHOICES) do
            if choice[1] == slot then return choice[2] end
        end
        return tostring(slot)
    end

    local function DarkFrame(title, w, h)
        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:SetSize(w, h)
        frame:Center()
        frame:MakePopup()
        frame.Paint = function(self, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, Color(20, 20, 20, 245))
            draw.RoundedBoxEx(8, 0, 0, pw, 30, Color(40, 40, 40), true, true, false, false)
            draw.SimpleText(title, "DermaDefaultBold", 10, 15, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        return frame
    end

    local function Label(parent, text)
        local label = vgui.Create("DLabel", parent)
        label:SetText(text)
        label:SetTextColor(Color(200, 200, 200))
        label:Dock(TOP)
        label:DockMargin(0, 8, 0, 2)
        return label
    end

    -- Installed weapons (SWEPs + HL2) that are not in the list yet
    local function GetInstalledWeapons(exclude)
        local result = {}
        for class, name in pairs(HL2_WEAPONS) do
            if !exclude[class] then table.insert(result, { id = class, name = name }) end
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

    -- Picker to add installed weapons; onPick(weapon) for each one chosen
    local function OpenWeaponPicker(exclude, onPick)
        local frame = DarkFrame("Add weapons (double-click, or select several and press Add)", 560, 520)

        local search = vgui.Create("DTextEntry", frame)
        search:Dock(TOP)
        search:SetPlaceholderText("Search by class, name or category...")

        local list = vgui.Create("DListView", frame)
        list:Dock(FILL)
        list:DockMargin(0, 6, 0, 6)
        list:AddColumn("Class")
        list:AddColumn("Name")
        list:AddColumn("Category")

        local all = GetInstalledWeapons(exclude)
        local function Fill(filter)
            list:Clear()
            filter = string.lower(filter or "")
            for _, weapon in ipairs(all) do
                local text = string.lower(weapon.id .. " " .. weapon.name .. " " .. (weapon.category or ""))
                if filter == "" or string.find(text, filter, 1, true) then
                    list:AddLine(weapon.id, weapon.name, weapon.category or "").weapon = weapon
                end
            end
        end
        Fill()
        search.OnChange = function(self) Fill(self:GetValue()) end

        local function AddSelected()
            for _, line in ipairs(list:GetSelected()) do
                onPick(line.weapon)
                exclude[line.weapon.id] = true
            end
            all = GetInstalledWeapons(exclude)
            Fill(search:GetValue())
        end
        list.DoDoubleClick = AddSelected

        local manual = vgui.Create("DPanel", frame)
        manual:Dock(BOTTOM)
        manual:SetTall(24)
        manual:SetPaintBackground(false)

        local addButton = vgui.Create("DButton", manual)
        addButton:SetText("Add")
        addButton:Dock(RIGHT)
        addButton:SetWide(90)
        addButton.DoClick = AddSelected

        local classEntry = vgui.Create("DTextEntry", manual)
        classEntry:Dock(FILL)
        classEntry:DockMargin(0, 0, 6, 0)
        classEntry:SetPlaceholderText("...or type a class (e.g. m9k_ak47) and press Enter")
        classEntry.OnEnter = function(self)
            local class = string.Trim(self:GetValue())
            if class == "" or exclude[class] then return end
            onPick({ id = class, name = class })
            exclude[class] = true
            self:SetValue("")
        end
    end

    function Admin.OpenEditor(weaponList)
        if IsValid(Admin.Frame) then Admin.Frame:Remove() end

        local working = table.Copy(weaponList)
        local frame = DarkFrame("JDeathmatch - Weapons config (admin)", math.min(980, ScrW() - 40), math.min(620, ScrH() - 40))
        Admin.Frame = frame

        -- Right: fields of the selected weapon
        local side = vgui.Create("DPanel", frame)
        side:Dock(RIGHT)
        side:SetWide(300)
        side:DockMargin(8, 0, 0, 0)
        side:DockPadding(10, 4, 10, 10)
        side.Paint = function(self, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30)) end

        -- Left: the list
        local list = vgui.Create("DListView", frame)
        list:Dock(FILL)
        list:SetMultiSelect(false)
        list:AddColumn("Name"):SetWidth(170)
        list:AddColumn("Class"):SetWidth(170)
        list:AddColumn("Slot"):SetWidth(150)
        list:AddColumn("Ammo"):SetWidth(55)
        list:AddColumn("Dmg x"):SetWidth(55)

        local function UpdateLine(line)
            local w = line.weapon
            line:SetColumnText(1, w.name)
            line:SetColumnText(2, w.id)
            line:SetColumnText(3, SlotLabel(w.slot))
            line:SetColumnText(4, w.ammo == 0 and "default" or w.ammo)
            line:SetColumnText(5, w.dmgmul)
        end

        local function AddLine(weapon)
            local line = list:AddLine("", "", "", "", "")
            line.weapon = weapon
            UpdateLine(line)
            return line
        end

        for _, weapon in ipairs(working) do AddLine(weapon) end

        -- RemoveLine leaves holes in GetLines(), so collect them in their original order
        local function GetLines()
            local lines = {}
            for _, line in pairs(list:GetLines()) do table.insert(lines, line) end
            table.sort(lines, function(a, b) return a:GetID() < b:GetID() end)
            return lines
        end

        local selectedLine
        local loading = false

        Label(side, "Name shown in menus")
        local nameEntry = vgui.Create("DTextEntry", side)
        nameEntry:Dock(TOP)

        Label(side, "Weapon class")
        local classEntry = vgui.Create("DTextEntry", side)
        classEntry:Dock(TOP)

        Label(side, "Slot")
        local slotBox = vgui.Create("DComboBox", side)
        slotBox:Dock(TOP)
        for _, choice in ipairs(SLOT_CHOICES) do slotBox:AddChoice(choice[2], choice[1]) end

        Label(side, "Ammo on spawn (0 = weapon default)")
        local ammoWang = vgui.Create("DNumberWang", side)
        ammoWang:Dock(TOP)
        ammoWang:SetMinMax(0, 9999)
        ammoWang:SetDecimals(0)

        Label(side, "Damage multiplier (1 = normal)")
        local dmgSlider = vgui.Create("DNumSlider", side)
        dmgSlider:Dock(TOP)
        dmgSlider:SetMinMax(0, 10)
        dmgSlider:SetDecimals(2)
        dmgSlider:SetText("")
        dmgSlider.Label:SetVisible(false)

        local fields = { nameEntry, classEntry, slotBox, ammoWang, dmgSlider }
        local function SetFieldsEnabled(enabled)
            for _, field in ipairs(fields) do field:SetEnabled(enabled) end
        end
        SetFieldsEnabled(false)

        -- Edits apply to the working copy right away; nothing is sent until "Save"
        local function Edited(apply)
            if loading or !IsValid(selectedLine) then return end
            apply(selectedLine.weapon)
            UpdateLine(selectedLine)
        end
        nameEntry.OnChange = function(self) Edited(function(w) w.name = self:GetValue() end) end
        classEntry.OnChange = function(self) Edited(function(w) w.id = string.Trim(self:GetValue()) end) end
        slotBox.OnSelect = function(_, _, _, slot) Edited(function(w) w.slot = slot end) end
        ammoWang.OnValueChanged = function(self, value) Edited(function(w) w.ammo = math.floor(tonumber(value) or 0) end) end
        dmgSlider.OnValueChanged = function(self, value) Edited(function(w) w.dmgmul = math.Round(value, 2) end) end

        list.OnRowSelected = function(_, _, line)
            selectedLine = line
            local w = line.weapon
            loading = true
            nameEntry:SetValue(w.name or "")
            classEntry:SetValue(w.id or "")
            for i, choice in ipairs(SLOT_CHOICES) do
                if choice[1] == w.slot then slotBox:ChooseOptionID(i) end
            end
            ammoWang:SetValue(w.ammo or 0)
            dmgSlider:SetValue(w.dmgmul or 1)
            loading = false
            SetFieldsEnabled(true)
        end

        local function Button(parent, text, dock, onClick)
            local button = vgui.Create("DButton", parent)
            button:SetText(text)
            button:Dock(dock)
            button:DockMargin(0, 6, 0, 0)
            button:SetTall(28)
            button.DoClick = onClick
            return button
        end

        -- Bottom of the side panel, from the bottom up
        Button(side, "Close without saving", BOTTOM, function() frame:Remove() end)

        Button(side, "Save and apply on the server", BOTTOM, function()
            local result = {}
            for _, line in ipairs(GetLines()) do table.insert(result, line.weapon) end

            local data = util.Compress(util.TableToJSON(result))
            net.Start("JDM_AdminSaveConfig")
            net.WriteUInt(#data, 32)
            net.WriteData(data, #data)
            net.SendToServer()
            frame:Remove()
        end)

        Button(side, "Remove selected", BOTTOM, function()
            if !IsValid(selectedLine) then return end
            list:RemoveLine(selectedLine:GetID())
            selectedLine = nil
            SetFieldsEnabled(false)
        end)

        Button(side, "Add weapons...", BOTTOM, function()
            local exclude = {}
            for _, line in ipairs(GetLines()) do exclude[line.weapon.id] = true end

            OpenWeaponPicker(exclude, function(weapon)
                local line = AddLine({ id = weapon.id, name = weapon.name, slot = 1, ammo = 0, dmgmul = 1 })
                list:ClearSelection()
                list:SelectItem(line)
            end)
        end)
    end

    net.Receive("JDM_AdminOpenEditor", function()
        local len = net.ReadUInt(32)
        local json = util.Decompress(net.ReadData(len))
        local weaponList = json and util.JSONToTable(json)
        if istable(weaponList) then Admin.OpenEditor(weaponList) end
    end)

    function Admin.RequestEditor()
        net.Start("JDM_AdminRequestEditor")
        net.SendToServer()
    end

    concommand.Add("jdm_admin", Admin.RequestEditor)
end
