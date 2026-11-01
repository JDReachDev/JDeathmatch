-- Admin weapon config editor (server side): send the config, validate and save the edited one

if SERVER then
    JDM = JDM or {}
    JDM.Admin = JDM.Admin or {}
    JDM.Admin.LastSaveAt = {}

    local VALID_SLOTS = { [1] = true, [2] = true, [3] = true, [4] = true }
    VALID_SLOTS[JDM.Config.MOABSlot] = true

    local MAX_WEAPONS = 256

    -- Big tables go compressed, net.WriteTable has a 64 KB limit
    local function WriteCompressed(tbl)
        local data = util.Compress(util.TableToJSON(tbl))
        net.WriteUInt(#data, 32)
        net.WriteData(data, #data)
    end

    local function ReadCompressed()
        local len = net.ReadUInt(32)
        if len <= 0 or len > 65000 then return nil end
        local json = util.Decompress(net.ReadData(len))
        return json and util.JSONToTable(json)
    end

    -- Returns a clean copy of the weapon list, or nil + error message
    function JDM.Admin.SanitizeWeapons(list)
        if !istable(list) then return nil, "Invalid data." end
        if #list == 0 then return nil, "The list is empty: keep at least one weapon." end
        if #list > MAX_WEAPONS then return nil, "Too many weapons (max " .. MAX_WEAPONS .. ")." end

        local clean, seen = {}, {}
        for i, weapon in ipairs(list) do
            if !istable(weapon) then return nil, "Entry " .. i .. " is not valid." end

            local id = isstring(weapon.id) and string.Trim(weapon.id) or ""
            if id == "" or #id > 64 or !string.match(id, "^[%w_%-%.]+$") then
                return nil, "Entry " .. i .. ": invalid weapon class '" .. tostring(weapon.id) .. "'."
            end
            if seen[id] then return nil, "Weapon " .. id .. " is in the list twice." end
            seen[id] = true

            local name = isstring(weapon.name) and string.Trim(weapon.name) or ""
            if name == "" then name = id end

            local slot = tonumber(weapon.slot)
            if !slot or !VALID_SLOTS[slot] then return nil, id .. ": invalid slot " .. tostring(weapon.slot) .. "." end

            local ammo = math.floor(tonumber(weapon.ammo) or 0)
            local dmgmul = tonumber(weapon.dmgmul) or 1

            table.insert(clean, {
                id = id,
                name = string.sub(name, 1, 64),
                slot = slot,
                ammo = math.Clamp(ammo, 0, 9999),
                dmgmul = math.Clamp(math.Round(dmgmul, 2), 0, 100),
            })
        end
        return clean
    end

    function JDM.Admin.OpenEditor(ply)
        if !IsValid(ply) or !ply:IsAdmin() then return end

        net.Start("JDM_AdminOpenEditor")
        WriteCompressed(JDM.Weapons.List or {})
        net.Send(ply)
    end

    net.Receive("JDM_AdminRequestEditor", function(len, ply)
        if !IsValid(ply) or !ply:IsAdmin() then return end
        JDM.Admin.OpenEditor(ply)
    end)

    net.Receive("JDM_AdminSaveConfig", function(len, ply)
        if !IsValid(ply) or !ply:IsAdmin() then return end

        local key = JDM.PlayerKey(ply)
        if CurTime() - (JDM.Admin.LastSaveAt[key] or 0) < 2 then return end
        JDM.Admin.LastSaveAt[key] = CurTime()

        local list, err = JDM.Admin.SanitizeWeapons(ReadCompressed())
        if !list then
            ply:ChatPrint("[JDM] Config not saved: " .. err)
            return
        end

        -- Keep the previous config, in case of a bad edit
        local filePath = JDM.Config.WeaponFilePath
        local previous = file.Read(filePath, "DATA")
        if previous then
            file.Write(string.StripExtension(filePath) .. "_backup.txt", previous)
        end

        file.Write(filePath, util.TableToJSON(list, true))
        JDM.Weapons.Load()
        JDM.Weapons.SendSlots(player.GetHumans(), false)

        print("[INFO] " .. ply:Nick() .. " saved the weapons config (" .. #list .. " weapons).")
        PrintMessage(HUD_PRINTTALK, "[JDM] " .. ply:Nick() .. " updated the weapons config. Changes apply on your next spawn.")
    end)

    -- Settings tab: only JDM ConVars, numbers clamped to their range
    net.Receive("JDM_AdminSetConVars", function(len, ply)
        if !IsValid(ply) or !ply:IsAdmin() then return end

        local changed = net.ReadTable()
        local applied = {}

        for _, cvar in ipairs(JDM.ConVars) do
            local value = changed[cvar.name]
            if !isstring(value) then continue end

            if cvar.type == "number" then
                local number = tonumber(value)
                if !number then continue end
                value = tostring(math.Clamp(math.floor(number), cvar.min, cvar.max))
            elseif cvar.type == "bool" then
                value = tobool(value) and "1" or "0"
            elseif cvar.type == "music" then
                -- A sound path, nothing that could run commands
                value = string.Trim(value)
                if #value > 128 or !string.match(value, "^[%w_%-%./]*$") then continue end
            end

            RunConsoleCommand(cvar.name, value)
            table.insert(applied, cvar.name .. " = " .. value)
        end

        if #applied > 0 then
            print("[INFO] " .. ply:Nick() .. " changed settings: " .. table.concat(applied, ", "))
            PrintMessage(HUD_PRINTTALK, "[JDM] " .. ply:Nick() .. " changed: " .. table.concat(applied, ", "))
        end
    end)

    -- F3 (gm_showspare1) opens the editor
    function GM:ShowSpare1(ply)
        if ply:IsAdmin() then
            JDM.Admin.OpenEditor(ply)
        else
            ply:ChatPrint("Only admins can edit the weapons config.")
        end
    end

    hook.Add("PlayerDisconnected", "JDM_CleanupAdminData", function(ply)
        JDM.Admin.LastSaveAt[JDM.PlayerKey(ply)] = nil
    end)
end
