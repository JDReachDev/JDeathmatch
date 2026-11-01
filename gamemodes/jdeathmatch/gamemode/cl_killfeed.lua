-- Kill feed (client side): "Killer [Weapon] Victim" at the top right, replaces the default death notices

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.KillFeed = JDM.Client.KillFeed or {}

    local Feed = JDM.Client.KillFeed
    local LIFETIME, MAX_ENTRIES = 6, 6
    Feed.Entries = {}

    net.Receive("JDM_KillFeed", function()
        local entry = {
            killer = net.ReadEntity(), killerName = net.ReadString(),
            victim = net.ReadEntity(), victimName = net.ReadString(),
            weapon = string.upper(net.ReadString()), headshot = net.ReadBool(),
            time = CurTime(),
        }
        local me = LocalPlayer()
        entry.mine = entry.killer == me or entry.victim == me
        table.insert(Feed.Entries, 1, entry)
        if #Feed.Entries > MAX_ENTRIES then table.remove(Feed.Entries) end
    end)

    -- The default notices are replaced by the feed
    function GM:AddDeathNotice() end

    function GM:DrawDeathNotice()
        local HUD = JDM.Client.HUD
        local colors = HUD.Colors
        local s = HUD.Scale or 1
        local me = LocalPlayer()
        local pad, rowH, gap = math.Round(8 * s), math.Round(28 * s), math.Round(4 * s)
        local right, y = ScrW() - math.Round(20 * s), math.Round(20 * s)

        surface.SetFont("JDM_HUD_Small")
        for i = #Feed.Entries, 1, -1 do
            if CurTime() - Feed.Entries[i].time > LIFETIME then table.remove(Feed.Entries, i) end
        end

        for _, e in ipairs(Feed.Entries) do
            local alpha = math.Clamp((LIFETIME - (CurTime() - e.time)) / 0.5, 0, 1)
            local weaponText = e.weapon .. (e.headshot and "  HEADSHOT" or "")
            local killerW = e.killerName != "" and surface.GetTextSize(e.killerName) or 0
            local weaponW = surface.GetTextSize(weaponText) + pad * 2
            local victimW = surface.GetTextSize(e.victimName)
            local w = pad + (killerW > 0 and killerW + pad or 0) + weaponW + pad + victimW + pad

            local x = right - w
            surface.SetAlphaMultiplier(alpha)
            draw.RoundedBox(4, x, y, w, rowH, e.mine and Color(colors.Accent.r, colors.Accent.g, colors.Accent.b, 90) or colors.Background)

            local cx, cy = x + pad, y + rowH / 2
            if killerW > 0 then
                draw.SimpleText(e.killerName, "JDM_HUD_Small", cx, cy, e.killer == me and colors.Gold or colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                cx = cx + killerW + pad
            end

            draw.RoundedBox(3, cx, y + gap, weaponW, rowH - gap * 2, Color(0, 0, 0, 120))
            draw.SimpleText(weaponText, "JDM_HUD_Small", cx + pad, cy, e.headshot and colors.Gold or colors.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            cx = cx + weaponW + pad

            draw.SimpleText(e.victimName, "JDM_HUD_Small", cx, cy, e.victim == me and colors.Gold or colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetAlphaMultiplier(1)

            y = y + rowH + gap
        end
    end
end
