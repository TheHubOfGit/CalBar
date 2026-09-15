import Foundation

public struct PositionedEvent: Identifiable, Hashable, Sendable {
    public var id: String { event.id }
    public let event: CalendarEvent
    public let column: Int
    public let totalColumns: Int

    public init(event: CalendarEvent, column: Int, totalColumns: Int) {
        self.event = event
        self.column = column
        self.totalColumns = max(1, totalColumns)
    }

    /// Horizontal offset fraction (from 0.0 to 1.0)
    public var leftFraction: Double {
        Double(column) / Double(totalColumns)
    }

    /// Horizontal width fraction (from 0.0 to 1.0)
    public var widthFraction: Double {
        1.0 / Double(totalColumns)
    }
}

public enum EventLayoutAlgorithm {
    /// Computes column indices and total column counts for overlapping events in a single day
    public static func layoutEvents(_ events: [CalendarEvent]) -> [PositionedEvent] {
        // Exclude all-day events from timed layout
        let timedEvents = events
            .filter { !$0.isAllDay }
            .sorted { (a, b) -> Bool in
                if a.start != b.start {
                    return a.start < b.start
                }
                return a.end > b.end // longer events first
            }

        guard !timedEvents.isEmpty else { return [] }

        // Step 1: Split into clusters of overlapping events
        var clusters: [[CalendarEvent]] = []
        var currentCluster: [CalendarEvent] = []
        var clusterEnd: Date = Date.distantPast

        for event in timedEvents {
            if currentCluster.isEmpty {
                currentCluster.append(event)
                clusterEnd = event.end
            } else if event.start < clusterEnd {
                // Overlaps with the current cluster
                currentCluster.append(event)
                if event.end > clusterEnd {
                    clusterEnd = event.end
                }
            } else {
                // New non-overlapping cluster
                clusters.append(currentCluster)
                currentCluster = [event]
                clusterEnd = event.end
            }
        }
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }

        // Step 2: For each cluster, greedily assign columns
        var result: [PositionedEvent] = []

        for cluster in clusters {
            var columns: [[CalendarEvent]] = []
            var eventColumnMap: [String: Int] = [:]

            for event in cluster {
                var placed = false
                for (colIndex, colEvents) in columns.enumerated() {
                    let lastInCol = colEvents.last!
                    // Check if event starts after or at the end of the last event in this column
                    if event.start >= lastInCol.end {
                        columns[colIndex].append(event)
                        eventColumnMap[event.id] = colIndex
                        placed = true
                        break
                    }
                }

                if !placed {
                    columns.append([event])
                    eventColumnMap[event.id] = columns.count - 1
                }
            }

            let clusterColumnCount = max(1, columns.count)
            for event in cluster {
                let col = eventColumnMap[event.id] ?? 0
                result.append(PositionedEvent(event: event, column: col, totalColumns: clusterColumnCount))
            }
        }

        return result
    }
}
