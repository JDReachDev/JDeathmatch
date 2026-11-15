-- JDM UI kit: every menu uses the HUD look (dark panels, red accent, Roboto).
-- Menus opened with UI.Popup leave the keyboard to the game, so you can keep moving while they are
-- open: the keyboard is only taken while a text field is focused.

if CLIENT then
    JDM = JDM or {}
    JDM.UI = JDM.UI or {}

    local UI = JDM.UI

    -- Same palette as the HUD (cl_hud.lua)
    UI.Colors = {
        Background  = Color(15, 15, 18, 242),
        Header      = Color(255, 255, 255, 6),
        Card        = Color(22, 22, 26, 255),
        Panel       = Color(255, 255, 255, 10),
        Hover       = Color(255, 255, 255, 24),
        Input       = Color(8, 8, 10, 230),
        Line        = Color(255, 255, 255, 22),
        Accent      = Color(220, 40, 40),
        AccentHover = Color(240, 66, 66),
        AccentDark  = Color(150, 25, 25),
        AccentSoft  = Color(220, 40, 40, 55),
        Text        = Color(240, 240, 240),
        TextDim     = Color(160, 160, 165),
        TextMuted   = Color(105, 105, 110),
        Gold        = Color(255, 200, 0),
        Green       = Color(90, 200, 110),
    }
    local C = UI.Colors

    -- Sizes are designed at 1080p
    function UI.S(n)
        return math.Round(n * (UI.Scale or 1))
    end
    local S = UI.S

    local function CreateFonts()
        UI.Scale = math.max(ScrH() / 1080, 0.75)
        local s = UI.Scale
        surface.CreateFont("JDM_UI_Title", { font = "Roboto", size = math.Round(28 * s), weight = 800 })
        surface.CreateFont("JDM_UI_Big",   { font = "Roboto", size = math.Round(22 * s), weight = 700 })
        surface.CreateFont("JDM_UI",       { font = "Roboto", size = math.Round(17 * s), weight = 600 })
        surface.CreateFont("JDM_UI_Small", { font = "Roboto", size = math.Round(14 * s), weight = 600 })
    end
    CreateFonts()
    hook.Add("OnScreenSizeChanged", "JDM_UIFonts", CreateFonts)

    function UI.LerpColor(t, a, b)
        return Color(Lerp(t, a.r, b.r), Lerp(t, a.g, b.g), Lerp(t, a.b, b.b), Lerp(t, a.a, b.a))
    end
    local LerpColor = UI.LerpColor

    -- Smooth 0..1 hover value kept on the panel
    function UI.Hover(pnl, on)
        pnl.JDM_Hover = math.Approach(pnl.JDM_Hover or 0, on and 1 or 0, FrameTime() * 8)
        return pnl.JDM_Hover
    end
    local Hover = UI.Hover

    -- Cut the text with "..." so it fits in maxW
    function UI.Fit(text, font, maxW)
        surface.SetFont(font)
        if surface.GetTextSize(text) <= maxW then return text end
        while #text > 1 and surface.GetTextSize(text .. "...") > maxW do
            text = string.sub(text, 1, -2)
        end
        return text .. "..."
    end

    ---------------------------------------------------------------------------
    -- Keyboard: popups only take it while one of their text fields is focused
    ---------------------------------------------------------------------------

    local function GetRoot(pnl)
        local world = vgui.GetWorldPanel()
        while IsValid(pnl) and IsValid(pnl:GetParent()) and pnl:GetParent() != world do
            pnl = pnl:GetParent()
        end
        return pnl
    end

    hook.Add("OnTextEntryGetFocus", "JDM_UI_Keyboard", function(entry)
        local root = GetRoot(entry)
        if IsValid(root) and root.JDM_Passthrough then root:SetKeyboardInputEnabled(true) end
    end)

    hook.Add("OnTextEntryLoseFocus", "JDM_UI_Keyboard", function(entry)
        local root = GetRoot(entry)
        if IsValid(root) and root.JDM_Passthrough then root:SetKeyboardInputEnabled(false) end
    end)

    -- Mouse for the menu, keyboard for the game (WASD, Q, F3, F4... keep working)
    function UI.Popup(frame)
        frame:MakePopup()
        frame:SetKeyboardInputEnabled(false)
        frame.JDM_Passthrough = true
    end

    ---------------------------------------------------------------------------
    -- Frame
    ---------------------------------------------------------------------------

    function UI.Frame(title, w, h)
        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:ShowCloseButton(false)
        frame:SetSize(math.min(w, ScrW() - S(40)), math.min(h, ScrH() - S(40)))
        frame:Center()

        frame.JDM_Title = string.upper(title)
        frame.JDM_HeaderH = S(62)
        local pad = S(16)
        frame:DockPadding(pad + S(4), frame.JDM_HeaderH + S(12), pad, pad)

        function frame:SetSubtitle(text) self.JDM_Subtitle = text end
        function frame:SetHint(text) self.JDM_Hint = text end

        frame.Paint = function(self, pw, ph)
            local hh = self.JDM_HeaderH
            draw.RoundedBox(8, 0, 0, pw, ph, C.Background)
            draw.RoundedBoxEx(8, 0, 0, pw, hh, C.Header, true, true, false, false)
            surface.SetDrawColor(C.Line)
            surface.DrawRect(0, hh - 1, pw, 1)
            draw.RoundedBoxEx(8, 0, 0, S(4), ph, C.Accent, true, false, true, false)

            local tx = S(22)
            if self.JDM_Subtitle and self.JDM_Subtitle != "" then
                draw.SimpleText(self.JDM_Title, "JDM_UI_Title", tx, hh / 2 + S(3), C.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
                draw.SimpleText(self.JDM_Subtitle, "JDM_UI_Small", tx + S(1), hh / 2 + S(4), C.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            else
                draw.SimpleText(self.JDM_Title, "JDM_UI_Title", tx, hh / 2, C.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            if self.JDM_Hint then
                draw.SimpleText(self.JDM_Hint, "JDM_UI_Small", pw - hh - S(2), hh / 2, C.TextMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        local close = vgui.Create("DButton", frame)
        close:SetText("")
        local cs = S(32)
        close:SetSize(cs, cs)
        close.Paint = function(self, pw, ph)
            local hov = Hover(self, self:IsHovered())
            draw.RoundedBox(4, 0, 0, pw, ph, LerpColor(hov, C.Panel, C.Accent))
            local m = math.Round(pw * 0.34)
            surface.SetDrawColor(C.Text)
            for o = 0, 1 do
                surface.DrawLine(m + o, m, pw - m + o, ph - m)
                surface.DrawLine(pw - m + o, m, m + o, ph - m)
            end
        end
        close.DoClick = function() frame:OnCloseButton() end
        frame.JDM_CloseButton = close

        -- Default: remove the frame. Menus that are only hidden override it.
        function frame:OnCloseButton() self:Remove() end

        local baseLayout = frame.PerformLayout
        frame.PerformLayout = function(self, pw, ph)
            baseLayout(self, pw, ph)
            local m = math.Round((self.JDM_HeaderH - cs) / 2)
            close:SetPos(pw - cs - m, m)
        end

        return frame
    end

    ---------------------------------------------------------------------------
    -- Controls
    ---------------------------------------------------------------------------

    function UI.Label(parent, text, font, color)
        local label = vgui.Create("DLabel", parent)
        label:SetFont(font or "JDM_UI")
        label:SetTextColor(color or C.Text)
        label:SetText(text)
        label:SizeToContents()
        return label
    end

    -- Small uppercase heading, docked on top
    function UI.Section(parent, text)
        local label = UI.Label(parent, string.upper(text), "JDM_UI_Small", C.TextDim)
        label:Dock(TOP)
        label:DockMargin(0, S(10), 0, S(4))
        return label
    end

    -- Plain background box
    function UI.Box(parent)
        local box = vgui.Create("DPanel", parent)
        box.Paint = function(self, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, C.Panel) end
        return box
    end

    -- style: "primary" (red), "danger" or "ghost" (default)
    function UI.Button(parent, text, style, onClick)
        local button = vgui.Create("DButton", parent)
        button:SetText("")
        button:SetTall(S(36))
        button.JDM_Text = text
        button.JDM_Style = style or "ghost"
        button.DoClick = onClick

        function button:SetLabel(label) self.JDM_Text = label end

        button.Paint = function(self, pw, ph)
            local enabled = self:IsEnabled()
            local hov = Hover(self, enabled and self:IsHovered())
            local bg, fg

            if !enabled then
                bg, fg = C.Panel, C.TextMuted
            elseif self.JDM_Style == "primary" then
                bg, fg = LerpColor(hov, C.Accent, C.AccentHover), color_white
            elseif self.JDM_Style == "danger" then
                bg, fg = LerpColor(hov, C.Panel, C.AccentDark), LerpColor(hov, Color(255, 110, 110), color_white)
            else
                bg, fg = LerpColor(hov, C.Panel, C.Hover), C.Text
            end
            if enabled and self:IsDown() then bg = LerpColor(0.4, bg, color_black) end

            draw.RoundedBox(4, 0, 0, pw, ph, bg)
            draw.SimpleText(string.upper(self.JDM_Text), "JDM_UI", pw / 2, ph / 2, fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return button
    end

    function UI.TextEntry(parent, placeholder)
        local entry = vgui.Create("DTextEntry", parent)
        entry:SetFont("JDM_UI")
        entry:SetTall(S(34))
        entry:SetUpdateOnType(true)
        entry.JDM_Placeholder = placeholder

        entry.Paint = function(self, pw, ph)
            local focus = self:HasFocus()
            draw.RoundedBox(4, 0, 0, pw, ph, focus and C.Accent or C.Line)
            draw.RoundedBox(4, 1, 1, pw - 2, ph - 2, self:IsEnabled() and C.Input or C.Panel)

            if self:GetText() == "" and self.JDM_Placeholder and !focus then
                draw.SimpleText(self.JDM_Placeholder, "JDM_UI", 4, ph / 2, C.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            self:DrawTextEntryText(self:IsEnabled() and C.Text or C.TextMuted, C.AccentSoft, C.Text)
        end

        -- Enter gives the keyboard back to the game
        entry.OnEnter = function(self) self:KillFocus() end
        return entry
    end

    -- Number field: onChange(number) with the value clamped to [min, max]
    function UI.NumberEntry(parent, min, max, decimals, value, onChange)
        local entry = UI.TextEntry(parent)
        entry:SetNumeric(true)

        local function Clean(v)
            local n = tonumber(v)
            if !n then return nil end
            n = math.Clamp(n, min, max)
            return decimals > 0 and math.Round(n, decimals) or math.floor(n)
        end

        function entry:SetNumber(n) self:SetText(tostring(Clean(n) or min)) end
        function entry:GetNumber() return Clean(self:GetText()) or min end
        entry:SetNumber(value)

        entry.OnChange = function(self)
            local n = Clean(self:GetText())
            if n and onChange then onChange(n) end
        end

        -- Show the clamped value once done typing
        entry.OnLoseFocus = function(self)
            self:SetText(tostring(self:GetNumber()))
            vgui.GetControlTable("DTextEntry").OnLoseFocus(self)
        end
        return entry
    end

    -- On/off switch
    function UI.Toggle(parent, checked, onChange)
        local toggle = vgui.Create("DButton", parent)
        toggle:SetText("")
        toggle:SetSize(S(46), S(24))
        toggle.JDM_On = checked == true
        toggle.JDM_Anim = toggle.JDM_On and 1 or 0

        toggle.DoClick = function(self)
            self.JDM_On = !self.JDM_On
            if onChange then onChange(self.JDM_On) end
        end

        toggle.Paint = function(self, pw, ph)
            self.JDM_Anim = math.Approach(self.JDM_Anim, self.JDM_On and 1 or 0, FrameTime() * 8)
            draw.RoundedBox(ph / 2, 0, 0, pw, ph, LerpColor(self.JDM_Anim, C.Hover, C.Accent))
            local thumb = ph - S(6)
            draw.RoundedBox(thumb / 2, S(3) + (pw - thumb - S(6)) * self.JDM_Anim, S(3), thumb, thumb, color_white)
        end
        return toggle
    end

    -- Dark dropdown menus (combo boxes)
    function UI.StyleMenu(menu)
        menu.Paint = function(self, pw, ph)
            draw.RoundedBox(4, 0, 0, pw, ph, Color(26, 26, 30, 252))
        end
        for _, option in ipairs(menu:GetCanvas():GetChildren()) do
            if option.SetFont then option:SetFont("JDM_UI") end
            option.UpdateColours = function(self) self:SetTextStyleColor(C.Text) end
            option.Paint = function(self, pw, ph)
                if self:IsHovered() then draw.RoundedBox(0, 0, 0, pw, ph, C.Accent) end
            end
            option:InvalidateLayout(true)
        end
        menu:InvalidateLayout(true)
    end

    function UI.Combo(parent)
        local box = vgui.Create("DComboBox", parent)
        box:SetFont("JDM_UI")
        box:SetTall(S(34))
        box:SetTextInset(S(8), 0)
        box.UpdateColours = function(self) self:SetTextStyleColor(self:IsEnabled() and C.Text or C.TextMuted) end

        box.Paint = function(self, pw, ph)
            local hov = Hover(self, self:IsEnabled() and (self:IsHovered() or self:IsMenuOpen()))
            draw.RoundedBox(4, 0, 0, pw, ph, LerpColor(hov, C.Line, C.Accent))
            draw.RoundedBox(4, 1, 1, pw - 2, ph - 2, self:IsEnabled() and C.Input or C.Panel)
        end

        box.DropButton.Paint = function(self, pw, ph)
            local cx, cy, r = pw / 2, ph / 2, S(4)
            draw.NoTexture()
            surface.SetDrawColor(C.TextDim)
            surface.DrawPoly({
                { x = cx - r, y = cy - r / 2 },
                { x = cx + r, y = cy - r / 2 },
                { x = cx, y = cy + r / 2 + 1 },
            })
        end

        box.OnMenuOpened = function(self, menu) UI.StyleMenu(menu) end
        return box
    end

    function UI.Scroll(parent)
        local scroll = vgui.Create("DScrollPanel", parent)
        local bar = scroll:GetVBar()
        bar:SetWide(S(6))
        bar:SetHideButtons(true)
        bar.Paint = function(self, pw, ph) draw.RoundedBox(3, 0, 0, pw, ph, C.Panel) end
        bar.btnGrip.Paint = function(self, pw, ph)
            local hov = Hover(self, self:IsHovered() or self.Depressed)
            draw.RoundedBox(3, 0, 0, pw, ph, LerpColor(hov, Color(255, 255, 255, 60), C.Accent))
        end
        scroll:GetCanvas():DockPadding(0, 0, S(10), 0)
        return scroll
    end

    -- Clickable list row; paintContent(row, w, h) draws its content. row.JDM_Selected highlights it.
    function UI.Row(parent, height, paintContent)
        local row = vgui.Create("DButton", parent)
        row:SetText("")
        row:Dock(TOP)
        row:SetTall(height or S(34))
        row:DockMargin(0, 0, 0, S(3))
        row.Paint = function(self, pw, ph)
            local hov = Hover(self, self:IsHovered())
            if self.JDM_Selected then
                draw.RoundedBox(4, 0, 0, pw, ph, C.AccentSoft)
                draw.RoundedBoxEx(4, 0, 0, S(3), ph, C.Accent, true, false, true, false)
            else
                draw.RoundedBox(4, 0, 0, pw, ph, LerpColor(hov, C.Panel, C.Hover))
            end
            if paintContent then paintContent(self, pw, ph) end
        end
        return row
    end

    -- Tab bar: tabs:AddTab(name) returns the panel of the tab
    function UI.Tabs(parent)
        local tabs = vgui.Create("DPanel", parent)
        tabs:SetPaintBackground(false)
        tabs.Items = {}

        local bar = vgui.Create("DPanel", tabs)
        bar:Dock(TOP)
        bar:SetTall(S(38))
        bar:DockMargin(0, 0, 0, S(12))
        bar.Paint = function(self, pw, ph)
            surface.SetDrawColor(C.Line)
            surface.DrawRect(0, ph - 1, pw, 1)
        end

        function tabs:Select(item)
            for _, other in ipairs(self.Items) do other.panel:SetVisible(other == item) end
            self.Active = item
            self:InvalidateLayout()
        end

        function tabs:AddTab(name)
            local label = string.upper(name)
            local panel = vgui.Create("DPanel", self)
            panel:Dock(FILL)
            panel:SetPaintBackground(false)
            panel:SetVisible(false)

            local item = { panel = panel }
            local button = vgui.Create("DButton", bar)
            button:SetText("")
            button:Dock(LEFT)
            button:DockMargin(0, 0, S(4), 0)
            surface.SetFont("JDM_UI")
            button:SetWide(surface.GetTextSize(label) + S(32))
            button.Paint = function(btn, pw, ph)
                local active = self.Active == item
                local hov = Hover(btn, btn:IsHovered() or active)
                draw.SimpleText(label, "JDM_UI", pw / 2, ph / 2 - S(1), LerpColor(hov, C.TextDim, C.Text), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                if active then
                    surface.SetDrawColor(C.Accent)
                    surface.DrawRect(0, ph - S(3), pw, S(3))
                end
            end
            button.DoClick = function() self:Select(item) end

            table.insert(self.Items, item)
            if !self.Active then self:Select(item) end
            return panel
        end

        return tabs
    end

    -- Small box on the HUD with a key hint, e.g. "MAP VOTE 12s   [F4]"
    function UI.DrawHint(x, y, text, key, accent)
        surface.SetFont("JDM_UI")
        local tw, th = surface.GetTextSize(text)
        surface.SetFont("JDM_UI_Small")
        local kw = surface.GetTextSize(key)
        local pad = S(10)
        local h = th + S(14)
        local w = pad + tw + pad + kw + S(12) + pad

        draw.RoundedBox(6, x, y, w, h, Color(15, 15, 18, 210))
        draw.RoundedBoxEx(6, x, y, S(4), h, accent or C.Accent, true, false, true, false)
        draw.SimpleText(text, "JDM_UI", x + pad + S(2), y + h / 2, C.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local kx = x + pad + tw + pad
        draw.RoundedBox(4, kx, y + S(6), kw + S(12), h - S(12), C.Hover)
        draw.SimpleText(key, "JDM_UI_Small", kx + S(6), y + h / 2, C.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        return w, h
    end
end
