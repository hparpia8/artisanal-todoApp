#!/usr/bin/env swift
// Generates Light, Dark, and Tinted app icon variants for macOS + iOS.
// Run from the project root: swift scripts/generate_icon.swift
//
// Layout: ruled-paper background, vertical stack —
//   header rule (like a notepad divider), checked box (top), unchecked box (below).
// Clipped to a continuous rounded rectangle (squircle, superellipse n = 4.5).

import Foundation
import CoreGraphics
import ImageIO

// ── Palette ───────────────────────────────────────────────────────────────

struct Palette {
    let background:      CGColor
    let paperLine:       CGColor   // horizontal ruled lines
    let headerRule:      CGColor   // single accent line above the checked box
    let uncheckedStroke: CGColor
    let checkedStroke:   CGColor
    let checkmark:       CGColor
    let checkedFill:     CGColor
}

let light = Palette(
    background:      CGColor(red: 0.973, green: 0.961, blue: 0.918, alpha: 1.000),
    paperLine:       CGColor(red: 0.820, green: 0.805, blue: 0.768, alpha: 0.900),
    headerRule:      CGColor(red: 0.722, green: 0.451, blue: 0.200, alpha: 0.380),
    uncheckedStroke: CGColor(red: 0.420, green: 0.384, blue: 0.345, alpha: 1.000),
    checkedStroke:   CGColor(red: 0.722, green: 0.451, blue: 0.200, alpha: 1.000),
    checkmark:       CGColor(red: 0.722, green: 0.451, blue: 0.200, alpha: 1.000),
    checkedFill:     CGColor(red: 0.722, green: 0.451, blue: 0.200, alpha: 0.100)
)

let dark = Palette(
    background:      CGColor(red: 0.110, green: 0.102, blue: 0.090, alpha: 1.000),
    paperLine:       CGColor(red: 0.220, green: 0.200, blue: 0.175, alpha: 0.900),
    headerRule:      CGColor(red: 0.784, green: 0.518, blue: 0.227, alpha: 0.420),
    uncheckedStroke: CGColor(red: 0.478, green: 0.447, blue: 0.408, alpha: 1.000),
    checkedStroke:   CGColor(red: 0.784, green: 0.518, blue: 0.227, alpha: 1.000),
    checkmark:       CGColor(red: 0.784, green: 0.518, blue: 0.227, alpha: 1.000),
    checkedFill:     CGColor(red: 0.784, green: 0.518, blue: 0.227, alpha: 0.140)
)

// Tinted: transparent BG + white elements — system overlays the user's accent colour
let tinted = Palette(
    background:      CGColor(red: 0, green: 0, blue: 0, alpha: 0.000),
    paperLine:       CGColor(red: 1, green: 1, blue: 1, alpha: 0.120),
    headerRule:      CGColor(red: 1, green: 1, blue: 1, alpha: 0.500),
    uncheckedStroke: CGColor(red: 1, green: 1, blue: 1, alpha: 0.700),
    checkedStroke:   CGColor(red: 1, green: 1, blue: 1, alpha: 1.000),
    checkmark:       CGColor(red: 1, green: 1, blue: 1, alpha: 1.000),
    checkedFill:     CGColor(red: 1, green: 1, blue: 1, alpha: 0.180)
)

// ── Squircle path ─────────────────────────────────────────────────────────

