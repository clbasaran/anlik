import WidgetKit
import SwiftUI

/// Entry point for the watchOS Widget Extension target (`StripMateWatchWidgets`).
/// Hosts complications surfaced on the watch face and Smart Stack.
@main
struct StripMateWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakComplication()
        PromptComplication()
        PhotoComplication()
    }
}
