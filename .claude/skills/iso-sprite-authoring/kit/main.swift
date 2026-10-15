// isokit CLI: render every building, construction stage and moving-part frame.
//
//   xcrun swiftc -o <bin> kit/*.swift && <bin> <out-dir> [scales, default 1,2,3]
//
// Writes <name>@<s>x.png, <name>-stage<k>@<s>x.png, <name>-<part>-<f>@<s>x.png and timings.txt.
import AppKit
import SceneKit

func scene(for building: Building, stage: Int, withGround: Bool) -> SCNNode {
    let kit = Builder()
    building.build(kit, stage)
    let root = SCNNode()
    root.addChildNode(kit.root)
    Rig.add(to: root, cell: building.cell)
    if withGround { root.addChildNode(Rig.shadowCatcher()) }
    return root
}

/// Overlay frame: the building writes depth only (it occludes and shadows the part but is not drawn).
func movingFrame(for building: Building, part: MovingPart, frame: Int) -> SCNNode {
    let root = scene(for: building, stage: building.stages, withGround: false)
    root.enumerateHierarchy { node, _ in
        node.geometry?.materials.forEach { $0.colorBufferWriteMask = [] }
    }
    let kit = Builder()
    part.build(kit, frame)
    root.addChildNode(kit.root)
    return root
}

let arguments = CommandLine.arguments
let outDir = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : ".")
let scales = (arguments.count > 2 ? arguments[2] : "1,2,3").split(separator: ",").compactMap { Int($0) }
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
var log: [String] = []

func emit(_ root: SCNNode, _ cell: SpriteCell, _ name: String) throws {
    for scale in scales {
        let seconds = try Renderer.render(root, cell: cell, scale: scale, to: outDir.appendingPathComponent("\(name)@\(scale)x.png"))
        log.append(String(format: "%@ @%dx %.2fs", name, scale, seconds))
    }
}

let started = Date()
for building in Buildings.all {
    try emit(scene(for: building, stage: building.stages, withGround: true), building.cell, building.name)
    for stage in 0 ..< building.stages {
        try emit(scene(for: building, stage: stage, withGround: true), building.cell, "\(building.name)-stage\(stage)")
    }
    if let part = building.moving {
        for frame in 0 ..< part.frames {
            try emit(movingFrame(for: building, part: part, frame: frame), building.cell, "\(building.name)-\(part.name)-\(frame)")
        }
    }
}

log.append(String(format: "total %.1fs", Date().timeIntervalSince(started)))
try log.joined(separator: "\n").write(to: outDir.appendingPathComponent("timings.txt"), atomically: true, encoding: .utf8)
print(log.joined(separator: "\n"))
