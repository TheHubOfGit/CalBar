import SwiftUI

public enum TimelineDensity: String, CaseIterable, Identifiable, Codable, Sendable {
    case compact = "Compact"
    case regular = "Regular"
    case spacious = "Spacious"

    public var id: String { rawValue }

    public var hourHeight: CGFloat {
        switch self {
        case .compact: return 38.0
        case .regular: return 52.0
        case .spacious: return 68.0
        }
    }
}

public enum PastTimeColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case gray = "Subtle Gray"
    case slate = "Slate Dark"
    case blue = "Cool Blue"
    case amber = "Warm Amber"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .gray: return Color.secondary
        case .slate: return Color(nsColor: .darkGray)
        case .blue: return Color.blue
        case .amber: return Color.orange
        }
    }
}

public enum TimelineScrollBehavior: String, CaseIterable, Identifiable, Codable, Sendable {
    case currentTime = "Scroll to current time"
    case specificTime = "Scroll to specific hour"
    case retainPosition = "Restore last scroll position"

    public var id: String { rawValue }
}
