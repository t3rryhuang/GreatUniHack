import RealityKit
import UIKit

/// A rectangle on the ground the player can't walk through.
struct Collider: Sendable {
    let minX: Float, maxX: Float, minZ: Float, maxZ: Float
}

enum BillboardKind: String, CaseIterable, Identifiable, Sendable {
    case welcome, nextQuest, park, savings, event
    var id: String { rawValue }
}

struct BillboardSlot: Sendable {
    let kind: BillboardKind
    let position: SIMD3<Float>
    /// Rotation around y (radians); 0 faces +z.
    let yaw: Float
    let size: SIMD2<Float>
}

/// Builds the voxel Manchester city centre in code: the Nancy Rothwell Building (the
/// hackathon venue), Piccadilly Gardens, a Metrolink stop, the Northern Quarter and the
/// Community Park lot. Everything is procedural: no model files.
@MainActor
enum ManchesterWorld {
    static let bounds = Collider(minX: -52, maxX: 48, minZ: -12, maxZ: 86)

    // Palette
    static let pavement: UInt32 = 0xC9C6C0, road: UInt32 = 0x4A4A4E, roadLine: UInt32 = 0xF2F2F2, grass: UInt32 = 0x6DAA5C
    static let path: UInt32 = 0xD9CBA8, brick: UInt32 = 0xA0523D, brickDark: UInt32 = 0x7E3F2F, cladding: UInt32 = 0xE4E6EA
    static let glass: UInt32 = 0x8FC3E8, steel: UInt32 = 0x6E7682, wood: UInt32 = 0x9C6B3F, leaf: UInt32 = 0x3E8E46
    static let trunk: UInt32 = 0x6B4A2E, natwestPurple: UInt32 = 0x5E10B1, tramYellow: UInt32 = 0xF2C230, lobbyFloor: UInt32 = 0xEDE6DA

    struct Built {
        let root: Entity
        let colliders: [Collider]
        let billboards: [BillboardSlot]
    }

    static func build() -> Built {
        var v = VoxelBuilder()
        var colliders: [Collider] = []
        func solid(_ x: Float, _ z: Float, _ w: Float, _ d: Float) { colliders.append(Collider(minX: x, maxX: x + w, minZ: z, maxZ: z + d)) }

        // Ground: pavement everywhere, then roads, grass and squares on top.
        v.block(x: -54, y: -0.2, z: -14, w: 104, h: 0.2, d: 102, pavement)
        // Main road between the venue and the city (east-west) and a north-south road.
        v.block(x: -54, y: 0, z: 14, w: 104, h: 0.02, d: 6, road)
        for x in stride(from: Float(-50), to: 48, by: 4) { v.block(x: x, y: 0.02, z: 16.9, w: 2, h: 0.01, d: 0.2, roadLine) }
        v.block(x: 17, y: 0, z: 20, w: 3, h: 0.02, d: 42, road)

        buildVenue(&v, solid)
        buildPiccadilly(&v, solid)
        buildTramStop(&v, solid)
        buildNorthernQuarter(&v, solid)
        buildParkLot(&v, solid)

        // Street furniture
        for x in stride(from: Float(-40), through: 40, by: 16) { lamp(&v, x, 13); lamp(&v, x + 8, 21) }

        // City edge: tall blocks so the world feels enclosed.
        for x in stride(from: Float(-52), to: 48, by: 10) {
            let h = Float(10 + Int(abs(x).truncatingRemainder(dividingBy: 3)) * 4)
            v.block(x: x, y: 0, z: 84, w: 9, h: h, d: 4, x.truncatingRemainder(dividingBy: 20) == 0 ? brick : cladding)
        }
        solid(-54, 84, 104, 4)

        let root = v.build(named: "manchester")
        let billboards = [
            BillboardSlot(kind: .welcome, position: [0, 6.5, -9.3], yaw: 0, size: [8, 3]),
            BillboardSlot(kind: .nextQuest, position: [-8, 4.2, 22.4], yaw: .pi, size: [5, 2.6]),
            BillboardSlot(kind: .savings, position: [12, 4.2, 22.4], yaw: .pi, size: [5, 2.6]),
            BillboardSlot(kind: .event, position: [-30, 6, 28], yaw: .pi / 2, size: [5, 2.6]),
            BillboardSlot(kind: .park, position: [0, 4.5, 60.6], yaw: .pi, size: [6, 3])
        ]
        return Built(root: root, colliders: colliders, billboards: billboards)
    }

