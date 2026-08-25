import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import KittenTag

final class CoverOptimizerTests: XCTestCase {
    func testProducesRequestedSquareJPEG() throws {
        let input = try makeImage(width: 1_600, height: 900, type: .png)
        let output = try CoverOptimizer.optimize(input, size: 1_000, format: .jpeg)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))

        XCTAssertEqual(image.width, 1_000)
        XCTAssertEqual(image.height, 1_000)
        XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.jpeg")
    }

    func testClampsOutputSizeToSupportedRange() throws {
        let input = try makeImage(width: 600, height: 600, type: .jpeg)
        let output = try CoverOptimizer.optimize(input, size: 100, format: .png)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))

        XCTAssertEqual(image.width, 500)
        XCTAssertEqual(image.height, 500)
        XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.png")
    }

    private func makeImage(width: Int, height: Int, type: UTType) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
