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
                
                if path.status != .satisfied {
                    #if DEBUG
                    print("DEBUG: Network unavailable — app will use cached data")
                    #endif
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