    // MARK: Nancy Rothwell Building (the venue)

    private static func buildVenue(_ v: inout VoxelBuilder, _ solid: (Float, Float, Float, Float) -> Void) {
        let h: Float = 11
        // Floor
        v.block(x: -15, y: 0, z: -10, w: 30, h: 0.05, d: 20, lobbyFloor)
        // Back and side walls
        v.block(x: -15, y: 0, z: -10, w: 30, h: h, d: 0.6, cladding); solid(-15, -10, 30, 0.6)
        v.block(x: -15, y: 0, z: -10, w: 0.6, h: h, d: 20, cladding); solid(-15, -10, 0.6, 20)
        v.block(x: 14.4, y: 0, z: -10, w: 0.6, h: h, d: 20, cladding); solid(14.4, -10, 0.6, 20)
        // Front: glass facade with a door gap in the middle (x -3...3).
        for (x0, w) in [(Float(-15), Float(12)), (Float(3), Float(12))] {
            v.block(x: x0, y: 0, z: 9.4, w: w, h: 1, d: 0.6, cladding)
            v.block(x: x0, y: 1, z: 9.6, w: w, h: 7, d: 0.2, glass, opacity: 0.45)
            for fx in stride(from: x0, through: x0 + w, by: 2) { v.block(x: fx, y: 1, z: 9.5, w: 0.2, h: 7, d: 0.4, steel) }
            solid(x0, 9.4, w, 0.6)
        }
        v.block(x: -15, y: 8, z: 9.4, w: 30, h: h - 8, d: 0.6, cladding)
        v.block(x: -3.2, y: 4, z: 9.3, w: 6.4, h: 0.4, d: 0.8, natwestPurple)
        // Roof with long skylight strips
        for z in stride(from: Float(-10), to: 10, by: 4) { v.block(x: -15, y: h, z: z, w: 30, h: 0.4, d: 2.6, cladding) }
        // Upper walkway (mezzanine look) along the back
        v.block(x: -14.4, y: 4.5, z: -9.4, w: 28.8, h: 0.3, d: 3, cladding)
        v.block(x: -14.4, y: 4.8, z: -6.5, w: 28.8, h: 1, d: 0.1, glass, opacity: 0.5)
        // Sponsor desk (Sam stands behind it), off the line from the spawn to the door
        v.block(x: 7.5, y: 0, z: 5, w: 5, h: 1.1, d: 1.2, natwestPurple); solid(7.5, 5, 5, 1.2)
        v.block(x: 7.5, y: 1.1, z: 5, w: 5, h: 0.08, d: 1.2, 0xFFFFFF)
        // Hackathon tables with laptops
        for (x, z) in [(Float(4), Float(-6)), (Float(9), Float(-6)), (Float(4), Float(-1)), (Float(9), Float(-1)), (Float(-12), Float(0))] {
            v.block(x: x - 1.5, y: 0.75, z: z - 0.8, w: 3, h: 0.08, d: 1.6, wood)
            for (lx, lz) in [(-1.3, -0.6), (1.2, -0.6), (-1.3, 0.6), (1.2, 0.6)] as [(Float, Float)] {
                v.block(x: x + lx, y: 0, z: z + lz, w: 0.1, h: 0.75, d: 0.1, steel)
            }
            v.block(x: x - 0.9, y: 0.83, z: z - 0.3, w: 0.6, h: 0.03, d: 0.4, 0x333333)
            v.block(x: x - 0.9, y: 0.83, z: z - 0.32, w: 0.6, h: 0.35, d: 0.03, 0x333333)
            v.block(x: x + 0.3, y: 0.83, z: z - 0.1, w: 0.6, h: 0.03, d: 0.4, 0xBBBBBB)
            solid(x - 1.5, z - 0.8, 3, 1.6)
        }
        // Stage and banner wall at the back
        v.block(x: -6, y: 0, z: -9.4, w: 12, h: 0.5, d: 3, 0x2C2C2C); solid(-6, -9.4, 12, 3)
        // Plants
        for (x, z) in [(Float(-13.5), Float(8)), (Float(13.5), Float(8)), (Float(-13.5), Float(-8))] {
            v.block(x: x - 0.4, y: 0, z: z - 0.4, w: 0.8, h: 0.6, d: 0.8, 0x2C2C2C)
            v.box([x, 1.1, z], [1.1, 1, 1.1], leaf)
            solid(x - 0.4, z - 0.4, 0.8, 0.8)
        }
    }

