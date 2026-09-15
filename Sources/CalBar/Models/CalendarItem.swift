import Foundation
import SwiftUI

/// Represents a calendar from Google Calendar or Apple EventKit
public struct CalendarItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var summary: String
    public var colorHex: String
    public var isSelected: Bool
    public var isPrimary: Bool
    public var accessRole: String?

    public init(
        id: String,
        summary: String,
        colorHex: String,
        isSelected: Bool = true,
        isPrimary: Bool = false,
        accessRole: String? = nil
    ) {
        self.id = id
        self.summary = summary
        self.colorHex = colorHex
        self.isSelected = isSelected
        self.isPrimary = isPrimary
        self.accessRole = accessRole
    }
}
