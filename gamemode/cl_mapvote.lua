-- Client-side map voting UI

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.MapVote = JDM.Client.MapVote or {}
    
    JDM.Client.MapVote.AvailableMaps = {}
    
    -- Open map voting menu
    function JDM.Client.MapVote.OpenMenu()
        local frameMapVote = vgui.Create("DFrame")
        frameMapVote:SetTitle("Map Voting")
        frameMapVote:SetSize(300, 200)
        frameMapVote:Center()
        frameMapVote:ShowCloseButton(false)
        frameMapVote:MakePopup()
        
        local listView = vgui.Create("DListView", frameMapVote)
        listView:Dock(FILL)
        listView:AddColumn("Available maps")
        
        for _, map in ipairs(JDM.Client.MapVote.AvailableMaps) do
            listView:AddLine(map)
        end
        
        listView.OnRowSelected = function(_, _, row)
            local selectedMap = row:GetColumnText(1)
            net.Start("CastVote")
            net.WriteString(selectedMap)
            net.SendToServer()
            frameMapVote:Close()
        end
    end
    
    -- Receive map list from server
    net.Receive("SendMapList", function()
        JDM.Client.MapVote.AvailableMaps = net.ReadTable()
        JDM.Client.MapVote.OpenMenu()
    end)
end
