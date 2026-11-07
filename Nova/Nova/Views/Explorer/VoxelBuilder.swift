import RealityKit
import UIKit

/// Builds voxel geometry in code. Boxes of the same colour are merged into one mesh,
/// so a whole city block is a handful of draw calls instead of thousands of entities.
struct VoxelBuilder {
    private struct Key: Hashable {
        let colour: UInt32
        let opacity: Float
    }

    private struct Group {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
    }

    private var groups: [Key: Group] = [:]

    /// Faces of a unit box: normal plus two in-plane axes with u × v = n (counter-clockwise from outside).
    private static let faces: [(n: SIMD3<Float>, u: SIMD3<Float>, v: SIMD3<Float>)] = [
        (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)),
        (SIMD3(-1, 0, 0), SIMD3(0, 0, 1), SIMD3(0, 1, 0)),
        (SIMD3(0, 1, 0), SIMD3(0, 0, 1), SIMD3(1, 0, 0)),
        (SIMD3(0, -1, 0), SIMD3(1, 0, 0), SIMD3(0, 0, 1)),
        (SIMD3(0, 0, 1), SIMD3(1, 0, 0), SIMD3(0, 1, 0)),
        (SIMD3(0, 0, -1), SIMD3(0, 1, 0), SIMD3(1, 0, 0))
    ]

    /// Adds a box by its centre and full size, in metres.
    mutating func box(_ center: SIMD3<Float>, _ size: SIMD3<Float>, _ colour: UInt32, opacity: Float = 1) {
        let key = Key(colour: colour, opacity: opacity)
        var group = groups[key] ?? Group()
        let half = size / 2
        for face in Self.faces {
            let base = UInt32(group.positions.count)
            let c = center + face.n * half
            let u = face.u * half
            let v = face.v * half
            group.positions += [c - u - v, c + u - v, c + u + v, c - u + v]
            group.normals += Array(repeating: face.n, count: 4)
            group.indices += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        groups[key] = group
    }

    /// Adds a box from its minimum corner and size (handy for floors and walls).
    mutating func block(x: Float, y: Float, z: Float, w: Float, h: Float, d: Float, _ colour: UInt32, opacity: Float = 1) {
        box(SIMD3(x + w / 2, y + h / 2, z + d / 2), SIMD3(w, h, d), colour, opacity: opacity)
    }

    /// One ModelEntity per colour.
    func build(named name: String = "voxels") -> Entity {
        let root = Entity()
        root.name = name
        for (key, group) in groups {
            var descriptor = MeshDescriptor(name: "\(name)-\(key.colour)")
            descriptor.positions = MeshBuffers.Positions(group.positions)
            descriptor.normals = MeshBuffers.Normals(group.normals)
            descriptor.primitives = .triangles(group.indices)
            guard let mesh = try? MeshResource.generate(from: [descriptor]) else { continue }
            root.addChild(ModelEntity(mesh: mesh, materials: [Self.material(key.colour, opacity: key.opacity)]))
        }
        return root
    }

    static func material(_ colour: UInt32, opacity: Float = 1, roughness: Float = 0.85) -> RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(hex: colour))
        m.roughness = .init(floatLiteral: roughness)
        m.metallic = .init(floatLiteral: 0)
        if opacity < 1 { m.blending = .transparent(opacity: .init(floatLiteral: opacity)) }
        return m
    }
}

/// A flat, always-lit picture in the world (billboards, name tags), textured from a SwiftUI view.
enum ViewTexture {
    @MainActor
    static func texture<V: View>(_ view: V, scale: CGFloat = 2) -> TextureResource? {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        return try? TextureResource.generate(from: image, options: .init(semantic: .color))
    }

    @MainActor
    static func material<V: View>(_ view: V, scale: CGFloat = 2) -> RealityKit.Material {
        var m = UnlitMaterial()
        if let texture = texture(view, scale: scale) {
            m.color = .init(tint: .white, texture: .init(texture))
        }
        return m
    }
}

import SwiftUI