    // MARK: Piccadilly Gardens

    private static func buildPiccadilly(_ v: inout VoxelBuilder, _ solid: (Float, Float, Float, Float) -> Void) {
        v.block(x: -16, y: 0, z: 24, w: 32, h: 0.06, d: 32, grass)
        v.block(x: -1.5, y: 0.06, z: 24, w: 3, h: 0.02, d: 32, path)
        v.block(x: -16, y: 0.06, z: 38.5, w: 32, h: 0.02, d: 3, path)
        // Water feature (fountain bowl) in the middle
        v.block(x: -3, y: 0, z: 37, w: 6, h: 0.5, d: 6, 0xBFC4CC)
        v.block(x: -2.6, y: 0.4, z: 37.4, w: 5.2, h: 0.12, d: 5.2, 0x5FA8D3)
        solid(-3, 37, 6, 6)
        for (x, z) in [(Float(-12), Float(28)), (Float(-10), Float(50)), (Float(11), Float(28)), (Float(12), Float(50)), (Float(-13), Float(43)), (Float(13), Float(34))] {
            tree(&v, x, z); solid(x - 0.4, z - 0.4, 0.8, 0.8)
        }
        for (x, z) in [(Float(-6), Float(30)), (Float(4), Float(30)), (Float(-6), Float(48)), (Float(4), Float(48))] { bench(&v, x, z) }
        // Billboard poles
        pole(&v, -8, 22.6); pole(&v, 12, 22.6)
    }

    // MARK: Metrolink stop

    private static func buildTramStop(_ v: inout VoxelBuilder, _ solid: (Float, Float, Float, Float) -> Void) {
        // Rails
        for x in [Float(22.6), Float(24.0), Float(25.4), Float(26.8)] { v.block(x: x, y: 0, z: 22, w: 0.15, h: 0.12, d: 40, steel) }
        // Platform
        v.block(x: 28, y: 0, z: 30, w: 4, h: 0.35, d: 16, 0xBFBFBF)
        v.block(x: 28, y: 0.35, z: 30, w: 0.3, h: 0.02, d: 16, tramYellow)
        // Shelter
        v.block(x: 30.5, y: 0.35, z: 34, w: 0.15, h: 2.6, d: 0.15, steel); v.block(x: 30.5, y: 0.35, z: 40, w: 0.15, h: 2.6, d: 0.15, steel)
        v.block(x: 30, y: 2.95, z: 33.6, w: 2, h: 0.12, d: 7, steel)
        v.block(x: 31.6, y: 0.35, z: 34, w: 0.1, h: 2.4, d: 6, glass, opacity: 0.4)
        solid(31.5, 34, 0.3, 6)
        // Tram (yellow Metrolink style)
        v.block(x: 23.2, y: 0.4, z: 26, w: 3, h: 3, d: 14, tramYellow)
        v.block(x: 23.1, y: 1.8, z: 27, w: 3.2, h: 1, d: 12, 0x2C3A4A)
        v.block(x: 23.2, y: 3.4, z: 30, w: 3, h: 0.2, d: 6, 0x444444)
        v.block(x: 24.2, y: 3.6, z: 32.5, w: 1, h: 1, d: 0.1, 0x444444)
        solid(23.2, 26, 3, 14)
        // Ticket machine
        v.block(x: 29.4, y: 0.35, z: 44, w: 0.8, h: 1.6, d: 0.6, natwestPurple)
        v.block(x: 29.5, y: 1.3, z: 43.95, w: 0.6, h: 0.4, d: 0.05, 0x9AD3F5)
        solid(29.4, 44, 0.8, 0.6)
        // Phone shop
        v.block(x: 36, y: 0, z: 44, w: 10, h: 6, d: 8, cladding); solid(36, 44, 10, 8)
        v.block(x: 36, y: 1, z: 43.9, w: 10, h: 2.5, d: 0.1, glass, opacity: 0.6)
        v.block(x: 36, y: 4, z: 43.85, w: 10, h: 0.8, d: 0.1, 0x2F7DE1)
    }

