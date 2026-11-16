import UIKit

class ImageProcessing {

    /**
     * Resizes a UIImage to targetSize (80x80) and converts to 16-bit RGB565 Little-Endian bytes
     */
    static func convertToRgb565(image: UIImage, targetSize: Int = 80) -> Data {
        let size = CGSize(width: targetSize, height: targetSize)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        guard let cgImage = scaledImage.cgImage else { return Data() }

        let width = targetSize
        let height = targetSize
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var rawPixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: &rawPixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return Data()
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var outputData = Data(capacity: width * height * 2)

        for i in 0..<(width * height) {
            let offset = i * 4
            let r = UInt16(rawPixels[offset]) >> 3       // 5 bits red
            let g = UInt16(rawPixels[offset + 1]) >> 2   // 6 bits green
            let b = UInt16(rawPixels[offset + 2]) >> 3   // 5 bits blue

            let rgb565 = (r << 11) | (g << 5) | b
            var leValue = rgb565.littleEndian
            withUnsafeBytes(of: &leValue) { ptr in
                outputData.append(contentsOf: ptr)
            }
        }

        return outputData
    }

    /**
     * Splits raw RGB565 data into chunk packets with headers:
     * Header: [chunkIndex: UInt16 LE] [totalChunks: UInt16 LE] [payload bytes]
     */
    static func createChunks(rawData: Data, chunkSize: Int = 480) -> [Data] {
        let totalCount = rawData.count
        let totalChunks = UInt16((totalCount + chunkSize - 1) / chunkSize)
        var chunks: [Data] = []

        for i in 0..<totalChunks {
            let offset = Int(i) * chunkSize
            let length = min(chunkSize, totalCount - offset)
            let subdata = rawData.subdata(in: offset..<(offset + length))

            var packet = Data(capacity: 4 + length)
            var indexLE = UInt16(i).littleEndian
            var totalLE = totalChunks.littleEndian

            withUnsafeBytes(of: &indexLE) { packet.append(contentsOf: $0) }
            withUnsafeBytes(of: &totalLE) { packet.append(contentsOf: $0) }
            packet.append(subdata)

            chunks.append(packet)
        }

        return chunks
    }

    /**
     * Generates a sleek gradient banner image for custom text marquee
     */
    static func createBannerArtwork(text: String, size: Int = 80) -> UIImage {
        let targetSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { ctx in
            // Draw background gradient
            let colors = [UIColor(red: 0.06, green: 0.72, blue: 0.51, alpha: 1.0).cgColor,
                          UIColor(red: 0.02, green: 0.31, blue: 0.23, alpha: 1.0).cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])

            // Draw text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]

            let displayText = text.count > 16 ? String(text.prefix(13)) + "..." : text
            let textSize = displayText.size(withAttributes: attrs)
            let textRect = CGRect(
                x: 4,
                y: (CGFloat(size) - textSize.height) / 2.0,
                width: CGFloat(size) - 8,
                height: textSize.height
            )
            displayText.draw(in: textRect, withAttributes: attrs)
        }
    }
}
