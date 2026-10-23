import AppKit
import SceneKit

public enum RenderError: Error, CustomStringConvertible {
    case noMetalDevice
    case snapshot(String)
    case write(String)

    public var description: String {
        switch self {
        case .noMetalDevice: "no Metal device: IsoKit renders need a Mac GPU"
        case let .snapshot(what): "could not render \(what)"
        case let .write(path): "could not write \(path)"
        }
    }
}

public enum Renderer {
    static let supersample = 4

    /// Renders `root` into its cell at `scale`, supersampled 4x and downsampled with high-quality filtering.
    public static func image(_ root: SCNNode, cell: SpriteCell, scale: Int) throws -> CGImage {
        guard let device = MTLCreateSystemDefaultDevice() else { throw RenderError.noMetalDevice }
        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        scene.rootNode.addChildNode(root)
        let camera = Rig.camera(for: cell)
        scene.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        let bigSize = CGSize(width: cell.widthPx * scale * supersample, height: cell.heightPx * scale * supersample)
        let snap = renderer.snapshot(atTime: 0, with: bigSize, antialiasingMode: .multisampling4X)
        var rect = CGRect(origin: .zero, size: bigSize)
        guard let big = snap.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw RenderError.snapshot("\(cell.widthPx)x\(cell.heightPx)@\(scale)x")
        }
        let ctx = try canvas(width: cell.widthPx * scale, height: cell.heightPx * scale)
        ctx.interpolationQuality = .high
        ctx.draw(big, in: CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
        guard let image = ctx.makeImage() else { throw RenderError.snapshot("downsample") }
        return image
    }

    /// `overlay` drawn over `base`, both the same size.
    public static func composite(_ base: CGImage, _ overlay: CGImage) throws -> CGImage {
        let ctx = try canvas(width: base.width, height: base.height)
        let rect = CGRect(x: 0, y: 0, width: base.width, height: base.height)
        ctx.draw(base, in: rect)
        ctx.draw(overlay, in: rect)
        guard let image = ctx.makeImage() else { throw RenderError.snapshot("composite") }
        return image
    }

    public static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw RenderError.write(url.path)
        }
        try png.write(to: url)
    }

    /// Whether any pixel of `image` is at least half opaque, the content gate's test for an empty frame.
    public static func hasVisiblePixel(_ image: CGImage) -> Bool {
        guard let ctx = try? canvas(width: image.width, height: image.height), let data = ctx.data else { return false }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: ctx.bytesPerRow * image.height)
        return stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] >= 128 }
    }

    static func canvas(width: Int, height: Int) throws -> CGContext {
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else { throw RenderError.snapshot("canvas \(width)x\(height)") }
        return ctx
    }
}
