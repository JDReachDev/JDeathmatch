<#
.SYNOPSIS
    Renders the Workshop icon (512x512 JPEG): blurred in-game background, 3D crosshair, title.

.EXAMPLE
    .\make_icon.ps1
    .\make_icon.ps1 -Background ..\docs\screenshots\dam.jpg -Out out\icon_test.jpg
#>
param(
    # Screenshot used (blurred) as background
    [string]$Background = (Join-Path $PSScriptRoot "..\docs\screenshots\hud.jpg"),
    [string]$Out = (Join-Path $PSScriptRoot "icon.jpg"),
    [string]$Title = "JDEATHMATCH",
    # Crosshair rotation in degrees (Y = left/right, X = up/down)
    [double]$RotateY = 0,
    [double]$RotateX = 0,
    # Where the 3D depth shows, in pixels at full depth (positive = down / right)
    [double]$ExtrudeX = 0,
    [double]$ExtrudeY = 12,
    # Crosshair size (1 = same as the old icon)
    [double]$Size = 1.07
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if (-not ("JdmIcon" -as [type])) {
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;

public static class JdmIcon
{
    const int S = 512;
    static readonly PointF Center = new PointF(256, 194);
    const float Focal = 700f, Depth = 30f;
    static float Half = 160f;
    static float Scale = 1f;
    static float ExtrudeX, ExtrudeY;

    public static void Render(string bgPath, string outPath, string title, double rotY, double rotX, double size,
                              double extrudeX, double extrudeY)
    {
        ExtrudeX = (float)extrudeX;
        ExtrudeY = (float)extrudeY;
        Scale = (float)size;
        Half = 160f * Scale;
        using (var bmp = new Bitmap(S, S, PixelFormat.Format32bppArgb))
        using (var g = Graphics.FromImage(bmp))
        {
            Setup(g);
            DrawBackground(g, bgPath);
            DrawCrosshair(g, rotY * Math.PI / 180, rotX * Math.PI / 180);
            DrawTitle(g, title);
            SaveJpeg(bmp, outPath, 93L);
        }
    }

    static void Setup(Graphics g)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.CompositingQuality = CompositingQuality.HighQuality;
        g.TextRenderingHint = TextRenderingHint.AntiAlias;
    }

    // ---------- background ----------

    static void DrawBackground(Graphics g, string path)
    {
        using (var src = Image.FromFile(path))
        using (var bg = new Bitmap(S, S, PixelFormat.Format32bppArgb))
        {
            int side = Math.Min(src.Width, src.Height);
            var crop = new Rectangle((src.Width - side) / 2, (src.Height - side) / 2, side, side);
            using (var bgg = Graphics.FromImage(bg))
            {
                Setup(bgg);
                bgg.DrawImage(src, new Rectangle(0, 0, S, S), crop, GraphicsUnit.Pixel);
            }
            BoxBlur(bg, 6, 3);
            g.DrawImage(bg, 0, 0, S, S);
        }

        // Darken, more at the bottom where the title goes
        using (var b = new LinearGradientBrush(new Rectangle(0, 0, S, S), Color.FromArgb(150, 12, 6, 8), Color.FromArgb(235, 6, 3, 4), 90f))
            g.FillRectangle(b, 0, 0, S, S);

        // Red glow behind the crosshair
        using (var gp = new GraphicsPath())
        {
            gp.AddEllipse(Center.X - 240, Center.Y - 240, 480, 480);
            using (var pb = new PathGradientBrush(gp))
            {
                pb.CenterColor = Color.FromArgb(120, 210, 30, 30);
                pb.SurroundColors = new[] { Color.FromArgb(0, 210, 30, 30) };
                g.FillPath(pb, gp);
            }
        }

        // Vignette
        using (var gp = new GraphicsPath())
        {
            gp.AddEllipse(-130, -130, S + 260, S + 260);
            using (var pb = new PathGradientBrush(gp))
            {
                pb.CenterColor = Color.FromArgb(0, 0, 0, 0);
                pb.SurroundColors = new[] { Color.FromArgb(220, 0, 0, 0) };
                pb.FocusScales = new PointF(0.5f, 0.5f);
                g.FillPath(pb, gp);
            }
        }
    }

    static void BoxBlur(Bitmap bmp, int r, int passes)
    {
        int w = bmp.Width, h = bmp.Height;
        var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        var a = new int[w * h];
        var b = new int[w * h];
        Marshal.Copy(data.Scan0, a, 0, a.Length);
        for (int p = 0; p < passes; p++)
        {
            BlurPass(a, b, w, h, r, true);
            BlurPass(b, a, w, h, r, false);
        }
        Marshal.Copy(a, 0, data.Scan0, a.Length);
        bmp.UnlockBits(data);
    }

    static void BlurPass(int[] src, int[] dst, int w, int h, int r, bool horizontal)
    {
        int lines = horizontal ? h : w, len = horizontal ? w : h;
        for (int l = 0; l < lines; l++)
        {
            for (int i = 0; i < len; i++)
            {
                int sa = 0, sr = 0, sg = 0, sb = 0, n = 0;
                for (int k = Math.Max(0, i - r); k <= Math.Min(len - 1, i + r); k++)
                {
                    int c = horizontal ? src[l * w + k] : src[k * w + l];
                    sa += (c >> 24) & 255; sr += (c >> 16) & 255; sg += (c >> 8) & 255; sb += c & 255; n++;
                }
                int idx = horizontal ? l * w + i : i * w + l;
                dst[idx] = ((sa / n) << 24) | ((sr / n) << 16) | ((sg / n) << 8) | (sb / n);
            }
        }
    }

    // ---------- crosshair ----------

    // Same shape as the old icon: ring, four ticks, center dot
    static GraphicsPath Shape()
    {
        var p = new GraphicsPath(FillMode.Winding);
        p.AddPolygon(Circle(112, false));
        p.AddPolygon(Circle(90, true));    // reversed: makes the hole
        p.AddRectangle(new RectangleF(-11, -152, 22, 84));
        p.AddRectangle(new RectangleF(-11, 68, 22, 84));
        p.AddRectangle(new RectangleF(-152, -11, 84, 22));
        p.AddRectangle(new RectangleF(68, -11, 84, 22));
        p.AddPolygon(Circle(14, false));
        return p;
    }

    static PointF[] Circle(float radius, bool reversed)
    {
        const int n = 180;
        var pts = new PointF[n];
        for (int i = 0; i < n; i++)
        {
            double t = 2 * Math.PI * (reversed ? n - i : i) / n;
            pts[i] = new PointF((float)(Math.Cos(t) * radius), (float)(Math.Sin(t) * radius));
        }
        return pts;
    }

    static PointF Project(double x, double y, double z, double ry, double rx)
    {
        // Oblique shift of the back layers, then rotate around Y and X, then perspective
        // (centered: front and back are shifted by half the depth each way)
        x += ExtrudeX * (z / Depth - 0.5);
        y += ExtrudeY * (z / Depth - 0.5);
        double x1 = x * Math.Cos(ry) + z * Math.Sin(ry);
        double z1 = -x * Math.Sin(ry) + z * Math.Cos(ry);
        double y2 = y * Math.Cos(rx) - z1 * Math.Sin(rx);
        double z2 = y * Math.Sin(rx) + z1 * Math.Cos(rx);
        double k = Focal / (Focal + z2);
        return new PointF((float)(Center.X + x1 * k), (float)(Center.Y + y2 * k));
    }

    // The shape placed at depth z (0 = front face, positive = behind)
    static GraphicsPath Layer(double z, double ry, double rx)
    {
        var p = Shape();
        using (var m = new Matrix()) { m.Scale(Scale, Scale); p.Transform(m); }
        var dest = new[] {
            Project(-Half, -Half, z, ry, rx), Project(Half, -Half, z, ry, rx),
            Project(-Half, Half, z, ry, rx), Project(Half, Half, z, ry, rx),
        };
        p.Warp(dest, new RectangleF(-Half, -Half, 2 * Half, 2 * Half), null, WarpMode.Perspective, 0.1f);
        return p;
    }

    static void DrawCrosshair(Graphics g, double ry, double rx)
    {
        int steps = (int)Depth;

        // Soft drop shadow
        using (var shadow = new Bitmap(S, S, PixelFormat.Format32bppArgb))
        {
            using (var sg = Graphics.FromImage(shadow))
            using (var back = Layer(Depth, ry, rx))
            using (var brush = new SolidBrush(Color.FromArgb(200, 0, 0, 0)))
            {
                Setup(sg);
                sg.TranslateTransform(10, 16);
                sg.FillPath(brush, back);
            }
            BoxBlur(shadow, 7, 3);
            g.DrawImage(shadow, 0, 0, S, S);
        }

        // Outline around the whole solid
        using (var outline = new Pen(Color.FromArgb(255, 12, 4, 6), 9f) { LineJoin = LineJoin.Round })
            for (int i = steps; i >= 0; i -= 2)
                using (var l = Layer(i, ry, rx)) g.DrawPath(outline, l);

        // Extrusion, dark at the back and lighter toward the front
        for (int i = steps; i >= 1; i--)
        {
            double t = 1.0 - (double)i / steps;
            var c = Color.FromArgb(255, (int)(80 + 70 * t), (int)(8 + 12 * t), (int)(10 + 12 * t));
            using (var l = Layer(i, ry, rx))
            using (var brush = new SolidBrush(c))
            using (var pen = new Pen(c, 1.2f))
            {
                g.FillPath(brush, l);
                g.DrawPath(pen, l);
            }
        }

        // Front face
        using (var front = Layer(0, ry, rx))
        {
            var bounds = front.GetBounds();
            // Light rim first, the fill covers its inner half and the edges inside the shape
            using (var rim = new Pen(Color.FromArgb(200, 255, 165, 155), 3.2f) { LineJoin = LineJoin.Round })
                g.DrawPath(rim, front);
            using (var brush = new LinearGradientBrush(bounds, Color.FromArgb(255, 255, 92, 82), Color.FromArgb(255, 200, 26, 30), 60f))
                g.FillPath(brush, front);
        }
    }

    // ---------- title ----------

    static void DrawTitle(Graphics g, string title)
    {
        var family = FindFamily("Bahnschrift SemiBold Condensed", "Bahnschrift Condensed", "Bahnschrift", "Arial Black");
        var style = family.IsStyleAvailable(FontStyle.Bold) ? FontStyle.Bold : FontStyle.Regular;
        var fmt = StringFormat.GenericTypographic;

        // Letter by letter, for wider tracking
        var text = new GraphicsPath(FillMode.Winding);
        float x = 0, tracking = 9f, size = 100f;
        foreach (char ch in title)
        {
            using (var glyph = new GraphicsPath())
            {
                glyph.AddString(ch.ToString(), family, (int)style, size, new PointF(0, 0), fmt);
                var gb = glyph.GetBounds();
                using (var m = new Matrix()) { m.Translate(x - gb.Left, 0); glyph.Transform(m); }
                text.AddPath(glyph, false);
                x += gb.Width + tracking;
            }
        }

        // Fit to 440 px wide, centered under the crosshair
        var b = text.GetBounds();
        float scale = 440f / b.Width;
        using (var m = new Matrix())
        {
            m.Translate(256, 424);
            m.Scale(scale, scale);
            m.Translate(-(b.Left + b.Width / 2), -(b.Top + b.Height / 2));
            text.Transform(m);
        }
        b = text.GetBounds();

        using (var shadow = new Bitmap(S, S, PixelFormat.Format32bppArgb))
        {
            using (var sg = Graphics.FromImage(shadow))
            using (var brush = new SolidBrush(Color.FromArgb(230, 0, 0, 0)))
            {
                Setup(sg);
                sg.TranslateTransform(0, 6);
                sg.FillPath(brush, text);
            }
            BoxBlur(shadow, 5, 3);
            g.DrawImage(shadow, 0, 0, S, S);
        }

        using (var pen = new Pen(Color.FromArgb(255, 12, 4, 6), 6f) { LineJoin = LineJoin.Round })
            g.DrawPath(pen, text);
        using (var brush = new LinearGradientBrush(new RectangleF(b.Left, b.Top - 1, b.Width, b.Height + 2), Color.White, Color.FromArgb(255, 200, 200, 205), 90f))
            g.FillPath(brush, text);

        // Red accent bar under the title
        float barW = 120, barY = b.Bottom + 12;
        using (var bar = new SolidBrush(Color.FromArgb(255, 225, 45, 45)))
            g.FillRectangle(bar, 256 - barW / 2, barY, barW, 5);
        text.Dispose();
    }

    static FontFamily FindFamily(params string[] names)
    {
        var installed = new InstalledFontCollection().Families;
        foreach (var name in names)
            foreach (var f in installed)
                if (string.Equals(f.Name, name, StringComparison.OrdinalIgnoreCase)) return f;
        return FontFamily.GenericSansSerif;
    }

    static void SaveJpeg(Bitmap bmp, string path, long quality)
    {
        ImageCodecInfo jpeg = null;
        foreach (var c in ImageCodecInfo.GetImageEncoders())
            if (c.FormatID == ImageFormat.Jpeg.Guid) jpeg = c;
        using (var ps = new EncoderParameters(1))
        {
            ps.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, quality);
            bmp.Save(path, jpeg, ps);
        }
    }
}
'@
}

$Background = (Resolve-Path $Background).Path
$Out = [System.IO.Path]::GetFullPath($Out)
[JdmIcon]::Render($Background, $Out, $Title, $RotateY, $RotateX, $Size, $ExtrudeX, $ExtrudeY)
Write-Host "Icon saved: $Out"
