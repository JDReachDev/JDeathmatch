-- Big announcements: the match winner and new Annihilators (MOAB), with the player's avatar and an icon.
-- The server sends them with the victory / MOAB sound (cl_sounds.lua calls Announce.Show).

if CLIENT then
    JDM = JDM or {}
    JDM.Client = JDM.Client or {}
    JDM.Client.Announce = JDM.Client.Announce or {}

    local Announce = JDM.Client.Announce

    local GOLD   = Color(255, 200, 0)
    local RED    = Color(220, 40, 40)
    local BG     = Color(15, 15, 18, 225)
    local TEXT   = Color(240, 240, 240)
    local DIM    = Color(170, 170, 175)

    local function Scale() return ScrH() / 1080 end
    local function S(n) return math.Round(n * Scale()) end

    local function CreateFonts()
        local s = Scale()
        surface.CreateFont("JDM_Announce_Label", { font = "Roboto", size = math.Round(19 * s), weight = 800 })
        surface.CreateFont("JDM_Announce_Name",  { font = "Roboto", size = math.Round(44 * s), weight = 800 })
        surface.CreateFont("JDM_Announce_Sub",   { font = "Roboto", size = math.Round(20 * s), weight = 600 })
    end
    CreateFonts()
    hook.Add("OnScreenSizeChanged", "JDM_AnnounceFonts", CreateFonts)

    -- Crown icon (filled polygons, so it stays sharp at any size)
    local function Tri(a, b, c)
        surface.DrawPoly({ { x = a[1], y = a[2] }, { x = b[1], y = b[2] }, { x = c[1], y = c[2] } })
    end

    local function DrawCrown(x, y, size, color)
        local function P(px, py) return { x + px * size, y + py * size } end
        draw.NoTexture()
        surface.SetDrawColor(color)
        Tri(P(0.04, 0.22), P(0.36, 0.64), P(0.04, 0.64))
        Tri(P(0.5, 0.08), P(0.74, 0.64), P(0.26, 0.64))
        Tri(P(0.96, 0.22), P(0.96, 0.64), P(0.64, 0.64))
        surface.DrawRect(x + 0.04 * size, y + 0.63 * size, 0.92 * size, 0.2 * size)

        -- Jewels on the band and on the tips
        local j = math.max(math.Round(size * 0.09), 2)
        surface.SetDrawColor(120, 20, 20)
        for _, px in ipairs({ 0.25, 0.5, 0.75 }) do
            surface.DrawRect(x + px * size - j / 2, y + 0.73 * size - j / 2, j, j)
        end
        surface.SetDrawColor(color)
        for _, tip in ipairs({ { 0.04, 0.22 }, { 0.5, 0.08 }, { 0.96, 0.22 } }) do
            draw.RoundedBox(j / 2, x + tip[1] * size - j / 2, y + tip[2] * size - j / 2, j, j, color)
        end
    end

    local function Remove()
        if IsValid(Announce.Panel) then Announce.Panel:Remove() end
        Announce.Panel = nil
    end

    -- kind: "win" or "moab". data: { ply, name, sub, weapon = { id, name } }
    function Announce.Show(kind, data)
        Remove()

        local isWin = kind == "win"
        local accent = isWin and GOLD or RED
        local label = isWin and "VICTORY" or "ANNIHILATOR"
        local duration = isWin and 25 or 6 -- the win banner leaves earlier when the map vote opens

        local w, h = S(620), S(140)
        local avatarSize = h - S(28)
        local iconSize = isWin and S(86) or S(92)

        local panel = vgui.Create("DPanel")
        panel:ParentToHUD()
        panel:SetSize(w, h)
        panel:SetMouseInputEnabled(false)
        panel:SetKeyboardInputEnabled(false)
        panel.Start = RealTime()
        Announce.Panel = panel

        local baseY = isWin and math.Round(ScrH() * 0.17) or S(96)
        local x = math.Round(ScrW() / 2 - w / 2)
        panel:SetPos(x, baseY)
        panel:SetAlpha(0)

        -- Avatar with an accent frame
        local pad = S(14)
        local frame = S(3)
        if IsValid(data.ply) then
            local avatar = vgui.Create("AvatarImage", panel)
            avatar:SetPos(pad + S(6) + frame, (h - avatarSize) / 2 + frame)
            avatar:SetSize(avatarSize - frame * 2, avatarSize - frame * 2)
            avatar:SetPlayer(data.ply, 184)
            avatar:SetMouseInputEnabled(false)
        end

        local name = data.name or "?"
        local sub = data.sub or ""

        panel.Paint = function(self, pw, ph)
            local t = RealTime() - self.Start

            -- Background, accent bar, and a soft glow of the accent color
            draw.RoundedBox(8, 0, 0, pw, ph, BG)
            draw.RoundedBox(8, 0, 0, pw, ph, Color(accent.r, accent.g, accent.b, 18 + 14 * math.sin(t * 4)))
            draw.RoundedBoxEx(8, 0, 0, S(6), ph, accent, true, false, true, false)

            -- Avatar frame (the AvatarImage child is drawn on top of it)
            local ax, ay = pad + S(6), (ph - avatarSize) / 2
            draw.RoundedBox(4, ax, ay, avatarSize, avatarSize, accent)
            if !IsValid(data.ply) then
                draw.RoundedBox(4, ax + frame, ay + frame, avatarSize - frame * 2, avatarSize - frame * 2, Color(30, 30, 34))
                draw.SimpleText(string.upper(string.sub(name, 1, 1)), "JDM_Announce_Name", ax + avatarSize / 2, ay + avatarSize / 2, TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            -- Icon on the right: crown for the winner, the MOAB weapon for an Annihilator
            local ix, iy = pw - pad - iconSize, (ph - iconSize) / 2
            if isWin then
                local bob = math.Round(math.sin(t * 3) * S(3))
                DrawCrown(ix, iy + bob, iconSize, accent)
            elseif data.weapon and JDM.Client.Weapons and JDM.Client.Weapons.DrawIcon then
                draw.RoundedBox(6, ix - S(2), iy - S(2), iconSize + S(4), iconSize + S(4), accent)
                JDM.Client.Weapons.DrawIcon(data.weapon, ix, iy, iconSize)
            end

            -- Texts
            local tx = ax + avatarSize + S(18)
            local textW = ix - tx - S(12)
            local fit = JDM.UI and JDM.UI.Fit or function(s) return s end
            draw.SimpleText(label, "JDM_Announce_Label", tx, ph / 2 - S(30), accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(fit(name, "JDM_Announce_Name", textW), "JDM_Announce_Name", tx, ph / 2 + S(2), TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(fit(sub, "JDM_Announce_Sub", textW), "JDM_Announce_Sub", tx, ph / 2 + S(36), DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- Slide in from above, fade out at the end (real time: the match end is in slow motion)
        panel.Think = function(self)
            local t = RealTime() - self.Start
            local vote = JDM.Client.MapVote
            if isWin and vote and vote.Active and self.Leave == nil then
                self.Leave = t
            end
            if !isWin and t > duration and self.Leave == nil then self.Leave = t end
            if t > 25 and self.Leave == nil then self.Leave = t end

            local inFrac = math.Clamp(t / 0.35, 0, 1)
            local ease = 1 - (1 - inFrac) ^ 3
            local alpha = ease
            if self.Leave then
                alpha = alpha * math.Clamp(1 - (t - self.Leave) / 0.4, 0, 1)
                if alpha <= 0 then Remove() return end
            end

            self:SetPos(x, baseY - math.Round((1 - ease) * S(40)))
            self:SetAlpha(alpha * 255)
        end
    end

    hook.Add("ShutDown", "JDM_AnnounceCleanup", Remove)
end
