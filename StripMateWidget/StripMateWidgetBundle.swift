import WidgetKit
import SwiftUI

@main
struct StripMateWidgetBundle: WidgetBundle {
    
    var body: some Widget {
        StripMateWidget()
        QRCodeWidget()
        
        if #available(iOS 18.0, *) {
            StripMateControls()
        }
    }
}
