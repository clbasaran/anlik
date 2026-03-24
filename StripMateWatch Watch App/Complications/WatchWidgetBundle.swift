import WidgetKit
import SwiftUI

/// Widget bundle for watch complications.
/// NOTE: This requires a separate watchOS Widget Extension target in Xcode.
/// The target's entry point should use @main with this bundle.
struct StripMateWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakComplication()
        PromptComplication()
    }
}
