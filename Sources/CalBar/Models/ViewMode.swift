import Foundation

public enum ViewMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case day = "Day"
    case week = "Week"

    public var id: String { rawValue }
}
