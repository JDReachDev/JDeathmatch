-- Client-side scoreboard

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.Scoreboard = JDM.Client.Scoreboard or {}
    
    -- Track which players have received MOAB
    JDM.Client.Scoreboard.MOABPlayers = {}
    
    -- Scoreboard panel
    JDM.Client.Scoreboard.Panel = nil
    
    -- Create scoreboard panel
    function JDM.Client.Scoreboard.CreatePanel()
        if IsValid(JDM.Client.Scoreboard.Panel) then
            return JDM.Client.Scoreboard.Panel
        end
        
        local scrW, scrH = ScrW(), ScrH()
        local panelWidth = math.min(800, scrW * 0.8)
        local panelHeight = math.min(600, scrH * 0.8)
        
        local frame = vgui.Create("DFrame")
        frame:SetSize(panelWidth, panelHeight)
        frame:Center()
        frame:SetTitle("")
        frame:SetDraggable(false)
        frame:ShowCloseButton(false)
        frame:SetDeleteOnClose(false)
        frame:SetVisible(false)
        frame.Paint = function(self, w, h)
            -- Background with transparency
            draw.RoundedBox(8, 0, 0, w, h, Color(20, 20, 20, 240))
            
            -- Header
            draw.RoundedBoxEx(8, 0, 0, w, 60, Color(40, 40, 40, 255), true, true, false, false)
            
            -- Title
            draw.SimpleText("SCOREBOARD", "DermaLarge", w / 2, 30, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        
        -- Header info panel
        local headerPanel = vgui.Create("DPanel", frame)
        headerPanel:SetPos(10, 70)
        headerPanel:SetSize(panelWidth - 20, 40)
        headerPanel.Paint = function(self, w, h)
            local maxKills = 30
            local moabKills = 25
            if ConVarExists("jdm_maxkills") then
                maxKills = GetConVar("jdm_maxkills"):GetInt()
            end
            if ConVarExists("jdm_moabkills") then
                moabKills = GetConVar("jdm_moabkills"):GetInt()
            end
            
            -- Background
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 30, 255))
            
            -- Max kills to win
            draw.SimpleText("Kills to win: " .. maxKills, "DermaDefault", 10, h / 2 , Color(255, 200, 0, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            
            -- MOAB kills requirement
            draw.SimpleText("Kills to MOAB: " .. moabKills, "DermaDefault", w / 2, h / 2, Color(255, 100, 100, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            
            -- Player count
            local playerCount = #player.GetAll()
            draw.SimpleText("Players: " .. playerCount, "DermaDefault", w - 10, h / 2, Color(200, 200, 200, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        
        -- Scroll panel for player list
        local scrollPanel = vgui.Create("DScrollPanel", frame)
        scrollPanel:SetPos(10, 120)
        scrollPanel:SetSize(panelWidth - 20, panelHeight - 120)
        
        -- Player list
        local playerList = vgui.Create("DListLayout", scrollPanel)
        playerList:SetSize(panelWidth - 40, 0)
        playerList:Dock(FILL)
        
        -- Store references
        JDM.Client.Scoreboard.Panel = frame
        JDM.Client.Scoreboard.ScrollPanel = scrollPanel
        JDM.Client.Scoreboard.PlayerList = playerList
        
        return frame
    end
    
    -- Update scoreboard
    function JDM.Client.Scoreboard.Update()
        if !IsValid(JDM.Client.Scoreboard.Panel) then
            JDM.Client.Scoreboard.CreatePanel()
        end
        
        local playerList = JDM.Client.Scoreboard.PlayerList
        if !IsValid(playerList) then return end
        
        -- Clear existing entries
        playerList:Clear()
        
        -- Get all players and filter out invalid ones
        local allPlayers = player.GetAll()
        local players = {}
        for _, ply in ipairs(allPlayers) do
            if IsValid(ply) and ply:IsPlayer() then
                table.insert(players, ply)
            end
        end
        
        -- Sort players by kills (descending), then by deaths (ascending)
        table.sort(players, function(a, b)
            if !IsValid(a) or !IsValid(b) then 
                return IsValid(a) -- Put valid players first
            end
            
            local killsA = a:Frags()
            local killsB = b:Frags()
            
            -- Sort by kills descending
            if killsA ~= killsB then
                return killsA > killsB
            end
            
            -- If kills are equal, sort by deaths ascending (fewer deaths = better)
            local deathsA = a:Deaths()
            local deathsB = b:Deaths()
            return deathsA < deathsB
        end)
        
        -- Get config values (with fallback)
        local maxKills = 30
        local moabKills = 25
        if ConVarExists("jdm_maxkills") then
            maxKills = GetConVar("jdm_maxkills"):GetInt()
        end
        if ConVarExists("jdm_moabkills") then
            moabKills = GetConVar("jdm_moabkills"):GetInt()
        end
        
        -- Create entry for each player
        for i, ply in ipairs(players) do
            if !IsValid(ply) then continue end
            
            local kills = ply:Frags()
            local deaths = ply:Deaths()
            local kd = deaths > 0 and math.Round(kills / deaths, 2) or kills
            
            -- Player row panel
            local row = vgui.Create("DPanel", playerList)
            row:SetSize(playerList:GetWide(), 30)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 5)
            
            -- Highlight current player
            local isLocalPlayer = ply == LocalPlayer()
            local bgColor = isLocalPlayer and Color(50, 80, 120, 200) or Color(35, 35, 35, 200)
            local textColor = isLocalPlayer and Color(255, 255, 200, 255) or Color(255, 255, 255, 255)
            
            -- Avatar image
            local avatarSize = 24
            local avatar = vgui.Create("AvatarImage", row)
            avatar:SetSize(avatarSize, avatarSize)
            avatar:SetPos(5, (30 - avatarSize) / 2)
            avatar:SetPlayer(ply, avatarSize)
            
            row.Paint = function(self, w, h)
                -- Background
                draw.RoundedBox(4, 0, 0, w, h, bgColor)
                
                -- Position indicator
                local posColor = Color(200, 200, 200, 255)
                if i == 1 then
                    posColor = Color(255, 215, 0, 255) -- Gold for first
                elseif i == 2 then
                    posColor = Color(192, 192, 192, 255) -- Silver for second
                elseif i == 3 then
                    posColor = Color(205, 127, 50, 255) -- Bronze for third
                end
                
                draw.SimpleText("#" .. i, "DermaDefault", 35, h / 2, posColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                
                -- Player name
                local nameX = 70
                draw.SimpleText(ply:Nick(), "DermaDefault", nameX, h / 2, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                
                -- Kills
                local killsX = w * 0.35
                local killsColor = kills >= maxKills and Color(0, 255, 0, 255) or Color(255, 255, 255, 255)
                draw.SimpleText("K: " .. kills, "DermaDefault", killsX, h / 2, killsColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                
                -- Deaths
                local deathsX = w * 0.45
                draw.SimpleText("D: " .. deaths, "DermaDefault", deathsX, h / 2, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                
                -- K/D Ratio
                local kdX = w * 0.55
                draw.SimpleText("K/D: " .. kd, "DermaDefault", kdX, h / 2, Color(200, 200, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                
                -- MOAB status
                local moabX = w * 0.7
                local moabText = ""
                local moabColor = Color(200, 200, 200, 255)
                
                -- Check if player has already received MOAB
                local steamID = ply:SteamID()
                local hasMOAB = JDM.Client.Scoreboard.MOABPlayers[steamID] == true
                
                if hasMOAB then
                    moabText = "MOAB ✓"
                    moabColor = Color(255, 100, 100, 255)
                else
                    moabText = "K to MOAB: " .. (moabKills - kills)
                    moabColor = Color(150, 150, 150, 255)
                end
                
                draw.SimpleText(moabText, "DermaDefault", moabX, h / 2, moabColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                
                -- Progress to win
                local progressX = w * 0.9
                local progress = math.min(kills / maxKills, 1)
                local progressColor = Color(0, 255, 0, 255)
                if progress < 0.5 then
                    progressColor = Color(255, 255, 0, 255)
                elseif progress < 0.75 then
                    progressColor = Color(255, 165, 0, 255)
                end
                
                draw.SimpleText(math.Round(progress * 100) .. "%", "DermaDefault", progressX, h / 2, progressColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
    end
    
    -- Show scoreboard
    function JDM.Client.Scoreboard.Show()
        local panel = JDM.Client.Scoreboard.CreatePanel()
        if IsValid(panel) then
            panel:SetVisible(true)
            panel:MakePopup()
            JDM.Client.Scoreboard.Update()
        end
    end
    
    -- Hide scoreboard
    function JDM.Client.Scoreboard.Hide()
        local panel = JDM.Client.Scoreboard.Panel
        if IsValid(panel) then
            panel:SetVisible(false)
        end
    end
    
    -- Hook to show/hide scoreboard on Tab
    hook.Add("ScoreboardShow", "JDM_ShowScoreboard", function()
        JDM.Client.Scoreboard.Show()
        return true -- Prevent default scoreboard
    end)
    
    hook.Add("ScoreboardHide", "JDM_HideScoreboard", function()
        JDM.Client.Scoreboard.Hide()
        return true -- Prevent default scoreboard
    end)
    
    -- Update scoreboard periodically when visible
    hook.Add("Think", "JDM_UpdateScoreboard", function()
        if IsValid(JDM.Client.Scoreboard.Panel) and JDM.Client.Scoreboard.Panel:IsVisible() then
            -- Update every 0.5 seconds
            if !JDM.Client.Scoreboard.LastUpdate or CurTime() - JDM.Client.Scoreboard.LastUpdate > 0.5 then
                JDM.Client.Scoreboard.Update()
                JDM.Client.Scoreboard.LastUpdate = CurTime()
            end
        end
    end)
    
    -- Receive MOAB status from server
    net.Receive("SendMoabStatus", function()
        local moabPlayers = net.ReadTable()
        -- Clear and rebuild MOAB players table
        JDM.Client.Scoreboard.MOABPlayers = {}
        for _, steamID in ipairs(moabPlayers) do
            JDM.Client.Scoreboard.MOABPlayers[steamID] = true
        end
    end)
end

