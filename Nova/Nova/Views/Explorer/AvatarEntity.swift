import RealityKit
import UIKit

/// A voxel character built from boxes. Limbs hang from pivots so they can swing
/// when walking and play emotes. Forward is -z.
@MainActor
final class AvatarEntity {
    let root = Entity()
    private let body = Entity()
    private let leftArm = Entity(), rightArm = Entity(), leftLeg = Entity(), rightLeg = Entity()
    private var parts = Entity()
    private(set) var look: AvatarLook
    private(set) var cosmetic: String?
    private var walkPhase: Float = 0
    private var emote: Emote?
    private var emoteTime: Float = 0

    init(look: AvatarLook, cosmetic: String? = nil) {
        self.look = look
        self.cosmetic = cosmetic
        root.addChild(body)
        rebuild()
    }

    func update(look: AvatarLook, cosmetic: String?) {
        guard look != self.look || cosmetic != self.cosmetic else { return }
        self.look = look
        self.cosmetic = cosmetic
        rebuild()
    }

    func play(_ emote: Emote) {
        self.emote = emote
        emoteTime = 0
    }

    /// Swings limbs while moving and runs any emote. `speed` is 0...1.
    func animate(dt: Float, speed: Float, reduceMotion: Bool) {
        if let emote {
            emoteTime += dt
            let t = emoteTime
            switch emote {
            case .wave:
                rightArm.orientation = simd_quatf(angle: .pi * 0.9 + sin(t * 10) * 0.25, axis: [0, 0, 1])
            case .cheer:
                leftArm.orientation = simd_quatf(angle: -.pi * 0.9, axis: [0, 0, 1])
                rightArm.orientation = simd_quatf(angle: .pi * 0.9, axis: [0, 0, 1])
                body.position.y = reduceMotion ? 0 : abs(sin(t * 8)) * 0.3
            case .dance:
                body.orientation = simd_quatf(angle: reduceMotion ? 0 : t * 6, axis: [0, 1, 0])
                leftArm.orientation = simd_quatf(angle: -.pi * 0.6 + sin(t * 9) * 0.4, axis: [0, 0, 1])
                rightArm.orientation = simd_quatf(angle: .pi * 0.6 - sin(t * 9) * 0.4, axis: [0, 0, 1])
            }
            if t > 2.2 {
                self.emote = nil
                body.position.y = 0
                body.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
                leftArm.orientation = simd_quatf(angle: 0, axis: [0, 0, 1])
                rightArm.orientation = simd_quatf(angle: 0, axis: [0, 0, 1])
            }
            return
        }
        walkPhase += dt * 10 * speed
        let swing = reduceMotion ? 0 : sin(walkPhase) * 0.7 * speed
        leftLeg.orientation = simd_quatf(angle: swing, axis: [1, 0, 0])
        rightLeg.orientation = simd_quatf(angle: -swing, axis: [1, 0, 0])
        leftArm.orientation = simd_quatf(angle: -swing, axis: [1, 0, 0])
        rightArm.orientation = simd_quatf(angle: swing, axis: [1, 0, 0])
    }

    private func box(_ size: SIMD3<Float>, _ colour: UInt32, at position: SIMD3<Float>, in parent: Entity) {
        let e = ModelEntity(mesh: .generateBox(size: size), materials: [VoxelBuilder.material(colour)])
        e.position = position
        parent.addChild(e)
    }

