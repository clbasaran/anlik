import SwiftUI
import MapKit

/// Monochrome map popup showing where a strip was taken.
/// Presented as a bottom sheet from PhotoDetailView.
struct StripLocationMapView: View {
    let latitude: Double
    let longitude: Double
    let cityName: String?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var cameraPosition: MapCameraPosition
    @State private var pulseScale: CGFloat = 1.0
    
    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double, cityName: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.cityName = cityName
        self._cameraPosition = State(
            wrappedValue: .camera(
                MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    distance: 2500,
                    heading: 0,
                    pitch: 0
                )
            )
        )
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Map
            Map(position: $cameraPosition) {
                Annotation("", coordinate: coordinate) {
                    locationPin
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControlVisibility(.hidden)
            .colorScheme(.dark)
            .ignoresSafeArea()
            
            // Top bar overlay
            VStack(spacing: 0) {
                headerBar
                Spacer()
            }
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .environment(\.colorScheme, .dark)
            }
            .accessibilityLabel("Kapat")

            Spacer()
            
            // City name label
            HStack(spacing: 6) {
                Image(systemName: "mappin")
                    .font(.system(size: 11, weight: .semibold))
                Text(cityName ?? "konum")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            
            Spacer()
            
            // Balance spacer
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Location Pin (Monochrome)
    
    private var locationPin: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                .frame(width: 48, height: 48)
                .scaleEffect(pulseScale)
                .opacity(2.0 - Double(pulseScale))
            
            // Middle ring
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 32, height: 32)
            
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                .frame(width: 32, height: 32)
            
            // Center dot
            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .shadow(color: .white.opacity(0.4), radius: 6, x: 0, y: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.4
            }
        }
    }
}
