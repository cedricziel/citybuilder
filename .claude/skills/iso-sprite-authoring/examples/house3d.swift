// Pre-rendered 3D house sprite: procedural SceneKit geometry + PBR + one warm sun,
// rendered through the game's 2:1 isometric camera to a PNG at sprite scale.
//
//   xcrun swift house3d.swift <out-dir> <scale>     # scale 1 -> 128x112, 3 -> 384x336
//
// World axes: x = +col (screen down-right), z = +row (screen down-left), y = up.
// One tile = 4 m. The house sits on a 2x2 footprint, x,z in [0, 8].
// Optional 3rd arg "b" renders the slate-roof variant (house3d-b@Nx.png).
// Reference script, not shipped code: short maths names are kept on purpose.
// swiftlint:disable identifier_name force_try large_tuple
import AppKit
import SceneKit

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "."
let scale = args.count > 2 ? Int(args[2]) ?? 1 : 1
let variantB = args.count > 3 && args[3] == "b"
let supersample = 4
let spriteW = 128, spriteH = 112 // @1x; footprint bottom corner = bottom-centre

// MARK: camera maths (2:1 dimetric)

// Yaw 45 deg puts the tile diagonal horizontal; pitch -30 deg (sin 30 = 1/2) squashes it 2:1.
// A 4 m tile edge projects to 4*sqrt(2) view units across, which must be 64 px.
let tile = 4.0
let pxPerMetre = 64.0 / (2.0.squareRoot() * tile) // 11.31 px/m at @1x
let pitch = -30.0 * .pi / 180, yaw = 45.0 * .pi / 180
let fwd = SCNVector3(-cos(30 * .pi / 180) / 2.0.squareRoot(), -0.5, -cos(30 * .pi / 180) / 2.0.squareRoot())
let up = SCNVector3(-0.5 / 2.0.squareRoot(), cos(30 * .pi / 180), -0.5 / 2.0.squareRoot())

// MARK: deterministic procedural textures

struct LCG {
    var s: UInt64; mutating func next() -> Double {
        s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407; return Double(
            s >> 33
        ) /
            Double(1 << 31)
    }
}

func texture(_ w: Int, _ h: Int, seed: UInt64, _ draw: (CGContext, inout LCG) -> Void) -> CGImage {
    let ctx = CGContext(
        data: nil,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    var rng = LCG(s: seed)
    draw(ctx, &rng)
    return ctx.makeImage()!
}

func speckled(_ r: Double, _ g: Double, _ b: Double, amount: Double, seed: UInt64) -> CGImage {
    texture(128, 128, seed: seed) { ctx, rng in
        ctx.setFillColor(red: r, green: g, blue: b, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
        for _ in 0 ..< 1400 {
            let k = (rng.next() - 0.5) * amount
            ctx.setFillColor(red: r + k, green: g + k, blue: b + k * 0.8, alpha: 1)
            ctx.fill(CGRect(x: rng.next() * 128, y: rng.next() * 128, width: 2, height: 2))
        }
    }
}

let roofTiles = texture(128, 128, seed: 7) { ctx, rng in
    for row in 0 ..< 8 { // courses run along the ridge (texture u); v runs down the slope
        for col in 0 ..< 8 {
            let k = (rng.next() - 0.5) * 0.12
            if variantB { // grey-blue slate
                ctx.setFillColor(red: 0.33 + k, green: 0.34 + k, blue: 0.38 + k, alpha: 1)
            } else { // terracotta
                ctx.setFillColor(red: 0.62 + k, green: 0.24 + k * 0.6, blue: 0.14 + k * 0.4, alpha: 1)
            }
            let off = row % 2 == 0 ? 0.0 : 8.0
            ctx.fill(CGRect(x: Double(col) * 16 + off, y: Double(row) * 16, width: 15, height: 16))
        }
        ctx.setFillColor(red: 0.28, green: 0.10, blue: 0.06, alpha: 1)
        ctx.fill(CGRect(x: 0, y: Double(row) * 16, width: 128, height: 3))
    }
}

func material(_ image: Any, rough: Double, repeatU: Double = 1, repeatV: Double = 1) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = image
    m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
    m.diffuse.contentsTransform = SCNMatrix4MakeScale(CGFloat(repeatU), CGFloat(repeatV), 1)
    m.roughness.contents = rough
    m.metalness.contents = 0.0
    return m
}

let plaster = material(
    variantB ? speckled(0.95, 0.91, 0.82, amount: 0.06, seed: 1) : speckled(0.90, 0.80, 0.64, amount: 0.08, seed: 1),
    rough: 0.9,
    repeatU: 2,
    repeatV: 2
)
let timber = material(speckled(0.28, 0.17, 0.10, amount: 0.06, seed: 2), rough: 0.8)
let stone = material(speckled(0.56, 0.53, 0.49, amount: 0.18, seed: 3), rough: 0.95, repeatU: 3)
let roof = material(roofTiles, rough: 0.7)
// Box faces map u down the slope; rotate so tile courses run parallel to the ridge.
roof.diffuse.contentsTransform = SCNMatrix4Mult(SCNMatrix4MakeRotation(.pi / 2, 0, 0, 1), SCNMatrix4MakeScale(2, 3, 1))
let glass = material(NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1), rough: 0.2)
let litGlass = material(NSColor(red: 0.95, green: 0.62, blue: 0.25, alpha: 1), rough: 0.5)
litGlass.emission.contents = NSColor(red: 1.0, green: 0.62, blue: 0.22, alpha: 1)
let wood = material(speckled(0.55, 0.38, 0.22, amount: 0.1, seed: 4), rough: 0.85)

