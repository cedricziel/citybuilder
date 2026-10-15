import AppKit
import SceneKit

/// The shared light rig and camera. Every building lights identically (design D3).
public enum Rig {
    /// One warm sun from screen upper-left, high enough that the cast shadow stays in the cell,
    /// plus a cool sky fill.
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

    /// Orthographic 2:1 camera whose view puts the footprint's bottom vertex at the cell's bottom-centre.
    static func camera(for cell: SpriteCell) -> SCNNode {
        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.projectionDirection = .vertical
        let halfHeight = CGFloat(cell.heightPx) / 2 / Iso.pxPerMetre
        cam.orthographicScale = Double(halfHeight)
        cam.zNear = 1
        cam.zFar = 300
        // SSAO samples with per-run noise (design D5); ISOKIT_SSAO=0 turns it off for debugging.
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
