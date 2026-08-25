import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CoverOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg = "JPEG"
    case png = "PNG"

    var id: Self { self }

    fileprivate var type: UTType {
        switch self {
        case .jpeg: .jpeg
        case .png: .png
        }
    }
}

enum CoverOptimizer {
    static let sizeRange = 500...4_000

    static func optimize(
        _ data: Data,
        size requestedSize: Int,
        format: CoverOutputFormat,
        jpegQuality: Double = 0.86
    ) throws -> Data {
        let size = min(max(requestedSize, sizeRange.lowerBound), sizeRange.upperBound)
        guard let input = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw CoverOptimizationError.invalidImage
        }

        let extent = input.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            throw CoverOptimizationError.invalidImage
        }

        let squareSide = min(extent.width, extent.height)
        let cropRect = CGRect(
            x: extent.midX - squareSide / 2,
            y: extent.midY - squareSide / 2,
            width: squareSide,
            height: squareSide
        )
        let cropped = input.cropped(to: cropRect).transformed(
            by: CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY)
        )
        let scale = CGFloat(size) / squareSide
        let scaled = cropped.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let renderRect = CGRect(x: 0, y: 0, width: size, height: size)

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let context = CIContext(options: [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace,
            .cacheIntermediates: false
        ])
        guard let image = context.createCGImage(
            scaled,
            from: renderRect,
            format: .RGBA8,
            colorSpace: colorSpace
        ) else {
            throw CoverOptimizationError.renderFailed
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            format.type.identifier as CFString,
            1,
            nil
        ) else {
            throw CoverOptimizationError.encodeFailed
        }

        var properties: [CFString: Any] = [:]
        if format == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality] = min(max(jpegQuality, 0.5), 1)
            properties[kCGImagePropertyJFIFDictionary] = [kCGImagePropertyJFIFIsProgressive: false]
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CoverOptimizationError.encodeFailed
        }
        return output as Data
    }
}

enum CoverOptimizationError: LocalizedError {
    case invalidImage
    case renderFailed
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: L10n.string("Kapak görseli okunamadı.")
        case .renderFailed: L10n.string("Kapak görseli yeniden boyutlandırılamadı.")
        case .encodeFailed: L10n.string("Optimize edilmiş kapak oluşturulamadı.")
        }
    }
}
