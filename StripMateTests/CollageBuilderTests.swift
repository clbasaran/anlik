import XCTest
@testable import StripMate

final class CollageBuilderTests: XCTestCase {

    func testCellFramesForTwoHorizontal() {
        let size = CGSize(width: 1080, height: 1920)
        let frames = CollageBuilder.cellFrames(for: .twoHorizontal, in: size, gap: 4)
        XCTAssertEqual(frames.count, 2)
        // Both cells should have full height
        XCTAssertEqual(frames[0].height, 1920)
        XCTAssertEqual(frames[1].height, 1920)
        // Total width + gap should equal canvas width
        let totalWidth = frames[0].width + 4 + frames[1].width
        XCTAssertEqual(totalWidth, 1080, accuracy: 0.1)
    }

    func testCellFramesForFourGrid() {
        let size = CGSize(width: 1080, height: 1920)
        let frames = CollageBuilder.cellFrames(for: .fourGrid, in: size, gap: 4)
        XCTAssertEqual(frames.count, 4)
        // All cells should be roughly equal size
        let firstWidth = frames[0].width
        for frame in frames {
            XCTAssertEqual(frame.width, firstWidth, accuracy: 0.1)
        }
    }

    func testLayoutCountsMatchPhotoCount() {
        for layout in CollageLayout.allCases {
            let size = CGSize(width: 1080, height: 1920)
            let frames = CollageBuilder.cellFrames(for: layout, in: size, gap: 4)
            XCTAssertEqual(frames.count, layout.photoCount, "Layout \(layout.id) should have \(layout.photoCount) frames")
        }
    }

    func testAllAspectRatios() {
        for ratio in CollageAspectRatio.allCases {
            XCTAssertGreaterThan(ratio.width, 0)
            XCTAssertGreaterThan(ratio.height, 0)
            XCTAssertEqual(ratio.ratio, ratio.width / ratio.height, accuracy: 0.001)
        }
    }

    func testPhotoTransformIdentity() {
        let identity = PhotoTransform.identity
        XCTAssertEqual(identity.offset, .zero)
        XCTAssertEqual(identity.scale, 1.0)
    }

    func testLayoutsForCount() {
        let twoLayouts = CollageLayout.layouts(for: 2)
        XCTAssertTrue(twoLayouts.allSatisfy { $0.photoCount == 2 })
        XCTAssertGreaterThanOrEqual(twoLayouts.count, 2)

        let threeLayouts = CollageLayout.layouts(for: 3)
        XCTAssertTrue(threeLayouts.allSatisfy { $0.photoCount == 3 })

        let fourLayouts = CollageLayout.layouts(for: 4)
        XCTAssertTrue(fourLayouts.allSatisfy { $0.photoCount == 4 })
    }

    func testBuildReturnsNilWithInsufficientPhotos() {
        let smallImage = createTestImage(width: 100, height: 100)
        // fourGrid needs 4 photos but we only provide 1
        let result = CollageBuilder.build(images: [smallImage], layout: .fourGrid)
        XCTAssertNil(result)
    }

    func testBuildReturnsImageWithSufficientPhotos() {
        let img1 = createTestImage(width: 200, height: 300)
        let img2 = createTestImage(width: 200, height: 300)
        let result = CollageBuilder.build(images: [img1, img2], layout: .twoHorizontal)
        XCTAssertNotNil(result)
        // Output should be 1080x1920 (portrait default)
        XCTAssertEqual(result?.size.width, 1080)
        XCTAssertEqual(result?.size.height, 1920)
    }

    func testBuildWithDifferentAspectRatios() {
        let img1 = createTestImage(width: 200, height: 300)
        let img2 = createTestImage(width: 200, height: 300)

        let portrait = CollageBuilder.build(images: [img1, img2], layout: .twoHorizontal, aspectRatio: .portrait)
        XCTAssertEqual(portrait?.size.width, 1080)
        XCTAssertEqual(portrait?.size.height, 1920)

        let square = CollageBuilder.build(images: [img1, img2], layout: .twoHorizontal, aspectRatio: .square)
        XCTAssertEqual(square?.size.width, 1080)
        XCTAssertEqual(square?.size.height, 1080)

        let instagram = CollageBuilder.build(images: [img1, img2], layout: .twoHorizontal, aspectRatio: .instagram)
        XCTAssertEqual(instagram?.size.width, 1080)
        XCTAssertEqual(instagram?.size.height, 1350)
    }

    // MARK: - Helpers

    private func createTestImage(width: Int, height: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
