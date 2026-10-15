// isokit: building parts. All sizes in metres, footprint-local.
import AppKit
import SceneKit

/// A wall face the camera can see. The camera looks from +x/+z, so only south (+z) and east (+x)
/// faces get timber, windows and doors; the hidden faces stay plain.
enum Face {
    case south(wallZ: CGFloat) // `along` runs +x
    case east(wallX: CGFloat) // `along` runs +z

    func point(along: CGFloat, y: CGFloat, out: CGFloat) -> SCNVector3 {
        switch self {
        case let .south(wallZ): SCNVector3(along, y, wallZ + out)
        case let .east(wallX): SCNVector3(wallX + out, y, along)
        }
    }
}

/// A rectangle on a face: centre (along, y) and size.
struct FaceRect {
    let along: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
}

/// Roof over the box lo...hi (x/z used; lo.y = eave height).
struct RoofSpec {
    var lo: SCNVector3
    var hi: SCNVector3
    var pitchDegrees: CGFloat = 42
    var overhang: CGFloat = 0.45
    var finish: Finish = .thatch
    var gableFinish: Finish = .plaster
    var ridgeAlongX = true

    var eave: CGFloat {
        lo.y
    }

    var tanPitch: CGFloat {
        tan(pitchDegrees * .pi / 180)
    }
}

/// Collects a recipe's nodes. Recipes only call its part methods.
public final class Builder {
    let root = SCNNode()

    public init() {}

    @discardableResult
    func add(
        _ geometry: SCNGeometry,
        _ material: SCNMaterial,
        at position: SCNVector3,
        euler: SCNVector3 = SCNVector3(0, 0, 0)
    ) -> SCNNode {
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.position = position
        node.eulerAngles = euler
        root.addChildNode(node)
        return node
    }

    /// Axis-aligned block between two corners; the texture repeats every `metresPerRepeat`.
    @discardableResult
    func block(_ lo: SCNVector3, _ hi: SCNVector3, _ finish: Finish, metresPerRepeat: CGFloat = 2) -> SCNNode {
        let size = hi - lo
        let box = SCNBox(width: size.x, height: size.y, length: size.z, chamferRadius: 0)
        // Thin slabs (paving, yards) show their top face: map V across the slab, not its height.
        let spanV = size.y < 0.3 ? size.z : size.y
        let material = finish.material(repeatU: max(size.x, size.z) / metresPerRepeat, repeatV: spanV / metresPerRepeat)
        return add(box, material, at: lo + size * 0.5)
    }

    /// A thin member standing proud of a face: post, beam, brace, frame, shutter.
    func onFace(_ face: Face, _ rect: FaceRect, depth: CGFloat, finish: Finish, roll: CGFloat = 0) {
        let centre = face.point(along: rect.along, y: rect.y, out: depth / 2)
        switch face {
        case .south:
            add(
                SCNBox(width: rect.width, height: rect.height, length: depth, chamferRadius: 0),
                finish.material(),
                at: centre,
                euler: SCNVector3(0, 0, roll)
            )
        case .east:
            add(
                SCNBox(width: depth, height: rect.height, length: rect.width, chamferRadius: 0),
                finish.material(),
                at: centre,
                euler: SCNVector3(-roll, 0, 0)
            )
        }
    }

    /// Flat-shaded polygons (convex, any winding); normals forced upward-facing for roofs.
    func polygons(_ faces: [[SCNVector3]], finish: Finish) {
        var vertices: [SCNVector3] = [], normals: [SCNVector3] = [], uvs: [CGPoint] = [], indices: [Int32] = []
        for raw in faces where raw.count >= 3 {
            var face = raw
            var normal = (face[1] - face[0]).cross(face[2] - face[0]).normalized
            if normal.y < 0 {
                face.reverse()
                normal = SCNVector3(-normal.x, -normal.y, -normal.z)
            }
            let alongEave = (face[1] - face[0]).normalized
            let upSlope = normal.cross(alongEave)
            let base = Int32(vertices.count)
            for point in face {
                vertices.append(point)
                normals.append(normal)
                let rel = point - face[0]
                uvs.append(CGPoint(x: rel.dot(alongEave) / 2, y: rel.dot(upSlope) / 2))
            }
            for index in 1 ..< (face.count - 1) {
                indices += [base, base + Int32(index), base + Int32(index + 1)]
            }
        }
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs)
            ],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        let material = finish.material()
        material.isDoubleSided = true
        add(geometry, material, at: SCNVector3(0, 0, 0))
    }
}

