-- Client-side weapon selection UI

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.Weapons = JDM.Client.Weapons or {}
    
    -- Variables
    JDM.Client.Weapons.Slots = {}
    JDM.Client.Weapons.Frame = nil
    JDM.Client.Weapons.IsOpen = false
    
    -- Send weapon selection to server
    local function SendWeaponSelection(selection)
        net.Start("SetPlayerWeapons")
        net.WriteTable(selection)
        net.SendToServer()
    end
    
    -- Create weapon selection frame
    local function CreateWeaponFrame()
        if IsValid(JDM.Client.Weapons.Frame) then
            JDM.Client.Weapons.Frame:Show()
            return
        end
        
        local frame = vgui.Create("DFrame")
        frame:SetTitle("Select your weapons")
        frame:SetSize(400, 300)
        frame:Center()
        frame:ShowCloseButton(false)
        frame:MakePopup()
        frame:SetKeyboardInputEnabled(false)
        
        JDM.Client.Weapons.Frame = frame
        local weaponSelection = {} -- To save player choices
        
        for slot, weapons in pairs(JDM.Client.Weapons.Slots) do
            local slotPanel = vgui.Create("DPanel", frame)
            slotPanel:SetTall(40)
            slotPanel:Dock(TOP)
            slotPanel:DockMargin(10, 10, 10, 0)
            
            local label = vgui.Create("DLabel", slotPanel)
            label:SetText(JDM.Config.WeaponSlotLabels[slot] or "Slot " .. slot)
            label:SetTextColor(Color(23, 144, 243))
            label:Dock(TOP)
            label:DockMargin(5, 0, 0, 0)
            
            local comboBox = vgui.Create("DComboBox", slotPanel)
            comboBox:Dock(FILL)
            
            for _, weapon in ipairs(weapons) do
                comboBox:AddChoice(weapon.name, weapon.id)
            end
            
            comboBox.OnSelect = function(_, _, _, weaponID)
                weaponSelection[slot] = weaponID
            end
        end
        
        local saveButton = vgui.Create("DButton", frame)
        saveButton:SetText("Save and close")
        saveButton:Dock(BOTTOM)
        saveButton.DoClick = function()
            SendWeaponSelection(weaponSelection)
            frame:Hide()
            JDM.Client.Weapons.IsOpen = false
        end
    end
    
    -- Open weapon menu
    function JDM.Client.Weapons.OpenMenu()
        CreateWeaponFrame()
        JDM.Client.Weapons.IsOpen = true
    end
    
    -- Close weapon menu
    function JDM.Client.Weapons.CloseMenu()
        if IsValid(JDM.Client.Weapons.Frame) then
            JDM.Client.Weapons.Frame:Hide()
            JDM.Client.Weapons.IsOpen = false
        end
    end
    
    -- Hook to open/close menu with Q
    hook.Add("PlayerButtonDown", "JDM_OpenWeaponMenuOnQ", function(ply, button)
        if button == KEY_Q then
            if JDM.Client.Weapons.IsOpen then
                JDM.Client.Weapons.CloseMenu()
            else
                JDM.Client.Weapons.OpenMenu()
            end
        end
    end)
    
    -- Receive weapon lists from server
    net.Receive("SendWeaponSlots", function()
        JDM.Client.Weapons.Slots = net.ReadTable()
        JDM.Client.Weapons.OpenMenu()
    end)
end
