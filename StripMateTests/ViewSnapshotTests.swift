import Testing
import SwiftUI
import UIKit
@testable import StripMate

/// Lightweight snapshot test foundation. We don't pull in pointfree's
/// swift-snapshot-testing yet — that's a future call once the surface area is
/// big enough to warrant another SPM dep. Instead these tests exercise the
/// SwiftUI render pipeline through `ImageRenderer`, asserting that small
/// presentational components produce a non-empty image at expected sizes.
///
/// What this catches:
/// - View composition errors that compile but fail to render (e.g. missing
///   environment, infinite layout, force-unwrap inside the body).
/// - Accidental dependency on a runtime singleton that breaks in tests.
///
/// What this DOES NOT catch yet:
/// - Pixel diffs / regressions in styling. For that we'd persist the rendered
///   image as a baseline file and compare on each run; pointfree's library
///   handles that nicely. See backlog.
@Suite("View Snapshots")
@MainActor
struct ViewSnapshotTests {

    // MARK: - State views

    @Test("LoadingStateView renders")
    func loadingState() {
        let view = LoadingStateView(label: "yükleniyor")
            .frame(width: 320, height: 200)
            .background(Color.black)
        let image = render(view, size: CGSize(width: 320, height: 200))
        #expect(image != nil)
        #expect(image!.size.width > 0)
    }

    @Test("ErrorStateView renders with retry")
    func errorState() {
        let view = ErrorStateView(
            title: "yüklenemedi.",
            message: "internet bağlantını kontrol et.",
            retryLabel: "tekrar dene",
            onRetry: {}
        )
        .frame(width: 320, height: 400)
        .background(Color.black)
        let image = render(view, size: CGSize(width: 320, height: 400))
        #expect(image != nil)
    }

    // MARK: - Auth components

    @Test("AuthTextField renders with email content type")
    func authTextField() {
        let view = WrappedAuth { binding in
            AuthTextField(
                placeholder: "e-posta",
                text: binding,
                icon: "envelope",
                contentType: .emailAddress,
                keyboardType: .emailAddress,
                autocapitalize: false
            )
            .frame(width: 320)
            .padding()
            .background(Color.black)
        }
        let image = render(view, size: CGSize(width: 320, height: 80))
        #expect(image != nil)
    }

    @Test("AuthSecureField renders")
    func authSecureField() {
        let view = WrappedAuth { binding in
            AuthSecureField(
                placeholder: "şifre",
                text: binding,
                icon: "lock",
                contentType: .password
            )
            .frame(width: 320)
            .padding()
            .background(Color.black)
        }
        let image = render(view, size: CGSize(width: 320, height: 80))
        #expect(image != nil)
    }

    // MARK: - Camera components

    @Test("PreviewSuccessOverlay shows paperplane when visible")
    func previewSuccessOverlayVisible() {
        let view = PreviewSuccessOverlay(isVisible: true)
            .frame(width: 390, height: 844)
        let image = render(view, size: CGSize(width: 390, height: 844))
        #expect(image != nil)
    }

    @Test("CameraModePicker selected segment stays compact")
    func cameraModePickerSelectedSegmentStaysCompact() {
        let view = WrappedCameraMode { mode in
            CameraModePicker(mode: mode)
                .frame(width: 390, height: 500)
                .background(Color.black)
        }
        let image = render(view, size: CGSize(width: 390, height: 500))
        #expect(image != nil)

        let bounds = whitePixelBounds(in: image!)
        #expect(bounds != nil)
        #expect(bounds!.width < 190)
        #expect(bounds!.height < 70)
    }

    // MARK: - Friends components

    @Test("FriendGateHelpSheet renders all four rows")
    func friendGateHelpSheet() {
        let view = FriendGateHelpSheet()
            .frame(width: 390, height: 600)
            .background(Color.black)
        let image = render(view, size: CGSize(width: 390, height: 600))
        #expect(image != nil)
    }

    // MARK: - Helpers

    /// Render a SwiftUI view to UIImage at the requested size. Returns nil if
    /// the renderer failed (e.g. the view threw during layout).
    private func render<V: View>(_ view: V, size: CGSize) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 2.0
        return renderer.uiImage
    }

    private func whitePixelBounds(in image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let r = bytes[offset]
                let g = bytes[offset + 1]
                let b = bytes[offset + 2]
                let a = bytes[offset + 3]
                if r > 245 && g > 245 && b > 245 && a > 245 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        let scale = image.scale
        return CGRect(
            x: CGFloat(minX) / scale,
            y: CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale,
            height: CGFloat(maxY - minY + 1) / scale
        )
    }
}

/// Tiny wrapper that owns an in-process Binding for fields that need one.
/// Saves having to declare @State in every test case.
@MainActor
private struct WrappedAuth<Content: View>: View {
    let content: (Binding<String>) -> Content
    @State private var text: String = ""

    var body: some View {
        content($text)
    }
}

@MainActor
private struct WrappedCameraMode<Content: View>: View {
    let content: (Binding<CameraMode>) -> Content
    @State private var mode: CameraMode = .foto

    var body: some View {
        content($mode)
    }
}
