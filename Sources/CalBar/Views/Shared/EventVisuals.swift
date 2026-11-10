import SwiftUI

/// Applies the "already happened" treatment to an event chip.
///
/// `.blur(radius: 0)` still forces SwiftUI into an offscreen rendering pass for every event on
/// screen, so when the preference is off the modifier is skipped entirely rather than applied
/// with a zero radius.
private struct PastEventTreatment: ViewModifier {
    let isPassed: Bool
    let blurRadius: CGFloat

    func body(content: Content) -> some View {
        if isPassed && blurRadius > 0 {
            content.blur(radius: blurRadius)
        } else {
            content
        }
    }
}

extension View {
    public func pastEventTreatment(isPassed: Bool, blurRadius: CGFloat) -> some View {
        modifier(PastEventTreatment(isPassed: isPassed, blurRadius: blurRadius))
    }
}