    // MARK: Northern Quarter

    private static func buildNorthernQuarter(_ v: inout VoxelBuilder, _ solid: (Float, Float, Float, Float) -> Void) {
        // Cobbled square
        v.block(x: -46, y: 0, z: 26, w: 28, h: 0.04, d: 34, 0x8E8378)
        // Red-brick warehouses around the square
        let buildings: [(Float, Float, Float, Float, Float)] = [(-52, 24, 6, 14, 12), (-52, 40, 6, 20, 15), (-46, 58, 12, 6, 13), (-30, 58, 12, 6, 11)]
        for (x, z, w, d, h) in buildings {
            v.block(x: x, y: 0, z: z, w: w, h: h, d: d, brick); solid(x, z, w, d)
            // Windows in rows
            var wy: Float = 1.5
            while wy < h - 1 {
                if w > d {
                    for wx in stride(from: x + 1, to: x + w - 1, by: 2.2) { v.block(x: wx, y: wy, z: z - 0.05, w: 1.2, h: 1.4, d: 0.1, 0x2C3A4A) }
                } else {
                    for wz in stride(from: z + 1, to: z + d - 1, by: 2.2) { v.block(x: x + w - 0.05, y: wy, z: wz, w: 0.1, h: 1.4, d: 1.2, 0x2C3A4A) }
                }
                wy += 2.6
            }
            v.block(x: x, y: h, z: z, w: w, h: 0.4, d: d, brickDark)
        }
        // Market stalls with striped roofs
        let stalls: [(Float, Float, UInt32)] = [(-30, 40, 0xD8343B), (-24, 40, natwestPurple), (-36, 46, 0x1E9C99), (-30, 48, tramYellow)]
        for (x, z, colour) in stalls {
            v.block(x: x - 1.5, y: 0, z: z - 0.8, w: 3, h: 1, d: 1.6, wood)
            v.block(x: x - 1.5, y: 1, z: z - 0.8, w: 0.1, h: 1.4, d: 0.1, steel); v.block(x: x + 1.4, y: 1, z: z - 0.8, w: 0.1, h: 1.4, d: 0.1, steel)
            for i in 0..<4 { v.block(x: x - 1.6 + Float(i) * 0.8, y: 2.4, z: z - 1, w: 0.8, h: 0.15, d: 2, i.isMultiple(of: 2) ? colour : 0xFFFFFF) }
            for i in 0..<3 { v.box([x - 0.8 + Float(i) * 0.8, 1.15, z - 0.2], [0.4, 0.3, 0.4], [0xEE7A2A, 0x3E9B4F, 0xF2C230][i]) }
            solid(x - 1.5, z - 0.8, 3, 1.6)
        }
        // A street-art wall (Northern Quarter murals)
        v.block(x: -46, y: 0, z: 26, w: 0.6, h: 5, d: 10, brick)
        for (i, c) in [0xE5689B, 0x2F7DE1, 0xF2C230, 0x3E9B4F].enumerated() as EnumeratedSequence<[UInt32]> {
            v.block(x: -45.38, y: 1 + Float(i), z: 27 + Float(i) * 2, w: 0.05, h: 1.5, d: 3, c)
        }
        solid(-46, 26, 0.6, 10)
        pole(&v, -30, 28)
    }

    // MARK: Community Park lot (the build stages are added by `parkEntity`)

    private static func buildParkLot(_ v: inout VoxelBuilder, _ solid: (Float, Float, Float, Float) -> Void) {
        v.block(x: -16, y: 0, z: 62, w: 32, h: 0.05, d: 20, 0x9C8B6E)
        // Fence with a gate on the south side
        for x in stride(from: Float(-16), through: 16, by: 1) where abs(x) > 2 {
            v.block(x: x, y: 0, z: 61.8, w: 0.12, h: 1, d: 0.12, wood)
        }
        v.block(x: -16, y: 0.7, z: 61.85, w: 14, h: 0.1, d: 0.05, wood); v.block(x: 2, y: 0.7, z: 61.85, w: 14, h: 0.1, d: 0.05, wood)
        pole(&v, 0, 60.4)
    }

