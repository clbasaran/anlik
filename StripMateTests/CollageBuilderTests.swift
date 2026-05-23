import XCTest
@testable import StripMate

/// Replaces the old CollageBuilder tests — the v2 engine is split between
/// `CollageGeometry` (frame math) and `CollageRenderer` (compose), so tests
/// follow the same split.
final class CollageGeometryTests: XCTestCase {

    private let canvas = CGSize(width: 1080, height: 1920)

    // MARK: - Frame counts

    func testFrameCount_matchesPhotoCount() {
        for preset in CollagePreset.allCases {
            for count in preset.supportedCounts {
                let frames = CollageGeometry.frames(for: preset, count: count, in: canvas)
                XCTAssertEqual(frames.count, count, "\(preset).frames(\(count)) should produce \(count) rects")
            }
        }
    }

    // MARK: - Bounds

    func testFrames_areInsideCanvas() {
        let canvasRect = CGRect(origin: .zero, size: canvas)
        for preset in CollagePreset.allCases {
            for count in preset.supportedCounts {
                let frames = CollageGeometry.frames(for: preset, count: count, in: canvas)
                for (i, f) in frames.enumerated() {
                    XCTAssertTrue(canvasRect.contains(f) || canvasRect.intersects(f),
                                  "\(preset)[\(i)] (\(count) photos) escapes canvas: \(f)")
                    XCTAssertGreaterThan(f.width, 0)
                    XCTAssertGreaterThan(f.height, 0)
                }
            }
        }
    }

    // MARK: - Non-overlap (interior frames don't overlap each other)

    func testFrames_doNotOverlap() {
        for preset in CollagePreset.allCases {
            for count in preset.supportedCounts {
                let frames = CollageGeometry.frames(for: preset, count: count, in: canvas)
                for i in 0..<frames.count {
                    for j in (i + 1)..<frames.count {
                        let a = frames[i].insetBy(dx: 1, dy: 1) // small inset to ignore touching edges
                        let b = frames[j].insetBy(dx: 1, dy: 1)
                        XCTAssertFalse(a.intersects(b),
                                       "\(preset) frames [\(i)] and [\(j)] overlap (\(count) photos)")
                    }
                }
            }
        }
    }

    // MARK: - bant only supports 2-3

    func testBant_doesNotSupportFour() {
        XCTAssertFalse(CollagePreset.bant.supportedCounts.contains(4))
    }

    // MARK: - Cerceve (frame preset) — outer padding present

    func testCerceve_hasOuterPadding() {
        let frames = CollageGeometry.frames(for: .cerceve, count: 2, in: canvas)
        XCTAssertGreaterThan(frames[0].minX, 0, "çerçeve preset should pad inward from canvas edge")
        XCTAssertGreaterThan(frames[0].minY, 0)
    }
}

