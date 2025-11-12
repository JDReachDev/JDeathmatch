-- Network strings and client-server communication

if SERVER then
    -- Network strings for weapons
    util.AddNetworkString("SendWeaponSlots")
    util.AddNetworkString("SetPlayerWeapons")
    
    -- Network string for MOAB sound
    util.AddNetworkString("SendMoabSound")
    
    -- Network string for MOAB status sync
    util.AddNetworkString("SendMoabStatus")
    
    -- Network strings for map voting
    util.AddNetworkString("OpenMapVoteMenu")
    util.AddNetworkString("SendMapList")
    util.AddNetworkString("CastVote")
end

