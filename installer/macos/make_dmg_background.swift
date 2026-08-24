#!/usr/bin/env swift
// DMG background — EXACTLY 1320×840 px (@2x for 660×420 pt). Sync with tool/build_dmg.sh.

import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("Usage: make_dmg_background.swift <logo.png> <output.png>\n", stderr)
    exit(1)
}

let logoPath = args[1]
let outPath = args[2]

let W = 1320
let H = 840

let iconX: CGFloat = 88
let iconY: CGFloat = 238
let appsX: CGFloat = 368
let iconSize: CGFloat = 96
let s: CGFloat = 2

let leftX: CGFloat = 40

func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat((hex >> 0) & 0xFF) / 255
    return NSColor(calibratedRed: r, green: g, blue: b, alpha: alpha)
}

let brand = rgb(0x0B6E4F)
let brandDark = rgb(0x08543C)
let brandLight = rgb(0x14956C)

func rTop(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: CGFloat(H) - y - h, width: w, height: h)
}

func pTop(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    NSPoint(x: x, y: CGFloat(H) - y)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: W, pixelsHigh: H,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else {
    fputs("Failed to create bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let gradient = NSGradient(colors: [rgb(0xF3F8F6), rgb(0xFFFFFF), rgb(0xEAF4F0)])
gradient?.draw(from: NSPoint(x: 0, y: CGFloat(H)), to: NSPoint(x: CGFloat(W), y: 0), options: [])

func text(_ str: String, size: CGFloat, weight: NSFont.Weight, color: NSColor,
          x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, align: NSTextAlignment = .left) {
    let p = NSMutableParagraphStyle()
    p.alignment = align
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: p,
    ]
    (str as NSString).draw(in: rTop(x, y, w, h), withAttributes: attrs)
}

if let logo = NSImage(contentsOfFile: logoPath) {
    let logoH: CGFloat = 38
    let aspect = logo.size.width / max(logo.size.height, 1)
    logo.draw(in: rTop(leftX, 24, min(logoH * aspect, 220), logoH))
}

text("EastmarkHK Snowball", size: 22, weight: .bold, color: rgb(0x0F172A),
     x: leftX, y: 72, w: 420, h: 28)
text("Compound interest · month by month", size: 13, weight: .medium, color: rgb(0x64748B),
     x: leftX, y: 98, w: 460, h: 18)
text("Drag the app into the Applications folder", size: 12, weight: .semibold, color: brandDark,
     x: leftX, y: 118, w: 420, h: 16)

let cardW: CGFloat = 220
let cardH: CGFloat = 76
let cardX: CGFloat = 410
let cardTop: CGFloat = 70
let card = rTop(cardX, cardTop, cardW, cardH)
let cardPath = NSBezierPath(roundedRect: card, xRadius: 10, yRadius: 10)
rgb(0xFFFFFF, alpha: 0.94).setFill()
cardPath.fill()
brand.withAlphaComponent(0.25).setStroke()
cardPath.lineWidth = 1.5
cardPath.stroke()

text("Your investment", size: 11, weight: .semibold, color: rgb(0x64748B),
     x: cardX + 12, y: cardTop + 8, w: 180, h: 14)
text("Grows over time", size: 20, weight: .bold, color: brand,
     x: cardX + 12, y: cardTop + 24, w: 196, h: 26)
text("PDF report included", size: 9, weight: .medium, color: rgb(0x94A3B8),
     x: cardX + 12, y: cardTop + 54, w: 160, h: 12)

let arrowStartX: CGFloat = (cardX + cardW + 6) * s
let arrowStartY: CGFloat = (cardTop + cardH * 0.55) * s
let arrowEndX: CGFloat = (appsX + 8) * s
let arrowEndY: CGFloat = (iconY + iconSize * 0.35) * s

func drawDiagonalArrow(from sx: CGFloat, _ sy: CGFloat, to ex: CGFloat, _ ey: CGFloat) {
    let p0 = pTop(sx, sy)
    let p1 = pTop(ex, ey)

    let halo = NSBezierPath()
    halo.move(to: p0)
    halo.line(to: p1)
    halo.lineWidth = 12
    halo.lineCapStyle = .round
    NSColor.white.setStroke()
    halo.stroke()

    let shaft = NSBezierPath()
    shaft.move(to: p0)
    shaft.line(to: p1)
    shaft.lineWidth = 6
    shaft.lineCapStyle = .round
    rgb(0xDC2626).setStroke()
    shaft.stroke()

    let dx = p1.x - p0.x
    let dy = p1.y - p0.y
    let len = max(hypot(dx, dy), 1)
    let ux = dx / len
    let uy = dy / len
    let px = -uy
    let py = ux
    let tip = p1
    let head = NSBezierPath()
    head.move(to: tip)
    head.line(to: NSPoint(x: tip.x - ux * 34 + px * 16, y: tip.y - uy * 34 + py * 16))
    head.line(to: NSPoint(x: tip.x - ux * 34 - px * 16, y: tip.y - uy * 34 - py * 16))
    head.close()
    rgb(0xDC2626).setFill()
    head.fill()
}

drawDiagonalArrow(from: arrowStartX, arrowStartY, to: arrowEndX, arrowEndY)

let midY: CGFloat = (iconY + iconSize * 0.42) * s
let midX0: CGFloat = (iconX + iconSize + 6) * s
let midX1: CGFloat = (appsX - 10) * s
let mid = NSBezierPath()
mid.move(to: pTop(midX0, midY))
mid.line(to: pTop(midX1, midY))
mid.lineWidth = 4
mid.lineCapStyle = .round
brandLight.withAlphaComponent(0.45).setStroke()
mid.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outPath))
    print("Wrote \(outPath) (\(W)×\(H))")
} catch {
    fputs("Write failed: \(error)\n", stderr)
    exit(1)
}
