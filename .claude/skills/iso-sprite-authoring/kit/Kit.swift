// isokit: camera, light rig and renderer shared by every building.
//
// World axes: x = +col (screen down-right), z = +row (screen down-left), y = up.
// One tile = 4 m. A footprint of n x n tiles spans x, z in [0, 4n].
import AppKit
import SceneKit

extension SCNVector3 {
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func * (lhs: SCNVector3, rhs: CGFloat) -> SCNVector3 {
        SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    func dot(_ other: SCNVector3) -> CGFloat {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: SCNVector3) -> SCNVector3 {
        SCNVector3(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x)
    }

    var length: CGFloat {
        dot(self).squareRoot()
    }

    var normalized: SCNVector3 {
        self * (1 / max(length, 1e-9))
    }
}

/// 2:1 dimetric projection. Yaw 45 deg puts the tile diagonal horizontal; pitch -30 deg
/// (sin 30 = 1/2) squashes it 2:1. A 4 m tile edge projects to 4*sqrt(2) view units = 64 px.
enum Iso {
    static let tileMetres: CGFloat = 4
    static let pxPerMetre: CGFloat = 64 / (CGFloat(2).squareRoot() * tileMetres)
    static let cos30: CGFloat = .init(3).squareRoot() / 2
    static let invRoot2: CGFloat = 1 / CGFloat(2).squareRoot()
    static let forward = SCNVector3(-cos30 * invRoot2, -0.5, -cos30 * invRoot2)
    static let up = SCNVector3(-0.5 * invRoot2, cos30, -0.5 * invRoot2)
}

/// One atlas cell: n x n footprint, 64n px wide, `heightPx` tall at @1x.
/// The footprint's bottom corner sits at the cell's bottom-centre (SpriteKit anchor (0.5, 0)).
struct SpriteCell {
    let footprint: Int
    let heightPx: Int
    var widthPx: Int {
        64 * footprint
    }

    var sizeMetres: CGFloat {
        CGFloat(footprint) * Iso.tileMetres
    }
}

enum Rig {
    /// One warm sun from screen upper-left, high enough that the cast shadow stays in the cell,
    /// plus a cool sky fill. Shared by every building so they light identically.
    static func add(to root: SCNNode, cell: SpriteCell) {
        let centre = SCNVector3(cell.sizeMetres / 2, 0, cell.sizeMetres / 2)
        let sun = SCNLight()
        sun.type = .directional
        sun.color = NSColor(red: 1.0, green: 0.84, blue: 0.64, alpha: 1)
        sun.intensity = 2600
        sun.castsShadow = true
        sun.shadowMapSize = CGSize(width: 4096, height: 4096)
        sun.shadowSampleCount = 16
        sun.shadowRadius = 4
        sun.orthographicScale = cell.sizeMetres * 1.6
        sun.shadowColor = NSColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 0.55)
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.position = centre + SCNVector3(-9, 30, 9)
        sunNode.look(at: centre)
        root.addChildNode(sunNode)

        let sky = SCNLight()
        sky.type = .ambient
        sky.color = NSColor(red: 0.66, green: 0.68, blue: 0.78, alpha: 1)
        sky.intensity = 480
        let skyNode = SCNNode()
        skyNode.light = sky
        root.addChildNode(skyNode)
    }

    /// Ground that only receives shadow, so the cast shadow lands in the sprite's alpha.
    static func shadowCatcher() -> SCNNode {
        let floor = SCNFloor()
        floor.reflectivity = 0
        let material = SCNMaterial()
        material.lightingModel = .shadowOnly
        floor.materials = [material]
        return SCNNode(geometry: floor)
    }

    static func camera(for cell: SpriteCell) -> SCNNode {
        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.projectionDirection = .vertical
        let halfHeight = CGFloat(cell.heightPx) / 2 / Iso.pxPerMetre
        cam.orthographicScale = Double(halfHeight)
        cam.zNear = 1
        cam.zFar = 300
        // SSAO samples with per-run noise, so renders differ by up to 32/255 between runs.
        // ISOKIT_SSAO=0 turns it off for byte-identical output.
        let ssao = ProcessInfo.processInfo.environment["ISOKIT_SSAO"] != "0"
        cam.screenSpaceAmbientOcclusionIntensity = ssao ? 1.4 : 0
        cam.screenSpaceAmbientOcclusionRadius = 0.5
        cam.wantsHDR = true
        cam.exposureOffset = -0.3
        let node = SCNNode()
        node.camera = cam
        node.eulerAngles = SCNVector3(-CGFloat.pi / 6, CGFloat.pi / 4, 0)
        let anchor = SCNVector3(cell.sizeMetres, 0, cell.sizeMetres)
        node.position = anchor + Iso.up * halfHeight - Iso.forward * 80
        return node
    }
}

enum Renderer {
    static let supersample = 4

    /// Renders `root` into a cell at `scale`, supersampled 4x and downsampled. Returns seconds taken.
    @discardableResult
    static func render(_ root: SCNNode, cell: SpriteCell, scale: Int, to url: URL) throws -> Double {
        let start = Date()
        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        scene.rootNode.addChildNode(root)
        let camera = Rig.camera(for: cell)
        scene.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        let bigSize = CGSize(width: cell.widthPx * scale * supersample, height: cell.heightPx * scale * supersample)
        let snap = renderer.snapshot(atTime: 0, with: bigSize, antialiasingMode: .multisampling4X)
        var rect = CGRect(origin: .zero, size: bigSize)
        guard let big = snap.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw KitError.render(url.lastPathComponent)
        }
        let outW = cell.widthPx * scale, outH = cell.heightPx * scale
        guard let ctx = CGContext(
            data: nil, width: outW, height: outH, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else { throw KitError.render(url.lastPathComponent) }
        ctx.interpolationQuality = .high
        ctx.draw(big, in: CGRect(x: 0, y: 0, width: outW, height: outH))
        guard let image = ctx.makeImage(),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw KitError.render(url.lastPathComponent) }
        try png.write(to: url)
        return Date().timeIntervalSince(start)
    }
}

enum KitError: Error {
    case render(String)
}