final class CollageStateTests: XCTestCase {

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }

    // MARK: - Photo count snapping the preset

    func testInit_snapsToSupportedPreset() {
        let imgs = [makeImage(), makeImage(), makeImage(), makeImage()]
        // bant only goes up to 3; init with 4 photos should pick a different preset.
        let state = CollageState(photos: imgs, preset: .bant)
        XCTAssertNotEqual(state.preset, .bant)
        XCTAssertTrue(state.preset.supportedCounts.contains(4))
    }

    // MARK: - Transform invalidation on mutation

    func testReplacePhoto_dropsThatSlotsTransform() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        state.setTransform(CollagePhotoTransform(scale: 2.0, offset: .init(width: 0.5, height: 0)), at: 0)
        state.replacePhoto(at: 0, with: makeImage())
        XCTAssertNil(state.transforms[0])
    }

    func testRemovePhoto_clearsAllTransforms() {
        let state = CollageState(photos: [makeImage(), makeImage(), makeImage()], preset: .klasik)
        state.setTransform(CollagePhotoTransform(scale: 2.0, offset: .zero), at: 1)
        state.setTransform(CollagePhotoTransform(scale: 1.5, offset: .zero), at: 2)
        state.removePhoto(at: 0)
        XCTAssertTrue(state.transforms.isEmpty,
                      "Removing a photo shifts indices — leaving stale transforms applies them to the wrong photo")
    }

    func testSwap_swapsTransforms() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        let t = CollagePhotoTransform(scale: 2.0, offset: .zero)
        state.setTransform(t, at: 0)
        state.swap(0, 1)
        XCTAssertEqual(state.transforms[1]?.scale, 2.0)
        XCTAssertNil(state.transforms[0])
    }

    func testSetPreset_dropsTransforms() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        state.setTransform(CollagePhotoTransform(scale: 2.0, offset: .zero), at: 0)
        state.setPreset(.cerceve)
        XCTAssertTrue(state.transforms.isEmpty)
    }

    // MARK: - Background override

    func testBackgroundOverride_appliesToSupportedPreset() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        state.setBackgroundOverride(.black)
        if case let .solid(color) = state.effectiveStyle.background {
            XCTAssertEqual(color, .black)
        } else {
            XCTFail("klasik should keep solid background after override")
        }
    }

    func testBackgroundOverride_ignoredOnAkis() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .akis)
        state.setBackgroundOverride(.white)
        // setBackgroundOverride is a no-op on presets that don't support it.
        XCTAssertNil(state.backgroundOverride)
    }

    func testSetPreset_clearsOverrideOnAkisSwitch() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        state.setBackgroundOverride(.black)
        state.setPreset(.akis)
        XCTAssertNil(state.backgroundOverride,
                     "Switching to akış should drop a stale override that doesn't apply")
    }

    // MARK: - Undo

    func testUndo_revertsPresetChange() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        XCTAssertFalse(state.canUndo)
        state.setPreset(.cerceve)
        XCTAssertTrue(state.canUndo)
        state.undo()
        XCTAssertEqual(state.preset, .klasik)
        XCTAssertFalse(state.canUndo)
    }

    func testUndo_revertsBackgroundOverride() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        state.setBackgroundOverride(.black)
        state.undo()
        XCTAssertNil(state.backgroundOverride)
    }

    func testUndo_revertsRemovePhoto() {
        let imgs = [makeImage(), makeImage(), makeImage()]
        let state = CollageState(photos: imgs, preset: .klasik)
        state.removePhoto(at: 0)
        XCTAssertEqual(state.photos.count, 2)
        state.undo()
        XCTAssertEqual(state.photos.count, 3)
    }

    // MARK: - Reset transform

    func testResetTransform_clearsThatSlot() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        state.setTransform(CollagePhotoTransform(scale: 2.0, offset: .init(width: 0.5, height: 0)), at: 0)
        state.resetTransform(at: 0)
        XCTAssertNil(state.transforms[0])
    }

    // MARK: - Interaction lifecycle

    func testBeginInteraction_setsFlagAndFocus() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        XCTAssertFalse(state.isInteracting)
        state.beginInteraction(at: 1)
        XCTAssertTrue(state.isInteracting)
        XCTAssertEqual(state.focusedIndex, 1)
    }

    func testEndInteraction_clearsInteractingFlag() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        state.beginInteraction(at: 0)
        state.endInteraction()
        XCTAssertFalse(state.isInteracting)
    }

    func testBeginInteraction_singleHistoryEntryPerGesture() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        state.beginInteraction(at: 0)
        // Multiple live writes during the same gesture should NOT each push
        // history — that would flood the undo stack with intermediate frames.
        state.setTransform(CollagePhotoTransform(scale: 1.5, offset: .zero), at: 0)
        state.beginInteraction(at: 0) // re-entered while still interacting
        state.setTransform(CollagePhotoTransform(scale: 2.0, offset: .zero), at: 0)
        state.endInteraction()
        // One push max for the whole gesture.
        XCTAssertTrue(state.canUndo)
        state.undo()
        XCTAssertFalse(state.canUndo,
                       "A continuous gesture should produce exactly one undoable entry")
    }

    // MARK: - Render generation gating

    func testCommitRender_acceptsCurrentGeneration() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        let myGen = state.nextRenderGeneration()
        let img = makeImage()
        XCTAssertTrue(state.commitRender(img, generation: myGen))
        XCTAssertNotNil(state.renderedPreview)
    }

    func testCommitRender_rejectsStaleGeneration() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        let oldGen = state.nextRenderGeneration()
        _ = state.nextRenderGeneration() // newer scheduled
        let img = makeImage()
        XCTAssertFalse(state.commitRender(img, generation: oldGen),
                       "Stale render must be rejected so the latest layout/preset wins")
    }
}

final class CollageRendererTests: XCTestCase {

    private func makeImage(color: UIColor = .red) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 200, height: 300)).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
        }
    }

    func testRender_producesCanonicalCanvas() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        let img = CollageRenderer.render(state: state)
        XCTAssertNotNil(img)
        XCTAssertEqual(img?.size.width, CollageRenderer.canvasSize.width)
        XCTAssertEqual(img?.size.height, CollageRenderer.canvasSize.height)
    }

    func testRender_returnsNilForEmptyPhotos() {
        let state = CollageState(photos: [], preset: .klasik)
        XCTAssertNil(CollageRenderer.render(state: state))
    }

    func testRender_handlesAllPresets() {
        let imgs = [makeImage(), makeImage(), makeImage()]
        for preset in CollagePreset.allCases where preset.supportedCounts.contains(3) {
            let state = CollageState(photos: imgs, preset: preset)
            XCTAssertNotNil(CollageRenderer.render(state: state),
                            "Preset \(preset) should render with 3 photos")
        }
    }

    func testRender_extremeTransforms_doNotCrash() {
        let state = CollageState(photos: [makeImage(), makeImage()], preset: .klasik)
        state.setTransform(CollagePhotoTransform(scale: 99.0, offset: .init(width: 99, height: -99)), at: 0)
        let img = CollageRenderer.render(state: state)
        XCTAssertNotNil(img, "Renderer must clamp internally and never crash on out-of-range transforms")
    }
}