// MARK: roofs

extension Builder {
    /// A thicker, weathered course along a thatched slab's lower edge, at slab-local `edge` along z.
    private func thatchEave(length: CGFloat, at edge: CGFloat) -> SCNNode {
        let eave = SCNBox(width: length, height: 0.24, length: 0.4, chamferRadius: 0.06)
        eave.materials = [Finish.thatchEave.material(repeatU: 0.25, repeatV: length / 2, rotated: true)]
        let node = SCNNode(geometry: eave)
        node.position = SCNVector3(0, 0.02, edge)
        return node
    }

    /// Gable roof of two thick slabs plus gable triangles. Returns the ridge height.
    @discardableResult
    func gableRoof(_ spec: RoofSpec) -> CGFloat {
        let length = spec.ridgeAlongX ? spec.hi.x - spec.lo.x : spec.hi.z - spec.lo.z
        let depth = spec.ridgeAlongX ? spec.hi.z - spec.lo.z : spec.hi.x - spec.lo.x
        let rise = depth / 2 * spec.tanPitch
        let frame = SCNNode()
        if spec.ridgeAlongX {
            frame.position = SCNVector3(spec.lo.x, 0, (spec.lo.z + spec.hi.z) / 2)
        } else {
            frame.eulerAngles = SCNVector3(0, -CGFloat.pi / 2, 0)
            frame.position = SCNVector3((spec.lo.x + spec.hi.x) / 2, 0, spec.lo.z)
        }
        root.addChildNode(frame)
        let slope = depth / 2 / cos(spec.pitchDegrees * .pi / 180) + spec.overhang
        for side in [CGFloat(-1), 1] {
            let slab = SCNBox(width: length + 2 * spec.overhang, height: 0.16, length: slope, chamferRadius: 0)
            slab.materials = [spec.finish.material(repeatU: slope / 2, repeatV: length / 2, rotated: true)]
            let node = SCNNode(geometry: slab)
            node.position = SCNVector3(length / 2, spec.eave + rise / 2 + 0.1, side * (depth / 4 + 0.12))
            node.eulerAngles = SCNVector3(side * spec.pitchDegrees * .pi / 180, 0, 0)
            frame.addChildNode(node)
            if case .thatch = spec.finish {
                node.addChildNode(thatchEave(length: length + 2 * spec.overhang, at: side * (slope / 2 - 0.2)))
            }
        }
        for gableX in [CGFloat(0.1), length - 0.1] {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: -depth / 2, y: 0))
            path.line(to: NSPoint(x: depth / 2, y: 0))
            path.line(to: NSPoint(x: 0, y: rise))
            path.close()
            let shape = SCNShape(path: path, extrusionDepth: 0.2)
            shape.materials = [spec.gableFinish.material(repeatU: depth / 2, repeatV: rise / 2)]
            let node = SCNNode(geometry: shape)
            node.eulerAngles = SCNVector3(0, CGFloat.pi / 2, 0)
            node.position = SCNVector3(gableX, spec.eave, 0)
            frame.addChildNode(node)
        }
        let ridge = SCNNode(geometry: SCNBox(width: length + 2 * spec.overhang, height: 0.2, length: 0.24, chamferRadius: 0.04))
        ridge.geometry?.materials = [Finish.timber.material()]
        ridge.position = SCNVector3(length / 2, spec.eave + rise + 0.14, 0)
        frame.addChildNode(ridge)
        return spec.eave + rise
    }

    /// Hip roof (pyramid when square). Eaves overhang and drop with the pitch. Returns the apex height.
    @discardableResult
    func hipRoof(_ spec: RoofSpec) -> CGFloat {
        let over = spec.overhang
        let x0 = spec.lo.x - over, x1 = spec.hi.x + over, z0 = spec.lo.z - over, z1 = spec.hi.z + over
        let eave = spec.eave - over * spec.tanPitch
        let half = min(x1 - x0, z1 - z0) / 2
        let top = eave + half * spec.tanPitch
        let midX = (x0 + x1) / 2, midZ = (z0 + z1) / 2
        let alongX = (x1 - x0) >= (z1 - z0)
        let ridgeA = alongX ? SCNVector3(x0 + half, top, midZ) : SCNVector3(midX, top, z0 + half)
        let ridgeB = alongX ? SCNVector3(x1 - half, top, midZ) : SCNVector3(midX, top, z1 - half)
        let sw = SCNVector3(x0, eave, z1), se = SCNVector3(x1, eave, z1)
        let ne = SCNVector3(x1, eave, z0), nw = SCNVector3(x0, eave, z0)
        let faces: [[SCNVector3]] = alongX
            ? [[sw, se, ridgeB, ridgeA], [ne, nw, ridgeA, ridgeB], [se, ne, ridgeB], [nw, sw, ridgeA]]
            : [[sw, se, ridgeB], [ne, nw, ridgeA], [se, ne, ridgeA, ridgeB], [nw, sw, ridgeB, ridgeA]]
        polygons(faces, finish: spec.finish)
        return top
    }
}

