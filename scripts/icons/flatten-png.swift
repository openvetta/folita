// ictool 导出 16 位 PNG，体积约为 8 位的 2.5 倍；图标显示不需要 16 位精度，原地转为 8 位 RGBA。
import CoreGraphics
import Foundation
import ImageIO

for path in CommandLine.arguments.dropFirst() {
    let url = URL(filePath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
              space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
    else { fatalError("cannot read \(path)") }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let output = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { fatalError("cannot convert \(path)") }
    CGImageDestinationAddImage(destination, output, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("cannot write \(path)") }
}
