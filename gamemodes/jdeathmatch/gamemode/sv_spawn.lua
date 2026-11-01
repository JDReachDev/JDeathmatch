-- Spawn points management

if SERVER then
    JDM = JDM or {}
    JDM.Spawn = JDM.Spawn or {}

    -- Spawn points table
    JDM.Spawn.Points = {}

    -- Player hull, used to check if a spawn point is occupied
    local hullMins = Vector(-16, -16, 0)
    local hullMaxs = Vector(16, 16, 72)

    -- Load all available spawn points
    function JDM.Spawn.LoadSpawnPoints()
        JDM.Spawn.Points = {}

        -- Find all spawn point types
        local spawnClasses = {
            "info_player_start",
            "info_player_deathmatch",
            "info_player_terrorist",
            "info_player_counterterrorist",
            "info_player_teamspawn",
            "info_player_combine",
            "info_player_rebel"
        }

        local seen = {}
        for _, class in ipairs(spawnClasses) do
            for _, spawn in ipairs(ents.FindByClass(class)) do
                if !seen[spawn] then
                    seen[spawn] = true
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

    -- Players that are actually in the arena (alive and not spectating)
    local function GetEnemies(ply)
        local enemies = {}
        for _, other in ipairs(player.GetAll()) do
            if other != ply and other:Alive() and other:GetObserverMode() == OBS_MODE_NONE then
                table.insert(enemies, other)
            end
        end
        return enemies
    end

    local function IsOccupied(spawn, ply)
        local pos = spawn:GetPos()
        for _, ent in ipairs(ents.FindInBox(pos + hullMins, pos + hullMaxs)) do
            if ent:IsPlayer() and ent != ply and ent:Alive() then
                return true
            end
        end
        return false
    end

    -- Find the spawn point whose nearest enemy is the farthest away
    function JDM.Spawn.GetFarthestSpawn(ply)
        -- Map cleanups recreate the spawn entities, so reload if any is gone
        local needsReload = #JDM.Spawn.Points == 0
        for _, spawn in ipairs(JDM.Spawn.Points) do
            if !IsValid(spawn) then
                needsReload = true
                break
            end
        end
        if needsReload then JDM.Spawn.LoadSpawnPoints() end

        if #JDM.Spawn.Points == 0 then return nil end

        local free = {}
        for _, spawn in ipairs(JDM.Spawn.Points) do
            if !IsOccupied(spawn, ply) then
                table.insert(free, spawn)
            end
        end
        if #free == 0 then free = JDM.Spawn.Points end

        local enemies = GetEnemies(ply)

        -- Nobody to run away from: spread players randomly
        if #enemies == 0 then
            return free[math.random(#free)]
        end

        local best = {}
        local bestDistance = -1

        for _, spawn in ipairs(free) do
            local spawnPos = spawn:GetPos()
            local nearest = math.huge

            for _, enemy in ipairs(enemies) do
                nearest = math.min(nearest, spawnPos:DistToSqr(enemy:GetPos()))
            end

            if nearest > bestDistance then
                bestDistance = nearest
                best = { spawn }
            elseif nearest == bestDistance then
                table.insert(best, spawn)
            end
        end

        return best[math.random(#best)]
    end

    -- Engine picks the spawn here, so the player never appears at another point first
    function GM:PlayerSelectSpawn(ply, transition)
        if GetConVar("jdm_farspawn"):GetBool() then
            local spawn = JDM.Spawn.GetFarthestSpawn(ply)
            if IsValid(spawn) then return spawn end
        end

        return self.BaseClass.PlayerSelectSpawn(self, ply, transition)
    end

    -- Hook to load spawn points
    hook.Add("InitPostEntity", "JDM_LoadSpawnPoints", function()
        JDM.Spawn.LoadSpawnPoints()
    end)
end