let scene = SCNScene()
scene.background.contents = NSColor.clear
let root = scene.rootNode

@discardableResult
func box(
    _ w: Double,
    _ h: Double,
    _ l: Double,
    at p: (Double, Double, Double),
    _ m: SCNMaterial,
    rot: SCNVector3 = SCNVector3(0, 0, 0),
    chamfer: Double = 0
) -> SCNNode {
    let g = SCNBox(width: w, height: h, length: l, chamferRadius: chamfer)
    g.materials = [m]
    let n = SCNNode(geometry: g)
    n.position = SCNVector3(p.0, p.1, p.2)
    n.eulerAngles = rot
    root.addChildNode(n)
    return n
}

// MARK: house (body x 0.8..7.2, z 1.2..6.8)

let x0 = 0.8, x1 = 7.2, z0 = 1.2, z1 = 6.8, plinthH = 0.4, wallH = 3.2
let cx = (x0 + x1) / 2, cz = (z0 + z1) / 2, depth = z1 - z0, length = x1 - x0
box(length + 0.2, plinthH, depth + 0.2, at: (cx, plinthH / 2, cz), stone)
box(length, wallH, depth, at: (cx, plinthH + wallH / 2, cz), plaster)
let eave = plinthH + wallH

// Gables: triangle extruded along x
let rise = depth / 2 * tan(40 * .pi / 180)
for gx in [x0 + 0.1, x1 - 0.1] {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: -depth / 2, y: 0)); path.line(to: NSPoint(x: depth / 2, y: 0)); path.line(to: NSPoint(x: 0, y: rise)); path
        .close()
    let shape = SCNShape(path: path, extrusionDepth: 0.2)
    shape.materials = [plaster]
    let n = SCNNode(geometry: shape)
    n.eulerAngles = SCNVector3(0, Double.pi / 2, 0)
    n.position = SCNVector3(gx, eave, cz)
    root.addChildNode(n)
}

// Roof: two tiled slabs, 40 deg pitch, 0.4 m overhang
let slope = (depth / 2) / cos(40 * .pi / 180) + 0.45
for side in [-1.0, 1.0] {
    let midZ = cz + side * depth / 4, midY = eave + rise / 2
    let n = box(
        length + 0.8,
        0.14,
        slope,
        at: (cx, midY + 0.12, midZ + side * 0.1),
        roof,
        rot: SCNVector3(side * 40 * .pi / 180, 0, 0)
    )
    _ = n
}

box(length + 0.8, 0.18, 0.22, at: (cx, eave + rise + 0.12, cz), timber) // ridge beam

/// Timber frame on the two visible walls: +z face (lit) and +x face (shade)
let fz = z1 + 0.03, fx = x1 + 0.03
for px in stride(from: x0, through: x1, by: length / 4) {
    box(0.18, wallH, 0.06, at: (px, plinthH + wallH / 2, fz), timber)
}

for pz in stride(from: z0, through: z1, by: depth / 3) {
    box(0.06, wallH, 0.18, at: (fx, plinthH + wallH / 2, pz), timber)
}

box(length, 0.16, 0.06, at: (cx, plinthH + 1.6, fz), timber)
box(length, 0.16, 0.06, at: (cx, eave - 0.08, fz), timber)
box(0.06, 0.16, depth, at: (fx, plinthH + 1.6, cz), timber)
box(0.06, 0.16, depth, at: (fx, eave - 0.08, cz), timber)
box(0.12, 1.9, 0.05, at: (x0 + 0.8, plinthH + 0.8, fz), timber, rot: SCNVector3(0, 0, -0.75))
box(0.05, 1.9, 0.12, at: (fx, plinthH + 0.8, z0 + 0.7), timber, rot: SCNVector3(0.75, 0, 0))

/// Windows and door
func windowZ(_ x: Double, _ y: Double, lit: Bool) {
    box(0.86, 1.02, 0.05, at: (x, y, fz + 0.01), timber)
    box(0.66, 0.82, 0.05, at: (x, y, fz + 0.03), lit ? litGlass : glass)
}

func windowX(_ z: Double, _ y: Double, lit: Bool) {
    box(0.05, 1.02, 0.86, at: (fx + 0.01, y, z), timber)
    box(0.05, 0.82, 0.66, at: (fx + 0.03, y, z), lit ? litGlass : glass)
}

