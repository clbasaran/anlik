import WidgetKit
import SwiftUI

@main
struct StripMateWidgetBundle: WidgetBundle {

    var body: some Widget {
        StripMateWidget()
        PartnerWidget()
        QRCodeWidget()

        if #available(iOS 18.0, *) {
            StripMateControls()
        }
    }
}