    /// The park's visible upgrades for a stage: benches, then trees, a fountain and a skatepark.
    static func parkEntity(stage: ParkStage) -> Entity {
        var v = VoxelBuilder()
        if stage == .emptyLot {
            v.block(x: -4, y: 0, z: 70, w: 2, h: 0.6, d: 1, 0x8C8C8C)
            v.block(x: 3, y: 0, z: 74, w: 1.5, h: 0.4, d: 1.5, 0x8C8C8C)
        }
        if stage >= .benches {
            v.block(x: -16, y: 0.05, z: 70.5, w: 32, h: 0.02, d: 2, path)
            for x in [Float(-12), -4, 6, 12] { bench(&v, x, 68) }
        }
        if stage >= .trees {
            v.block(x: -15.5, y: 0.05, z: 63, w: 31, h: 0.02, d: 5, grass)
            for x in stride(from: Float(-14), through: 14, by: 7) { tree(&v, x, 78) }
            for x in [Float(-14), 14] { tree(&v, x, 65) }
        }
        if stage >= .fountain {
            v.block(x: -2.5, y: 0, z: 72, w: 5, h: 0.6, d: 5, 0xBFC4CC)
            v.block(x: -2.1, y: 0.5, z: 72.4, w: 4.2, h: 0.12, d: 4.2, 0x5FA8D3)
            v.block(x: -0.3, y: 0.6, z: 74.2, w: 0.6, h: 1.6, d: 0.6, 0xBFC4CC)
            v.block(x: -0.15, y: 2.2, z: 74.35, w: 0.3, h: 0.5, d: 0.3, 0x9AD3F5, opacity: 0.7)
        }
        if stage >= .skatepark {
            v.block(x: 6, y: 0, z: 73, w: 8, h: 0.1, d: 6, 0x9A9A9A)
            for i in 0..<5 { v.block(x: 6 + Float(i) * 0.4, y: 0, z: 73, w: 0.4, h: 1.2 - Float(i) * 0.24, d: 6, 0xB4B4B4) }
            v.block(x: 11, y: 0, z: 75, w: 2.5, h: 0.5, d: 1, 0xB4B4B4)
        }
        return v.build(named: "park-\(stage.rawValue)")
    }

    /// Colliders added by the park stage (so the fountain is solid).
    static func parkColliders(stage: ParkStage) -> [Collider] {
        stage >= .fountain ? [Collider(minX: -2.5, maxX: 2.5, minZ: 72, maxZ: 77)] : []
    }

    // MARK: Props

    private static func tree(_ v: inout VoxelBuilder, _ x: Float, _ z: Float) {
        v.block(x: x - 0.2, y: 0, z: z - 0.2, w: 0.4, h: 2, d: 0.4, trunk)
        v.box([x, 2.6, z], [2.2, 1.6, 2.2], leaf)
        v.box([x, 3.6, z], [1.4, 0.8, 1.4], 0x4FA057)
    }

    private static func bench(_ v: inout VoxelBuilder, _ x: Float, _ z: Float) {
        v.block(x: x, y: 0.45, z: z, w: 2, h: 0.1, d: 0.6, wood)
        v.block(x: x, y: 0.55, z: z + 0.5, w: 2, h: 0.5, d: 0.1, wood)
        v.block(x: x + 0.1, y: 0, z: z + 0.1, w: 0.1, h: 0.45, d: 0.4, steel)
        v.block(x: x + 1.8, y: 0, z: z + 0.1, w: 0.1, h: 0.45, d: 0.4, steel)
    }

    private static func lamp(_ v: inout VoxelBuilder, _ x: Float, _ z: Float) {
        v.block(x: x, y: 0, z: z, w: 0.15, h: 4, d: 0.15, 0x2C2C2C)
        v.block(x: x - 0.2, y: 4, z: z - 0.2, w: 0.55, h: 0.25, d: 0.55, 0xFFF1C1)
    }

    private static func pole(_ v: inout VoxelBuilder, _ x: Float, _ z: Float) {
        v.block(x: x - 0.1, y: 0, z: z - 0.1, w: 0.2, h: 3, d: 0.2, 0x2C2C2C)
    }
}