windowZ(x0 + 1.2, plinthH + 2.4, lit: false); windowZ(x0 + 4.0, plinthH + 2.4, lit: true); windowZ(x0 + 5.4, plinthH + 0.9, lit: false)
windowX(z0 + 1.6, plinthH + 2.4, lit: true); windowX(z0 + 4.0, plinthH + 0.9, lit: false); windowX(z0 + 4.0, plinthH + 2.4, lit: false)
box(1.0, 2.0, 0.08, at: (x0 + 2.6, plinthH + 1.0, fz + 0.02), wood)

// Chimney through the back slope
box(0.6, 2.2, 0.6, at: (x0 + 4.6, eave + rise - 0.2, cz - 0.9), stone)

// Clutter: barrels by the door, a woodpile on the shade side
for (i, bx) in [x0 + 3.5, x0 + 4.1].enumerated() {
    let c = SCNCylinder(radius: 0.28, height: 0.75); c.materials = [wood]
    let n = SCNNode(geometry: c); n.position = SCNVector3(bx, 0.375, z1 + 0.45 + Double(i) * 0.2); root.addChildNode(n)
}

for row in 0 ..< 3 {
    for i in 0 ..< (4 - row) {
        let c = SCNCylinder(radius: 0.14, height: 1.2); c.materials = [wood]
        let n = SCNNode(geometry: c); n.eulerAngles = SCNVector3(Double.pi / 2, 0, 0)
        n.position = SCNVector3(x1 + 0.45, 0.14 + Double(row) * 0.25, z0 + 1.0 + Double(i) * 0.3 + Double(row) * 0.15)
        root.addChildNode(n)
    }
}

// Shadow catcher ground (only the shadow ends up in the sprite)
let ground = SCNFloor(); ground.reflectivity = 0
let gm = SCNMaterial(); gm.lightingModel = .shadowOnly; ground.materials = [gm]
root.addChildNode(SCNNode(geometry: ground))

// MARK: light rig: one warm low sun (upper-left of screen) + cool sky fill

let sun = SCNLight(); sun.type = .directional
sun.color = NSColor(red: 1.0, green: 0.84, blue: 0.64, alpha: 1); sun.intensity = 2600
sun.castsShadow = true; sun.shadowMapSize = CGSize(width: 4096, height: 4096)
sun.shadowSampleCount = 16; sun.shadowRadius = 4; sun.orthographicScale = 14
sun.shadowColor = NSColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 0.55)
let sunNode = SCNNode(); sunNode.light = sun
sunNode.position = SCNVector3(4 - 9, 30, 4 + 9) // high-ish sun from screen left; keeps the cast shadow inside 128 px
sunNode.look(at: SCNVector3(4, 0, 4))
root.addChildNode(sunNode)
let sky = SCNLight(); sky.type = .ambient; sky.color = NSColor(red: 0.66, green: 0.68, blue: 0.78, alpha: 1); sky.intensity = 480
let skyNode = SCNNode(); skyNode.light = sky; root.addChildNode(skyNode)

// MARK: camera

let cam = SCNCamera()
cam.usesOrthographicProjection = true
cam.orthographicScale = Double(spriteH) / 2 / pxPerMetre // half the view height in metres
cam.zNear = 1; cam.zFar = 200
cam.screenSpaceAmbientOcclusionIntensity = 1.4
cam.screenSpaceAmbientOcclusionRadius = 0.5
cam.wantsHDR = true
cam.exposureOffset = -0.3
let camNode = SCNNode(); camNode.camera = cam
camNode.eulerAngles = SCNVector3(pitch, yaw, 0)
let anchor = SCNVector3(8, 0, 8) // footprint bottom corner -> sprite bottom-centre
let half = Double(spriteH) / 2 / pxPerMetre
camNode.position = SCNVector3(
    anchor.x + up.x * half - fwd.x * 60,
    anchor.y + up.y * half - fwd.y * 60,
    anchor.z + up.z * half - fwd.z * 60
)
root.addChildNode(camNode)

// MARK: render supersampled, downsample, write PNG

let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
renderer.scene = scene
renderer.pointOfView = camNode
let bigW = spriteW * scale * supersample, bigH = spriteH * scale * supersample
let snap = renderer.snapshot(atTime: 0, with: CGSize(width: bigW, height: bigH), antialiasingMode: .multisampling4X)
var rect = CGRect(x: 0, y: 0, width: bigW, height: bigH)
let big = snap.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
let outW = spriteW * scale, outH = spriteH * scale
let ctx = CGContext(
    data: nil,
    width: outW,
    height: outH,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.interpolationQuality = .high
ctx.draw(big, in: CGRect(x: 0, y: 0, width: outW, height: outH))
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
let url = URL(fileURLWithPath: "\(outDir)/house3d\(variantB ? "-b" : "")@\(scale)x.png")
try! rep.representation(using: .png, properties: [:])!.write(to: url)
print("wrote \(url.path) \(outW)x\(outH)")

// swiftlint:enable identifier_name force_try large_tuple
