-- Settings for optional addons from the example collection.
-- Every block checks that the addon is installed, so nothing happens without it.

-- Battlefield 6 Hitmarkers (workshop 3550189961): turn off the dynamic ("real") position,
-- so the hit markers stay on the crosshair.
local function SetupBF6Hitmarkers()
    if SERVER then
        if !ConVarExists("bf6_override_hitmarker_dynamic") then return end
        -- The override_* values only apply when bf6_override_enabled is on.
        -- The other override_* defaults match the client defaults, so only the position changes.
        RunConsoleCommand("bf6_override_enabled", "1")
        RunConsoleCommand("bf6_override_hitmarker_dynamic", "0")
    else
        if !ConVarExists("bf6_hitmarker_dynamic") then return end
        RunConsoleCommand("bf6_hitmarker_dynamic", "0")
    end
end

-- Addon autorun files are loaded before the gamemode, but wait for the world to be sure.
hook.Add("InitPostEntity", "JDM_AddonSettings", SetupBF6Hitmarkers)
