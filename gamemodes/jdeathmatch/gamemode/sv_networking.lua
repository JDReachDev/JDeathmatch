-- Network strings and client-server communication

if SERVER then
    -- Network strings for weapons
    util.AddNetworkString("JDM_SendWeaponSlots")
    util.AddNetworkString("JDM_SetPlayerWeapons")
    util.AddNetworkString("JDM_RequestWeaponSlots")
    
    -- Network string for MOAB sound
    util.AddNetworkString("JDM_SendMoabSound")
    
    -- Network string for victory sound
    util.AddNetworkString("JDM_SendVictorySound")
    
    -- Network string for MOAB status sync
    util.AddNetworkString("JDM_SendMoabStatus")
    
    -- Network strings for map voting
    util.AddNetworkString("JDM_SendMapList")
    util.AddNetworkString("JDM_CastVote")
end

