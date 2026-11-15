-- Map voting system: at the end of the match, or any time an admin runs "jdm_mapvote [seconds]"
-- (the match goes on while people vote, F4 on the client)

if SERVER then
    JDM = JDM or {}
    JDM.MapVote = JDM.MapVote or {}

    local MapVote = JDM.MapVote

    MapVote.Votes = {}
    MapVote.AvailableMaps = {}
    MapVote.Active = false
    MapVote.EndTime = 0
    MapVote.Winner = nil
    MapVote.Id = MapVote.Id or 0
    MapVote.LastVoteAt = {}

    -- Load available maps
    function MapVote.LoadAvailableMaps()
        MapVote.AvailableMaps = {}
        local allMaps = file.Find("maps/*.bsp", "GAME")

        for _, map in ipairs(allMaps) do
            local mapName = string.StripExtension(map)
            if string.StartWith(mapName, "dm_") or string.StartWith(mapName, "ttt_") then
                table.insert(MapVote.AvailableMaps, mapName)
            end
        end

        -- No dm_/ttt_ maps installed: offer the current map, so the match can still restart
        if #MapVote.AvailableMaps == 0 then
            table.insert(MapVote.AvailableMaps, game.GetMap())
        end

        print("[INFO] Available maps for voting:", table.concat(MapVote.AvailableMaps, ", "))
    end

    function MapVote.GetCounts()
        local counts = {}
        for _, map in pairs(MapVote.Votes) do
            counts[map] = (counts[map] or 0) + 1
        end
        return counts
    end

    -- Whole vote state to one player / a list (target), or everyone (nil)
    function MapVote.SendState(target, takeCursor)
        net.Start("JDM_MapVoteStart")
        net.WriteUInt(MapVote.Id, 16)
        net.WriteTable(MapVote.AvailableMaps)
        net.WriteDouble(MapVote.EndTime)
        net.WriteBool(takeCursor == true)
        net.WriteTable(MapVote.GetCounts())
        net.WriteString(MapVote.Winner or "")
        if target then net.Send(target) else net.Broadcast() end
    end

    function MapVote.BroadcastCounts()
        net.Start("JDM_MapVoteUpdate")
        net.WriteTable(MapVote.GetCounts())
        net.Broadcast()
    end

    -- Start a vote. endOfMatch gives everyone the cursor (players are frozen).
    -- A vote already running keeps its own timer.
    function MapVote.Start(duration, endOfMatch)
        if MapVote.Active then
            if endOfMatch and !MapVote.Winner then MapVote.SendState(nil, true) end
            return false
        end

        MapVote.Active = true
        MapVote.Winner = nil
        MapVote.Votes = {}
        MapVote.Id = (MapVote.Id + 1) % 65536
        MapVote.EndTime = CurTime() + duration
        MapVote.SendState(nil, endOfMatch)

        timer.Create("JDM_MapVote_End", duration, 1, MapVote.ChangeToWinningMap)
        return true
    end

    -- Determine winning map (ties: random among the best) and change map
    function MapVote.ChangeToWinningMap()
        if MapVote.Winner then return end
        timer.Remove("JDM_MapVote_End")

        local best, top = 0, {}
        for map, votes in pairs(MapVote.GetCounts()) do
            if votes > best then
                best, top = votes, { map }
            elseif votes == best then
                table.insert(top, map)
            end
        end

        local winner
        if #top > 0 then
            winner = top[math.random(#top)]
            PrintMessage(HUD_PRINTTALK, "[JDM] Next map: " .. winner .. " (" .. best .. (best == 1 and " vote" or " votes") .. "). Changing map in 5 seconds.")
        elseif #MapVote.AvailableMaps > 0 then
            winner = MapVote.AvailableMaps[math.random(#MapVote.AvailableMaps)]
            PrintMessage(HUD_PRINTTALK, "[JDM] No votes: random map " .. winner .. ". Changing map in 5 seconds.")
        else
            PrintMessage(HUD_PRINTTALK, "[JDM] No maps available!")
            return
        end

        MapVote.Active = true
        MapVote.Winner = winner
        MapVote.EndTime = CurTime()
        MapVote.SendState(nil, false)

        timer.Simple(5, function()
            game.ConsoleCommand("changelevel " .. winner .. "\n")
        end)
    end

    -- Receive player vote (changing it is allowed until the end)
    net.Receive("JDM_CastVote", function(len, ply)
        if !IsValid(ply) or !MapVote.Active or MapVote.Winner then return end

        local key = JDM.PlayerKey(ply)
        if CurTime() - (MapVote.LastVoteAt[key] or 0) < 0.1 then return end
        MapVote.LastVoteAt[key] = CurTime()

        local mapChoice = net.ReadString()
        if !table.HasValue(MapVote.AvailableMaps, mapChoice) then return end

        MapVote.Votes[key] = mapChoice
        MapVote.BroadcastCounts()
    end)

    -- A player who leaves takes the vote with them (removed in sv_player.lua)
    hook.Add("PlayerDisconnected", "JDM_MapVoteDisconnect", function(ply)
        MapVote.LastVoteAt[JDM.PlayerKey(ply)] = nil
        timer.Simple(0, function()
            if MapVote.Active and !MapVote.Winner then MapVote.BroadcastCounts() end
        end)
    end)

    -- Admins: start a vote while playing
    concommand.Add("jdm_mapvote", function(ply, cmd, args)
        if IsValid(ply) and !ply:IsAdmin() then
            ply:ChatPrint("Only admins can start a map vote.")
            return
        end

        local duration = math.Clamp(tonumber(args[1]) or 30, 10, 300)
        if MapVote.Start(duration, false) then
            PrintMessage(HUD_PRINTTALK, "[JDM] Map vote started (" .. duration .. "s): press F4 to vote.")
        elseif IsValid(ply) then
            ply:ChatPrint("A map vote is already running.")
        end
    end)

    -- Load maps on startup
    MapVote.LoadAvailableMaps()
end
