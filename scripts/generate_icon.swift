#!/usr/bin/env swift
// Generates Light, Dark, and Tinted app icon variants for macOS + iOS.
// Run from the project root: swift scripts/generate_icon.swift
//
// Variants:
//   Light  — warm cream background, copper checkmark
//   Dark   — charcoal background, warm copper checkmark
//   Tinted — transparent background, white elements (system applies accent colour)

import Foundation
import CoreGraphics
import ImageIO

// ── Palette ───────────────────────────────────────────────────────────────

struct Palette {
    let background:      CGColor
    let uncheckedStroke: CGColor
    let checkedStroke:   CGColor
    let checkmark:       CGColor
    let checkedFill:     CGColor
}

let light = Palette(
    background:      CGColor(red: 0.973, green: 0.961, blue: 0.918, alpha: 1.000),
    uncheckedStroke: CGColor(red: 0.420, green: 0.384, blue: 0.345, alpha: 1.000),
    checkedStroke:   CGColor(red: 0.722, green: 0.451, blue: 0.200, alpha: 1.000),
    checkmark:       CGColor(red: 0.722, green: 0.451, blue: 0.200, alpha: 1.000),
    checkedFill:     CGColor(red: 0.722, green: 0.451, blue: 0.200, alpha: 0.100)
)

let dark = Palette(
    background:      CGColor(red: 0.110, green: 0.102, blue: 0.090, alpha: 1.000),
    uncheckedStroke: CGColor(red: 0.478, green: 0.447, blue: 0.408, alpha: 1.000),
    checkedStroke:   CGColor(red: 0.784, green: 0.518, blue: 0.227, alpha: 1.000),
    checkmark:       CGColor(red: 0.784, green: 0.518, blue: 0.227, alpha: 1.000),
    checkedFill:     CGColor(red: 0.784, green: 0.518, blue: 0.227, alpha: 0.140)
)

// Tinted: transparent BG + white elements — system overlays the user's accent colour
let tinted = Palette(
    background:      CGColor(red: 0, green: 0, blue: 0, alpha: 0.000),  // transparent
    uncheckedStroke: CGColor(red: 1, green: 1, blue: 1, alpha: 0.700),
    checkedStroke:   CGColor(red: 1, green: 1, blue: 1, alpha: 1.000),
    checkmark:       CGColor(red: 1, green: 1, blue: 1, alpha: 1.000),
    checkedFill:     CGColor(red: 1, green: 1, blue: 1, alpha: 0.180)
)

// ── Drawing ───────────────────────────────────────────────────────────────

func makeIcon(size: Int, palette p: Palette) -> CGImage {
    let s  = CGFloat(size)
    let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Background
    ctx.setFillColor(p.background)
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    // Subtle paper vignette on light/dark (skip for tinted — it's transparent)
    if p.background.alpha > 0 && size >= 64 {
        let colors = [p.background, p.background.copy(alpha: 0)!] as CFArray
        if let grad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) {
            let centre = CGPoint(x: s/2, y: s/2)
            ctx.drawRadialGradient(
                grad,
                startCenter: centre, startRadius: 0,
                endCenter: centre,   endRadius: s * 0.72,
                options: []
            )
        }
    }

    // Layout — two square boxes side-by-side, centred
    let bs  = s * 0.285          // box side
    let gap = s * 0.075          // gap between boxes
    let ox  = (s - bs*2 - gap) / 2
    let oy  = (s - bs) / 2
    let lw  = max(1.0, s * 0.034)
    let cr  = bs * 0.14          // corner radius

    // ── Left box: CHECKED ─────────────────────────────────────────────────

    let leftRect = CGRect(x: ox, y: oy, width: bs, height: bs)
    let leftPath = CGPath(roundedRect: leftRect, cornerWidth: cr, cornerHeight: cr, transform: nil)

    // Subtle fill
    ctx.setFillColor(p.checkedFill)
    ctx.addPath(leftPath); ctx.fillPath()

    // Outline
    ctx.setStrokeColor(p.checkedStroke)
    ctx.setLineWidth(lw)
    ctx.addPath(leftPath); ctx.strokePath()

    // Checkmark (Y-up: vertex is the lowest y value)
    ctx.setStrokeColor(p.checkmark)
    ctx.setLineWidth(lw * 1.55)
    ctx.move(to:    CGPoint(x: ox + bs*0.19, y: oy + bs*0.52))   // left, mid
    ctx.addLine(to: CGPoint(x: ox + bs*0.42, y: oy + bs*0.27))   // vertex (bottom of ✓)
    ctx.addLine(to: CGPoint(x: ox + bs*0.82, y: oy + bs*0.73))   // upper-right
    ctx.strokePath()

    // ── Right box: UNCHECKED ──────────────────────────────────────────────

    let rx        = ox + bs + gap
    let rightRect = CGRect(x: rx, y: oy, width: bs, height: bs)
    let rightPath = CGPath(roundedRect: rightRect, cornerWidth: cr, cornerHeight: cr, transform: nil)

    ctx.setStrokeColor(p.uncheckedStroke)
    ctx.setLineWidth(lw)
    ctx.addPath(rightPath); ctx.strokePath()

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
    let sizes = (name == "tinted") ? [1024] : macSizes   // tinted: one size (iOS uses it)
    for sz in sizes {
        let url = iconsetDir.appendingPathComponent("icon_\(name)_\(sz).png")
        savePNG(makeIcon(size: sz, palette: palette), to: url)
        print("  ✓ \(name)  \(sz)×\(sz)")
    }
}

print("\nDone → \(iconsetDir.path)")
