import AppKit

func createCalBarIcon() -> NSImage {
    let size = NSSize(width: 1024, height: 1024)
    let image = NSImage(size: size)
    
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    // Clear background
    ctx.clear(CGRect(origin: .zero, size: size))
    
    // Squircle Dimensions (Standard macOS Big Sur / Sonoma icon grid)
    // 824x824 squircle centered in 1024x1024
    let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let cornerRadius: CGFloat = 185
    
    // Drop Shadow
    ctx.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowOffset = NSSize(width: 0, height: -22)
    shadow.shadowBlurRadius = 36
    shadow.set()
    
    let path = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor.white.setFill()
    path.fill()
    ctx.restoreGState()
    
    // Base Card Clip
    ctx.saveGState()
    path.addClip()
    
    // Card Base Gradient (Pure White to subtle off-white)
    let baseGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
        ]
    )!
    baseGradient.draw(in: squircleRect, angle: -90)
    
    // Top Header Banner (Google Blue Gradient)
    let headerHeight: CGFloat = 260
    let headerRect = CGRect(x: squircleRect.minX, y: squircleRect.maxY - headerHeight, width: squircleRect.width, height: headerHeight)
    let headerGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.10, green: 0.45, blue: 0.91, alpha: 1.0), // #1A73E8
            NSColor(calibratedRed: 0.08, green: 0.36, blue: 0.80, alpha: 1.0)  // #1557B0
        ]
    )!
    headerGradient.draw(in: headerRect, angle: -90)
    
    // Subtle glossy highlight on the top edge of header
    let highlightRect = CGRect(x: headerRect.minX, y: headerRect.maxY - 4, width: headerRect.width, height: 4)
    NSColor.white.withAlphaComponent(0.35).setFill()
    highlightRect.fill()
    
    // Header Text: "CALBAR"
    let title = "CALBAR"
    let titleFont = NSFont.systemFont(ofSize: 58, weight: .black)
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont,
        .foregroundColor: NSColor.white,
        .kern: 8.0
    ]
    let titleSize = title.size(withAttributes: titleAttrs)
    let titlePoint = CGPoint(
        x: headerRect.midX - titleSize.width / 2,
        y: headerRect.midY - titleSize.height / 2 + 10
    )
    title.draw(at: titlePoint, withAttributes: titleAttrs)
    
    // Small subtle month subline: "DAY & WEEK"
    let subTitle = "MENU BAR CALENDAR"
    let subFont = NSFont.systemFont(ofSize: 22, weight: .bold)
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor.white.withAlphaComponent(0.82),
        .kern: 4.0
    ]
    let subSize = subTitle.size(withAttributes: subAttrs)
    let subPoint = CGPoint(
        x: headerRect.midX - subSize.width / 2,
        y: headerRect.minY + 34
    )
    subTitle.draw(at: subPoint, withAttributes: subAttrs)
    
    // Calendar Sheet Content: Big "31"
    let bodyRect = CGRect(x: squircleRect.minX, y: squircleRect.minY, width: squircleRect.width, height: squircleRect.height - headerHeight)
    
    let dateNumber = "31"
    let numberFont = NSFont.systemFont(ofSize: 310, weight: .heavy)
    let numberAttrs: [NSAttributedString.Key: Any] = [
        .font: numberFont,
        .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 1.0), // #1F242B
        .kern: -4.0
    ]
    let numberSize = dateNumber.size(withAttributes: numberAttrs)
    let numberPoint = CGPoint(
        x: bodyRect.midX - numberSize.width / 2,
        y: bodyRect.midY - numberSize.height / 2 + 32
    )
    dateNumber.draw(at: numberPoint, withAttributes: numberAttrs)
    
    // Google Accent Dots below "31": Blue, Red, Yellow, Green
    let dotDiameter: CGFloat = 26
    let dotSpacing: CGFloat = 22
    let dotColors: [NSColor] = [
        NSColor(calibratedRed: 0.26, green: 0.52, blue: 0.96, alpha: 1.0), // Google Blue (#4285F4)
        NSColor(calibratedRed: 0.92, green: 0.26, blue: 0.21, alpha: 1.0), // Google Red (#EA4335)
        NSColor(calibratedRed: 0.98, green: 0.73, blue: 0.02, alpha: 1.0), // Google Yellow (#FBBC05)
        NSColor(calibratedRed: 0.20, green: 0.66, blue: 0.33, alpha: 1.0)  // Google Green (#34A853)
    ]
    let totalDotsWidth = CGFloat(dotColors.count) * dotDiameter + CGFloat(dotColors.count - 1) * dotSpacing
    var dotStartX = bodyRect.midX - totalDotsWidth / 2
    let dotY = bodyRect.minY + 70
    
    for color in dotColors {
        let dotRect = CGRect(x: dotStartX, y: dotY, width: dotDiameter, height: dotDiameter)
        color.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        dotStartX += dotDiameter + dotSpacing
    }
    
    // Inner Rim Stroke for Apple-style physical edge definition
    let innerStroke = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 1, dy: 1), xRadius: cornerRadius - 1, yRadius: cornerRadius - 1)
    NSColor.black.withAlphaComponent(0.08).setStroke()
    innerStroke.lineWidth = 2
    innerStroke.stroke()
    
    ctx.restoreGState()
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

let icon = createCalBarIcon()
savePNG(image: icon, path: "AppIcon_1024.png")
print("Saved AppIcon_1024.png successfully")