/// Superellipse (squircle) path — approximates Apple's "continuous corner" style.
/// n ≈ 4.5 closely matches iMessage / macOS icon geometry.
func squirclePath(size: CGFloat) -> CGPath {
    let path  = CGMutablePath()
    let cx    = size / 2
    let cy    = size / 2
    let r     = size / 2
    let n: CGFloat = 4.5
    let steps = 512
    for i in 0...steps {
        let angle = CGFloat(i) * 2 * .pi / CGFloat(steps)
        let cosA  = cos(angle)
        let sinA  = sin(angle)
        let denom = pow(pow(abs(cosA), n) + pow(abs(sinA), n), 1.0 / n)
        let x = cx + r * cosA / denom
        let y = cy + r * sinA / denom
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
        else       { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

// ── Drawing ───────────────────────────────────────────────────────────────

func makeIcon(size: Int, palette p: Palette) -> CGImage {
    let s   = CGFloat(size)
    let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // ── Clip to squircle + fill background ────────────────────────────────

    ctx.addPath(squirclePath(size: s))
    ctx.clip()

    ctx.setFillColor(p.background)
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    // ── Ruled lines (paper texture) ───────────────────────────────────────
    // Only draw for sizes where detail is legible (≥ 64 px)

    if size >= 64 {
        let lineSpacing = s * 0.083
        let marginX     = s * 0.06
        let lineWidth   = max(0.5, s * 0.006)

        ctx.setStrokeColor(p.paperLine)
        ctx.setLineWidth(lineWidth)

        var lineY = s * 0.05 + lineSpacing
        while lineY < s * 0.96 {
            ctx.move(to:    CGPoint(x: marginX,     y: lineY))
            ctx.addLine(to: CGPoint(x: s - marginX, y: lineY))
            ctx.strokePath()
            lineY += lineSpacing
        }
    }

    // ── Layout — vertical stack, centred ──────────────────────────────────
    // CGContext y-axis is bottom-up: high y = visually top.
    // Checked box is drawn at higher y (visually on top).
    // Unchecked box is drawn at lower y (visually below).

    let bs          = s * 0.285          // box side length
    let gap         = s * 0.055          // gap between boxes
    let lw          = max(1.0, s * 0.034)
    let cr          = bs * 0.14          // corner radius for boxes

    let totalHeight = bs * 2 + gap
    let stackBottom = (s - totalHeight) / 2

    let uncheckedOriginY = stackBottom          // bottom of lower box
    let checkedOriginY   = stackBottom + bs + gap  // bottom of upper box

    let ox = (s - bs) / 2               // horizontal centre

    // ── Header rule ───────────────────────────────────────────────────────
    // A single thicker line sitting above the checked box, like a notepad
    // header divider marking where tasks begin.

    if size >= 64 {
        let headerLineY = checkedOriginY + bs + s * 0.048
        let headerLW    = max(0.8, s * 0.009)
        ctx.setStrokeColor(p.headerRule)
        ctx.setLineWidth(headerLW)
        ctx.move(to:    CGPoint(x: s * 0.06, y: headerLineY))
        ctx.addLine(to: CGPoint(x: s * 0.94, y: headerLineY))
        ctx.strokePath()
    }

    // ── Checked box (top, visually above) ────────────────────────────────

    let checkedRect = CGRect(x: ox, y: checkedOriginY, width: bs, height: bs)
    let checkedPath = CGPath(roundedRect: checkedRect,
                             cornerWidth: cr, cornerHeight: cr, transform: nil)

    ctx.setFillColor(p.checkedFill)
    ctx.addPath(checkedPath); ctx.fillPath()

    ctx.setStrokeColor(p.checkedStroke)
    ctx.setLineWidth(lw)
    ctx.addPath(checkedPath); ctx.strokePath()

    // Checkmark — vertex is the lowest visual point (smallest y in CGContext)
    ctx.setStrokeColor(p.checkmark)
    ctx.setLineWidth(lw * 1.55)
    ctx.move(to:    CGPoint(x: ox + bs*0.19, y: checkedOriginY + bs*0.52))
    ctx.addLine(to: CGPoint(x: ox + bs*0.42, y: checkedOriginY + bs*0.27))
    ctx.addLine(to: CGPoint(x: ox + bs*0.82, y: checkedOriginY + bs*0.73))
    ctx.strokePath()

    // ── Unchecked box (below, visually underneath) ────────────────────────

    let uncheckedRect = CGRect(x: ox, y: uncheckedOriginY, width: bs, height: bs)
    let uncheckedPath = CGPath(roundedRect: uncheckedRect,
                               cornerWidth: cr, cornerHeight: cr, transform: nil)

    ctx.setStrokeColor(p.uncheckedStroke)
    ctx.setLineWidth(lw)
    ctx.addPath(uncheckedPath); ctx.strokePath()

    return ctx.makeImage()!
}

// ── PNG output ────────────────────────────────────────────────────────────

func savePNG(_ img: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

// ── Main ──────────────────────────────────────────────────────────────────

let root       = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetDir = root.appendingPathComponent("TodoApp/Assets.xcassets/AppIcon.appiconset")
try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let macSizes   = [16, 32, 64, 128, 256, 512, 1024]
let variants: [(String, Palette)] = [("light", light), ("dark", dark), ("tinted", tinted)]

for (name, palette) in variants {
    let sizes = (name == "tinted") ? [1024] : macSizes
    for sz in sizes {
        let url = iconsetDir.appendingPathComponent("icon_\(name)_\(sz).png")
        savePNG(makeIcon(size: sz, palette: palette), to: url)
        print("  ✓ \(name)  \(sz)×\(sz)")
    }
}

print("\nDone → \(iconsetDir.path)")
