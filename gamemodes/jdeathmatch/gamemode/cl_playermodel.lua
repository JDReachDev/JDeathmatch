-- Player model picker (opened from the loadout menu): a grid of every installed player model with a
-- search box and a rotating preview. It sets cl_playermodel, which the server applies on the next
-- spawn (sv_player.lua).

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.PlayerModel = JDM.Client.PlayerModel or {}

    local PM = JDM.Client.PlayerModel
    local UI = JDM.UI
    local C, S = UI.Colors, UI.S

    -- The base gamemode usually creates it; make sure it exists and is sent to the server
    if !ConVarExists("cl_playermodel") then
        CreateClientConVar("cl_playermodel", "kleiner", true, true)
    end

    function PM.GetCurrent()
        local cvar = GetConVar("cl_playermodel")
        return cvar and cvar:GetString() or "kleiner"
    end

    -- Every valid player model, sorted by name: { { name, model }, ... }
    local function GetModels()
        local list = {}
        for name, model in pairs(player_manager.AllValidModels()) do
            table.insert(list, { name = name, model = model })
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        return list
    end

    local function SetPreview(panel, model)
        panel:SetModel(model)
        local ent = panel.Entity
        if !IsValid(ent) then return end

        -- Models that use the player color proxy
        local color = IsValid(LocalPlayer()) and LocalPlayer():GetPlayerColor() or Vector(0.24, 0.34, 0.41)
        function ent:GetPlayerColor() return color end

        local seq = ent:LookupSequence("idle_all_01")
        if seq and seq > 0 then ent:ResetSequence(seq) end

        local mins, maxs = ent:GetRenderBounds()
        local height = math.max(maxs.z - mins.z, 10)
        local center = (mins.z + maxs.z) / 2
        panel:SetFOV(36)
        panel:SetLookAt(Vector(0, 0, center))
        panel:SetCamPos(Vector(height * 1.75, 0, center + height * 0.08))
    end

    function PM.IsOpen()
        return IsValid(PM.Frame)
    end

    function PM.Close()
        if IsValid(PM.Frame) then PM.Frame:Remove() end
    end

    function PM.Open()
        PM.Close()

        local models = GetModels()
        local selected = PM.GetCurrent()

        local frame = UI.Frame("Player model", S(1040), S(700))
        frame:SetSubtitle("Applies on your next spawn")
        UI.Popup(frame)
        PM.Frame = frame

        -- Right column: preview, name, buttons
        local sideW = S(300)
        local side = vgui.Create("DPanel", frame)
        side:Dock(RIGHT)
        side:SetWide(sideW)
        side:DockMargin(S(14), 0, 0, 0)
        side.Paint = function(self, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, C.Panel) end
        side:DockPadding(S(10), S(10), S(10), S(10))

        local apply = UI.Button(side, "Use this model", "primary", function()
            RunConsoleCommand("cl_playermodel", selected)
            surface.PlaySound("ui/buttonclick.wav")
            frame:Remove()
        end)
        apply:Dock(BOTTOM)
        apply:SetTall(S(40))

        local back = UI.Button(side, "Back", "ghost", function()
            frame:Remove()
        end)
        back:Dock(BOTTOM)
        back:SetTall(S(40))
        back:DockMargin(0, 0, 0, S(8))

        local nameLabel = vgui.Create("DPanel", side)
        nameLabel:Dock(BOTTOM)
        nameLabel:SetTall(S(46))
        nameLabel:DockMargin(0, S(6), 0, S(8))
        nameLabel.Paint = function(self, pw, ph)
            local current = selected == PM.GetCurrent()
            draw.SimpleText(UI.Fit(string.upper(selected), "JDM_UI_Big", pw), "JDM_UI_Big", pw / 2, ph / 2 - S(8), C.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(current and "IN USE" or "NOT IN USE YET", "JDM_UI_Small", pw / 2, ph / 2 + S(13), current and C.Green or C.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local preview = vgui.Create("DModelPanel", side)
        preview:Dock(FILL)
        preview:SetAnimated(true)
        local baseLayout = preview.LayoutEntity
        preview.LayoutEntity = function(self, ent)
            baseLayout(self, ent)
            ent:SetAngles(Angle(0, RealTime() * 30 % 360, 0))
        end
        SetPreview(preview, player_manager.TranslatePlayerModel(selected))

        -- Left: search and grid
        local search = UI.TextEntry(frame, "Search models...")
        search:Dock(TOP)
        search:DockMargin(0, 0, 0, S(10))

        local scroll = UI.Scroll(frame)
        scroll:Dock(FILL)

        local grid = vgui.Create("DIconLayout", scroll)
        grid:Dock(TOP)
        grid:SetSpaceX(S(8))
        grid:SetSpaceY(S(8))

        local tileW, iconSize = S(108), S(96)
        local tileH = iconSize + S(30)

        local function Select(entry)
            selected = entry.name
            SetPreview(preview, entry.model)
            surface.PlaySound("ui/buttonclick.wav")
        end

        local function Rebuild()
            grid:Clear()
            local filter = string.lower(string.Trim(search:GetText()))
            for _, entry in ipairs(models) do
                if filter != "" and !string.find(string.lower(entry.name), filter, 1, true) then continue end

                local tile = grid:Add("DButton")
                tile:SetText("")
                tile:SetSize(tileW, tileH)
                if entry.name == selected then grid.JDM_Current = tile end
                tile.DoClick = function() Select(entry) end
                tile.DoDoubleClick = function()
                    Select(entry)
                    apply:DoClick()
                end
                tile.Paint = function(self, pw, ph)
                    local hov = UI.Hover(self, self:IsHovered())
                    local isSelected = selected == entry.name
                    if isSelected then
                        draw.RoundedBox(6, 0, 0, pw, ph, C.Accent)
                        draw.RoundedBox(5, 2, 2, pw - 4, ph - 4, C.Card)
                        draw.RoundedBox(5, 2, 2, pw - 4, ph - 4, C.AccentSoft)
                    else
                        draw.RoundedBox(6, 0, 0, pw, ph, UI.LerpColor(hov, C.Panel, C.Hover))
                    end
                    local inUse = entry.name == PM.GetCurrent()
                    draw.SimpleText(UI.Fit(entry.name, "JDM_UI_Small", pw - S(8)), "JDM_UI_Small", pw / 2, ph - S(14),
                        (isSelected or inUse) and C.Text or C.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    if inUse then
                        draw.RoundedBox(3, pw - S(12), S(6), S(6), S(6), C.Green)
                    end
                end

                local icon = vgui.Create("SpawnIcon", tile)
                icon:SetSize(iconSize, iconSize)
                icon:SetPos((tileW - iconSize) / 2, S(4))
                icon:SetModel(entry.model)
                icon:SetTooltip(false)
                icon:SetMouseInputEnabled(false)
            end
            grid:InvalidateLayout(true)
        end

        search.OnChange = function() Rebuild() end
        Rebuild()

        -- Scroll to the model in use (once the grid has its layout)
        timer.Simple(0, function()
            if IsValid(scroll) and IsValid(grid.JDM_Current) then scroll:ScrollToChild(grid.JDM_Current) end
        end)
    end
end