// MARK: walls

extension Builder {
    /// Posts, sill, mid rail, top plate and corner braces across `span` of a face.
    func timberFrame(_ face: Face, span: ClosedRange<CGFloat>, base: CGFloat, height: CGFloat, posts: Int) {
        let width = span.upperBound - span.lowerBound
        let bay = width / CGFloat(max(posts - 1, 1))
        for index in 0 ..< posts {
            let along = span.lowerBound + bay * CGFloat(index)
            onFace(face, FaceRect(along: along, y: base + height / 2, width: 0.2, height: height), depth: 0.07, finish: .timber)
        }
        for railY in [base + 0.08, base + height / 2, base + height - 0.08] {
            onFace(face, FaceRect(along: span.lowerBound + width / 2, y: railY, width: width, height: 0.16), depth: 0.07, finish: .timber)
        }
        let braceLength = (bay * bay + height * height / 4).squareRoot()
        let angle = atan2(height / 2, bay)
        onFace(
            face,
            FaceRect(along: span.lowerBound + bay / 2, y: base + height / 4, width: braceLength, height: 0.14),
            depth: 0.06,
            finish: .timber,
            roll: angle
        )
        onFace(
            face,
            FaceRect(along: span.upperBound - bay / 2, y: base + height / 4, width: braceLength, height: 0.14),
            depth: 0.06,
            finish: .timber,
            roll: -angle
        )
    }

    func window(_ face: Face, along: CGFloat, y: CGFloat, lit: Bool, shutters: NSColor? = nil) {
        onFace(face, FaceRect(along: along, y: y, width: 0.86, height: 1.0), depth: 0.06, finish: .timber)
        onFace(face, FaceRect(along: along, y: y, width: 0.64, height: 0.8), depth: 0.09, finish: lit ? .litGlass : .glass)
        onFace(face, FaceRect(along: along, y: y - 0.55, width: 1.0, height: 0.1), depth: 0.16, finish: .timber)
        if let shutters {
            for side in [CGFloat(-1), 1] {
                onFace(face, FaceRect(along: along + side * 0.68, y: y, width: 0.42, height: 0.94), depth: 0.05, finish: .paint(shutters))
            }
        }
    }

    func door(_ face: Face, along: CGFloat, base: CGFloat, width: CGFloat = 1.0, height: CGFloat = 2.0) {
        onFace(face, FaceRect(along: along, y: base + height / 2, width: width + 0.2, height: height + 0.1), depth: 0.06, finish: .timber)
        onFace(face, FaceRect(along: along, y: base + height / 2, width: width, height: height), depth: 0.08, finish: .planks)
    }

    func chimney(x: CGFloat, depth: CGFloat, from bottom: CGFloat, to top: CGFloat) {
        block(SCNVector3(x - 0.3, bottom, depth - 0.3), SCNVector3(x + 0.3, top, depth + 0.3), .rubble)
        block(SCNVector3(x - 0.36, top - 0.12, depth - 0.36), SCNVector3(x + 0.36, top, depth + 0.36), .rubble)
    }

    /// Lean-to porch on a south face: two posts and a sloped slab.
    func porch(alongX span: ClosedRange<CGFloat>, wallZ: CGFloat, depth: CGFloat, height: CGFloat) {
        for postX in [span.lowerBound, span.upperBound] {
            block(SCNVector3(postX - 0.09, 0, wallZ + depth - 0.09), SCNVector3(postX + 0.09, height, wallZ + depth + 0.09), .timber)
        }
        let width = span.upperBound - span.lowerBound + 0.4
        let slab = SCNBox(width: width, height: 0.1, length: depth + 0.3, chamferRadius: 0)
        add(
            slab,
            Finish.planks.material(repeatU: width / 2, repeatV: 1, rotated: true),
            at: SCNVector3((span.lowerBound + span.upperBound) / 2, height + 0.25, wallZ + depth / 2),
            euler: SCNVector3(0.3, 0, 0)
        )
    }
}
