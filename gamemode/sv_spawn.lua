-- Spawn points management

if SERVER then
    JDM = JDM or {}
    JDM.Spawn = JDM.Spawn or {}
    
    -- Spawn points table
    JDM.Spawn.Points = {}
    
    -- Load all available spawn points
    function JDM.Spawn.LoadSpawnPoints()
        JDM.Spawn.Points = {}
        
        -- Find all spawn point types
        local spawnClasses = {
            "info_player_start",
            "info_player_deathmatch",
            "info_player_terrorist",
            "info_player_counterterrorist",
            "info_player_teamspawn"
        }
        
        for _, class in ipairs(spawnClasses) do
            local foundSpawns = ents.FindByClass(class)
            for _, spawn in ipairs(foundSpawns) do
                -- Avoid duplicates
                local isDuplicate = false
                for _, existing in ipairs(JDM.Spawn.Points) do
                    if existing == spawn then
                        isDuplicate = true
                        break
                    end
                end
                
                if !isDuplicate then
                    table.insert(JDM.Spawn.Points, spawn)
                end
            end
        end
        
        if #JDM.Spawn.Points == 0 then
            print("[WARN] No spawn points found on the map!")
        else
            print("[INFO] Spawn points loaded:", #JDM.Spawn.Points)
        end
    end
    
    -- Find the spawn point farthest from other players
    function JDM.Spawn.GetFarthestSpawn(ply)
        if #JDM.Spawn.Points == 0 then
            print("[WARN] No spawn points found! Using random spawn.")
            return nil
        end
        
        local farthestSpawn = nil
        local maxDistance = -1
        
        for _, spawn in ipairs(JDM.Spawn.Points) do
            if !IsValid(spawn) then continue end
            
            local totalDistance = 0
            local spawnPos = spawn:GetPos()
            
            for _, otherPly in ipairs(player.GetAll()) do
                if IsValid(otherPly) and otherPly:Alive() and otherPly ~= ply then
                    totalDistance = totalDistance + spawnPos:DistToSqr(otherPly:GetPos())
                end
            end
            
            if totalDistance > maxDistance then
                maxDistance = totalDistance
                farthestSpawn = spawn
            end
        end
        
        -- If no valid spawn is found, choose a random one
        if !farthestSpawn then
            print("[WARN] No far spawn found! Random selection.")
            if #JDM.Spawn.Points > 0 then
                farthestSpawn = JDM.Spawn.Points[math.random(#JDM.Spawn.Points)]
            end
        end
        
        return farthestSpawn
    end
    
    -- Hook to load spawn points
    hook.Add("InitPostEntity", "JDM_LoadSpawnPoints", function()
        JDM.Spawn.LoadSpawnPoints()
    end)
end

