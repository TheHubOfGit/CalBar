import AppKit

func createDMGBackground() -> NSImage {
    // 1200x800 for 600x400 @2x Retina
    let size = NSSize(width: 1200, height: 800)
    let image = NSImage(size: size)
    
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    // Background Gradient (Very soft modern light gray/blue)
    let bounds = CGRect(origin: .zero, size: size)
    let bgGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.99, alpha: 1.0),
            NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1.0)
        ]
    )!
    bgGradient.draw(in: bounds, angle: -90)
    
    // Top Instruction Text
    let title = "Install CalBar"
    let titleFont = NSFont.systemFont(ofSize: 42, weight: .bold)
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 1.0)
    ]
    let titleSize = title.size(withAttributes: titleAttrs)
    title.draw(at: CGPoint(x: (1200 - titleSize.width) / 2, y: 680), withAttributes: titleAttrs)
    
    let subtitle = "Drag CalBar to the Applications folder to install"
    let subFont = NSFont.systemFont(ofSize: 24, weight: .medium)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(calibratedRed: 0.45, green: 0.48, blue: 0.53, alpha: 1.0)
    ]
    let subSize = subtitle.size(withAttributes: subAttrs)
    subtitle.draw(at: CGPoint(x: (1200 - subSize.width) / 2, y: 640), withAttributes: subAttrs)
    
    // Sleek Arrow in the Center (between (320, 380) and (880, 380))
    // Center is (600, 380)
    let arrowStartX: CGFloat = 490
    let arrowEndX: CGFloat = 710
    let arrowY: CGFloat = 380
    
    ctx.saveGState()
    let arrowPath = NSBezierPath()
    arrowPath.move(to: CGPoint(x: arrowStartX, y: arrowY))
    arrowPath.line(to: CGPoint(x: arrowEndX, y: arrowY))
    
    // Arrowhead
    arrowPath.move(to: CGPoint(x: arrowEndX - 18, y: arrowY + 16))
    arrowPath.line(to: CGPoint(x: arrowEndX + 2, y: arrowY))
    arrowPath.line(to: CGPoint(x: arrowEndX - 18, y: arrowY - 16))
    
    arrowPath.lineWidth = 4
    arrowPath.lineCapStyle = .round
    arrowPath.lineJoinStyle = .round
    
    NSColor(calibratedRed: 0.10, green: 0.45, blue: 0.91, alpha: 0.75).setStroke()
    arrowPath.stroke()
    ctx.restoreGState()
    
    // Bottom Subtle Watermark
    let footer = "CalBar  •  Google Calendar Day & Week for macOS Menu Bar"
    let footerFont = NSFont.systemFont(ofSize: 18, weight: .regular)
    let footerAttrs: [NSAttributedString.Key: Any] = [
        .font: footerFont,
        .foregroundColor: NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.63, alpha: 0.75),
        .kern: 1.5
    ]
    let footerSize = footer.size(withAttributes: footerAttrs)
    footer.draw(at: CGPoint(x: (1200 - footerSize.width) / 2, y: 50), withAttributes: footerAttrs)
    
    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG")
    }
    try! png.write(to: URL(fileURLWithPath: path))
}

let bg = createDMGBackground()
savePNG(image: bg, path: "dmg_background.png")
print("Saved dmg_background.png")