    private func rebuild() {
        parts.removeFromParent()
        parts = Entity()
        body.addChild(parts)
        for pivot in [leftArm, rightArm, leftLeg, rightLeg] {
            pivot.children.removeAll()
            pivot.removeFromParent()
        }
        let skin = look.skin.hex, top = look.topColour.hex, bottom = look.bottomColour.hex
        let hair = look.hairColour.hex, shoe = look.shoeColour.hex, dark: UInt32 = 0x1E1E1E

        // Legs and shoes hang from the hips.
        for (pivot, x) in [(leftLeg, Float(-0.13)), (rightLeg, Float(0.13))] {
            pivot.position = [x, 0.82, 0]
            box([0.22, 0.72, 0.24], bottom, at: [0, -0.38, 0], in: pivot)
            let shoeSize: SIMD3<Float> = look.shoes == .boots ? [0.26, 0.2, 0.32] : look.shoes == .sliders ? [0.24, 0.06, 0.3] : [0.25, 0.12, 0.33]
            box(shoeSize, shoe, at: [0, -0.76 + shoeSize.y / 2 - 0.04, -0.04], in: pivot)
            parts.addChild(pivot)
        }
        // Torso
        let torsoHeight: Float = look.top == .jacket ? 0.74 : 0.68
        box([0.6, torsoHeight, 0.32], top, at: [0, 0.82 + torsoHeight / 2, 0], in: parts)
        if look.top == .hoodie { box([0.44, 0.24, 0.12], top, at: [0, 1.5, 0.2], in: parts) }
        if look.top == .jacket { box([0.08, 0.5, 0.02], dark, at: [0, 1.22, -0.17], in: parts) }
        if look.top == .jumper { box([0.62, 0.08, 0.34], 0xFFFFFF, at: [0, 1.25, 0], in: parts) }
        // Arms hang from the shoulders; T-shirts show skin below the sleeve.
        for (pivot, x) in [(leftArm, Float(-0.4)), (rightArm, Float(0.4))] {
            pivot.position = [x, 1.46, 0]
            if look.top == .tshirt {
                box([0.18, 0.24, 0.2], top, at: [0, -0.12, 0], in: pivot)
                box([0.16, 0.46, 0.18], skin, at: [0, -0.47, 0], in: pivot)
            } else {
                box([0.18, 0.66, 0.2], top, at: [0, -0.33, 0], in: pivot)
                box([0.16, 0.08, 0.18], skin, at: [0, -0.7, 0], in: pivot)
            }
            parts.addChild(pivot)
        }
        // Head and face
        box([0.42, 0.42, 0.42], skin, at: [0, 1.74, 0], in: parts)
        box([0.07, 0.07, 0.02], dark, at: [-0.1, 1.77, -0.215], in: parts)
        box([0.07, 0.07, 0.02], dark, at: [0.1, 1.77, -0.215], in: parts)
        box([0.14, 0.03, 0.02], 0xB0524A, at: [0, 1.64, -0.215], in: parts)
        // Hair
        switch look.hair {
        case .short: box([0.46, 0.12, 0.46], hair, at: [0, 1.98, 0.01], in: parts); box([0.46, 0.2, 0.08], hair, at: [0, 1.86, 0.2], in: parts)
        case .long: box([0.46, 0.12, 0.46], hair, at: [0, 1.98, 0.01], in: parts); box([0.46, 0.6, 0.1], hair, at: [0, 1.66, 0.22], in: parts)
            box([0.06, 0.4, 0.4], hair, at: [-0.23, 1.76, 0.02], in: parts); box([0.06, 0.4, 0.4], hair, at: [0.23, 1.76, 0.02], in: parts)
        case .curly:
            for x in stride(from: Float(-0.18), through: 0.18, by: 0.12) { for z in stride(from: Float(-0.18), through: 0.18, by: 0.12) {
                box([0.14, 0.14, 0.14], hair, at: [x, 2.0 + (abs(x + z) < 0.1 ? 0.04 : 0), z], in: parts)
            } }
        case .bun: box([0.46, 0.1, 0.46], hair, at: [0, 1.97, 0.01], in: parts); box([0.2, 0.18, 0.2], hair, at: [0, 2.1, 0.12], in: parts)
        case .buzz: box([0.44, 0.04, 0.44], hair, at: [0, 1.96, 0], in: parts)
        case .afro: box([0.62, 0.36, 0.6], hair, at: [0, 2.0, 0.04], in: parts)
        case .braids: box([0.46, 0.1, 0.46], hair, at: [0, 1.97, 0.01], in: parts)
            for x in [Float(-0.16), 0, 0.16] { box([0.08, 0.7, 0.08], hair, at: [x, 1.6, 0.24], in: parts) }
        }
        // Accessory
        switch look.accessory {
        case .none: break
        case .glasses: box([0.4, 0.05, 0.03], dark, at: [0, 1.79, -0.225], in: parts)
            box([0.12, 0.1, 0.02], 0x9AD3F5, at: [-0.1, 1.77, -0.23], in: parts); box([0.12, 0.1, 0.02], 0x9AD3F5, at: [0.1, 1.77, -0.23], in: parts)
        case .cap: box([0.48, 0.12, 0.48], top == 0xF2F2F2 ? 0x22325E : 0xD8343B, at: [0, 2.02, 0], in: parts)
            box([0.4, 0.04, 0.22], top == 0xF2F2F2 ? 0x22325E : 0xD8343B, at: [0, 1.98, -0.3], in: parts)
        case .beanie: box([0.48, 0.2, 0.48], 0x22325E, at: [0, 2.03, 0.01], in: parts); box([0.1, 0.1, 0.1], 0xF2F2F2, at: [0, 2.17, 0], in: parts)
        case .headphones: box([0.5, 0.05, 0.1], dark, at: [0, 2.0, 0], in: parts)
            box([0.06, 0.16, 0.14], dark, at: [-0.24, 1.76, 0], in: parts); box([0.06, 0.16, 0.14], dark, at: [0.24, 1.76, 0], in: parts)
        }
        // Earned cosmetic
        switch cosmetic {
        case "backpack": box([0.46, 0.5, 0.18], 0x5E10B1, at: [0, 1.18, 0.26], in: parts)
        case "scarf": box([0.5, 0.1, 0.36], 0x5E10B1, at: [0, 1.5, 0], in: parts); box([0.12, 0.3, 0.04], 0x5E10B1, at: [0.12, 1.36, -0.19], in: parts)
        case "crown": for x in [Float(-0.15), 0, 0.15] { box([0.08, 0.14, 0.08], 0xF2C230, at: [x, 2.18, 0], in: parts) }
            box([0.44, 0.06, 0.44], 0xF2C230, at: [0, 2.1, 0], in: parts)
        case "halo": box([0.5, 0.03, 0.06], 0xFDD166, at: [0, 2.3, -0.22], in: parts); box([0.5, 0.03, 0.06], 0xFDD166, at: [0, 2.3, 0.22], in: parts)
            box([0.06, 0.03, 0.5], 0xFDD166, at: [-0.22, 2.3, 0], in: parts); box([0.06, 0.03, 0.5], 0xFDD166, at: [0.22, 2.3, 0], in: parts)
        default: break
        }
    }
}
