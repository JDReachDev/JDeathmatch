-- Client-side scoreboard (hold Tab)

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.Scoreboard = JDM.Client.Scoreboard or {}

    local Board = JDM.Client.Scoreboard
    local UI = JDM.UI
    local C, S = UI.Colors, UI.S

    -- Players who already got the MOAB this map (kept by the server)
    Board.MOABPlayers = Board.MOABPlayers or {}

    local RANK_COLORS = { Color(255, 215, 0), Color(200, 200, 205), Color(205, 127, 50) }

    -- Column centers / edges, as fractions of the row width
    local COL_KILLS, COL_DEATHS, COL_KD, COL_MOAB, COL_BAR, COL_BAR_END = 0.47, 0.55, 0.63, 0.72, 0.79, 0.90

    local function GetLimits()
        local maxKills = ConVarExists("jdm_maxkills") and GetConVar("jdm_maxkills"):GetInt() or 30
        local moabKills = ConVarExists("jdm_moabkills") and GetConVar("jdm_moabkills"):GetInt() or 25
        return maxKills, moabKills
    end

    local function StreakMode()
        return ConVarExists("jdm_moabstreak") and GetConVar("jdm_moabstreak"):GetBool()
    end

    function Board.CreatePanel()
        if IsValid(Board.Panel) then return Board.Panel end

        local frame = UI.Frame("JDeathmatch", S(940), math.Round(ScrH() * 0.8))
        frame:SetDraggable(false)
        frame.JDM_CloseButton:SetVisible(false)
        frame:SetVisible(false)
        frame.OnCloseButton = function(self) self:SetVisible(false) end

        frame.Think = function(self)
            local count = player.GetCount()
            self:SetSubtitle(game.GetMap() .. "  ·  " .. count .. (count == 1 and " player" or " players"))
        end

        -- Match rules
        local info = vgui.Create("DPanel", frame)
        info:Dock(TOP)
        info:SetTall(S(34))
        info:DockMargin(0, 0, 0, S(10))
        info.Paint = function(self, w, h)
            local maxKills, moabKills = GetLimits()
            local chips = {
                { "FIRST TO " .. maxKills .. " KILLS WINS", C.Accent },
                { "MOAB AT " .. moabKills .. (StreakMode() and " KILLS IN A ROW" or " KILLS"), C.Gold },
            }
            local x = 0
            for _, chip in ipairs(chips) do
                surface.SetFont("JDM_UI_Small")
                local tw = surface.GetTextSize(chip[1])
                local cw = tw + S(30)
                draw.RoundedBox(4, x, 0, cw, h, C.Panel)
                draw.RoundedBox(3, x + S(10), h / 2 - S(3), S(6), S(6), chip[2])
                draw.SimpleText(chip[1], "JDM_UI_Small", x + S(22), h / 2, C.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                x = x + cw + S(8)
            end
        end

        -- Column titles
        local header = vgui.Create("DPanel", frame)
        header:Dock(TOP)
        header:SetTall(S(22))
        header:DockMargin(0, 0, S(10), S(4))
        header.Paint = function(self, w, h)
            local function Title(text, x, align)
                draw.SimpleText(text, "JDM_UI_Small", x, h / 2, C.TextMuted, align or TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            Title("#", S(24))
            Title("PLAYER", S(52), TEXT_ALIGN_LEFT)
            Title("KILLS", w * COL_KILLS)
            Title("DEATHS", w * COL_DEATHS)
            Title("K/D", w * COL_KD)
            Title(StreakMode() and "STREAK" or "MOAB", w * COL_MOAB)
            Title("PROGRESS", w * COL_BAR, TEXT_ALIGN_LEFT)
            Title("PING", w - S(14), TEXT_ALIGN_RIGHT)
        end

        -- Rows go straight into the scroll panel: its canvas grows with them, so it scrolls
        local scrollPanel = UI.Scroll(frame)
        scrollPanel:Dock(FILL)

        Board.Panel = frame
        Board.ScrollPanel = scrollPanel
        Board.PlayerList = scrollPanel
        return frame
    end

    local function AddRow(list, i, ply, maxKills, moabKills)
        local kills, deaths = ply:Frags(), ply:Deaths()
        local kd = deaths > 0 and math.Round(kills / deaths, 2) or kills
        local isMe = ply == LocalPlayer()
        local hasMOAB = Board.MOABPlayers[JDM.PlayerKey(ply)] == true
        local streak = ply:GetNWInt("JDM_Streak", 0)
        local rowH = S(40)

        local row = vgui.Create("DPanel", list)
        row:Dock(TOP)
        row:SetTall(rowH)
        row:DockMargin(0, 0, 0, S(4))

        local avatarSize = rowH - S(12)
        local avatar = vgui.Create("AvatarImage", row)
        avatar:SetSize(avatarSize, avatarSize)
        avatar:SetPos(S(46), S(6))
        avatar:SetPlayer(ply, 64)

        row.Paint = function(self, w, h)
            if !IsValid(ply) then return end

            draw.RoundedBox(4, 0, 0, w, h, isMe and C.AccentSoft or C.Panel)
            if isMe then draw.RoundedBoxEx(4, 0, 0, S(3), h, C.Accent, true, false, true, false) end

            draw.SimpleText(i, "JDM_UI_Big", S(24), h / 2, RANK_COLORS[i] or C.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            local nameX = S(46) + avatarSize + S(10)
            local name = UI.Fit(ply:Nick(), "JDM_UI", w * COL_KILLS - nameX - S(30))
            draw.SimpleText(name, "JDM_UI", nameX, h / 2, isMe and C.Text or C.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            draw.SimpleText(kills, "JDM_UI_Big", w * COL_KILLS, h / 2, kills >= maxKills and C.Green or C.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(deaths, "JDM_UI", w * COL_DEATHS, h / 2, C.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(kd, "JDM_UI", w * COL_KD, h / 2, C.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- MOAB: done, or kills still needed (in a row, in consecutive mode)
            local moabText, moabColor
            if hasMOAB then
                moabText, moabColor = "MOAB", C.Gold
            elseif StreakMode() then
                moabText, moabColor = streak .. " / " .. moabKills, streak > 0 and C.Text or C.TextMuted
            else
                moabText, moabColor = math.max(moabKills - kills, 0) .. " TO GO", C.TextMuted
            end
            draw.SimpleText(moabText, "JDM_UI_Small", w * COL_MOAB, h / 2, moabColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Progress to win
            local progress = maxKills > 0 and math.Clamp(kills / maxKills, 0, 1) or 0
            local bx, bw, bh = math.Round(w * COL_BAR), math.Round(w * (COL_BAR_END - COL_BAR)), S(6)
            draw.RoundedBox(3, bx, h / 2 - bh / 2, bw, bh, C.Panel)
            if progress > 0 then
                draw.RoundedBox(3, bx, h / 2 - bh / 2, math.max(math.Round(bw * progress), bh), bh, progress >= 1 and C.Green or C.Accent)
            end

            local ping = ply:IsBot() and "BOT" or ply:Ping()
            draw.SimpleText(ping, "JDM_UI_Small", w - S(14), h / 2, C.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    function Board.Update()
        if !IsValid(Board.Panel) then Board.CreatePanel() end

        local list = Board.PlayerList
        if !IsValid(list) then return end

        -- Hidden first: Remove only happens next frame, so old rows would still take space
        for _, child in ipairs(list:GetCanvas():GetChildren()) do
            child:SetVisible(false)
        end
        list:Clear()

        local players = {}
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then table.insert(players, ply) end
        end

        -- Kills descending, then deaths ascending
        table.sort(players, function(a, b)
            if a:Frags() != b:Frags() then return a:Frags() > b:Frags() end
            return a:Deaths() < b:Deaths()
        end)

        local maxKills, moabKills = GetLimits()
        for i, ply in ipairs(players) do
            AddRow(list, i, ply, maxKills, moabKills)
        end
    end

    function Board.Show()
        local panel = Board.CreatePanel()
        if !IsValid(panel) then return end
        panel:SetVisible(true)
        panel:MakePopup()
        -- Keep the keyboard free, otherwise releasing Tab never hides the scoreboard
        panel:SetKeyboardInputEnabled(false)
        Board.Update()
        Board.LastUpdate = CurTime()
    end

    function Board.Hide()
        if IsValid(Board.Panel) then Board.Panel:SetVisible(false) end
    end

    hook.Add("ScoreboardShow", "JDM_ShowScoreboard", function()
        Board.Show()
        return true
    end)

    hook.Add("ScoreboardHide", "JDM_HideScoreboard", function()
        Board.Hide()
        return true
    end)

    -- Refresh twice a second while visible
    hook.Add("Think", "JDM_UpdateScoreboard", function()
        if IsValid(Board.Panel) and Board.Panel:IsVisible() and CurTime() - (Board.LastUpdate or 0) > 0.5 then
            Board.Update()
            Board.LastUpdate = CurTime()
        end
    end)

    -- Receive MOAB status from server
    net.Receive("JDM_SendMoabStatus", function()
        Board.MOABPlayers = {}
        for _, key in ipairs(net.ReadTable()) do
            Board.MOABPlayers[key] = true
        end
    end)
end
