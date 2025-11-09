-- Map voting system

if SERVER then
    JDM = JDM or {}
    JDM.MapVote = JDM.MapVote or {}
    
    -- Data structures
    JDM.MapVote.Votes = {}
    JDM.MapVote.AvailableMaps = {}
    
    -- Load available maps
    function JDM.MapVote.LoadAvailableMaps()
        JDM.MapVote.AvailableMaps = {}
        local allMaps = file.Find("maps/*.bsp", "GAME")
        
        for _, map in ipairs(allMaps) do
            local mapName = string.StripExtension(map)
            if string.StartWith(mapName, "dm_") or string.StartWith(mapName, "ttt_") then
                table.insert(JDM.MapVote.AvailableMaps, mapName)
            end
        end
        
        print("[INFO] Available maps for voting:", table.concat(JDM.MapVote.AvailableMaps, ", "))
    end
    
    -- Determine winning map and change map
    function JDM.MapVote.ChangeToWinningMap()
        local voteCount = {}
        
        -- Count votes
        for _, map in pairs(JDM.MapVote.Votes) do
            voteCount[map] = (voteCount[map] or 0) + 1
        end
        
        -- Find map with most votes
        local winningMap = nil
        local maxVotes = 0
        for map, votes in pairs(voteCount) do
            if votes > maxVotes then
                maxVotes = votes
                winningMap = map
            end
        end
        
        if winningMap then
            PrintMessage(HUD_PRINTCENTER, "Winning map: " .. winningMap .. "! Changing map in 5 seconds.")
            
            timer.Simple(5, function()
                game.ConsoleCommand("changelevel " .. winningMap .. "\n")
            end)
        else
            PrintMessage(HUD_PRINTTALK, "No map received votes! Random map selection.")
            
            -- Random map selection
            if #JDM.MapVote.AvailableMaps > 0 then
                local randomMap = JDM.MapVote.AvailableMaps[math.random(1, #JDM.MapVote.AvailableMaps)]
                
                timer.Simple(5, function()
                    game.ConsoleCommand("changelevel " .. randomMap .. "\n")
                end)
            else
                PrintMessage(HUD_PRINTTALK, "No maps available!")
            end
        end
        
        -- Reset votes for next voting
        JDM.MapVote.Votes = {}
    end
    
    -- Receive player vote
    net.Receive("CastVote", function(len, ply)
        if !IsValid(ply) then return end
        
        local mapChoice = net.ReadString()
        
        -- Validate map
        if !table.HasValue(JDM.MapVote.AvailableMaps, mapChoice) then
            ply:ChatPrint("Invalid map!")
            return
        end
        
        -- Save vote
        JDM.MapVote.Votes[ply:SteamID()] = mapChoice
        ply:ChatPrint("You voted for: " .. mapChoice)
    end)
    
    -- Load maps on startup
    JDM.MapVote.LoadAvailableMaps()
end
