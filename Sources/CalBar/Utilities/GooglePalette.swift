import SwiftUI

public enum GooglePalette {
    // Brand Colors
    public static let googleBlue = Color(hex: "#1a73e8")
    public static let googleRed = Color(hex: "#ea4335")
    public static let googleYellow = Color(hex: "#fbbc04")
    public static let googleGreen = Color(hex: "#34a853")

    // Google Calendar Event Color IDs (1 to 11)
    public static let eventColors: [String: String] = [
        "1": "#7986cb",  // Lavender
        "2": "#33b679",  // Sage
        "3": "#8e24aa",  // Grape
        "4": "#e67c73",  // Flamingo
        "5": "#f6c026",  // Banana
        "6": "#f5511d",  // Tangerine
        "7": "#039be5",  // Peacock
        "8": "#616161",  // Graphite
        "9": "#3f51b5",  // Blueberry
        "10": "#0b8043", // Basil
        "11": "#d60000"  // Tomato
    ]

    public static func color(forEventColorId colorId: String?, calendarHex: String?) -> Color {
        if let id = colorId, let hex = eventColors[id] {
            return Color(hex: hex)
        }
        if let hex = calendarHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return googleBlue
    }

    public static func hex(forEventColorId colorId: String?, calendarHex: String?) -> String {
        if let id = colorId, let hex = eventColors[id] {
            return hex
        }
        if let hex = calendarHex, !hex.isEmpty {
            return hex
        }
        return "#1a73e8"
    }
}

/// Resolved-color memo.
///
/// `Color(hex:)` allocates a `Scanner` and walks the string every time it runs, and event
/// chips ask for their color on every render pass. The set of distinct calendar colors is
/// tiny, so caching turns a per-frame parse into a dictionary hit.
final class ResolvedColorCache: @unchecked Sendable {
    static let shared = ResolvedColorCache()

    private let lock = NSLock()
    private var colors: [String: Color] = [:]
    private var darkness: [String: Bool] = [:]

    func color(for hex: String) -> Color {
        lock.lock()
        defer { lock.unlock() }
        if let cached = colors[hex] { return cached }
        let resolved = Color(hex: hex)
        colors[hex] = resolved
        return resolved
    }

    func isDark(_ hex: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let cached = darkness[hex] { return cached }
        let resolved = Color.isColorDark(hex: hex)
        darkness[hex] = resolved
        return resolved
    }
}

extension Color {
    /// Memoized counterpart to `Color(hex:)` for use on render-hot paths.
    public static func cached(hex: String) -> Color {
        ResolvedColorCache.shared.color(for: hex)
    }

    public static func isColorDarkCached(hex: String) -> Bool {
        ResolvedColorCache.shared.isDark(hex)
    }

    public init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 26, 115, 232) // Default to Google Blue
        }

        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }

    public static func isColorDark(hex: String) -> Bool {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.65
    }
}
