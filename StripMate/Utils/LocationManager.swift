import Foundation
import CoreLocation
import Combine
import MapKit

@MainActor
public final class LocationManager: NSObject, ObservableObject {
    public static let shared = LocationManager()

    private let manager = CLLocationManager()

    @Published public var lastLocation: CLLocation?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        self.authorizationStatus = manager.authorizationStatus
    }

    public func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    private func startTracking() {
        manager.startUpdatingLocation()
    }

    public func fetchLocation() async -> (CLLocation?, String?) {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return (nil, nil)
        }

        manager.startUpdatingLocation()

        var count = 0
        while count < 6 {
            if let loc = manager.location, abs(loc.timestamp.timeIntervalSinceNow) <= 30 {
                break
            }
            try? await Task.sleep(for: .milliseconds(500))
            count += 1
        }

        guard let location = manager.location else {
            manager.stopUpdatingLocation()
            return (nil, nil)
        }

        manager.stopUpdatingLocation()

        let cityName = await reverseGeocode(location)
        return (location, cityName)
    }

    public func reverseGeocode(_ location: CLLocation) async -> String? {
        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = nil
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
            request.resultTypes = .address

            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            if let item = response.mapItems.first {
                // Extract city from address components
                if let locality = item.placemark.locality {
                    return locality
                } else if let area = item.placemark.administrativeArea {
                    return area
                } else if let country = item.placemark.country {
                    return country
                }
                return item.name
            }
        } catch {
            #if DEBUG
            print("Geocoding failed: \(error.localizedDescription)")
            #endif
        }
        return nil
    }
}

extension LocationManager: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.lastLocation = locations.last

        if let location = locations.last {
            let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
            sharedDefaults?.set(location.coordinate.latitude, forKey: "user_last_lat")
            sharedDefaults?.set(location.coordinate.longitude, forKey: "user_last_lon")
        }
    }
}
