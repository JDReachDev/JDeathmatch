-- Map vote: live map tiles with the vote counts.
-- It also works mid-match (an admin runs "jdm_mapvote"): the panel stays on screen without the cursor,
-- F4 takes the cursor to vote and gives it back. At the end of the match the cursor is given right away.

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.MapVote = JDM.Client.MapVote or {}

    local Vote = JDM.Client.MapVote
    local UI = JDM.UI
    local C, S = UI.Colors, UI.S

    Vote.Id = -1
    Vote.Maps = {}
    Vote.Counts = {}
    Vote.EndTime = 0
    Vote.Active = false
    Vote.Winner = nil
    Vote.MyVote = nil

    -- Workshop ID of the mounted addon that contains each map (built once)
    local mapAddons
    local function GetMapAddon(map)
        if !mapAddons then
            mapAddons = {}
            for _, addon in ipairs(engine.GetAddons()) do
                if addon.mounted and addon.wsid and string.find(string.lower(addon.tags or ""), "map", 1, true) then
                    for _, bsp in ipairs(file.Find("maps/*.bsp", addon.title) or {}) do
                        mapAddons[string.StripExtension(bsp)] = addon.wsid
                    end
                end
            end
        end
        return mapAddons[map]
    end

    -- Thumbnail: maps/thumb/<map>.png when the map has one, else the preview image of its
    -- Workshop addon (downloaded in the background). false = none (the tile shows the name)
    local thumbs = {}
    local function GetThumb(map)
        if thumbs[map] == nil then
            thumbs[map] = false
            for _, path in ipairs({ "maps/thumb/" .. map .. ".png", "maps/" .. map .. ".png" }) do
                if file.Exists(path, "GAME") then
                    thumbs[map] = Material(path, "smooth")
                    return thumbs[map]
                end
            end

            local wsid = GetMapAddon(map)
            if wsid then
                steamworks.FileInfo(wsid, function(info)
                    if !info or !info.previewid then return end
                    steamworks.Download(info.previewid, true, function(name)
                        if !name then return end
                        local mat = AddonMaterial(name)
                        if mat and !mat:IsError() then thumbs[map] = mat end
                    end)
                end)
            end
        end
        return thumbs[map]
    end

    local function TimeLeft()
        return math.max(math.ceil(Vote.EndTime - CurTime()), 0)
    end

    local function TotalVotes()
        local total = 0
        for _, count in pairs(Vote.Counts) do total = total + count end
        return total
    end

    local function HasCursor()
        return IsValid(Vote.Frame) and Vote.Frame:IsVisible() and Vote.Frame:IsMouseInputEnabled()
    end

    local function CastVote(map)
        if !Vote.Active or Vote.Winner or Vote.MyVote == map then return end
        Vote.MyVote = map
        surface.PlaySound("ui/buttonclick.wav")
        net.Start("JDM_CastVote")
        net.WriteString(map)
        net.SendToServer()
    end

    local function MapTile(parent, map, w, h)
        local tile = vgui.Create("DButton", parent)
        tile:SetText("")
        tile:SetSize(w, h)
        tile.DoClick = function() CastVote(map) end

        local shortName = string.upper(string.gsub(map, "^%a+_", ""))

        tile.Paint = function(self, pw, ph)
            local mine, winner = Vote.MyVote == map, Vote.Winner == map
            local loser = Vote.Winner != nil and !winner
            local hov = UI.Hover(self, self:IsHovered() and !Vote.Winner)
            local count = Vote.Counts[map] or 0
            local total = TotalVotes()

            local border = (winner and C.Gold) or (mine and C.Accent) or UI.LerpColor(hov, C.Line, C.TextDim)
            draw.RoundedBox(6, 0, 0, pw, ph, border)
            draw.RoundedBox(6, 2, 2, pw - 4, ph - 4, C.Card)

            -- Thumbnail (or the map name when the map has none)
            local imgH = ph - S(50)
            local mat = GetThumb(map)
            if mat then
                surface.SetMaterial(mat)
                surface.SetDrawColor(255, 255, 255, loser and 70 or 255)
                -- Crop to fill the tile without stretching (Workshop previews are often square)
                local u0, v0, u1, v1 = 0, 0, 1, 1
                local mw, mh = mat:Width(), mat:Height()
                if mw > 0 and mh > 0 and imgH > 0 then
                    local tileAspect, imgAspect = (pw - 4) / imgH, mw / mh
                    if imgAspect > tileAspect then
                        local cut = (1 - tileAspect / imgAspect) / 2
                        u0, u1 = cut, 1 - cut
                    else
                        local cut = (1 - imgAspect / tileAspect) / 2
                        v0, v1 = cut, 1 - cut
                    end
                end
                surface.DrawTexturedRectUV(2, 2, pw - 4, imgH, u0, v0, u1, v1)
            else
                surface.SetDrawColor(32, 32, 37, 255)
                surface.DrawRect(2, 2, pw - 4, imgH)
                draw.SimpleText(UI.Fit(shortName, "JDM_UI_Big", pw - S(20)), "JDM_UI_Big", pw / 2, imgH / 2, loser and C.TextMuted or C.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            -- Tag in the corner
            local tag, tagBg, tagFg
            if winner then tag, tagBg, tagFg = "NEXT MAP", C.Gold, color_black
            elseif mine then tag, tagBg, tagFg = "YOUR VOTE", C.Accent, color_white end
            if tag then
                surface.SetFont("JDM_UI_Small")
                local tw, th = surface.GetTextSize(tag)
                draw.RoundedBox(4, S(8), S(8), tw + S(12), th + S(6), tagBg)
                draw.SimpleText(tag, "JDM_UI_Small", S(14), S(11), tagFg)
            end

            -- Name, votes and share of the votes
            local by = imgH + S(8)
            draw.SimpleText(UI.Fit(map, "JDM_UI", pw - S(60)), "JDM_UI", S(10), by, loser and C.TextMuted or C.Text)
            draw.SimpleText(count, "JDM_UI_Big", pw - S(10), by - S(2), count > 0 and C.Text or C.TextMuted, TEXT_ALIGN_RIGHT)

            local barY, barW = ph - S(14), pw - S(20)
            draw.RoundedBox(2, S(10), barY, barW, S(4), C.Panel)
            if count > 0 then
                draw.RoundedBox(2, S(10), barY, math.max(math.Round(barW * count / total), S(4)), S(4), winner and C.Gold or C.Accent)
            end
        end
        return tile
    end

    local function BuildFrame()
        local maps = Vote.Maps
        local frameW = math.min(S(960), ScrW() - S(40))
        local contentW = frameW - S(36) - S(16)
        local space = S(10)
        local cols = math.max(math.floor((contentW + space) / (S(200) + space)), 1)
        local tileW = math.floor((contentW - space * (cols - 1)) / cols)
        local tileH = math.Round(tileW * 0.5625) + S(50)
        local rows = math.ceil(#maps / cols)
        local frameH = S(62) + S(12) + rows * (tileH + space) + S(16)

        local frame = UI.Frame("Map vote", frameW, math.min(frameH, ScrH() - S(80)))
        UI.Popup(frame)
        frame.OnCloseButton = function(self) self:SetVisible(false) end

        frame.Think = function(self)
            local total = TotalVotes()
            local votes = total .. (total == 1 and " vote" or " votes")
            if Vote.Winner then
                self:SetSubtitle("Next map: " .. Vote.Winner .. "  ·  " .. votes)
                self:SetHint("")
            else
                self:SetSubtitle("Ends in " .. TimeLeft() .. "s  ·  " .. votes .. "  ·  click a map to vote, click another to change")
                self:SetHint(self:IsMouseInputEnabled() and "F4  BACK TO THE GAME" or "F4  USE THE CURSOR")
            end
        end

        local scroll = UI.Scroll(frame)
        scroll:Dock(FILL)

        local grid = vgui.Create("DIconLayout", scroll)
        grid:Dock(TOP)
        grid:SetSpaceX(space)
        grid:SetSpaceY(space)
        for _, map in ipairs(maps) do
            MapTile(grid, map, tileW, tileH)
        end

        return frame
    end

    function Vote.Open(cursor)
        if !IsValid(Vote.Frame) then Vote.Frame = BuildFrame() end
        Vote.Frame:SetVisible(true)
        Vote.Frame:SetMouseInputEnabled(cursor == true)
    end

    function Vote.Hide()
        if IsValid(Vote.Frame) then Vote.Frame:SetVisible(false) end
    end

    -- Vote state: new vote, late join, end of match, or the result
    net.Receive("JDM_MapVoteStart", function()
        local id = net.ReadUInt(16)
        local maps = net.ReadTable()
        Vote.EndTime = net.ReadDouble()
        local takeCursor = net.ReadBool()
        Vote.Counts = net.ReadTable()
        local winner = net.ReadString()
        Vote.Winner = winner != "" and winner or nil

        local keepCursor = HasCursor()
        if id != Vote.Id then
            -- A new vote: new tiles, no vote yet
            Vote.Id = id
            Vote.MyVote = nil
            Vote.Maps = maps
            if IsValid(Vote.Frame) then Vote.Frame:Remove() end
        end
        Vote.Active = true
        Vote.Open(takeCursor or keepCursor)
    end)

    net.Receive("JDM_MapVoteUpdate", function()
        Vote.Counts = net.ReadTable()
    end)

    -- F4 (gm_showspare2): show the panel with the cursor, or give the cursor back to the game
    hook.Add("PlayerBindPress", "JDM_MapVoteKey", function(ply, bind, pressed)
        if !pressed or bind != "gm_showspare2" or !Vote.Active then return end

        if !IsValid(Vote.Frame) or !Vote.Frame:IsVisible() then
            Vote.Open(true)
        else
            Vote.Frame:SetMouseInputEnabled(!Vote.Frame:IsMouseInputEnabled())
        end
        return true
    end)

    -- Reminder on the HUD while the panel is hidden
    hook.Add("HUDPaint", "JDM_MapVoteHint", function()
        if !Vote.Active or (IsValid(Vote.Frame) and Vote.Frame:IsVisible()) then return end
        local text = Vote.Winner and ("NEXT MAP: " .. string.upper(Vote.Winner)) or ("MAP VOTE  " .. TimeLeft() .. "s")
        UI.DrawHint(S(30), S(30), text, "F4", Vote.Winner and C.Gold or C.Accent)
    end)
end
