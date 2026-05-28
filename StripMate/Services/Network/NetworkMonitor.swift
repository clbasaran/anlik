import Foundation
import Network

/// Monitors network connectivity and provides offline-aware behavior.
@Observable
public final class NetworkMonitor {
    public static let shared = NetworkMonitor()

    public private(set) var isConnected: Bool = true
    public private(set) var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.stripmate.networkmonitor", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
                self?.connectionType = path.availableInterfaces.first?.type
                self?.isExpensive = path.isExpensive || path.isConstrained

                if path.status != .satisfied {
                    AppLogger.network.info("Network unavailable — app will use cached data")
                }
            }
        }
        monitor.start(queue: queue)
    }

    /// Whether the current path is considered expensive (cellular).
    public private(set) var isExpensive: Bool = false

    /// Adaptive JPEG quality based on network type and data saver preference.
    /// - WiFi: 0.92 (high)
    /// - Cellular (4G/LTE): 0.85 (medium)
    /// - Cellular (slow / constrained): 0.75 (low)
    /// - Data Saver enabled: always 0.75
    public var recommendedJPEGQuality: CGFloat {
        let dataSaverEnabled = UserDefaults.standard.bool(forKey: "data_saver_mode")
        if dataSaverEnabled { return 0.75 }

        guard isConnected else { return 0.75 }

        if connectionType == .wifi {
            return 0.92
        }

        // Cellular — if path is constrained (Low Data Mode) or expensive, use lower quality
        if isExpensive {
            return 0.85
        }

        return 0.92
    }

    deinit {
        monitor.cancel()
    }
}
