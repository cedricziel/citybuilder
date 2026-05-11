// MARK: SPIKE

//
// Throwaway hello-iso scene for M0 task 1.14. This file MUST be deleted or
// rewritten test-first before M2 — see openspec/changes/add-mvp-foundation/
// tasks.md task 3.3. Coverage and TDD gates skip files marked `// MARK: SPIKE`.

import Foundation
import SpriteKit

#if canImport(SwiftUI)
import SwiftUI
#endif

/// Iso projection: a tile at (col, row) projects to:
///   screen.x = (col - row) * (tileWidth / 2)
///   screen.y = (col + row) * (tileHeight / 2)
private enum IsoMath {
    static let tileWidth: CGFloat = 64
    static let tileHeight: CGFloat = 32
    static let gridSize = 50

    static func screenPoint(forCol col: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(col - row) * (tileWidth / 2),
            y: CGFloat(col + row) * (tileHeight / 2)
        )
    }
}

/// A throwaway scene that draws a 50x50 isometric grid using diamond tiles
/// and provides a centered camera. No game logic, no input — just enough to
/// prove SpriteKit + SwiftUI integration works on iOS and macOS.
public final class HelloIsoScene: SKScene {
    override public func didMove(to _: SKView) {
        backgroundColor = .black
        scaleMode = .resizeFill

        let camera = SKCameraNode()
        addChild(camera)
        self.camera = camera

        let tileShape = makeDiamondPath()
        let palette: [SKColor] = [
            SKColor(red: 0.4, green: 0.6, blue: 0.3, alpha: 1),
            SKColor(red: 0.45, green: 0.65, blue: 0.35, alpha: 1)
        ]

        for row in 0 ..< IsoMath.gridSize {
            for col in 0 ..< IsoMath.gridSize {
                let tile = SKShapeNode(path: tileShape)
                tile.fillColor = palette[(row + col) % palette.count]
                tile.strokeColor = SKColor.black.withAlphaComponent(0.2)
                tile.lineWidth = 0.5
                tile.position = IsoMath.screenPoint(forCol: col, row: row)
                addChild(tile)
            }
        }

        // Center camera on the grid's middle tile.
        let centerCol = IsoMath.gridSize / 2
        let centerRow = IsoMath.gridSize / 2
        camera.position = IsoMath.screenPoint(forCol: centerCol, row: centerRow)
        camera.setScale(2.0)
    }

    private func makeDiamondPath() -> CGPath {
        let halfWidth = IsoMath.tileWidth / 2
        let halfHeight = IsoMath.tileHeight / 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: halfHeight))
        path.addLine(to: CGPoint(x: halfWidth, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -halfHeight))
        path.addLine(to: CGPoint(x: -halfWidth, y: 0))
        path.closeSubpath()
        return path
    }
}

#if canImport(SwiftUI)
/// SwiftUI host for the hello-iso spike. Both app shells embed this view in
/// place of the M0 placeholder Text view to confirm iso rendering works.
public struct HelloIsoView: View {
    public init() {}

    public var body: some View {
        SpriteView(scene: makeScene())
            .ignoresSafeArea()
    }

    private func makeScene() -> SKScene {
        let scene = HelloIsoScene()
        scene.size = CGSize(width: 800, height: 600)
        return scene
    }
}
#endif
